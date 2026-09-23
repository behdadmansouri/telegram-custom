# TODO: Telegram Custom 📨

## ⚡ Next up
- [ ] 🧍 **Install desktop build deps** `S`: one `pacman` line, in [USAGE.md](USAGE.md); unblocks the first desktop build
- [ ] 🤖 **First stock desktop build** `M`: `desktop/build.sh` once deps are in
- [ ] 🤖 **First stock Android build** `M`: CI run on push; fix whatever breaks
- [ ] 🤖 **Desktop cheap patches** `M`: ads, stories, similar channels, custom emoji, per-folder counters (plan phase 2)
- [ ] 🤖 **Desktop ghost mode** `M`: plan phase 3

## 🤔 Needs your call
- [ ] 🧍 **Own api_id?** `S` `think`: builds use official keys for now; tradeoff in [docs/plan.md](docs/plan.md)
- [ ] 🧍 **Back up `.secrets/`** `S`: the Android signing key; lose it and every update needs an uninstall

- [ ] 🧍 **Stories + similar channels: hide them?** `S`: assumed yes; say if you meant keep
- [ ] 🧍 **Spy essentials: where do deleted messages live?** `M` `think`: inside the passcode-encrypted data, or skip; plan phase 6

## 📋 Backlog
- [ ] 🤖 **Hardening patches** `M`: no link-preview fetch while typing, local-only drafts (plan phase 4)
- [ ] 🤖 **Android feature patches** `L`: plan phase 5
- [ ] 🤖 **Update script** `M`: bump `*/UPSTREAM` to the newest upstream, rebuild, report patches that no longer apply
