#!/usr/bin/env bash
# Build the Android APK on this machine: pinned DrKLO/Telegram + our patches +
# android/customize.sh, the same recipe as the CI workflow. Signs with the key
# in .secrets/ and uses the api_id in .env, so the APK updates over a CI one.
#
# Usage: android/build.sh [--install]   (--install: adb install to a USB phone)
# Needs once: JDK 17 (pacman jdk17-openjdk) and, in ~/Android/Sdk,
#   platforms;android-36 build-tools;36.0.0 ndk;27.2.12479018 cmake;3.22.1
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
cache=${TG_CUSTOM_CACHE:-$HOME/.cache/telegram-custom}
# Patch tree: branch "custom" = upstream + our patches as commits; write
# patches here (see USAGE.md). Build tree: a worktree that customize.sh dirties
# (package id, icon, signing), so secrets never land in a commit.
tree=$cache/android-src
bld=$cache/android-build
ref=$(grep -v '^#' "$here/UPSTREAM" | head -1)

export JAVA_HOME=${JAVA_HOME_17:-/usr/lib/jvm/java-17-openjdk}
export ANDROID_HOME=${ANDROID_HOME:-$HOME/Android/Sdk}
[[ -x $JAVA_HOME/bin/java ]] || { echo "error: no JDK 17 at $JAVA_HOME (sudo pacman -S jdk17-openjdk)" >&2; exit 1; }
[[ -d $ANDROID_HOME/ndk/27.2.12479018 ]] || { echo "error: NDK 27.2.12479018 missing in $ANDROID_HOME (see header)" >&2; exit 1; }

# 1. patch tree at the pinned commit + our series. Refuse on uncommitted work:
#    that is a patch being written, export it first.
[[ -d $tree/.git ]] || git clone -q https://github.com/DrKLO/Telegram.git "$tree"
git -C "$tree" cat-file -e "$ref^{commit}" 2>/dev/null || git -C "$tree" fetch -q origin
if [[ -n $(git -C "$tree" status --porcelain) ]]; then
    echo "error: $tree has uncommitted changes" >&2
    exit 1
fi
git -C "$tree" checkout -q -B custom "$ref"
shopt -s nullglob
patches=("$here"/patches/*.patch)
(( ${#patches[@]} )) && git -C "$tree" -c user.name=custom -c user.email=custom@localhost am -q "${patches[@]}"
echo "patches: ${#patches[@]}"

# 2. build tree: reset to "custom", keeping ignored build output (incremental).
[[ -d $bld ]] || git -C "$tree" worktree add -q --detach "$bld" custom
git -C "$bld" checkout -q -f --detach custom
git -C "$bld" clean -qfd
echo "sdk.dir=$ANDROID_HOME" > "$bld/local.properties"

# 3. customize with our secrets (never exported past this script)
set -a
[[ -f $root/.env ]] && source "$root/.env"
[[ -f $root/.secrets/android-signing.env ]] && source "$root/.secrets/android-signing.env"
set +a
[[ -f $root/.secrets/android-release.jks ]] && export ANDROID_KEYSTORE_B64=$(base64 -w0 "$root/.secrets/android-release.jks")
PATCHES_APPLIED=1 GRADLE_HEAP_GB=${GRADLE_HEAP_GB:-5} "$here/customize.sh" "$bld"

# 4. build, memory-capped like desktop/build.sh (the OOM killer here prefers
#    the Electron apps over the compiler)
cd "$bld"
systemd-run --user --scope --quiet -p MemoryHigh=8G -p MemoryMax=10G \
    ./gradlew --no-daemon :TMessagesProj_App:assembleAfatRelease
apk=$(ls TMessagesProj_App/build/outputs/apk/afat/release/*.apk | head -1)
cp "$apk" "$cache/tg-custom.apk"
echo "apk: $cache/tg-custom.apk"
[[ ${1:-} == --install ]] && adb install -r "$cache/tg-custom.apk"
exit 0
