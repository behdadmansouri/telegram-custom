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
    echo "rolled back (the build you left is now $prefix.prev)"
    exit 0 ;;
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

[[ -x $stage/bin/Telegram ]] || { echo "no bin/Telegram in $stage" >&2; exit 1; }
mkdir -p "$(dirname "$prefix")"
rm -rf "$prefix.prev"
[[ -d $prefix ]] && mv "$prefix" "$prefix.prev"
cp -a "$stage" "$prefix"

# Own data dir: the official client keeps ~/.local/share/TelegramDesktop.
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/telegram-custom.desktop" <<DESKTOP
[Desktop Entry]
Name=Telegram Custom
Comment=Own build of Telegram Desktop
Exec="$prefix/bin/Telegram" -workdir "$workdir" -- %u
Icon=org.telegram.desktop
Terminal=false
Type=Application
Categories=Chat;Network;InstantMessaging;Qt;
StartupWMClass=TelegramDesktop
DESKTOP
echo "installed: $prefix/bin/Telegram (data: $workdir; previous build: $prefix.prev)"
