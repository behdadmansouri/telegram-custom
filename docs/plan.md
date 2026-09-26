# plan 🧭

Stock upstream + one small patch per feature, desktop first (Android later reuses the list).
AyuGram code locations below are from `AyuGram/AyuGramDesktop` branch `dev`, read 2026-09-23.

## 🧩 what the AyuGram features actually are

| Feature | What it does | Verdict |
|---|---|---|
| Ghost mode | Client stops sending: read receipts (`messages.readHistory`, `readMessageContents`), story views, online status, typing/upload status. Sub-options: "read on interact" (marks read only when you reply/react), "schedule messages" (sends via a ~12s schedule so you don't flip online). | **Build.** Caveat: any message you send still shows you online for a moment (server infers it), and reacting to a story always marks it viewed. |
| Spy essentials | Keeps deleted and edited messages in a local SQLite DB and shows them in a history box. | **Build** (user, 2026-09-23). ~4k lines in AyuGram (storage 870 + UI 3000); ours leaner. AyuGram's DB is plaintext, outside the local-passcode encryption. |
| Local Telegram Premium | Makes the *client* believe you have Premium (`UserData::isPremium()` returns true). Server never sees it. Anything the server checks still fails: non-`free` custom emoji, premium stickers, bigger uploads, faster downloads. | **Skip.** A costume, not a key. |
| Stickers and emojis | "Show only added emojis and stickers" (hide packs you never added), "unlimited recent stickers", "hide reactions" per chat type. | Superseded by the custom-emoji patch below. |
| Custom emoji in picker | Telegram API: only emoji flagged `free` work for non-premium accounts. Stock picker shows the rest greyed with a lock. | **Build:** hide non-premium-usable sets outright (1-line condition in `EmojiListWidget::refreshCustom()`). |
| Folder counters | AyuGram: one global "hide counters" switch. | **Build per-folder:** the badge code already loops per folder (`chat_filters_tabs_strip.cpp`, `window_filters_menu.cpp`), so a per-folder set is a small change. |
| Message filters | Regex rules that hide matching messages, plus a "shadow ban" list that hides everything from chosen users/channels. | **Build** (user, 2026-09-23). |
| Translate: "Telegram" provider | Calls Telegram's own `messages.translateText`, the same free API the stock per-message Translate uses. Not a Premium bypass; any quota is Telegram's. | Skip. |
| Notify delay | Stock desktop waits a few seconds before a notification, so it can cancel it if you read the message on another device meanwhile. The toggle removes the wait. | **Done:** no delay, unconditionally (patch 0005). |
| Disable ads | Suppresses sponsored channel messages, promo suggestions, search ads. | **Build.** |
| Stories / similar channels | Toggles that hide the stories strip + rings, and the "Similar channels" block. | **Keep visible** (user, 2026-09-23). |

## 🪜 phases

1. **Stock builds.** Desktop local (`desktop/build.sh`), Android on CI. Proves the pipeline before any patch.
2. **Desktop cheap patches**, one each: ads off, non-usable custom emoji hidden, per-folder counter
   hiding (folder tab right-click), notify delay off, purple logo. Settings live in
   `<workdir>/custom.json`; UI only where a toggle is used often.
3. **Desktop ghost mode**: the five send-guards + "read on interact", one toggle in the main menu.
   Skip "schedule messages" unless wanted.
4. **Hardening patches** (see below): no link-preview fetch while typing, no cloud draft sync.
5. **Android**: ads, custom emoji, folder counters, ghost mode, purple logo. Ghost mode on Android intercepts centrally
   in `tgnet/ConnectionsManager.java` (AyuGram4A's approach, stale 2023 source, reference only).
6. **Spy essentials + message filters** (desktop, then Android).

## 🛡️ hardening: what a client can and can't do

**The hard truth first.** Normal ("cloud") chats are encrypted only between you and Telegram's
servers; Telegram holds the keys, so staff or a legal request can reach them. No client patch changes
that. Only **Secret Chats** are end-to-end, and they exist on Android/iOS only; Telegram Desktop has
never had them.

What *is* in reach:

| Vector | Fix | Kind |
|---|---|---|
| Anyone who copies `~/.local/share/TelegramCustom/tdata` owns your account (session key on disk) | Settings → Privacy → **Local passcode** (encrypts local data) | setting |
| SIM swap / SMS code interception | **Two-step verification** password; review Active sessions | setting |
| Call peer sees your IP | Privacy → Calls → **Peer-to-peer: Nobody** | setting |
| Typing a URL sends it to Telegram (link preview fetched server-side) before you hit send | Patch: fetch preview only on send, or never | patch |
| Unsent drafts sync to Telegram's cloud | Patch: keep drafts local | patch |
| Truly private conversation | Secret Chat on the phone | habit |
| Android build still bundles Google/Firebase libs | Strip later (Telegram-FOSS did it); FCM already can't work for our package id | backlog |

## 🔑 api_id

Own api_id since 2026-09-23: in `.env` (local builds) and repo secrets `TG_API_ID`/`TG_API_HASH`
(CI). Without them the builds fall back to the official keys. Changing it is a compile definition on
the whole desktop target, so it forces a full rebuild once.

## 🤝 trust: what makes a public build believable

The design already does the heavy lifting: the whole difference from Telegram is `*/patches/*.patch`
on top of a pinned upstream commit, small enough for a person or an LLM to read in one sitting.
What is missing is proof that the *binary* people download came from that source.

| # | Piece | What it proves | Cost | Pick |
|---|---|---|---|---|
| 1 | Build provenance (`actions/attest@v4` in both workflows; users run `gh attestation verify <apk> -R behdadmansouri/telegram-custom`) | this exact file was built by this repo's workflow from commit X, not on my laptop | ~10 lines | **done** |
| 2 | GitHub Releases: APK + desktop tarball, SHA-256 and patch list in the notes | a stable, public, non-expiring download (Actions artifacts need a login and expire in 30 days) | ~20 lines | **done**: every `main` build |
| 3 | README "what's changed from upstream": one line per patch with its size, plus a copy-paste prompt for an AI review of `android/patches/` | the diff is small and readable; invites the "have an agent check it" review | a README | **done** |
| 4 | CI patch-lint: fail if a patch adds a URL/host, a socket or HTTP client, a manifest permission, or a dependency | "our changes add no network endpoints", checked on every build | a small script | **done** |
| 5 | Signing-key fingerprint in the README | future APKs come from the same key | 1 line | **done** |
| 6 | Reproducible builds (anyone rebuilds, gets the same bytes) | strongest proof there is | large: timestamps, NDK paths, signing | no, for now |
| 7 | Third-party audit, or live traffic auditing | real assurance on upstream's own network behaviour | beyond a hobby project; upstream's traffic is Telegram's anyway | no |
