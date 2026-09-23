#!/usr/bin/env bash
# Install a built Telegram Custom into ~/.local/opt/telegram-custom, keeping
# the previous build as telegram-custom.prev (undo: desktop/install.sh --rollback).
#
# Usage: desktop/install.sh <stage-dir>   (from desktop/build.sh)
#        desktop/install.sh --from-ci     (newest successful GitHub build)
#        desktop/install.sh --rollback
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
prefix=$HOME/.local/opt/telegram-custom
workdir=$HOME/.local/share/TelegramCustom

case ${1:?usage: install.sh <stage-dir> | --from-ci | --rollback} in
--rollback)
    [[ -d $prefix.prev ]] || { echo "no previous build to roll back to" >&2; exit 1; }
    mv "$prefix" "$prefix.rollback-tmp"
    mv "$prefix.prev" "$prefix"
    mv "$prefix.rollback-tmp" "$prefix.prev"
    rollback=1
    stage= ;;
--from-ci)
    dl=$(mktemp -d)
    trap 'rm -rf "$dl"' EXIT
    run=$(gh run list -R behdadmansouri/telegram-custom -w desktop -s success -L 1 --json databaseId -q '.[0].databaseId')
    [[ -n $run ]] || { echo "no successful desktop build yet" >&2; exit 1; }
    gh run download "$run" -R behdadmansouri/telegram-custom -D "$dl"
    mkdir "$dl/stage"
    tar -C "$dl/stage" -xzf "$dl"/*/telegram-custom.tar.gz
    stage=$dl/stage ;;
*)
    stage=$1 ;;
esac

[[ -n $stage && -d $stage/usr ]] && stage=$stage/usr   # cmake installs under /usr
if [[ -z ${rollback:-} ]]; then
    [[ -x $stage/bin/Telegram ]] || { echo "no bin/Telegram in $stage" >&2; exit 1; }
    mkdir -p "$(dirname "$prefix")"
    rm -rf "$prefix.prev"
    [[ -d $prefix ]] && mv "$prefix" "$prefix.prev"
    cp -a "$stage" "$prefix"
fi

# Launcher + icons under our own app id (patch "Own Linux app id"), so the
# shell shows our purple icon, not the official client's. Own data dir: the
# official client keeps ~/.local/share/TelegramDesktop.
id=org.telegram.desktop.custom
icons=$HOME/.local/share/icons/hicolor
for png in "$prefix"/share/icons/hicolor/*/apps/org.telegram.desktop.png; do
    size=$(basename "$(dirname "$(dirname "$png")")")
    mkdir -p "$icons/$size/apps"
    cp "$png" "$icons/$size/apps/$id.png"
done
touch "$icons"
rm -f "$HOME/.local/share/applications/telegram-custom.desktop"   # pre-app-id launcher
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/$id.desktop" <<DESKTOP
[Desktop Entry]
Name=Telegram Custom
Comment=Own build of Telegram Desktop
Exec="$prefix/bin/Telegram" -workdir "$workdir" -- %u
Icon=$id
Terminal=false
Type=Application
Categories=Chat;Network;InstantMessaging;Qt;
DESKTOP
if [[ -n ${rollback:-} ]]; then
    echo "rolled back (the build you left is now $prefix.prev)"
else
    echo "installed: $prefix/bin/Telegram (data: $workdir; previous build: $prefix.prev)"
fi
