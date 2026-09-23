# CLAUDE.md - Telegram Custom 📨

Own builds of Telegram Desktop and Android: stock upstream + a small patch series of features
learned from AyuGram. Split out of `PC Manager ⚙️/` 2026-09-23.

## Decisions
- **Base: stock upstream, never a fork.** Desktop `telegramdesktop/tdesktop`, Android `DrKLO/Telegram`.
  AyuGram is a reference to read, not a base: its diff is someone else's to rebase through and trust.
  64Gram dropped 2026-09-23 (one maintainer, feature list frozen since 2024-08).
- **Surgical patches.** Each feature = one small patch; no reformatting, no renames upstream would conflict with.
- **Desktop builds locally** against Manjaro's system libs (Arch PKGBUILD recipe), pinned to the
  version Manjaro stable packages. Installs to `~/.local/opt/telegram-custom`, data in
  `~/.local/share/TelegramCustom`; the pacman `telegram-desktop` stays as fallback.
- **Android builds on GitHub Actions** (no local SDK), arm64 only, package `org.telegram.messenger.custom`.
- **Secrets never in git:** signing key + passwords in `.secrets/` (gitignored, back it up: losing
  it means uninstall-to-update on the phone), copies in GitHub repo secrets. `api_id` in `.env`.
- **Upstream updates are ours:** bump the pin in `*/UPSTREAM`, rebuild, fix patches that no longer apply.

## Files
| File | Purpose | Created |
|---|---|---|
| TODO.md | work queue | 2026-09-23 |
| docs/plan.md | phased plan + what each AyuGram feature actually does | 2026-09-23 |
| desktop/UPSTREAM | pinned tdesktop version + hashes | 2026-09-23 |
| desktop/build.sh | fetch, patch, build, install desktop | 2026-09-23 |
| desktop/patches/ | desktop patch series (`git format-patch` output) | 2026-09-23 |
| android/UPSTREAM | pinned DrKLO/Telegram commit | 2026-09-23 |
| android/customize.sh | package id, label, arm64, signing, api_id, patches onto a DrKLO checkout | 2026-09-23 |
| android/patches/ | Android patch series | 2026-09-23 |
| .github/workflows/android.yml | CI build of the APK (artifact) | 2026-09-23 |
| memory/changelog.md | what shipped | 2026-09-23 |
| USAGE.md | how to build, install, update, write a patch | 2026-09-23 |
