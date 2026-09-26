# CLAUDE.md - Telegram Custom 📨

Own builds of Telegram Desktop and Android: stock upstream + a small patch series of features
learned from AyuGram. Split out of `PC Manager ⚙️/` 2026-09-23.

## Decisions
- **Base: stock upstream, never a fork.** Desktop `telegramdesktop/tdesktop`, Android `DrKLO/Telegram`.
  AyuGram is a reference to read, not a base: its diff is someone else's to rebase through and trust.
  64Gram dropped 2026-09-23 (one maintainer, feature list frozen since 2024-08).
- **Surgical patches.** Each feature = one small patch; no reformatting, no renames upstream would conflict with.
- **Desktop builds against Manjaro stable's system libs** (Arch PKGBUILD recipe), pinned to the
  version Manjaro stable packages: on GitHub in a `manjarolinux/base` container (ccache-cached), or
  locally with the same script. Installs to `~/.local/opt/telegram-custom` (previous build kept as
  `.prev`), data in `~/.local/share/TelegramCustom`; the pacman `telegram-desktop` stays as fallback.
- **Source/build trees live in `~/.cache/telegram-custom`**, never under this folder: the space in
  "AI Projects" breaks gobject-introspection's libtool step.
- **Stories and similar channels stay visible; themes stay stock** (user, 2026-09-23). Purple is the
  logo only, generated at build time, and shows because the app runs under its own id
  `org.telegram.desktop.custom` (launcher + icons installed under that name).
- **Repo is public** (user, 2026-09-23) for unlimited Actions minutes; never commit secrets.
- **Android builds locally or on GitHub Actions**, same recipe (`android/build.sh` / workflow), arm64 only,
  package `org.telegram.messenger.custom`. Actions minutes are free for a public repo, so CI stays on for `main`.
- **Feature branches until tried on the device** (2026-09-26): `main` is what CI publishes.
- **Secrets never in git:** signing key + passwords in `.secrets/` (gitignored, back it up: losing
  it means uninstall-to-update on the phone), copies in GitHub repo secrets. `api_id` in `.env`.
- **Upstream updates are ours:** bump the pin in `*/UPSTREAM`, rebuild, fix patches that no longer apply.

Navigation: [INDEX.md](INDEX.md).
