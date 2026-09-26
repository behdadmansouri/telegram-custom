#!/usr/bin/env bash
# Publish one CI build as a GitHub Release: the files, their SHA-256, and the
# patch list, so the release page says exactly what differs from upstream.
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
        echo "- ${subject#Subject: \[PATCH\] } ([source]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/blob/$GITHUB_SHA/$p))"
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
