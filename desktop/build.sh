#!/usr/bin/env bash
# Build our Telegram Desktop: pinned upstream tarball + desktop/patches, against
# Manjaro's system libs (the Arch PKGBUILD recipe), installed to its own prefix
# with its own data dir. Never touches the pacman telegram-desktop.
#
# Usage: desktop/build.sh [--fetch-only]
# Env:   JOBS (default 4), TG_API_ID/TG_API_HASH (or put them in .env),
#        KEEP_GOING=1 to collect every compile error in one run
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
source "$here/UPSTREAM"
[[ -f $root/.env ]] && source "$root/.env"

ver=$TDESKTOP_VERSION
# Source + build trees live outside the project: "AI Projects" has a space,
# and gobject-introspection's libtool step splits paths on it.
cache=${TG_CUSTOM_CACHE:-$HOME/.cache/telegram-custom}
src=$cache/src
tree=$src/tdesktop-$ver-full
td=$src/td
bld=$cache/build/desktop
jobs=${JOBS:-4}
# Official snap key; Arch's package uses it with Telegram's blessing (see the
# PKGBUILD comment). Own key from .env wins.
api_id=${TG_API_ID:-611335}
api_hash=${TG_API_HASH:-d524b414d21f4d37f08684c1df41ac9c}

mkdir -p "$src"

# 1. fetch + verify
tarball=$src/tdesktop-$ver-full.tar.gz
if [[ ! -f $tarball ]]; then
    curl -fL --retry 3 -o "$tarball.part" \
        "https://github.com/telegramdesktop/tdesktop/releases/download/v$ver/tdesktop-$ver-full.tar.gz"
    mv "$tarball.part" "$tarball"
fi
echo "$TDESKTOP_SHA512  $tarball" | sha512sum -c --quiet
[[ -d $td ]] || git clone -q https://github.com/tdlib/td.git "$td"
git -C "$td" checkout -q "$TD_COMMIT"
[[ ${1:-} == --fetch-only ]] && exit 0

# 2. unpack into a git tree (tag "upstream") so patches are plain git commits
if [[ ! -d $tree/.git ]]; then
    tar -C "$src" -xzf "$tarball"
    git -C "$tree" init -q
    git -C "$tree" add -A
    git -C "$tree" -c user.name=upstream -c user.email=upstream@localhost commit -qm "tdesktop $ver"
    git -C "$tree" tag upstream
fi

# 3. re-apply the patch series from scratch. Refuse on uncommitted work: that
#    is a patch being written, export it first (see USAGE.md).
if [[ -n $(git -C "$tree" status --porcelain) ]]; then
    echo "error: $tree has uncommitted changes" >&2
    exit 1
fi
git -C "$tree" checkout -q -B custom upstream
shopt -s nullglob
patches=("$here"/patches/*.patch)
if (( ${#patches[@]} )); then
    git -C "$tree" -c user.name=custom -c user.email=custom@localhost am -q "${patches[@]}"
fi
echo "patches: ${#patches[@]}"
# Purple logo: generated from the stock PNGs, committed so the tree stays clean.
python3 "$here/purple.py" "$tree"
git -C "$tree" -c user.name=custom -c user.email=custom@localhost commit -qam "generated: purple icons"

# 4. tde2e (end-to-end call encryption lib from tdlib), built once
if [[ ! -d $td/install ]]; then
    cmake -S "$td" -B "$td/build" -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$td/install" -Wno-dev -DTD_E2E_ONLY=ON
    cmake --build "$td/build" -j "$jobs"
    cmake --install "$td/build"
fi

# 5. configure + build. Locally memory-capped: the kernel OOM killer here
#    prefers Electron apps (Claude) over the compiler, see PC Manager
#    oom_kills_claude.md. ccache when present (CI always has it).
launcher=()
command -v ccache > /dev/null && launcher=(
    -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
cmake -S "$tree" -B "$bld" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/ \
    "${launcher[@]}" \
    -Dtde2e_DIR="$td/install/lib/cmake/tde2e" \
    -DTDESKTOP_API_ID="$api_id" \
    -DTDESKTOP_API_HASH="$api_hash"
keep=()
[[ -n ${KEEP_GOING:-} ]] && keep=(-- -k 0)
if [[ -n ${CI:-} ]]; then
    cmake --build "$bld" -j "$jobs" "${keep[@]}"
else
    systemd-run --user --scope --quiet -p MemoryHigh=7G -p MemoryMax=9G \
        cmake --build "$bld" -j "$jobs" "${keep[@]}"
fi

# 6. stage the install; locally, swap it in (desktop/install.sh keeps the
#    previous build for rollback). CI tars the stage instead.
stage=$cache/stage
rm -rf "$stage"
DESTDIR="$stage" cmake --install "$bld" > /dev/null
[[ -n ${CI:-} ]] || "$here/install.sh" "$stage"
