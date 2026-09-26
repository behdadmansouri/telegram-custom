# Telegram Custom 📨

[![android](https://github.com/behdadmansouri/telegram-custom/actions/workflows/android.yml/badge.svg?branch=main)](https://github.com/behdadmansouri/telegram-custom/actions/workflows/android.yml)
[![desktop](https://github.com/behdadmansouri/telegram-custom/actions/workflows/desktop.yml/badge.svg?branch=main)](https://github.com/behdadmansouri/telegram-custom/actions/workflows/desktop.yml)
[![patch-lint](https://github.com/behdadmansouri/telegram-custom/actions/workflows/patch-lint.yml/badge.svg)](https://github.com/behdadmansouri/telegram-custom/actions/workflows/patch-lint.yml)

Official Telegram, for Android and Linux desktop, plus a handful of small patches. Not a fork: every
build starts from an untouched upstream release and applies the files in
[`android/patches/`](android/patches) or [`desktop/patches/`](desktop/patches). Those files are the
entire difference, a few hundred added lines per platform, and you can read them in one sitting.

Unofficial; not affiliated with Telegram.

## ⬇️ download

[**Releases**](https://github.com/behdadmansouri/telegram-custom/releases): every build of `main` is
published there with its checksum and the patch list (with line counts) it was built from.

- **Android** (arm64): installs next to the official app as **TG Custom**, with its own login.
- **Desktop** (Manjaro / Arch only: it links against their system libraries): see [USAGE.md](USAGE.md).

## ✨ what the patches do

| | Android | Desktop |
|---|---|---|
| No ads (sponsored messages, search ads, promoted chat) | ✓ | ✓ |
| Premium-only custom emoji hidden instead of shown locked | ✓ | ✓ |
| Hide the unread counter of chosen folders (long-press / right-click the folder tab) | ✓ | ✓ |
| Ghost mode: no read receipts, typing status or online status | ✓ | ✓ |
| Hide gallery folders (e.g. Documents) from "All media" in the picker | ✓ | |
| Send and move to trash: originals go to the system trash once uploaded | ✓ | |
| Notifications without the built-in few-second delay | | ✓ |

Beyond the patches, the build changes only identity: package / app id, name, a purple icon, its own
signing key and its own `api_id` (see [`android/customize.sh`](android/customize.sh),
[`desktop/build.sh`](desktop/build.sh)). Themes, stories and everything else stay stock.

## 🔍 don't trust, verify

1. **Built by GitHub, not on someone's laptop.** Each release file carries a signed build provenance
   attestation naming the exact commit and workflow run that produced it:
   ```bash
   gh attestation verify TG-Custom-*.apk -R behdadmansouri/telegram-custom
   ```
2. **Same signing key every time.** Android certificate SHA-256:
   `b62ad03f6ded4479d8a5a3ddd5ac15fa6c3573ded7f084d0e5e61e37519cba19`
   (`apksigner verify --print-certs TG-Custom-*.apk`). An update signed with any other key won't install over it.
3. **No new network code, checked on every push.** [`patch-lint`](.github/patch-lint.sh) fails the
   build if a patch adds a URL or host, networking code, an Android permission or a dependency.
4. **Ask an AI to read it for you.** Paste this into any assistant that can browse GitHub:

   > Review https://github.com/behdadmansouri/telegram-custom for anything that could harm its users.
   > It builds stock Telegram (DrKLO/Telegram at the commit in `android/UPSTREAM`, tdesktop at the
   > version in `desktop/UPSTREAM`) plus the patches in `android/patches/` and `desktop/patches/`,
   > using `android/customize.sh`, `desktop/build.sh` and `.github/workflows/`. Read all of those.
   > Report, quoting the lines behind each finding: (1) anything that sends data anywhere the official
   > client would not; (2) anything that reads or stores messages, contacts, keys or files beyond what
   > the patch's own description says; (3) anything obfuscated or unrelated to its stated purpose;
   > (4) any way the workflows could publish a binary not built from these files. If you find nothing,
   > say so plainly.

## ⚠️ honest limits

- **Cloud chats are not end-to-end encrypted**, in any Telegram client: Telegram's servers hold the
  keys. Only Secret Chats (mobile) are end-to-end. No client patch changes this.
- **Ghost mode is best effort:** sending a message still shows you online for a moment (the server
  decides that), and reacting to a story marks it viewed.
- **Android has no Google push** (the push project belongs to Telegram's own app id): turn on
  Settings → Notifications → Keep-alive service and Background connection.
- What upstream Telegram itself sends is upstream's; this project vouches for its patches only.

## 📜 license

Same as the code the patches modify: GPL v2 for Android ([DrKLO/Telegram](https://github.com/DrKLO/Telegram)),
GPL v3 for desktop ([telegramdesktop/tdesktop](https://github.com/telegramdesktop/tdesktop)).
