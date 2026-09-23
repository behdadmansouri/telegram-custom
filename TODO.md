# TODO: Telegram Custom 📨

## ⚡ Next up
- [ ] 🧍 **Install desktop build deps** `S`: one `pacman` line, in [USAGE.md](USAGE.md); unblocks the first desktop build
- [ ] 🤖 **First stock desktop build** `M`: `desktop/build.sh` once deps are in
- [ ] 🤖 **First stock Android build** `M`: CI run on push; fix whatever breaks
- [ ] 🤖 **Desktop patches, phase 1** `L`: see [docs/plan.md](docs/plan.md)

## 🤔 Needs your call
- [ ] 🧍 **Own api_id?** `S` `think`: builds use official keys for now; tradeoff in [docs/plan.md](docs/plan.md)
- [ ] 🧍 **Back up `.secrets/`** `S`: the Android signing key; lose it and every update needs an uninstall

## 📋 Backlog
- [ ] 🤖 **Update script** `M`: bump `*/UPSTREAM` to the newest upstream, rebuild, report patches that no longer apply
