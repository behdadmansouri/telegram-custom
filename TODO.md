# TODO: Telegram Custom 📨

## ⚡ Next up
- [ ] 🤖 **Merge `android-gallery-trash` to `main` once tried on the phone** `S`: CI build of the branch, then the first Release
- [ ] 🤖 **Spy essentials (desktop)** `L`: keep deleted + edited messages; storage question below
- [ ] 🤖 **Message filters (desktop)** `L`: regex hide rules + hide-everything-from list

## 🔍 Verification
- [ ] 🧍 **Desktop: Telegram Custom launches with the purple icon, separate from the official app** - app menu → Telegram Custom. ☰ → Ghost mode; right-click a folder tab → Hide unread counter.
- [ ] 🧍 **The APK installs next to the official app as TG Custom, purple icon** - GitHub → Actions → android → newest run → artifact. Log in only after the api_id step.
- [ ] 🧍 **Android features work** - no ads; Settings → Ghost mode row; long-press a folder tab → Hide unread counter; locked emoji gone from the picker.

- [ ] 🧍 **Gallery: a hidden folder drops out of All media** - attach → album name at top → long-press e.g. Documents; it reads "· hidden" and its photos leave All media.
- [ ] 🧍 **Send and move to trash** - long-press send → Send and move to trash; after the upload one Android dialog asks to trash the originals.

## 🤔 Needs your call
- [ ] 🧍 **Trust kit: build 1, 3, 4, 5 too?** `M` `think`: [docs/plan.md](docs/plan.md) → trust (Releases done); top pick is signed build provenance
- [ ] 🧍 **Back up `.secrets/`** `S`: the Android signing key; lose it and every update needs an uninstall
- [ ] 🧍 **Spy essentials: encrypt the saved deleted messages?** `S` `think`: my pick is encrypted under the local passcode (AyuGram keeps them in plaintext)

## 📋 Backlog
- [ ] 🤖 **Desktop: send and move to trash** `M`: right-click send in the file box; files go to the desktop trash after upload
- [ ] 🤖 **Hardening patches** `M`: no link-preview fetch while typing, local-only drafts (plan phase 4)
- [ ] 🤖 **Update script** `M`: bump `*/UPSTREAM` to the newest upstream, rebuild, report patches that no longer apply
