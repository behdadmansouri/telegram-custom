# INDEX: Telegram Custom 📨

`desktop/`, `android/` and `.github/` are code trees: listed here, no INDEX of their own.

| File | Purpose | Created |
|---|---|---|
| CLAUDE.md | rules + decisions (`AGENTS.md` is a symlink to it) | 2026-09-23 |
| TODO.md | work queue | 2026-09-23 |
| USAGE.md | how to build, install, update, write a patch | 2026-09-23 |
| docs/ | plans → [docs/INDEX.md](docs/INDEX.md) | 2026-09-23 |
| memory/ | project memory → [memory/MEMORY.md](memory/MEMORY.md) | 2026-09-23 |
| desktop/UPSTREAM | pinned tdesktop version + hashes | 2026-09-23 |
| desktop/build.sh | fetch, patch, build (local or CI), then install.sh | 2026-09-23 |
| desktop/install.sh | install a build (local stage or `--from-ci`), `--rollback` | 2026-09-23 |
| desktop/purple.py | recolors the logo PNGs purple at build time (called by build.sh) | 2026-09-23 |
| desktop/patches/ | desktop patch series (`git format-patch` output) | 2026-09-23 |
| android/UPSTREAM | pinned DrKLO/Telegram commit | 2026-09-23 |
| android/build.sh | local APK build (same recipe as CI), `--install` over adb | 2026-09-26 |
| android/customize.sh | package id, label, arm64, signing, api_id, patches onto a DrKLO checkout | 2026-09-23 |
| android/patches/ | Android patch series | 2026-09-23 |
| .github/workflows/android.yml | CI build of the APK (artifact) | 2026-09-23 |
| .github/workflows/desktop.yml | CI build of desktop in a Manjaro container (artifact) | 2026-09-23 |
