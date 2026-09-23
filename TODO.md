# TODO: Telegram Custom 📨

## ⚡ Next up
- [ ] 🤖 **Compile + fix desktop patches** `M`: ads, custom emoji, folder counters, ghost mode, notify delay, purple; never compiled yet
- [ ] 🤖 **First desktop CI build** `M`: Manjaro container; later builds reuse ccache
- [ ] 🤖 **Spy essentials (desktop)** `L`: keep deleted + edited messages; storage question below
- [ ] 🤖 **Message filters (desktop)** `L`: regex hide rules + hide-everything-from list

## 🔍 Verification
- [ ] 🧍 **The APK installs next to the official app as TG Custom, purple icon** - GitHub → Actions → android → newest run → artifact. Log in only after the api_id step.
- [ ] 🧍 **Android features work** - no ads; Settings → Ghost mode row; long-press a folder tab → Hide unread counter; locked emoji gone from the picker.

## 🤔 Needs your call
- [ ] 🧍 **Get own api_id** `S`: my.telegram.org → API development tools; then put both values in `.env` and tell me (I set the GitHub secrets)
- [ ] 🧍 **Back up `.secrets/`** `S`: the Android signing key; lose it and every update needs an uninstall
- [ ] 🧍 **Spy essentials: encrypt the saved deleted messages?** `S` `think`: my pick is encrypted under the local passcode (AyuGram keeps them in plaintext)

## 📋 Backlog
- [ ] 🤖 **Hardening patches** `M`: no link-preview fetch while typing, local-only drafts (plan phase 4)
- [ ] 🤖 **Update script** `M`: bump `*/UPSTREAM` to the newest upstream, rebuild, report patches that no longer apply
