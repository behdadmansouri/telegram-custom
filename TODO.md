# TODO: Telegram Custom 📨

## ⚡ Next up
- [ ] 🤖 **First stock Android build** `M`: CI run on push; fix whatever breaks
- [ ] 🤖 **Compile + fix desktop patches 0001-0006** `M`: ads, custom emoji, per-folder counters, similar channels, stories, ghost mode; written, apply cleanly, never compiled

## 🤔 Needs your call
- [ ] 🧍 **Own api_id?** `S` `think`: builds use official keys for now; tradeoff in [docs/plan.md](docs/plan.md)
- [ ] 🧍 **Back up `.secrets/`** `S`: the Android signing key; lose it and every update needs an uninstall

- [ ] 🧍 **Stories + similar channels: hide them?** `S`: assumed yes; say if you meant keep
- [ ] 🧍 **Spy essentials: where do deleted messages live?** `M` `think`: inside the passcode-encrypted data, or skip; plan phase 6

## 📋 Backlog
- [ ] 🤖 **Hardening patches** `M`: no link-preview fetch while typing, local-only drafts (plan phase 4)
- [ ] 🤖 **Android feature patches** `L`: plan phase 5
- [ ] 🤖 **Update script** `M`: bump `*/UPSTREAM` to the newest upstream, rebuild, report patches that no longer apply
