#!/usr/bin/env bash
# Publish one CI build as a GitHub Release: the files, their SHA-256, and the
# patch list, so the release page says exactly what differs from upstream.
# Then, when TG_BOT_TOKEN and TG_CHANNEL are set (repo secrets), announces it
# on the Telegram channel: the file itself if it fits the bot limit, else a link.
# Usage (in a workflow, GH_TOKEN set): .github/release.sh android|desktop <version> <upstream> <file>...
set -euo pipefail

platform=$1 version=$2 upstream=$3
shift 3
case $platform in
    android) title="Android $version" latest=true ;;
    desktop) title="Desktop $version (Manjaro/Arch)" latest=false ;;
esac
tag="$platform-v$version-b$GITHUB_RUN_NUMBER"

{
    echo "Stock Telegram ${platform^} $version ($upstream) plus these patches, nothing else:"
    echo
    for p in "$platform"/patches/*.patch; do
        subject=$(awk '/^Subject: /{s=$0; while ((getline l) > 0 && l ~ /^ /) s = s l; print s; exit}' "$p")
        echo "- ${subject#Subject: \[PATCH\] }, +$(grep -c '^+[^+]' "$p") lines ([source]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/$GITHUB_SHA/$p))"
    done
    echo
    [[ $platform == desktop ]] && echo 'Install: unpack into a folder, then run `desktop/install.sh <folder>` from a clone of this repo.' && echo
    echo "Built by [this workflow run]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID) from commit $GITHUB_SHA."
    echo
    echo '```'
    (cd "$(dirname "$1")" && for f in "$@"; do sha256sum "$(basename "$f")"; done)
    echo '```'
} > notes.md

gh release create "$tag" "$@" --target "$GITHUB_SHA" --title "$title (build $GITHUB_RUN_NUMBER)" \
    --notes-file notes.md --latest=$latest

[[ -n ${TG_BOT_TOKEN:-} && -n ${TG_CHANNEL:-} ]] || { echo "no TG_BOT_TOKEN/TG_CHANNEL: not announcing"; exit 0; }
url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$tag"
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
caption=$(
    echo "<b>TG Custom · $(esc <<<"$title")</b> (build $GITHUB_RUN_NUMBER)"
    echo "Stock Telegram $version plus:"
    for p in "$platform"/patches/*.patch; do
        subject=$(awk '/^Subject: /{s=$0; while ((getline l) > 0 && l ~ /^ /) s = s l; print s; exit}' "$p")
        echo "• $(esc <<<"${subject#Subject: \[PATCH\] }")"
    done
    echo
    echo "<a href=\"$url\">Release notes, checksums, source</a>"
)
api="https://api.telegram.org/bot$TG_BOT_TOKEN"
if (( $(stat -c %s "$1") < 50000000 )); then   # Bot API upload limit
    curl -sS --fail-with-body -o /dev/null -F chat_id="$TG_CHANNEL" -F parse_mode=HTML \
        -F caption="$caption" -F document=@"$1" "$api/sendDocument"
else
    curl -sS --fail-with-body -o /dev/null -F chat_id="$TG_CHANNEL" -F parse_mode=HTML \
        -F text="$caption" "$api/sendMessage"
fi
echo "announced on $TG_CHANNEL"
