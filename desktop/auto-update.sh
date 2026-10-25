#!/usr/bin/env bash
# Daily automatic update of Telegram Custom on this machine from the newest
# desktop GitHub Release, with a desktop notification when something changed
# or went wrong (silent when already up to date).
#
# Usage: desktop/auto-update.sh --enable    copy this script and install.sh to
#                                           ~/.local/lib/telegram-custom and
#                                           start a daily systemd user timer
#        desktop/auto-update.sh --disable   stop and remove the timer
#        desktop/auto-update.sh             one run (what the timer does)
set -euo pipefail

lib=$HOME/.local/lib/telegram-custom
units=$HOME/.config/systemd/user
name=telegram-custom-update
repo=behdadmansouri/telegram-custom
prefix=$HOME/.local/opt/telegram-custom

case ${1:-} in
--enable)
    here=$(cd "$(dirname "$0")" && pwd)
    mkdir -p "$lib" "$units"
    # A copy, so the timer keeps working whatever branch the checkout is on.
    install -m 755 "$here/install.sh" "$here/auto-update.sh" "$lib/"
    cat > "$units/$name.service" <<UNIT
[Unit]
Description=Update Telegram Custom from its newest GitHub Release
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart="$lib/auto-update.sh"
UNIT
    cat > "$units/$name.timer" <<UNIT
[Unit]
Description=Daily Telegram Custom update

[Timer]
OnCalendar=*-*-* 10:00
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
UNIT
    systemctl --user daemon-reload
    systemctl --user enable --now "$name.timer"
    systemctl --user list-timers "$name.timer" --no-pager
    exit 0 ;;
--disable)
    systemctl --user disable --now "$name.timer" 2>/dev/null || true
    rm -f "$units/$name.service" "$units/$name.timer"
    systemctl --user daemon-reload
    echo "timer removed ($lib kept)"
    exit 0 ;;
esac

notify() { notify-send -a "Telegram Custom" -i org.telegram.desktop.custom "$1" "$2" 2>/dev/null || true; echo "$1: $2"; }

before=$(cat "$prefix/RELEASE" 2>/dev/null || echo none)
if ! out=$("$(dirname "$0")/install.sh" --release 2>&1); then
    notify "⚠️ Telegram Custom not updated" "$(tail -2 <<<"$out")"
    exit 1
fi
after=$(cat "$prefix/RELEASE" 2>/dev/null || echo none)
[[ $after == "$before" ]] && { echo "$out"; exit 0; }

# Check the result against GitHub itself, not install.sh's own word.
latest=$(gh release list -R "$repo" -L 100 --exclude-drafts --json tagName -q '.[].tagName' | grep '^desktop-v' | head -1)
if [[ $after != "$latest" ]]; then
    notify "⚠️ Telegram Custom update incomplete" "installed $after, newest is $latest"
    exit 1
fi
if pgrep -f "^$prefix(\.prev)?/bin/Telegram" > /dev/null; then
    notify "🟣 Telegram Custom updated" "${after#desktop-v}: quit and reopen it to switch (rollback: install.sh --rollback)"
else
    notify "🟣 Telegram Custom updated" "${after#desktop-v} is ready"
fi
