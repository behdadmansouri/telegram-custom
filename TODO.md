# TODO: Telegram Custom 📨

## ⚡ Next up
- [ ] 🧍 **Give CI a bot for the channel posts** `S`: new bot + channel, two `gh secret set` commands, then Actions → announce to check: [USAGE.md](USAGE.md) → announcements
- [ ] 🧍 **Delete the stale `TG_BOT_TOKEN` and `TG_CHANNEL` repo secrets** `S`: replaced by `TELEGRAM_*`; `TG_CHANNEL` held a placeholder
- [ ] 🤖 **Merge `android-gallery-trash` to `main` once tried on the phone** `S`: CI build of the branch, then the first Release
- [ ] 🤖 **Auto-upstream workflow** `M`: daily bump → build → `main` → Release, issue on failure: [plan](docs/plan.md) → batch 2 step 1
- [ ] 🤖 **Laptop update timer** `S`: daily `install.sh --release` + notification: batch 2 step 2
- [ ] 🧍 **Install Obtainium on the phone and add this repo** `S`: steps in [USAGE.md](USAGE.md) → android
- [ ] 🤖 **Batch-2 patches** `M`: build number in the menus, captioned photos auto-ungroup, 8 accounts: batch 2 step 4
- [ ] 🤖 **Trust model** `L` `think`: trusted chats load media, untrusted load nothing: [docs/trust.md](docs/trust.md)
- [ ] 🤖 **"What's custom" section** `L`: a card per patch with before/after: batch 2 step 7
- [ ] 🤖 **Spy essentials (desktop)** `L`: keep deleted + edited messages; storage question below
- [ ] 🤖 **Message filters (desktop)** `L`: regex hide rules + hide-everything-from list

## 🔍 Verification
- [ ] 🧍 **Desktop: Telegram Custom launches with the purple icon, separate from the official app** - app menu → Telegram Custom. ☰ → Ghost mode; right-click a folder tab → Hide unread counter.
- [ ] 🤖 **The laptop runs the newest desktop Release, with no build tree** - `desktop/install.sh --release` says "up to date"; `~/.cache/telegram-custom` absent.
- [ ] 🧍 **The APK installs next to the official app as TG Custom, purple icon** - GitHub → Actions → android → newest run → artifact. Log in only after the api_id step.
- [ ] 🧍 **Android features work** - no ads; Settings → Ghost mode row; long-press a folder tab → Hide unread counter; locked emoji gone from the picker.

- [ ] 🧍 **Gallery: a hidden folder drops out of All media** - attach → album name at top → long-press e.g. Documents; it reads "· hidden" and its photos leave All media.
- [ ] 🧍 **Send and move to trash** - long-press send → Send and move to trash; after the upload one Android dialog asks to trash the originals.
- [ ] 🧍 **Build number shows after the version** - Android: Settings footer ends "· TG Custom b<run>"; desktop: ☰ footer reads "Version 7.2.5 · b<run> – About". The number matches the release tag's `-b<run>`.

- [ ] 🤖 **Each `main` release has an attestation and a channel post** - `gh attestation verify` on the APK; the post in the channel.

## 🤔 Needs your call
- [ ] 🧍 **More hardening: which of these?** `S`: typing previews, secret-chat previews, static stickers in untrusted chats, local drafts, no Google libs: [plan](docs/plan.md) → batch 2 step 6
- [ ] 🧍 **Back up `.secrets/`** `S`: the Android signing key; lose it and every update needs an uninstall
- [ ] 🧍 **Spy essentials: encrypt the saved deleted messages?** `S` `think`: my pick is encrypted under the local passcode (AyuGram keeps them in plaintext)

## 📋 Backlog
- [ ] 🤖 **Desktop: send and move to trash** `M`: right-click send in the file box; files go to the desktop trash after upload
