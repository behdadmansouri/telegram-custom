#!/usr/bin/env bash
# Fingerprint of an Arch telegram-desktop PKGBUILD's build recipe: depends,
# makedepends, sources and the prepare/build/package functions, with the
# version, td commit and checksums masked. Same fingerprint = only the version
# moved, so desktop/build.sh still matches it and the bump can be automatic.
# Usage: .github/pkgbuild-recipe.sh <PKGBUILD>   (prints: pkgver td_commit sha512 fingerprint)
set -euo pipefail
# shellcheck disable=SC1090
source "$1"
fp=$(
    {
        printf 'dep %s\n' "${depends[@]}" | sort
        printf 'make %s\n' "${makedepends[@]}" | sort
        printf 'src %s\n' "${source[@]}"
        declare -f prepare build package 2>/dev/null || true
    } | sed "s/$pkgver/@VER@/g; s/$_td_commit/@TD@/g" | sha256sum | cut -c1-16
)
echo "$pkgver $_td_commit ${sha512sums[0]} $fp"
