# plan 🧭

Stock upstream + one small patch per feature, desktop first (Android later reuses the list).
AyuGram code locations below are from `AyuGram/AyuGramDesktop` branch `dev`, read 2026-09-23.

## 🧩 what the AyuGram features actually are

| Feature | What it does | Verdict |
|---|---|---|
| Ghost mode | Client stops sending: read receipts (`messages.readHistory`, `readMessageContents`), story views, online status, typing/upload status. Sub-options: "read on interact" (marks read only when you reply/react), "schedule messages" (sends via a ~12s schedule so you don't flip online). | **Build.** Caveat: any message you send still shows you online for a moment (server infers it), and reacting to a story always marks it viewed. |
| Spy essentials | Keeps deleted and edited messages in a local SQLite DB and shows them in a history box. | **Later, `think`.** ~4k lines in AyuGram (storage 870 + UI 3000). Also a plaintext DB of everything anyone deleted, sitting outside Telegram's local-passcode encryption. |
| Local Telegram Premium | Makes the *client* believe you have Premium (`UserData::isPremium()` returns true). Server never sees it. Anything the server checks still fails: non-`free` custom emoji, premium stickers, bigger uploads, faster downloads. | **Skip.** A costume, not a key. |
| Stickers and emojis | "Show only added emojis and stickers" (hide packs you never added), "unlimited recent stickers", "hide reactions" per chat type. | Superseded by the custom-emoji patch below. |
| Custom emoji in picker | Telegram API: only emoji flagged `free` work for non-premium accounts. Stock picker shows the rest greyed with a lock. | **Build:** hide non-premium-usable sets outright (1-line condition in `EmojiListWidget::refreshCustom()`). |
| Folder counters | AyuGram: one global "hide counters" switch. | **Build per-folder:** the badge code already loops per folder (`chat_filters_tabs_strip.cpp`, `window_filters_menu.cpp`), so a per-folder set is a small change. |
| Message filters | Regex rules that hide matching messages, plus a "shadow ban" list that hides everything from chosen users/channels. | Skip (not wanted). |
| Translate: "Telegram" provider | Calls Telegram's own `messages.translateText`, the same free API the stock per-message Translate uses. Not a Premium bypass; any quota is Telegram's. | Skip. |
| Notify delay | Stock desktop waits a few seconds before a notification, so it can cancel it if you read the message on another device meanwhile. The toggle removes the wait. | Optional, tiny. Worth it only if the phone isn't also open. |
| Disable ads | Suppresses sponsored channel messages, promo suggestions, search ads. | **Build.** |
| Stories / similar channels | Toggles that hide the stories strip + rings, and the "Similar channels" block. | **Build** (assumed you want them hidden; flip if not). |

## 🪜 phases

1. **Stock builds.** Desktop local (`desktop/build.sh`), Android on CI. Proves the pipeline before any patch.
2. **Desktop cheap patches**, one each: ads off, stories hidden, similar channels hidden, non-usable
   custom emoji hidden, per-folder counter hiding (toggle from the folder tab's right-click menu),
   notify delay off. Settings live in a small JSON file in the data dir; UI only where a toggle is
   used often.
3. **Desktop ghost mode**: the five send-guards + "read on interact", one toggle in the main menu.
   Skip "schedule messages" unless wanted.
4. **Hardening patches** (see below): no link-preview fetch while typing, no cloud draft sync.
5. **Android**: ads, stories, custom emoji, ghost mode. Ghost mode on Android intercepts centrally
   in `tgnet/ConnectionsManager.java` (AyuGram4A's approach, stale 2023 source, reference only).
6. **Spy essentials**, only after deciding where the DB lives (inside the passcode-encrypted data, or not at all).

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

Builds use the official keys now (desktop: the snap key Arch's package uses; Android: upstream's
default). Telegram's terms want third-party clients on their own `api_id`; the official key blends in
with every stock install. No verified reports of bans either way. Switch = put `TG_API_ID`/`TG_API_HASH`
in `.env` and in the repo's secrets, rebuild; sessions made with one key may need a fresh login.
