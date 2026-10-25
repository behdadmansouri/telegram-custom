#!/usr/bin/env bash
# Caller guard for the media trust model (docs/trust.md 4.1). The trust gates
# sit on a fixed set of media entry points. When upstream calls one of them
# from a file it never did, or stops calling it from a file where a hook sits,
# a path around the gates may have opened: fail, so a human reads the new
# caller before it ships. A changed count inside a known file only warns
# (upstream churns those files every release; an always-red guard gets
# updated blind).
#
# Usage: .github/media-callers.sh check|update <platform> <tree> [<rev>]
#   <rev>: count on that git rev of <tree> (desktop: the "upstream" tag, so
#   our own patches never count); without it, count the working files.
#   update rewrites <platform>'s lines of .github/media-callers.txt; do it in
#   the same commit as an upstream bump, after reading every new caller.
# Table: platform<TAB>pattern<TAB>file<TAB>count, counted on stock upstream.
set -euo pipefail

table=$(cd "$(dirname "$0")" && pwd)/media-callers.txt
mode=${1:?check or update}
platform=${2:?platform}
tree=${3:?tree}
rev=${4:-}

case $platform in
desktop)
    patterns=('AutoDownload::Should(' 'AutoDownload::ShouldAutoPlay('
        'autoLoadThumbnailAllowed(' 'loadThumbnail(' 'thumbnailWanted('
        'checkStickerLarge(' 'startPreloading(' 'PlainUrlLocation' 'f_udp_p2p')
    paths=(Telegram/SourceFiles) ;;
android)
    patterns=('canDownloadMedia(' 'canDownloadMediaType(' 'canPreloadStories('
        'getCurrentDownloadMask(' 'computeAutoDownload(' 'getForWebFile('
        'preloadStory(' 'udp_p2p' 'new ImageReceiver(')
    paths=(TMessagesProj/src/main/java) ;;
*)
    echo "unknown platform: $platform" >&2
    exit 2 ;;
esac

# "file:count" per file that contains the pattern.
count() {
    if [[ -n $rev ]]; then
        git -C "$tree" grep -c -F -e "$1" "$rev" -- "${paths[@]}" \
            | sed "s|^$rev:||" || true
    else
        (cd "$tree" && grep -rcF -e "$1" "${paths[@]}" | grep -v ':0$') || true
    fi
}

current=$(for p in "${patterns[@]}"; do
    count "$p" | while IFS= read -r line; do
        [[ -n $line ]] && printf '%s\t%s\t%s\t%s\n' \
            "$platform" "$p" "${line%:*}" "${line##*:}"
    done
done | sort)

[[ -f $table ]] || touch "$table"

if [[ $mode == update ]]; then
    { awk -F'\t' -v p="$platform" '$1 != p' "$table"; echo "$current"; } \
        | grep -v '^$' | sort > "$table.tmp"
    mv "$table.tmp" "$table"
    echo "updated $platform: $(grep -c . <<<"$current") lines"
    exit 0
fi

known=$(awk -F'\t' -v p="$platform" '$1 == p' "$table")
[[ -n $known ]] || { echo "::error::no $platform lines in $table (run update)"; exit 1; }
fail=0
while IFS=$'\t' read -r pl pat file n; do
    [[ -n ${file:-} ]] || continue
    old=$(awk -F'\t' -v p="$pl" -v q="$pat" -v f="$file" \
        '$1 == p && $2 == q && $3 == f { print $4 }' "$table")
    if [[ -z $old ]]; then
        echo "::error::$platform: new caller file for '$pat': $file ($n): classify it against the trust gates, then update"
        fail=1
    elif [[ $old != "$n" ]]; then
        echo "::warning::$platform: '$pat' in $file: $old -> $n calls"
    fi
done <<<"$current"
while IFS=$'\t' read -r pl pat file n; do
    [[ -n ${file:-} ]] || continue
    if ! grep -qF -- "$(printf '%s\t%s\t%s\t' "$pl" "$pat" "$file")" <<<"$current"; then
        echo "::error::$platform: '$pat' gone from $file (was $n): a hook site may have moved"
        fail=1
    fi
done <<<"$known"
(( fail )) && exit 1
echo "ok: $platform media callers match ($(grep -c . <<<"$current") pattern/file pairs)"
