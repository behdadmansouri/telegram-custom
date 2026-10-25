# INDEX: Telegram Custom 📨

`desktop/`, `android/` and `.github/` are code trees: listed here, no INDEX of their own.

| File | Purpose | Created |
|---|---|---|
| CLAUDE.md | rules + decisions (`AGENTS.md` is a symlink to it) | 2026-09-23 |
| README.md | public face: download, what the patches do, how to verify a build | 2026-09-26 |
| TODO.md | work queue | 2026-09-23 |
| USAGE.md | how to build, install, update, write a patch | 2026-09-23 |
| docs/ | plans → [docs/INDEX.md](docs/INDEX.md) | 2026-09-23 |
| memory/ | project memory → [memory/MEMORY.md](memory/MEMORY.md) | 2026-09-23 |
| desktop/UPSTREAM | pinned tdesktop version + hashes | 2026-09-23 |
| desktop/build.sh | fetch, patch, build (CI); `--tree` = patched source only, for writing a patch | 2026-09-23 |
| desktop/install.sh | install or update from the newest Release (`--release`), a branch run (`--from-ci`), `--rollback` | 2026-09-23 |
| desktop/purple.py | recolors the logo PNGs purple at build time (called by build.sh) | 2026-09-23 |
| desktop/patches/ | desktop patch series (`git format-patch` output) | 2026-09-23 |
| android/UPSTREAM | pinned DrKLO/Telegram commit | 2026-09-23 |
| android/customize.sh | package id, label, arm64, signing, api_id, patches onto a DrKLO checkout | 2026-09-23 |
| android/patches/ | Android patch series | 2026-09-23 |
| .github/workflows/android.yml | CI build of the APK (artifact; on `main` also a Release) | 2026-09-23 |
| .github/workflows/desktop.yml | CI build of desktop in a Manjaro container (artifact; on `main` also a Release) | 2026-09-23 |
| .github/release.sh | publishes a CI build as a GitHub Release (files, SHA-256, patch list) | 2026-09-26 |
| .github/announce.sh | posts a Release to the Telegram channel (file or link, changelog); skips without secrets | 2026-10-24 |
| .github/workflows/announce.yml | manual re-post of the newest release: checks the bot secrets without a build | 2026-10-24 |
| .github/patch-lint.sh | fails if a patch adds a URL, network code, a permission or a dependency | 2026-09-26 |
| .github/media-callers.sh | trust-model caller guard: fails CI on a new upstream caller file of a gated media function, warns on count changes (`update` after reading new callers) | 2026-10-25 |
| .github/media-callers.txt | its table: platform, pattern, file, count on stock upstream | 2026-10-25 |
| desktop/tests/trust_rules_test.cpp | unit test of the desktop trust rule table, run by CI against the patched tree | 2026-10-25 |
| .github/workflows/patch-lint.yml | runs patch-lint on every push (README badge) | 2026-09-26 |
