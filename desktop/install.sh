#!/usr/bin/env bash
# Install a built Telegram Custom into ~/.local/opt/telegram-custom, keeping
# the previous build as telegram-custom.prev (undo: desktop/install.sh --rollback).
#
# Usage: desktop/install.sh --release     (install or update: newest desktop
#                                          Release, provenance-checked)
#        desktop/install.sh --from-ci     (newest successful run on any branch,
#                                          for trying a feature branch)
#        desktop/install.sh --rollback
#        desktop/install.sh <stage-dir>   (a stage dir from desktop/build.sh)
set -euo pipefail

repo=behdadmansouri/telegram-custom
prefix=$HOME/.local/opt/telegram-custom
workdir=$HOME/.local/share/TelegramCustom

case ${1:?usage: install.sh --release | --from-ci | --rollback | <stage-dir>} in
--release)
    tag=$(gh release list -R "$repo" -L 100 --exclude-drafts --json tagName -q '.[].tagName' \
        | grep '^desktop-v' | head -1 || true)
    [[ -n $tag ]] || { echo "no desktop release yet" >&2; exit 1; }
    if [[ $(cat "$prefix/RELEASE" 2>/dev/null) == "$tag" ]]; then
        echo "up to date: $tag"
        exit 0
    fi
    dl=$(mktemp -d)
    trap 'rm -rf "$dl"' EXIT
    gh release download "$tag" -R "$repo" -p '*.tar.gz' -D "$dl"
    # Proof the file was built by this repo's workflow, not uploaded by hand.
    gh attestation verify "$dl"/*.tar.gz -R "$repo" > /dev/null
    mkdir "$dl/stage"
    tar -C "$dl/stage" -xzf "$dl"/*.tar.gz
    release=$tag
    stage=$dl/stage ;;
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
    run=$(gh run list -R "$repo" -w desktop -s success -L 1 --json databaseId -q '.[0].databaseId')
    [[ -n $run ]] || { echo "no successful desktop build yet" >&2; exit 1; }
    gh run download "$run" -R "$repo" -D "$dl"
    mkdir "$dl/stage"
    tar -C "$dl/stage" -xzf "$dl"/*/telegram-custom.tar.gz
    stage=$dl/stage ;;
*)
    stage=$1 ;;
esac

[[ -n $stage && -d $stage/usr ]] && stage=$stage/usr   # cmake installs under /usr
if [[ -z ${rollback:-} ]]; then
    [[ -x $stage/bin/Telegram ]] || { echo "no bin/Telegram in $stage" >&2; exit 1; }
    # CI links against Manjaro stable's current libs: refuse before swapping
    # anything if this machine lacks one (it needs a system update first).
    missing=$(ldd "$stage/bin/Telegram" | awk '/not found/ {print $1}')
    if [[ -n $missing ]]; then
        echo "not installed: missing libraries (update the system first):" $missing >&2
        exit 1
    fi
    mkdir -p "$(dirname "$prefix")"
    rm -rf "$prefix.prev"
    [[ -d $prefix ]] && mv "$prefix" "$prefix.prev"
    cp -a "$stage" "$prefix"
    [[ -n ${release:-} ]] && echo "$release" > "$prefix/RELEASE"
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
    echo "installed ${release:-}: $prefix/bin/Telegram (data: $workdir; previous build: $prefix.prev)"
fi
if pgrep -f "^$prefix(\.prev)?/bin/Telegram" > /dev/null; then
    echo "Telegram Custom is running the old build: quit and reopen it to switch."
fi
