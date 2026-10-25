# Trust model: design

Plan item: [plan.md](plan.md) → batch 2 step 5. Revised after [critique 1](archive/2026-10-25-trust-critique-1.md) and [critique 2](archive/2026-10-25-trust-critique-2.md). Pins read: Android DrKLO `0aae9598` (13.0.3), desktop tdesktop `v7.2.5`. Paths are relative to `TMessagesProj/src/main/java/org/telegram/` (Android) and `Telegram/SourceFiles/` (desktop). ✓ = verified in source at the pin; ~ = inferred (reasoned from nearby code, not traced end to end). "Cn" points at critique objection n.

## 0. 🧱 v1 build list (go straight down it)

One branch, one patch per platform (`0007-Media-trust` Android, `0007-Media-trust` desktop). Each step compiles on its own.

**Android (13.0.3)**

| # | Piece | Anchor | Lines |
|---|---|---|---|
| A1 | `messenger/TrustController.java` (new): rules of section 1, prefs, snapshots, per-dialog verdict cache, tapped set, toast, Java backfill | new file | 250 |
| A2 | Activity table `tc_activity`: create, feed, prune, one-time backfill (inside A1, two feed calls in storage) | `MessagesStorage.java:11863` (`putMessagesInternal`), `:16079` (`putMessages(messages_Messages, ...)`, history pages) ✓ | 2 |
| A3 | Auto-download gate, top of the 4 funnels | `DownloadController.java:688`, `:778` (`canDownloadMediaInternal` ×2), `:861`, `:942` (`TLRPC.Message` ×2) ✓ | 4 |
| A4 | Forwarded-story bypass in the `MessageObject` entry (its story branch returns before the funnel) | `DownloadController.java:609-617` ✓ | 1 |
| A5 | Peerless callers: wrap with the message's trust | `ui/Cells/DialogCell.java:5801` ✓ (`currentDialogId`); `messenger/RichMessageLayout.java:6687`, `:7214`, `:8144` ✓ (`root.messageObject`) | 4 |
| A6 | Image gate G (thumbnails, replies, pinned and composer bars, link-preview images, games, cached GIF/video autoplay, animated/video stickers) | `messenger/ImageReceiver.java:573`: first statement of the 11-arg `setImage` (`:572`), above the attach-backup block (`:573-588`) ✓ | 6 |
| A6b | Tap unlock: first tap on a message in an untrusted chat marks it and rebinds the cell | `ui/Cells/ChatMessageCell.java:17854` (first statement of `didPressButton`), rebind via `setMessageObject` (`:13328`) ✓ | 4 |
| A7 | Direct-URL web documents off | `messenger/ImageLocation.java:89` ✓ | 1 |
| A8 | Story preload | `ui/Stories/StoriesController.java:580` ✓ | 1 |
| A9 | Calls relay-only | `messenger/voip/VoIPService.java:3423`, `:1111`, `:1880`, `:4360` ✓ | 4 |
| A10 | Chat ⋮ menu item (state-first label) | `ui/ChatActivity.java:1656` (id beside `add_shortcut = 24`), `:4445-4486` (`lazilyAddSubItem` block), `:3939` (`id == add_shortcut` handler) ✓ | 20 |
| A11 | Settings row + one compact screen | after 0004 applies: row 101 below 0004's Ghost mode row 100, which 0004 inserts after stock row 10 (`ui/SettingsActivity.java:708` ✓ stock); `case 101:` after 0004's `case 100:`, which follows stock `case 10:` (`:845` ✓ stock); new `ui/TrustSettingsActivity.java` | 100 |
| | **Android total** | | **~400, ~50 inside upstream files** |

**Desktop (7.2.5)**

| # | Piece | Anchor | Lines |
|---|---|---|---|
| D1 | `custom/custom_trust.{h,cpp}` (new): rules (incl. own-message clause), per-account file, activity log, verdict cache, toast, repaint | new files + `Telegram/CMakeLists.txt` (as patch 0003) | 240 |
| D2 | Activity feed | `history/history.cpp:576` (`History::createItem`), beside the `topPeers` line `:595-596` ✓ | 3 |
| D3 | Auto-download + autoplay gates | `data/data_auto_download.cpp:371` (one check, skip stickers), `:406`, `:426`, `:449` ✓ | 8 |
| D4 | Network thumbnails (photos, replies, link previews, documents) | `data/data_photo_media.cpp:153`; `data/data_document.cpp:870` (`loadThumbnail`); `history/view/media/history_view_web_page.cpp:944`; `data/data_reply_preview.cpp:110-114` (Small fetch when no inline bytes) ✓ | 12 |
| D5 | Animated/video stickers static | `history/view/media/history_view_sticker.cpp:190-195` (`readyToDrawAnimationFrame`) ✓ | 3 |
| D6 | Direct-URL web documents off | `ui/image/image_location_factory.cpp:320-331` (`FromWebDocument`, `MTPDwebDocumentNoProxy` branch) ✓ | 2 |
| D7 | Story preload | after desktop 0004 applies (it also edits this file): `data/data_stories.cpp:2611-2613` stock (`startPreloading`, after the `Expects`) ✓ | 4 |
| D8 | Calls relay-only | `calls/calls_call.cpp:1090`, `:356`, `:490`, `:974` ✓ | 6 |
| D9 | Chat ⋮ menu item | `window/window_peer_menu.cpp:1922` (`fillHistoryActions`) + new `Filler::addToggleTrust` ✓ | 25 |
| D10 | Settings button + one compact box | `settings/sections/settings_advanced.cpp:217` (`BuildAutoDownloadSection`) ✓ | 75 |
| | **Desktop total** | | **~380, ~67 inside upstream files** |

**CI (both)**

| # | Piece | Where | Lines |
|---|---|---|---|
| C1 | Caller guard (section 4.1): fails on a new caller file or a count dropping to zero, warns on count changes | `.github/media-callers.sh` + `.github/media-callers.txt`, a step in `android.yml` and `desktop.yml` before patches apply | 40 + table |
| C2 | Rule-table unit tests (pure `decide()` on both platforms) | JVM test in the Android build, a small C++ test target or a `static_assert`-free test binary on desktop (~) | 80 |

## 1. 📐 rules (spec)

**Unit of trust is the chat (dialog).** Inputs, per account: the dialog kind (user, bot, basic group, supergroup, channel, secret chat); creator/admin flags; the contact list; the manual marks; per-person active days. An **active day** is a local calendar day on which that person sent you at least one non-service message in your private chat, as logged by this device (section 2.2 / 3.2).

**Rules, top to bottom, first match wins:**

| # | Rule | Result |
|---|---|---|
| 0 | Trust model off | trusted (stock everywhere) |
| 1 | Chat marked "never trust" | untrusted |
| 2 | Saved Messages, the Telegram service account 777000, or a message you sent (`out`) that is not a forward (Android `fwd_from == null`, desktop no `HistoryMessageForwarded`, ~) | trusted (for `out`: that message only) |
| 3 | Group, channel or bot marked trusted by hand | trusted, no decay |
| 4 | Group you created, or channel (broadcast) where you are creator or admin; setting, default on | trusted |
| 5 | Person marked trusted less than `grace` days ago | trusted |
| 6 | Person marked trusted with ≥ `N` active days in the last `D` | trusted |
| 7 | Contact with ≥ `N` active days in the last `D`; setting, default on | trusted |
| 8 | Group message whose sender is trusted by 2, 5, 6 or 7; setting, **default off** (C5) | trusted, that message only |
| 9 | Anything else | untrusted |

Rule 4 is deliberately narrower than "chats you admin": a supergroup where someone else made you admin is untrusted unless marked, because big public groups you moderate are full of strangers (default, user to confirm: question 4). Android: `chat.creator || ChatObject.isChannelAndNotMegaGroup(chat) && ChatObject.hasAdminRights(chat)` (`messenger/ChatObject.java:2127`, `:2085`, `:2123` ✓). Desktop: `amCreator() || isBroadcast() && hasAdminRights()` (`data/data_channel.h:358`, `:385`; `data/data_chat.h:67`, `:88` ✓).

**Decay of a hand-trusted person (5-6):** the mark is never deleted; it goes dormant below the threshold and revives when the person is active again. The chat menu label shows "dormant" (no list screen in v1, C8). **Secret chats** take the peer user's trust. **Bots** only by hand (3). **Non-contacts** only by hand (5-6).

**Settings (all adjustable; global, one set for all accounts):** trust model on (default on); `N` = 3 (1-30); `D` = 90 (7-365); `grace` = 90 (0-365); rule 4 on; rule 7 on; rule 8 off; "untrusted chats: tap to load" on; "untrusted calls: relay only" on. The five per-surface toggles of the draft collapse into "tap to load" (C8: nobody wants link images blocked but GIF autoplay allowed).

**What untrusted means (tap to load on):**
- No media downloads without a tap: photos, videos, GIFs, round videos, voice, files.
- Only the **embedded** thumbnail shows (Telegram's tiny blurred "stripped" size, bytes inside the message): no network thumbnail for photos, videos, GIFs, files, link previews, game previews, the quoted image in a reply, the pinned-message bar or the composer's reply/edit bar (R1-1, R1-14b, R2-3).
- Shared locations keep their static map: it is a Telegram-proxied web file, fetched by Telegram, not from your IP (R2-4).
- Nothing autoplays, including GIFs and videos already on disk from another chat.
- Animated (TGS) and video (webm) stickers show their static thumbnail; static stickers show as normal. Tapping a sticker opens its pack as in stock, which plays it.
- Stories of that peer are not preloaded.
- Direct-URL web documents (`webDocumentNoProxy`, fetched from your own IP, not through Telegram) never load, in any chat, while the trust model is on (C4).
- 1:1 calls use Telegram's relay only.
- A tap always loads that one item, for the rest of the session (GIFs and videos then play as stock).
- Your own sent messages load as stock; your forwards of someone else's media stay gated (the laptop has not seen them yet either).

**Not covered, said plainly:** custom emoji still animate (no chat context in their renderer, section 2.7); avatars and profile photos load everywhere (every client does); media opened in the photo viewer, story viewer or instant view loads (you opened it), and the story viewer's auto-advance to the next peer counts as opened; the shared-media grid (profile → Media) loads its thumbnails when you open the tab (its receivers have no parent view, `ui/Cells/SharedPhotoVideoCell2.java:79-80` ✓, so G cannot tell it from a viewer); service-message photos (chat photo changed) load (`ChatActionCell`, ~).

**Trusted means stock:** the user's normal auto-download, power-saving and P2P-privacy settings apply. Trust never forces a download stock would not do.

**Scope: per device, per account (C12).** Marks and the activity log live on each device and are never synced: syncing would mean new traffic through Telegram (cloud storage, a bot), which this repo does not add. Expect to mark a chat on the phone and again on the laptop, and expect the activity rule to disagree between devices for a while (each device counts only the messages it has seen). Settings are per device too.

## 2. 🤖 Android design

### 2.1 TrustController (A1)
One instance per account (`getInstance(account)`, the `DownloadController` pattern). Surface: `allows(MessageObject)`, `allows(TLRPC.Message)`, `isTrusted(long dialogId)`, `setMark(long dialogId, int state)` (none / trusted / never), `noteTapped(MessageObject)`, `refresh()`, and a pure static `decide(...)` taking plain values (kind, flags, mark, markedAt, activeDays, now, settings) for the unit test (C2). Called on the UI thread from cell binding (thousands of calls a second while scrolling), so `allows()` first checks the own-message clause, then one lookup in a per-dialog verdict cache (`LongSparseArray<Byte>`, filled lazily, cleared on `refresh()`, on a mark change and on `NotificationCenter.updateInterfaces` with the chat-info or contacts flags; ~15 lines, R2-8), then rule 8 if on. The cache is filled from immutable snapshots: the marks map and the active-user set are replaced whole (`volatile` reference to an unmodifiable copy) by `refresh()` on the storage queue (C14c). `MessagesController.getChat` reads a `ConcurrentHashMap` (`messenger/MessagesController.java:147` ✓), `ContactsController.contactsDict` too (`messenger/ContactsController.java:238` ✓).

### 2.2 Activity log (A2): count arrivals, not retained rows (C6)
Own table in the account's cache database, created on first use: `CREATE TABLE IF NOT EXISTS tc_activity(uid INTEGER, day INTEGER, PRIMARY KEY(uid, day))`.

**Feed:** `TrustController.noteIncoming(messages, mode)` at the top of `putMessagesInternal` (`messenger/MessagesStorage.java:11863` ✓, realtime updates) and of `putMessages(TLRPC.messages_Messages, ...)` (`:16079` ✓, history pages; the draft and C6 both called `putMessagesInternal` the single point, it is not: history pages insert into `messages_v2` from their own function, `:16244` ✓). Both run on the storage queue (~ for `:16079`, which posts itself there). Per message: skip unless `!out`, `action == null` (service messages, incoming calls included, do not count: C14a), `peer_id.user_id != 0`, not self, `mode == 0` (not scheduled). `INSERT OR IGNORE (uid, (date + tzOffset(date)) / 86400)`. One prepared statement per batch.

**Read:** `SELECT uid FROM tc_activity WHERE day >= ?today-D GROUP BY uid HAVING COUNT(*) >= ?N` into the active set. The table holds at most people × 365 rows; the query is trivial. **Prune:** `DELETE FROM tc_activity WHERE day < ?today-365` on refresh. **Refresh:** account start (after contacts load), every 6 h, and on a setting or mark change.

**Backfill, once per account** (flag in prefs), in Java so it applies the live feed's rules exactly (R2-5): iterate `SELECT uid, date, data FROM messages_v2 WHERE uid > 0 AND out = 0 AND date >= ?now-365d` (`messages_v2` schema `:551` ✓), deserialize `data` with `TLRPC.Message.TLdeserialize` (the call `MessagesStorage` uses throughout), skip `action != null`, and compute the day with the device zone at that date. One full scan on the storage queue, once; ~25 lines. It counts only what is still cached, so it starts with an approximation that the live feed replaces within `D` days. A third `messages_v2` writer, `putDialogsInternal` (`:17346` ✓, the top message of each dialog), is not hooked: it matters only right after login, when it would add at most one day per person. Desktop has no backfill.

**Survives:** "Clear local database" (`clearLocalDatabase`, `:1416` ✓, deletes a fixed list of stock tables, ~ for not touching ours) and auto-delete timers (rows are logged on arrival). **Lost:** on logout (the database is deleted), as intended.

### 2.3 Auto-download gate (A3-A5, C9)
`if (!getTrustController().allows(message)) return 0;` at the top of `canDownloadMediaInternal(MessageObject)` (`messenger/DownloadController.java:688` ✓) and `canDownloadMediaInternal(MessageObject, long)` (`:778` ✓): these are the funnel for `canDownloadMedia(MessageObject)` (`:609`) and both `canDownloadMediaType` overloads (`:652`, `:670` ✓). Same line at the top of `canDownloadMedia(TLRPC.Message)` (`:861` ✓, used by the background download queue) and `canDownloadMedia(TLRPC.Message, MessageMedia)` (`:942` ✓). One extra line in `canDownloadMedia(MessageObject)` before its story branch (`:610-617` ✓), which returns `true` for a forwarded public story without reaching the funnel. `DownloadController.java` is identical in this region between 12.10.3 and 13.0.3 (C9, ✓ by line numbers). Story preload: `StoriesController.preloadStory(dialogId, ...)` already has the dialog (`ui/Stories/StoriesController.java:576-580` ✓), one line.

Peerless callers (C9 asked to swap rather than wrap; swapping changes semantics, so wrap): `DialogCell.java:5801` passes `(AUTODOWNLOAD_TYPE_PHOTO, size)` inside `setThumb(int, MessageMedia)` (`:5779` ✓), wrap with `isTrusted(currentDialogId)`. `RichMessageLayout` has three `computeAutoDownload()` (`:6687` uses `getCurrentDownloadMask()`, `:7214` and `:8144` use `canDownloadMedia(TYPE_VIDEO, size)` ✓); the first returns true for every photo in a rich message whenever photo auto-download is on, a leak the draft missed. Each gets `if (!allows(root.messageObject)) return false;`; `root.messageObject` is null only for the no-message constructor (`:218` ✓), treated as allowed (~: previews of your own content).

This covers every caller of `canDownloadMedia`, `canDownloadMediaType`, `canPreloadStories` and `computeAutoDownload` found by grep (C14e: a statement about those callers, not about every image load; image loads are G's job).

### 2.4 Image gate G (A6): thumbnails, stickers, cached autoplay without touching ChatMessageCell
Why here: the network thumbnails C1 found (video and GIF document thumbs, `currentPhotoObjectThumb` fallbacks, reply images at `ui/Cells/ChatMessageCell.java:19324`, `:19339` ✓, game previews short-circuiting at `:8743` ✓) and sticker playback all go through `ImageReceiver.setImage`, and every one passes the message as `parentObject` (sticker: `Object parentObject = messageObject`, `:9699` ✓; replies pass `messageObject` or `messageObject.replyMessageObject` ✓). One hunk in `ImageReceiver` replaces 4-8 hunks in the churniest file (C10).

Hunk at the top of `setImage(mediaLocation, mediaFilter, imageLocation, imageFilter, thumbLocation, thumbFilter, thumb, size, ext, parentObject, cacheType)` (`messenger/ImageReceiver.java:572` ✓): `if (parentObject instanceof MessageObject && TrustController.gateActive) { Location[] l = TrustController.filter(this, (MessageObject) parentObject, mediaLocation, imageLocation, thumbLocation); mediaLocation = l[0]; imageLocation = l[1]; thumbLocation = l[2]; }`.

`filter` passes everything through unless all hold: trust model and "tap to load" on; `getParentView()` (`:3254` ✓) is a `ChatMessageCell`, a `DialogCell`, or a `BackupImageView` (the last covers the automatic pinned-message bar, `ui/ChatActivity.java:28630`, `:29947` ✓, and the composer reply/edit bar, `:29943` ✓, which pass the pinned or replied `MessageObject` as parent; ~ that `BackupImageView` gives its receiver itself as parent view); the message is not trusted (`allows()`, which includes your own messages); the message is not in the session's tapped set. Then:
- **Whitelist, not a viewer blacklist (R2-3):** a blacklist would have to know every viewer class, and some surfaces (the shared-media grid) have no parent view at all, so a blacklist cannot separate "opened by you" from "automatic" without reading every viewer; the whitelist fails open only on surfaces this doc names, and a new cell type shows up in C1's `new ImageReceiver(` count.
- **Taps:** the tap paths for GIF, video, round video and files call `FileLoader.loadFile` directly and re-enter `setImage` later without `forceLoading` (`ChatMessageCell.java:17899`, `:17915`, `:17920`, `:17933`, then `onSuccessDownload` `:17970`, `:17979`, `:17992`, per R2-1). So A6b: the first statement of `didPressButton` (`:17854` ✓) is `if (TrustController.noteTapped(currentMessageObject)) { currentMessageObject.forceUpdate = true; <rebind with the same arguments as the last setMessageObject, :13328>; return; }`, where `noteTapped` returns true only when it newly adds the message. The first tap rebinds under "allowed" (download, autoplay, existing-file paths run as stock); later taps are stock. `isForceLoding()` (`:384` ✓) stays in G as a belt: when true, add to the tapped set and pass through. The `setImage` without `forceLoading` near `:17935` is the wallpaper case, harmless (R2 read it).
- Telegram-proxied web files (`webFile != null && !webFile.noproxy`: static maps, `ChatMessageCell.java:9602-9603` ✓, and proxied bot thumbs) pass through (R2-4).
- Sticker document (`MessageObject.isStickerDocument` `:10271`): animated (`isAnimatedStickerDocument` `:10308`) or video (`isVideoStickerDocument` `:10283`) drops media and image locations and keeps the thumb (static webp) and the `pathThumb` outline; static stickers pass.
- Anything else keeps a location only if it is local: `photoSize instanceof TL_photoStrippedSize` or `TL_photoPathSize`, or a non-http `path`, or (for photo, not document, locations) `messageObject.mediaExists` (`MessageObject.java:252` ✓). GIF, video and round-video document locations are dropped even when cached, which closes cached autoplay with no `SharedConfig.isAutoplay*` edits.

The `thumb` drawable argument is never touched, so the embedded stripped image still shows. This replaces the draft's reasoning about `getClosestPhotoSizeWithSize(sizes, 40)` (C2 is right: `TL_photoStrippedSize` is 50 px and wins only as the first list entry; photos showed the stripped image because the cell prefers `strippedThumb` when present). G no longer depends on list order.

Cost: one `instanceof` per `setImage` when the gate is off; when on, a few field reads and set lookups. `setImage` runs thousands of times while scrolling; nothing in `filter` allocates on the pass-through path (return the inputs; allocate the array only when something is dropped).

### 2.5 Direct-URL web documents (A7, C4)
`ImageLocation.getForWebFile` turns a noproxy `WebFile` (`messenger/WebFile.java:61-71` ✓) into `imageLocation.path = webFile.url` (`messenger/ImageLocation.java:89-90` ✓), which `ImageLoader` fetches over plain HTTP from your IP. Add `if (webFile.noproxy && TrustController.blockNoProxy()) return null;` before it. Callers then show nothing (inline bot result thumbs in `ui/Cells/ContextLinkCell.java`, rich messages, invoice photos, ~ for each rendering an empty box gracefully). v1 blocks it for trusted bots too: `getForWebFile` has no chat context. v2 is ~5 lines in `ContextLinkCell`, which has the inline result's bot in reach (R2-9e), not the 20 caller files the previous draft feared. Proxied web documents (`location`-based, fetched by Telegram) are untouched.

### 2.6 Calls (A9)
`new Instance.Config(..., privateCall.p2p_allowed, ...)` (`messenger/voip/VoIPService.java:3423` ✓) → `&& isTrusted(user.id)`; set `udp_p2p` from the same check at `:1111` (outgoing), `:1880` and `:4360` (accepting) ✓. This governs what our client advertises and what our engine uses. The server-side "Peer-to-peer" privacy rule (`ContactsController.PRIVACY_RULES_TYPE_P2P`) still decides who may go P2P with you when the other side offers it; keep it at "My contacts" or "Nobody" as the floor (C14g; test plan step 8). Group calls go through Telegram's servers (~).

### 2.7 Stickers and custom emoji
Animated and video stickers are in v1 through G (no `ChatMessageCell` edit). Custom emoji are the stated exception: they draw through `ui/Components/AnimatedEmojiDrawable.java` (class `:60` ✓) whose `ImageReceiver` parent is the emoji document, not the message, so G cannot see the chat; threading the chat through means editing every text-drawing caller (~40-80 lines, high churn). Not planned unless the user asks.

### 2.8 Storage (A1)
Prefs file `telegram_custom` (patch 0003's `CustomSettings.prefs()` is private; `TrustController` opens the same file by name). Global keys `trust_on`, `trust_n`, `trust_d`, `trust_grace`, `trust_admin`, `trust_contacts`, `trust_sender`, `trust_tap`, `trust_relay`; per account `trust_marks_<account>` as a `StringSet` of `"<dialogId>:<state>:<markedAtUnix>"` and `trust_backfilled_<account>`. Undo is free: every mark change is reversible from the same menu.

### 2.9 UI (A10, A11, C10, C13)
**Chat ⋮ menu only** (no profile menu). New id beside `add_shortcut = 24` (`ui/ChatActivity.java:1656` ✓); item added in the `headerItem.lazilyAddSubItem` block (`:4445-4486` ✓, after `change_colors`); handler beside `id == add_shortcut` (`:3939` ✓). Label states first, action second: "Untrusted · Trust this chat", "Trusted (you) · Untrust", "Trusted (admin) · Never trust", "Trusted (active contact) · Never trust", "Dormant (you) · Trust again", "Never trusted · Clear". Keep the returned item and `setText` after a change. After a change: `getChatListView().getAdapter().notifyDataSetChanged()` (`:1760` ✓) so cells rebind.

**First-block toast:** the first time `allows()` returns false for a message whose chat is open (`LaunchActivity.getSafeLastFragment()` `ui/LaunchActivity.java:8784` ✓ is a `ChatActivity` with that `getDialogId()` `:12888` ✓), once per dialog per session, post on the UI thread `BulletinFactory.of(fragment).createSimpleBulletin(icon, "Media here waits for a tap", "Trust this chat", action)` (`ui/Components/BulletinFactory.java:447` ✓; icon an existing `R.raw` one, ~). The action sets the mark and refreshes the list as above. Lives in `TrustController`, no `ChatActivity` hunk. ~20 lines (inside A1).

**Settings:** row 101 next to Ghost mode's 100 (`ui/SettingsActivity.java:708`, `case` in `:845` ✓; patch 0004's pattern), subtitle "On · 3 days in 90". It opens `TrustSettingsActivity`: one screen, nine rows (master, N, D, grace as number rows with a picker dialog, rules 4/7/8, tap to load, relay calls). No list of marks (C8).

## 3. 🖥️ desktop design

### 3.1 custom_trust (D1)
`custom/custom_trust.{h,cpp}` beside `custom/custom_settings.*` (patch 0003), added to `Telegram/CMakeLists.txt` the same way. `Custom::Trusted(not_null<PeerData*>)`, `Custom::Allows(not_null<const HistoryItem*>)`, `SetMark`, `NoteIncoming`, pure `Decide(...)` for the test. State per `Main::Session` in a static `base::flat_map` (no upstream class changes). `Allows` first passes your own non-forwarded messages (`item->out()`, rule 2). Contacts `UserData::isContact()` (`data/data_user.h:261` ✓), bots `isBot()` (`:205`), self `isSelf()` and service `isServiceUser()` (`data/data_peer.h:274`, `:298` ✓).

### 3.2 Activity log (D2): own log only, no server seeding (C7)
tdesktop keeps no message database. `NoteIncoming` from `History::createItem` (`history/history.cpp:576` ✓), the point every `MTPMessage` becomes an item, history pages included; stock counts outgoing messages there for top peers (`:595-596` ✓, realtime only), ours runs for `!result->out() && peer->isUser() && !result->isService()` whether or not the message is new. Stored per account as `{peerId: [day, ...]}` pruned to 365 days, batched to disk (dirty flag, atomic `QSaveFile` on a 10 s timer and on quit). **UX, said plainly:** on desktop a contact becomes trusted by the activity rule once they have messaged you on `N` days since install, or once you have scrolled their private chat far enough back to load `N` days. No background requests (the draft's `messages.getHistory` seeding is dropped: new traffic, and `limit=100` under-counts chatty contacts, C7).

### 3.3 Gates (D3-D8)
- **Auto-download and autoplay** (`data/data_auto_download.cpp`): `Should(data, peer, document)` `:367`: one check at `:371` (`if (!document->sticker() && !allowed) return false;`), which also sits above `isGifv() → true` (`:377-378` ✓); `Should(data, peer, photo)` `:406`; `ShouldAutoPlay(data, peer, document)` `:426`; `ShouldAutoPlay(data, peer, photo)` `:449` ✓. Autoplay is the `AutoPlay*` types of the same table, so this includes media already cached. The peerless `Should(data, document)` (`:395`) is used only with no item (`data/data_document_media.cpp:333` ✓) and for stickers (below); left alone.
- **Photo thumbnails, reply photos:** `PhotoMedia::autoLoadThumbnailAllowed(peer)` (`data/data_photo_media.cpp:153-162` ✓) loads Small/Thumbnail whenever they exist; return false when untrusted. Reply previews call it (`data/data_reply_preview.cpp:110-114` ✓), but only when inline bytes exist: with none, `:110` fetches `Size::Small` regardless, so the condition there also gets the trust check (1 line, R2-9d).
- **Document thumbnails, reply documents:** `DocumentData::loadThumbnail(FileOrigin)` (`data/data_document.cpp:870` ✓) is the one function behind `loadThumbnail` at `history_view_gif.cpp:262`, `:1214`, `history_view_document.cpp:455` and `DocumentMedia::thumbnailWanted` (`data/data_document_media.cpp:242-245` ✓, used by replies `data_reply_preview.cpp:78` ✓). Gate: if the origin is a `FileOriginMessage`, its item (`session().data().message(...)`) exists and is not allowed, and the document is not a sticker and not already loaded or loading, return. A null item (a reply whose target is not loaded) fails open, as stock (R2-9c). ~6 lines.
- **Link previews:** large image through `Photo::automaticLoad` (gated above); the side image calls `_photoMedia->wanted(PhotoSize::Thumbnail, ...)` unconditionally (`history/view/media/history_view_web_page.cpp:944` ✓); gate it with `_parent->data()`.
- **Stickers static (D5):** in-chat stickers load through `checkStickerLarge()` → `automaticLoad(origin, nullptr)` (`data_document_media.cpp:288` ✓), i.e. with no peer, so `data_auto_download.cpp` cannot see the chat. Gate in `Sticker::readyToDrawAnimationFrame` (`history/view/media/history_view_sticker.cpp:190-195` ✓): when the item is not allowed and the sticker is animated or video, skip `checkStickerLarge()` and `setupPlayer()`, so the view keeps drawing its thumbnail (loaded at `:103` ✓). Covers cached stickers too. Clicking a sticker opens its pack (stock, ~).
- **Direct-URL web documents (D6):** `FromWebDocument` maps `MTPDwebDocumentNoProxy` to `PlainUrlLocation` (`ui/image/image_location_factory.cpp:306`, `:320-331` ✓), downloaded by `storage/file_download_web.cpp` from your IP; return an empty `ImageLocation()` while the trust model is on.
- **Stories (D7):** in `Stories::startPreloading` (`data/data_stories.cpp:2611` ✓), after the `Expects` (`:2612`) and before `make_unique<StoryPreload>` (`:2615`, else the loader starts: C14d): if the peer is untrusted and the id is not in `_toPreloadViewer`, `preloadFinished(id, false); return;` (`:2624-2637` ✓ erases it from all queues and continues).
- **Calls (D8):** `.enableP2P = call.is_p2p_allowed()` (`calls/calls_call.cpp:1090` ✓) → `&& Custom::Trusted(_user)` (`calls/calls_call.h:331` ✓); drop `f_udp_p2p` at `:356`, `:490`, `:974` when untrusted. `:1050` logs the result (test step 7). Server-side P2P rule is the floor, as on Android.

### 3.4 Stock exceptions reused
`Override { Default, ForceAllow, ForceDeny }` (`data/data_auto_download.h:50-54` ✓), the Settings → Advanced → Automatic media download "Always"/"Never" lists (`boxes/auto_download_box.cpp:355-361` ✓): a stock "Never" reads as never-trust, a stock "Always" as trusted by hand (rule 3/5 with `markedAt` = first seen). Our own marks stay the source of truth for the menu.

### 3.5 Storage
Global settings: new keys in `custom.json` (`cWorkingDir() + "custom.json"`, patch 0003). Per account: `trust_<selfUserId>.json` with marks `{peerId: {state, markedAt}}` and the activity log. Atomic `QSaveFile`.

### 3.6 UI (D9, D10, C13, C14f)
**Chat ⋮ menu only:** `Filler::addToggleTrust()` called from `fillHistoryActions` (`window/window_peer_menu.cpp:1922` ✓), same state-first labels as Android. After a change, repaint the open history so `draw` re-runs the gates (`Photo::draw` calls `automaticLoad`, `history/view/media/history_view_photo.cpp:340-348` ✓): `session.data().requestViewRepaint(view)` for each view of that history (`data/data_session.h:408` ✓), ~6 lines.

**First-block toast:** first gate refusal for an item in the chat shown by the active window, once per peer per session, via `crl::on_main` → `Window::Controller::showToast(Ui::Toast::Config)` (`window/window_controller.h:84` ✓) with "Media here waits for a tap. Trust this chat" where the link sets the mark (~ for the click-handler field name). ~20 lines in D1.

**Settings:** one "Media trust" button at the end of `BuildAutoDownloadSection` (`settings/sections/settings_advanced.cpp:217` ✓) opening one compact box with the same nine rows. C8 asked for no box; disagree in one line: the three numbers need an input, and a small box is the cheapest input tdesktop has (~75 lines, still under half the draft's 160).

## 4. 🧪 test plan

### 4.1 Caller-count guard (C1, C11)
`.github/media-callers.txt`: one line per `platform<TAB>pattern<TAB>file<TAB>count`, counted on the **upstream** tree before patches apply. Patterns: Android `canDownloadMedia(`, `canDownloadMediaType(`, `canPreloadStories(`, `getCurrentDownloadMask(`, `computeAutoDownload(`, `getForWebFile(`, `preloadStory(`, `udp_p2p`, `new ImageReceiver(` (G is load-bearing: a new file here is a new image surface to classify against G's whitelist); desktop `AutoDownload::Should(`, `AutoDownload::ShouldAutoPlay(`, `autoLoadThumbnailAllowed(`, `loadThumbnail(`, `thumbnailWanted(`, `checkStickerLarge(`, `startPreloading(`, `PlainUrlLocation`, `f_udp_p2p`. `.github/media-callers.sh check <platform> <tree>` greps and exits 1 only when a pattern appears in a **new file** or a known file's count **drops to zero** (a hook site vanished); a count change inside a known file prints a warning to the build log and the port commit message, not a failure (R2-7: upstream churns those files every release, and a guard that is always red gets updated blind). `update` rewrites the platform's lines. A step in `android.yml` and `desktop.yml` right after checkout, so the upstream workflow's red path (an issue naming the failed step) names the new caller. The table is updated in the same commit as each port, after reading every new caller.

### 4.2 Without a device
- CI builds both patches; C1 passes.
- `decide()` unit tests run the section 1 table row by row, with edges: day `D` vs `D+1`, grace expiry, never-trust beating admin, rule 4 on a non-creator supergroup admin (untrusted), rule 8 off by default, bots never by activity.
- Activity feed: a JVM test feeding synthetic `TLRPC.Message` lists (incoming, outgoing, service, scheduled, group) into `noteIncoming` against an in-memory SQLite asserts only the right `(uid, day)` rows land (~ for running `SQLiteDatabase` off-device: may need Robolectric; else code reading).
- Code reading: every anchor in section 0 carries a `telegram-custom` marker; `grep` count matches the build list.

### 4.3 On the phone and the laptop (the user)
1. Untrusted group: a photo, a video and a GIF show blurred; nothing plays; a tap loads that one.
2. A reply quoting a photo in that group shows a blurred quote image.
3. Animated and video stickers there are still pictures; tapping opens the pack.
4. The first blocked item shows the toast; "Trust this chat" loads everything and the menu now reads "Trusted (you) · Untrust".
5. A channel you admin and an active contact load as stock with no mark.
6. Link preview from an untrusted chat: card text shows, image blurred until tapped.
7. Call an untrusted contact: it connects; desktop log line shows `p2p` false (`calls_call.cpp:1050`); Android has no indicator in stock (~), code path only.
8. Settings → Privacy → Calls → Peer-to-peer is "My contacts" or "Nobody" on the account (the server-side floor).
9. Stories of an untrusted peer open with a loading spinner; trusted ones open instantly.
10. An inline bot whose results used direct URLs shows empty thumbnails (expected).
11. Tap a GIF and a video in an untrusted group: the GIF plays in place, the video plays; a GIF already cached from a trusted chat also needs one tap, then plays.
12. A photo you sent from the phone into an untrusted chat loads on the laptop without a tap; a forward of a stranger's photo does not.
13. A pinned message with a photo in an untrusted chat shows a blurred thumbnail in the pinned bar; a shared location shows its map.

## 5. ⚠️ risks

| Hook | Churn | Note |
|---|---|---|
| `DownloadController` funnels (A3, A4) | low | unchanged between 12.10.3 and 13.0.3 in this region |
| `ImageReceiver.setImage` (A6) | low-medium | 11-arg signature stable (~); the gate's correctness depends on tap paths keeping `setForceLoading(true)` and on cells keeping themselves as `parentView` |
| `RichMessageLayout` (A5) | medium | new feature, moving |
| `ChatActivity` menu (A10) | medium | menu block moved 46 lines in one release (C10); additive hunk, anchor on `add_shortcut` |
| `MessagesStorage` feeds (A2) | low | two one-line calls at function tops |
| `VoIPService` (A9) | low | |
| desktop `data_auto_download.cpp`, `data_document.cpp`, `data_photo_media.cpp` | low | small, stable data-layer files |
| desktop `history_view_sticker.cpp`, `history_view_web_page.cpp` | medium | view files, but one line each |
| desktop `data_stories.cpp` | medium | patch 0004 also edits it |
| desktop `window_peer_menu.cpp` | medium | additive filler |

**The real risk is a new caller that compiles** (rich messages were one): C1 turns it into a red build. G narrows the residual further on Android, because any new cell path that passes the message as `parentObject` is covered without being listed.

**G-specific risks:** a new tap path that bypasses `didPressButton` (e.g. a future in-cell control) leaves its item blurred; a downloaded video or GIF shows its blurred thumbnail after a restart until tapped once (the tapped set is per session; the cached file plays instantly). Both fail closed. A `BackupImageView` in a viewer that passes a `MessageObject` as parent would show blurred there (~, none found by the critique). The `didPressButton` hunk is one statement under a signature stable for years; low-medium churn.

**False untrust (safe, annoying):** fresh desktop install; a contact who only calls; a friend who writes in one burst a month; people who write only in shared groups. The fix is a hand mark (which decays the same way, so lower `N` or raise `grace`).

**False trust (dangerous side):** a compromised trusted account; a forwarded malicious file inside a trusted chat (trust is per chat, not per file origin); rule 8 if the user turns it on. A stranger cannot become trusted without being your contact or marked by you.

**Performance:** G runs on every `setImage`; pass-through costs one `instanceof` when off and a few lookups when on, no allocation. Activity SQL is a tiny table. Desktop gates run in `draw`, all precomputed.

## 6. 🤔 open questions (each has a default in the build; user to confirm)

1. **Hand-trusted person who goes quiet:** dormant, revives when active again. Default, user to confirm. Alternative: delete the mark at expiry.
2. **Group activity counts toward a person's active days?** No, private chat only ("messaged me"). Default, user to confirm.
3. **Grace for a fresh hand mark:** 90 days (= `D`). Default, user to confirm. Alternative: 0.
4. **Admin rule scope:** groups you created plus channels you create or admin; not supergroups where you are a non-creator admin. Default, user to confirm. Alternative: any chat you admin (your literal wording; trusts strangers' media in big groups you moderate).
5. **Trusted sender widens a message inside an untrusted group (rule 8):** off. Default, user to confirm.
6. **Direct-URL web documents blocked even for trusted bots in v1:** yes. Default, user to confirm (v2 can thread the bot through the inline-results cell).
7. **Custom emoji keep animating in untrusted chats:** yes, stated exception. Default, user to confirm.
8. **Desktop activity rule starts empty (no server seeding):** yes. Default, user to confirm.
9. **Desktop: stock "Always"/"Never" lists count as trust marks:** yes. Default, user to confirm.
10. **Telegram service account 777000 trusted:** yes. Default, user to confirm.
11. **Per-device marks, no sync:** yes. Default, user to confirm.
12. **Your own forwards of others' media stay gated:** yes (only your own original messages are exempt). Default, user to confirm.

## 7. 📝 critique 1 dispositions

| C | Disposition |
|---|---|
| 1 | Fixed: gate G on Android (one `ImageReceiver` hunk), `loadThumbnail` + `autoLoadThumbnailAllowed` + web-page side image on desktop |
| 2 | Fixed: reasoning replaced; G does not rely on list order |
| 3 | Fixed in v1: animated/video stickers static on both; custom emoji a stated exception |
| 4 | Fixed: noproxy web documents blocked while the model is on (no per-bot exception in v1) |
| 5 | Fixed: rule 8 default off |
| 6 | Fixed: own activity table on Android, fed at both storage entry points (C6 named one; history pages use a second); same arrival model as desktop |
| 7 | Taken: no desktop seeding |
| 8 | Taken, partly: one compact screen per platform, one "tap to load" toggle; desktop keeps a small box for number input (reason in 3.6) |
| 9 | Taken: 4 funnel hunks + 1 story line; peerless callers wrapped, not swapped (swapping changes the type check) |
| 10 | Taken: chat menu only, no profile menu, no `ChatMessageCell` edits; re-pinned to 13.0.3 |
| 11 | Taken: caller table + script in CI (4.1) |
| 12 | Fixed: per-device scope paragraph |
| 13 | Taken: first-block toast + state-first labels |
| 14 | a: service messages excluded; b: games covered by G; c: snapshot reads; d: check before `make_unique`; e: claim narrowed; f: repaint on mark change; g: server P2P floor in the test plan |

**Critique 2**

| R2 | Disposition |
|---|---|
| 1 | Fixed: A6b, first statement of `didPressButton` marks the message tapped and rebinds; `isForceLoding()` kept as a belt |
| 2 | Fixed: rule 2 exempts your own non-forwarded messages, both platforms |
| 3 | Fixed by extending the whitelist with `BackupImageView` (pinned and composer bars); shared-media grid listed under "Not covered" (you open it); reason for whitelist over blacklist in 2.4 |
| 4 | Fixed: proxied web files pass G; maps in the test plan |
| 5 | Taken: Java backfill with the live feed's rules; "starts better" reworded; `putDialogsInternal` noted |
| 6 | Fixed: anchors in files earlier patches touch now say "after 0004 applies" and cite the nearest stock line |
| 7 | Taken: fail on new files and zero counts, warn on count changes; `new ImageReceiver(` added |
| 8 | Taken: per-dialog verdict cache |
| 9 | a: one check at `:371`; c: null item fails open; d: reply `:110` gated; e: v2 bot exception ~5 lines; f: noted; g: G hunk is the first statement at `:573` |
