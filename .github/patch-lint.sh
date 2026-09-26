#!/usr/bin/env bash
# The promise in the README, checked on every push: our patches add no network
# endpoint, no network code, no permission and no dependency. Only the lines a
# patch adds are scanned; what upstream Telegram itself does is upstream's.
# A deliberate exception needs "lint-ok: <reason>" on the same added line.
set -euo pipefail
cd "$(dirname "$0")/.."

rules=(
    'URL or host|https?://|wss?://|ftp://'
    'network code|HttpURLConnection|HttpsURLConnection|okhttp|OkHttpClient|new URL\(|Socket\(|DatagramSocket|InetAddress|WebSocket|WebView|QNetworkAccessManager|QTcpSocket|QUdpSocket|QWebSocket|curl_easy'
    'Android permission|<uses-permission|<permission '
    'dependency|implementation[ (]|api[ (]["'"'"']|classpath |find_package|FetchContent|ExternalProject_Add|System\.loadLibrary'
)

fail=0
for p in android/patches/*.patch desktop/patches/*.patch; do
    added=$(grep -n '^+' "$p" | grep -v '^[0-9]*:+++ ' | grep -v 'lint-ok:' || true)
    for r in "${rules[@]}"; do
        name=${r%%|*}
        hits=$(grep -E "${r#*|}" <<<"$added" || true)
        if [[ -n $hits ]]; then
            echo "::error file=$p::adds $name"
            sed "s|^|    $p:|" <<<"$hits"
            fail=1
        fi
    done
done
(( fail )) && exit 1
echo "ok: $(ls android/patches/*.patch desktop/patches/*.patch | wc -l) patches, no network endpoints, network code, permissions or dependencies added"
