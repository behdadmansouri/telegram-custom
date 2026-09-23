#!/usr/bin/env bash
# Turn a stock DrKLO/Telegram checkout into our build: own package id and
# label, arm64 only, our patches. Signing and api_id come in via env (CI
# secrets), never from the repo.
# Usage: android/customize.sh <path-to-DrKLO-checkout>
set -euo pipefail

tg=$1
here=$(cd "$(dirname "$0")" && pwd)
pkg=${APP_PACKAGE:-org.telegram.messenger.custom}

cd "$tg"

# Our patch series, applied in order.
shopt -s nullglob
for p in "$here"/patches/*.patch; do
    echo "applying $(basename "$p")"
    git apply --whitespace=nowarn "$p"
done

# Purple launcher icon, same hue rotation as desktop/purple.py. Release uses
# @mipmap/ic_launcher(_round): the legacy PNGs, and on API 26+ the adaptive
# icon whose blue is the gradient in drawable/icon_background_sa.xml. The
# foreground plane, the shading overlay and the monochrome layer are white or
# themed and stay.
python3 - "$here/../desktop" <<'EOF'
import glob, os, re, sys, tempfile
sys.path.insert(0, sys.argv[1])
from PIL import Image
from purple import rotate

res = "TMessagesProj/src/main/res/"
pngs = sorted(glob.glob(res + "mipmap-*/ic_launcher.png") + glob.glob(res + "mipmap-*/ic_launcher_round.png"))
assert pngs and all(rotate(p) > 0 for p in pngs), "launcher PNGs missing or not blue"

def rot_hex(h):  # one pixel through rotate(), so the math is the same
    fd, tmp = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    Image.new("RGBA", (1, 1), "#" + h).save(tmp)
    rotate(tmp)
    r, g, b, _ = Image.open(tmp).getpixel((0, 0))
    os.remove(tmp)
    return "%02X%02X%02X" % (r, g, b)

f = res + "drawable/icon_background_sa.xml"
s = open(f).read()
t = re.sub(r'(android:(?:start|end)Color=")#([0-9A-Fa-f]{6})"',
           lambda m: m.group(1) + "#" + rot_hex(m.group(2)) + '"', s)
assert t != s, f + ": no gradient colors found"
open(f, "w").write(t)
print(f"icon: {len(pngs)} PNGs + adaptive background rotated purple")
EOF

# Own package id so it installs next to the Play Store Telegram.
sed -i "s/^APP_PACKAGE=.*/APP_PACKAGE=$pkg/" gradle.properties

# google-services refuses a package it has no client entry for. Clone the
# stock entry under our id. FCM push will not work for this id either way
# (the Firebase project is Telegram's); the app falls back to its own
# background connection.
python3 - "$pkg" <<'EOF'
import json, sys
pkg = sys.argv[1]
f = "TMessagesProj_App/google-services.json"
d = json.load(open(f))
if not any(c["client_info"]["android_client_info"]["package_name"] == pkg for c in d["client"]):
    c = json.loads(json.dumps(d["client"][0]))
    c["client_info"]["android_client_info"]["package_name"] = pkg
    d["client"].append(c)
json.dump(d, open(f, "w"), indent=2)
EOF

# arm64 only: a quarter of the native build time; every phone since ~2017.
python3 - <<'EOF'
import re
f = "TMessagesProj_App/build.gradle"
s = open(f).read()
s = re.sub(r'(afat \{\s*ndk \{\s*abiFilters )[^\n]*', r'\1"arm64-v8a"', s, count=1)
open(f, "w").write(s)
EOF
grep -m1 -A2 '^        afat {' TMessagesProj_App/build.gradle | grep abiFilters

# Launcher label, so it can't be mistaken for the official app.
sed -i 's|<string name="AppName">Telegram</string>|<string name="AppName">TG Custom</string>|' \
    TMessagesProj/src/main/res/values/strings.xml

# Own api_id when provided; otherwise upstream's default stays.
bv=TMessagesProj/src/main/java/org/telegram/messenger/BuildVars.java
if [[ -n ${TG_API_ID:-} && -n ${TG_API_HASH:-} ]]; then
    sed -i -E "s/(APP_ID = )[0-9]+;/\1$TG_API_ID;/; s/(APP_HASH = )\"[0-9a-f]+\";/\1\"$TG_API_HASH\";/" "$bv"
    echo "api_id: own"
else
    echo "api_id: upstream default"
fi

# Signing key, stable across builds so updates install over each other.
if [[ -n ${ANDROID_KEYSTORE_B64:-} ]]; then
    base64 -d <<<"$ANDROID_KEYSTORE_B64" > TMessagesProj/config/release.keystore
    sed -i -E "s/^RELEASE_KEY_PASSWORD=.*/RELEASE_KEY_PASSWORD=$ANDROID_KEY_PASSWORD/; s/^RELEASE_KEY_ALIAS=.*/RELEASE_KEY_ALIAS=$ANDROID_KEY_ALIAS/; s/^RELEASE_STORE_PASSWORD=.*/RELEASE_STORE_PASSWORD=$ANDROID_KEYSTORE_PASSWORD/" gradle.properties
    echo "signing: own key"
else
    echo "signing: upstream test key (APK will not update over an own-key install)"
fi

# Heap sized to the machine: upstream asks for 8g, a CI runner may have less.
mem_gb=$(awk '/MemTotal/ {print int($2/1048576)}' /proc/meminfo)
heap=$(( mem_gb * 7 / 10 )); (( heap < 3 )) && heap=3
sed -i -E "s/^org.gradle.jvmargs=.*/org.gradle.jvmargs=-Xmx${heap}g -XX:MaxMetaspaceSize=1g/" gradle.properties
echo "gradle heap: ${heap}g of ${mem_gb}g"
