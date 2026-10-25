#!/usr/bin/env bash
# Post a published release to the Telegram channel through the Bot API: the
# file itself when it fits the bot upload limit, otherwise a link. The caption
# says what changed since this platform's previous release, plus the patch list.
# Skips cleanly (exit 0, a notice in the run) while the secrets are unset.
#
# Usage (in a workflow, after .github/release.sh, or from announce.yml to
# re-post; GH_TOKEN, GH_REPO set; the tree checked out at the release commit):
#   .github/announce.sh android|desktop <tag> <file>
# Env: TELEGRAM_BOT_TOKEN, TELEGRAM_CHANNEL_ID (repo secrets)
set -euo pipefail

platform=$1 tag=$2 file=$3
if [[ -z ${TELEGRAM_BOT_TOKEN:-} || -z ${TELEGRAM_CHANNEL_ID:-} ]]; then
    echo "::notice::TELEGRAM_BOT_TOKEN or TELEGRAM_CHANNEL_ID not set: $tag not announced"
    exit 0
fi

url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/releases/tag/$tag"
read -r sha title < <(gh release view "$tag" --json targetCommitish,name -q '"\(.targetCommitish) \(.name)"')
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# Changelog: commit subjects touching this platform since its previous release
# (needs the full history: checkout with fetch-depth 0).
paths=("$platform")
[[ $platform == android ]] && paths+=(desktop/purple.py)
prev=$(gh release list -L 100 --json tagName -q '.[].tagName' | grep "^$platform-v" | grep -vx "$tag" | head -1 || true)
if [[ -n $prev ]]; then
    since=$(gh release view "$prev" --json targetCommitish -q .targetCommitish)
    changes=$(git log --no-merges --format=%s "$since..$sha" -- "${paths[@]}" 2>/dev/null || true)
    [[ -n $changes ]] || changes="Rebuild, no change to the app since $prev"
else
    changes=$(git log -1 --format=%s "$sha")
fi
n=$(wc -l <<<"$changes")

caption=$(
    echo "<b>TG Custom · $(esc <<<"$title")</b>"
    head -5 <<<"$changes" | cut -c1-90 | esc | sed 's/^/• /'
    (( n > 5 )) && echo "  (+$((n - 5)) more)"
    echo
    echo "Patches on stock Telegram:"
    for p in "$platform"/patches/*.patch; do
        subject=$(awk '/^Subject: /{s=$0; while ((getline l) > 0 && l ~ /^ /) s = s l; print s; exit}' "$p")
        echo "· $(esc <<<"${subject#Subject: \[PATCH\] }")"
    done
    echo
    echo "<a href=\"$url\">Release notes, checksums, source</a>"
)

api="https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN"
reply=$(mktemp)
# Bot API limits: 50 MB per uploaded file, 1024 characters per caption.
# --form-string: with -F a value starting with < or @ (the caption, an
# @channel) would be read as a file name.
if (( $(stat -c %s "$file") < 50000000 && ${#caption} <= 1024 )); then
    how="the file"
    code=$(curl -sS -o "$reply" -w '%{http_code}' --form-string chat_id="$TELEGRAM_CHANNEL_ID" \
        --form-string parse_mode=HTML --form-string caption="$caption" -F document=@"$file" "$api/sendDocument")
else
    how="a link ($(( $(stat -c %s "$file") / 1000000 )) MB is over the bot upload limit)"
    code=$(curl -sS -o "$reply" -w '%{http_code}' --form-string chat_id="$TELEGRAM_CHANNEL_ID" \
        --form-string parse_mode=HTML --form-string text="$caption" "$api/sendMessage")
fi
if [[ $code != 200 ]]; then
    echo "::error::Telegram refused the post (HTTP $code): $(jq -r .description "$reply" 2>/dev/null || cat "$reply")"
    exit 1
fi
echo "announced $tag on the channel as $how"
