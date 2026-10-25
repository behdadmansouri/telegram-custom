# Trust model: design

Plan item: [plan.md](plan.md) → batch 2 step 5. Pins read: Android DrKLO `9552e554` (12.10.3), desktop tdesktop `v7.2.5`. Paths are relative to `TMessagesProj/src/main/java/org/telegram/` (Android) and `Telegram/SourceFiles/` (desktop). ✓ = verified in source at the pin; ~ = inferred (reasoned from nearby code, not traced end to end).

## 1. 📐 rules (spec)

**Unit of trust is the chat (dialog), with one per-message widening.** A message is trusted when its chat is trusted, or (group chats only) when its sender is a trusted person. That mirrors stock, which already classes "media from a contact inside a group" as contact media (`DownloadController.java:711-727` ✓).

**Inputs, per account:** the account's own user id; the dialog's kind (user, bot, basic group, supergroup, channel, secret chat); admin/creator flags of the chat; the contact list; the manual lists below; a per-person set of "active days" (local calendar days on which that person sent at least one message in the private chat with you, within the window).

**Rules, evaluated top to bottom, first match wins:**

| # | Rule | Result |
|---|---|---|
| 0 | Master switch off | trusted (stock behaviour everywhere) |
| 1 | Chat is on the "never trust" list | untrusted |
| 2 | Saved Messages (self), or Telegram service account 777000 | trusted |
| 3 | Group, channel or bot on the "trusted" list | trusted (never decays) |
| 4 | Group or channel you created or admin (setting, default on) | trusted |
| 5 | Person on the "trusted" list, marked less than `grace` days ago | trusted |
| 6 | Person on the "trusted" list with at least `N` active days in the last `D` days | trusted |
| 7 | Contact with at least `N` active days in the last `D` days (setting, default on) | trusted |
| 8 | Group message whose sender is trusted by rules 2, 5, 6 or 7 (setting, default on) | trusted, this message only |
| 9 | Anything else | untrusted |

**Decay of a hand-trusted person (rules 5-6):** the mark is never deleted by decay. It is dormant while the person is below the threshold, and comes back by itself when they are active again. Why not clear it: clearing is a silent, irreversible edit to a user decision; dormancy gives the user's "it drops" behaviour without losing the mark. The trust screen lists dormant marks so the user sees why someone dropped.

**Secret chats:** take the trust of the peer user (rules 1, 5-7 by user id). **Bots:** only by hand (rule 3); a bot never passes the activity rule (its "messages" are automated). **Non-contact people:** only by hand (rules 5-6), since rule 7 needs a contact.

**Settings and defaults (all adjustable):**

| Setting | Default | Range |
|---|---|---|
| Trust model on | on | on/off |
| `N` active days | 3 | 1-30 |
| `D` window, days | 90 | 7-365 |
| `grace` for a fresh hand mark, days | = `D` | 0-365 |
| Admin/creator chats trusted | on | on/off |
| Active contacts trusted | on | on/off |
| Trusted sender widens a group message | on | on/off |
| Untrusted: block auto-download | on | on/off |
| Untrusted: block autoplay | on | on/off |
| Untrusted: block story preload | on | on/off |
| Untrusted: block link-preview images | on | on/off |
| Untrusted: calls relay-only (no P2P) | on | on/off |
| Untrusted: static stickers/custom emoji | off | on/off (separate optional item, section 2.9 / 3.8) |

**What untrusted means:** no media download without a tap (only the thumbnail embedded in the message, Telegram's tiny blurred "stripped" one, shows); no GIF/video/round-video autoplay; stories of that peer are not preloaded; link-preview images wait for a tap; 1:1 calls use Telegram's relay (P2P off: a direct call reveals the IP). A tap always loads: the gate only stops what happens on its own. **What trusted means:** exactly stock, under the user's normal auto-download, power-saving and P2P-privacy settings. Trust never forces a download stock would not do.

**Scope:** the manual lists and the activity data are per account (dialog ids are per account; contacts and admin rights are per account). The rule settings (numbers, toggles) are global, one set for all accounts, like Ghost mode. "Active day" uses the device's local time zone.

## 2. 🤖 Android design

### 2.1 Where trust is computed
New `messenger/TrustController.java`, one instance per account (`getInstance(account)`, same pattern as `DownloadController`). Public surface: `isTrusted(long dialogId)`, `isTrusted(MessageObject)` / `isTrusted(TLRPC.Message)` (applies rule 8 with `from_id`), `setManual(long dialogId, int state)` (none / trusted / never), `refresh()`. `isTrusted` is called on the UI thread from cell binding, so it must be O(1): it reads in-memory sets only (manual lists, active-user set) plus `MessagesController.getChat()` (a concurrent map). The expensive part (active days) is computed off-thread into a `volatile Set<Long> activeUsers`.

### 2.2 Counting "messaged on N separate days in D days"
Local data: `messages_v2(mid, uid, read_state, send_state, date, data, out, ...)` with index `uid_date_mid_idx_messages_v2 ON messages_v2(uid, date, mid)` (`MessagesStorage.java:551-553` ✓). For a private chat `uid` is the user id; `out` is 0 for incoming; `date` is server unix time.

Query, run on `MessagesStorage.getStorageQueue()`, once per candidate (contacts plus hand-marked people, typically a few hundred):

```sql
SELECT COUNT(DISTINCT (date + ?tzOffset) / 86400)
FROM messages_v2
WHERE uid = ?userId AND out = 0 AND date >= ?now - ?D*86400
```

Each is an index range scan on `(uid, date)`: sub-millisecond for a normal chat (~). A few hundred candidates is a few hundred ms on the storage thread at most, once per refresh. Not a single `GROUP BY uid` over the whole table: there is no index on `date` alone, so that would scan every cached message.

**Refresh cadence:** on account start after contacts load, then every 6 h, and immediately after the user changes a rule or a manual mark. Staleness of a few hours is fine: a person crossing the threshold today gets trusted by the next refresh. Optional incremental update (cheap, ~10 lines): when an incoming private message lands on a day not yet counted, add it in memory.

**When history is not cached locally:** stock caches every message it receives through updates and every history page it loads (`putMessagesInternal`, `MessagesStorage.java:11862` ✓), so on a phone that stays logged in the table is close to complete. Gaps: a fresh install or re-login (empty table), and Settings → Data → Storage → "Clear local database" (`clearLocalDatabase`, `MessagesStorage.java:1415` ✓, trims cached history). Failure mode is fail-closed: an active contact looks untrusted until they message again on N days, or until the user opens the chat (opening loads history into the table, ~). Recommended v1: accept the gap (no extra requests, no extra hook). If it bites, v2 adds our own table `tc_activity(uid INTEGER, day INTEGER, PRIMARY KEY(uid, day))` in the same database, fed from the top of `putMessagesInternal` and untouched by "clear local database" (~25 lines).

### 2.3 Admin and contacts
Admin/creator: `ChatObject.hasAdminRights(chat)` = `chat.creator || admin_rights.flags != 0` (`messenger/ChatObject.java:2123` ✓), `ChatObject.isCreator` (`:2127` ✓). Contacts: `ContactsController.contactsDict` (`messenger/ContactsController.java:238` ✓) or `isContact(userId)` (`:1770` ✓), the same map stock uses for its own contact class.

### 2.4 Gate points
**Auto-download** (one line each, `if (!getTrustController().isTrusted(msg)) return 0;` or `false`), all in `messenger/DownloadController.java`:
- `canDownloadMedia(MessageObject)` `:609` ✓, before the story branch (a forwarded public story otherwise loads regardless of presets, `:610-617` ✓).
- `canDownloadMediaType(MessageObject)` `:652` ✓ and `canDownloadMediaType(MessageObject, long)` `:670` ✓.
- `canDownloadMedia(TLRPC.Message)` `:861` ✓ (used by `MessagesStorage.java:12815` ✓ to queue background downloads of fresh messages, and `ChatActivity.java:41393`, `PhotoViewer.java:16492` ✓).
- `canDownloadMedia(TLRPC.Message, TLRPC.MessageMedia)` `:942` ✓.
- `canDownloadMedia(int type, long size)` `:627` ✓ has no peer. Wrap its peer-aware callers instead: `ui/Cells/DialogCell.java:5749` ✓ (chat-list thumbnail) and `messenger/RichMessageLayout.java:7209`, `:8139` ✓ (rich messages, `root` carries the account and message, ~). 3 lines.

These 8 sites cover every caller found: `grep` counts 11 in `ChatMessageCell`, 6 in `MessagesController` (via `getAutodownloadMask()` into `putMessages`), 5 in `PhotoViewer`, and singles elsewhere (✓ for the count; each caller funnels into one of the gated methods, ~ for the less common ones).

**Autoplay:** stock autoplay needs the media present or the download/stream allowed: GIF/round `autoDownload = canDownloadMedia(...)` then `if (mediaExists || autoDownload)` → autoplay (`ui/Cells/ChatMessageCell.java:8707-8721` ✓); streamed video `SharedConfig.isAutoplayVideo() && ... canStreamVideo() && canDownloadMedia(...)` (`:8691-8693`, `:10319-10320` ✓). So the download gate already stops autoplay of anything not yet on disk. Left open: media already cached (e.g. the same GIF seen in a trusted chat) still autoplays. Closing that needs a per-message check at the `SharedConfig.isAutoplayGifs()/isAutoplayVideo()` sites (`ChatMessageCell.java:3271`, `:4342`, `:8256`, `:8691`, `:9315`, `:10319`, `:18083`, `:18103` ✓), about 8 one-line edits; `LiteMode.isEnabled` (`messenger/LiteMode.java:149` ✓) is global and has no peer, so it is not the hook. Recommended: v1 relies on the download gate (the file was already decoded once when it was cached); the 8 edits are the v2 "block autoplay" toggle.

**Story preload:** `StoriesController.preloadStory(long dialogId, StoryItem)` checks `canPreloadStories()` at `ui/Stories/StoriesController.java:585` ✓; all three preload callers go through it (`:572-577`, `:878`, `:1545` ✓) and it already has `dialogId`. One line. Story playback inside the viewer is a user action and stays (see risks: auto-advance).

**Link-preview images:** a webpage photo counts as a photo for auto-download: `MessageObject.isPhoto(TLRPC.Message)` returns true for `TL_messageMediaWebPage` with a photo (`messenger/MessageObject.java:10601-10602` ✓), and the webpage branch of the cell loads the full image only if `canDownloadMedia(currentMessageObject)` (`ChatMessageCell.java:8735` ✓), else only the thumb (`:8742-8745` ✓). So the auto-download gate covers it with no extra edit. The fallback thumb is `getClosestPhotoSizeWithSize(sizes, 40)` (`:8240`, `:8289` ✓), which in practice picks the embedded stripped size (~: `FileLoader.java:1457-1487` picks the largest size ≤ 40 px, and the stripped one is the only one that small in normal photos). A dedicated "link-preview images" toggle separate from the download toggle is one extra condition at `:8735` (gate only when `media instanceof TL_messageMediaWebPage`).

**Calls, P2P:** engine flag `new Instance.Config(..., privateCall.p2p_allowed, ...)` at `messenger/voip/VoIPService.java:3420` ✓ → `privateCall.p2p_allowed && trusted(user.id)`; advertised flags `reqCall.protocol.udp_p2p = true` (`:1108` ✓, outgoing) and `udp_p2p = udp_reflector = true` (`:1877`, `:4367` ✓, accepting) → set `udp_p2p` from the same check. 4 lines. Group calls go through Telegram's servers anyway (~).

### 2.5 Storage
Same prefs file as `CustomSettings` (`getSharedPreferences("telegram_custom")`, created by patch 0003). Keys: `trust_on`, `trust_n`, `trust_d`, `trust_grace`, `trust_admin`, `trust_contacts`, `trust_sender`, `trust_block_*` (global); per account `trust_manual_<account>` as a `StringSet` of `"<dialogId>:<state>:<markedAtUnix>"`. `TrustController` keeps a parsed copy in memory and writes with `apply()`. Account-scoped like `hiddenCountersKey(account)` in 0003. Undo is free: every manual change is a toggle back.

### 2.6 UI
- **Chat header ⋮ menu:** one item "Trust this chat" / "Untrust this chat" / "Clear trust override", added next to the existing `headerItem.lazilyAddSubItem(...)` block (`ui/ChatActivity.java:4399-4440` ✓), new id constant beside `add_shortcut = 24` (`:1640` ✓), handler in the `onItemClick` chain next to `id == add_shortcut` (`:3897` ✓). After a change: `chatAdapter.notifyDataSetChanged()` so cells re-run `setMessageContent` (~). ~20 lines.
- **Profile ⋮ menu:** same item in `ui/ProfileActivity.java` next to `otherItem.addSubItem(add_shortcut, ...)` (`:12135`, `:12197`, `:12249` ✓), handler beside `id == add_shortcut` (`:2727` ✓). ~15 lines.
- **Visible state:** a small shield in the chat subtitle is tempting but touches the header layout; v1 shows the state only as the menu label ("Untrust" means it is trusted). Cheaper and honest.
- **Settings screen:** a "Media trust" row in `SettingsActivity` exactly like Ghost mode's (`SettingCell.Factory.of(100, ...)` and `case 100:` in patch 0004; use id 101), opening a new `ui/TrustSettingsActivity.java` built on the same `UItem` list pattern: master switch, N/D/grace number rows, the rule toggles, the "untrusted means" toggles, and a list of manual marks (with dormant ones flagged and a one-tap remove). ~200 lines.

### 2.7 Line estimate

| Piece | Lines |
|---|---|
| `TrustController.java` (rules, query, cache, prefs) | 180 |
| `DownloadController` gates + 3 caller wraps | 12 |
| Story preload gate | 1 |
| VoIP P2P | 4 |
| Chat menu + profile menu | 35 |
| Settings row + `TrustSettingsActivity` | 205 |
| Optional: cached-media autoplay (8 sites) | 8 |
| Optional: own activity table | 25 |
| **v1 total** | **~440, of which ~55 inside upstream files** |

### 2.8 Desktop-like "exceptions" check
Android 12.10 has no per-chat auto-download exception list: `canDownloadMediaInternal` (`DownloadController.java:688-776` ✓) consults only the contact/private/group/channel class and the presets. So nothing stock to reuse here, unlike desktop (3.4).

### 2.9 Optional: static stickers and custom emoji in untrusted chats
Stickers bypass auto-download: in the sticker branch the cell loads the document unconditionally (`ChatMessageCell.java:9760-9770` ✓, video sticker via `AUTOPLAY_FILTER`, animated via rlottie). Static-in-untrusted means: for video (webm, ffmpeg/vpx) and animated (TGS, rlottie) stickers, load only `currentPhotoObjectThumb` / `pathThumb` (the vector outline) plus a tap-to-play. ~15 lines in that branch. Custom emoji render through `ui/Components/AnimatedEmojiDrawable.java` (class at `:60` ✓), which already has a static-thumb path (`svgThumb`, `:636-671` ✓) but no per-chat context; threading the chat into it touches every text-drawing caller, ~40-80 lines and high churn. Recommendation: stickers yes (cheap), custom emoji only if the user wants it after seeing stickers.

## 3. 🖥️ desktop design

### 3.1 Where trust is computed
New `custom/custom_trust.{h,cpp}` (beside `custom/custom_settings.*` from patch 0003, added to `Telegram/CMakeLists.txt` the same way). `Custom::Trusted(not_null<PeerData*> peer)` and `Custom::Trusted(not_null<HistoryItem*>)` (rule 8 with `item->from()`); per-session state hangs off `Main::Session` via a static `base::flat_map<not_null<Main::Session*>, State>` (keeps it out of upstream classes). Admin: `ChannelData::amCreator()` / `hasAdminRights()` (`data/data_channel.h:358`, `:385` ✓), `ChatData` same (`data/data_chat.h:67`, `:88` ✓). Contacts: `UserData::isContact()` (`data/data_user.h:261` ✓); bots `isBot()` (`:205` ✓); self `isSelf()`, service `isServiceUser()` (`data/data_peer.h:274`, `:298` ✓).

### 3.2 The activity rule without a message database
tdesktop keeps history in memory only; nothing to query after a restart. Options:

| Option | How | Cost | Accuracy |
|---|---|---|---|
| A. Own activity log | `activity_<userId>.json` per account: `{peerId: [day, ...]}` pruned to `D` days; fed by every incoming private message the client materialises (realtime updates, history pages, dialog tops) | 1 hook, a few KB on disk, no requests | Starts empty on a new profile; fills as messages arrive; survives restarts |
| B. Loaded history only | count days in `History` blocks in memory | 0 storage | Resets every restart: everyone untrusted until their chat is opened. Fail-closed but useless |
| C. Server search | per contact `messages.getHistory` (or `messages.search` with `from_id` and `min_date`) and count days | 1-3 requests per contact per refresh; hundreds a day → flood-wait risk | Exact, any time |

**Recommendation: A, seeded lazily by C.** A carries the steady state for free. The gap (new profile, or a contact who was active before install) is filled by one capped `messages.getHistory(peer, limit=100)` for a contact the first time the client needs a trust decision about them and their log has fewer than `N` days but the dialog's last message is inside the window. Queue at most one request per 2 s, 50 per day, once per peer ever (a `seeded` flag in the same file). These requests go to Telegram about your own chats, which it already has; the only cost is rate limits. Until seeded the peer is untrusted (fail closed); `Photo::draw` calls `automaticLoad` on every paint (`history/view/media/history_view_photo.cpp:340-348` ✓), so a repaint after seeding re-evaluates with no extra plumbing.

**Feed hook:** `History::createItem` (`history/history.cpp:576` ✓) is where every `MTPMessage` becomes an item; stock already counts outgoing messages there for top peers (`session().topPeers().increment(peer, result->date())`, `:595-596` ✓, realtime only; ours must not require `newMessage`, so history pages count too). Add the mirror line for `!result->out() && peer->isUser()`. 2 lines. Writes are batched (dirty flag, `QSaveFile` atomic save on a 10 s timer and on quit), same atomic pattern as `custom_settings.cpp`.

### 3.3 Gate points (`data/data_auto_download.cpp` unless noted)
- `Should(data, peer, document)` `:367` ✓: insert after the sticker line (`:371` ✓) and before `isGifv() → true` (`:377-378` ✓), else GIFs always download.
- `Should(data, peer, photo)` `:406` ✓.
- `ShouldAutoPlay(data, peer, document)` `:426` ✓ and `ShouldAutoPlay(data, peer, photo)` `:449` ✓. Autoplay on desktop is the `AutoPlay*` types of the same table (feasibility D5 ✓), so this one function pair is the whole autoplay gate, including cached media (better than Android).
- Peerless `Should(data, document)` `:395` ✓ is used only when there is no item (`data/data_document_media.cpp:333` ✓); leave it.
- **Network thumbnails:** `PhotoMedia::autoLoadThumbnailAllowed(peer)` (`data/data_photo_media.cpp:153-162` ✓) loads the Small/Thumbnail size whenever it exists, regardless of settings. Gate it, so untrusted chats show only the inline (embedded) thumbnail. 1 line. Document thumbnails (`_data->loadThumbnail(...)` at `history/view/media/history_view_gif.cpp:262`, `:1214`, `history_view_document.cpp:455` ✓) load unconditionally too; gating them needs the item's peer at each of the 3 sites (~3 lines).
- **Stories:** `Stories::startPreloading(story)` (`data/data_stories.cpp:2611` ✓) is the one place a preload starts; if the story's peer is untrusted and the id is not in `_toPreloadViewer` (the open viewer), call `preloadFinished(id, false)` (`:2624-2637` ✓, drops it from the queues and moves on). ~5 lines.
- **Link previews:** the large preview photo goes through `Photo::automaticLoad(peer)` (gated above, `history_view_photo.cpp:348`, `:824` ✓); the small side image calls `_photoMedia->wanted(PhotoSize::Thumbnail, ...)` unconditionally (`history/view/media/history_view_web_page.cpp:944` ✓). Gate that call. 2 lines.
- **Calls P2P:** `.enableP2P = call.is_p2p_allowed()` (`calls/calls_call.cpp:1090` ✓) → `&& Custom::Trusted(_user)` (`_user` member, `calls/calls_call.h:331` ✓); drop `f_udp_p2p` at the three request sites `:356`, `:490`, `:974` ✓ when untrusted. ~6 lines.

### 3.4 Reuse stock per-chat exceptions
tdesktop already has per-peer auto-download exceptions: `Override { Default, ForceAllow, ForceDeny }` (`data/data_auto_download.h:50-54` ✓), consulted by every gate above via `data.peerOverride(peer->id)` (`data_auto_download.cpp:374`, `:410`, `:433`, `:456` ✓), edited in Settings → Advanced → Automatic media download → "Always"/"Never" lists (`boxes/auto_download_box.cpp:355-361` ✓), stored in the session settings. Recommended: read a stock "Never" as our "never trust" and a stock "Always" as hand-trusted (both are the user's own per-chat decision); keep our own list for everything else, because the stock override has no timestamp (needed for the person grace period) and Android has no equivalent. Our own list stays the source of truth for the trust menu item.

### 3.5 Storage
Global rule settings: new keys in `custom.json` (`cWorkingDir() + "custom.json"`, patch 0003's `custom_settings.cpp`). Per account: `trust_<selfUserId>.json` holding the manual marks `{peerId: {state, markedAt}}` plus the activity log and seeded flags (one file per account, so one account's churn never rewrites another's). Atomic `QSaveFile`, same as 0003.

### 3.6 UI
- **Peer menu:** new `Filler::addToggleTrust()` in `window/window_peer_menu.cpp`, called from `fillHistoryActions` (chat ⋮, `:1922` ✓), `fillContextMenuActions` (chat-list right-click, `:1897` ✓) and `fillProfileActions` (`:1945` ✓). Label flips between "Trust this chat" / "Untrust this chat", with "Clear trust override" when a manual mark exists. ~30 lines.
- **Settings section:** a "Media trust" button at the end of `BuildAutoDownloadSection` (`settings/sections/settings_advanced.cpp:217-256` ✓, the same section as the stock auto-download rows) opening a `Ui::GenericBox`: master switch, N/D/grace sliders, the rule toggles, the "untrusted means" toggles, and the manual list. ~150 lines. A main-menu entry like Ghost mode's is not worth it: this is set once, not toggled daily.

### 3.7 Line estimate

| Piece | Lines |
|---|---|
| `custom_trust.{h,cpp}` (rules, log, lazy seed queue, storage) | 260 |
| Auto-download/autoplay/thumbnail gates | 10 |
| Story preload | 5 |
| Webpage side image | 2 |
| Calls P2P | 6 |
| Feed hook in `History::createItem` | 2 |
| Peer menu | 30 |
| Settings button + box | 160 |
| CMakeLists | 2 |
| **total** | **~480, of which ~60 inside upstream files** |

### 3.8 Optional: static stickers
`Should(...)` and `ShouldAutoPlay(...)` return true for every sticker (`data_auto_download.cpp:356`, `:371`, `:398`, `:430` ✓) and `history_view_sticker.cpp:103` ✓ loads its thumbnail unconditionally. Static-in-untrusted: in `HistoryView::Sticker`, for animated (`isAnimated`, rlottie) and video (`isVideo`, ffmpeg) stickers, draw the thumbnail and skip creating the player until clicked (~20-30 lines, ~). Custom emoji go through `Data::CustomEmoji` with no chat context; same verdict as Android: stickers yes, custom emoji later if wanted.

## 4. 🧪 test plan (no device needed for the first half)

**Checkable by reading code and CI:**
- Every gate in 2.4 and 3.3 compiles and is reached: CI build plus a `grep` that each listed site carries a `telegram-custom` marker.
- Caller coverage: re-run the caller `grep`s (`canDownloadMedia(`, `AutoDownload::Should`, `ShouldAutoPlay`, `preloadStory(`, `startPreloading(`) after every upstream bump and diff the list against this doc; a new caller is a new leak.
- Rule logic is pure: `TrustController.decide(inputs)` / `Custom::TrustDecide(inputs)` take plain values (kind, flags, manual state, active-day count, now) so a JVM unit test and a small C++ test can run the table in section 1 row by row in CI, including decay edges (day `D` vs `D+1`, grace expiry, never-trust beating admin).
- Activity SQL: run the query from 2.2 against a synthetic SQLite with the same schema and index (`EXPLAIN QUERY PLAN` must show `uid_date_mid_idx_messages_v2`).

**Needs the user, on the phone and the laptop:**
1. Untrusted group: a new photo shows blurred, loads on tap; a GIF does not play until tapped.
2. Trusted (admin) channel: media loads as stock.
3. Mark a non-contact person trusted: media loads; set `grace` to 0 in settings: it drops (they have fewer than N days); remove the mark: stays untrusted.
4. An active contact (writes most days) is trusted without any mark.
5. A link with a preview from an untrusted chat: card text shows, image waits for a tap.
6. Stories ring of an untrusted person: opening is instant on trusted peers, shows loading on untrusted ones (no preload).
7. Call an untrusted contact: call works; on desktop the call log line `p2p` reads false (`calls_call.cpp:1050` ✓ logs it); Android shows no P2P indicator in stock (~), so there the proof is the code path plus the user hearing the call connect.
8. Clear local database (Android) and confirm the expected fail-closed drop of an active contact, then reopening their chat restores it.

## 5. ⚠️ risks

**Upstream churn per hook point:**

| Hook | Churn | Why |
|---|---|---|
| Android `DownloadController` 5 methods | low | stable for years; signatures unchanged across 11.x-12.x (~) |
| Android `ChatMessageCell` (optional autoplay, stickers) | **high** | 29.5k-line file, rewritten every release; keep edits to v2 and one-liners |
| Android `RichMessageLayout`, `DialogCell` wraps | medium | rich messages are new and moving |
| Android `ChatActivity` / `ProfileActivity` menus | medium | menu blocks get reshuffled; the patch is additive, conflicts are context-only |
| Android `VoIPService` | low | |
| Desktop `data_auto_download.cpp` | low | small file, stable API |
| Desktop `data_stories.cpp` preload | medium | stories code still evolving; 0004 already patches this file |
| Desktop `window_peer_menu.cpp` | medium | additive filler, list order changes often |
| Desktop `History::createItem` | low-medium | central, but our line sits beside a stable `topPeers` call |

**The real churn risk is a new caller, not a broken hook:** upstream adds a fresh media path (as rich messages did) that calls the peerless API, and media in untrusted chats loads again with no build error. The caller `grep` in section 4 is the guard; make it a CI step that fails on an unknown caller.

**Performance:** Android `isTrusted` on the bind path must stay set lookups; the SQL runs off-thread and is bounded by the candidate count. Desktop gates run in `draw`; same rule, everything precomputed. Desktop lazy seed is capped at 50 requests a day.

**False untrust (annoying, safe):** fresh install, cleared database (Android), a contact who calls but never texts, a close friend who sends one long burst a month (1 active day), voice-call-only relationships, a person who writes only in shared groups (rule 7 counts the private chat only). Mitigation: hand mark (decays the same way, so a monthly-burst friend needs `N` lowered or a long `grace`; see question 3).

**False trust (the dangerous side):** an admin chat where you admin a large public group full of strangers (rule 4 trusts every sender's media there); a compromised trusted account; a forwarded malicious file inside a trusted chat (trust is about the chat, not the file's origin); rule 8 lets a trusted contact's message load in a hostile group, which is intended. A stranger cannot become trusted without being a contact or being marked by you, and contact status is something they cannot set for you.

**Leaks not covered by this design:** media already cached on disk plays (Android v1); stickers and custom emoji (optional item); avatars and profile photos (always load, every client does; ~); in-viewer story auto-advance to the next peer loads that peer's story (user started the viewer); P2P privacy on the server still governs who *you* expose to when the *other* side is a trusted contact.

## 6. 🤔 open questions (my recommended answer first)

1. **Hand-trusted person who goes quiet: dormant or deleted?** Recommended: dormant (mark kept, revives when they are active again, shown as "dormant" in the list). Alternative: delete the mark at expiry.
2. **Does activity in shared groups count toward a person's active days?** Recommended: no, private chat only ("messaged me"); it keeps the query on one index and matches the words. Alternative: count their group messages too (heavier query, a talkative group member becomes trusted).
3. **Grace for a fresh hand mark:** recommended `grace = D` (90 days of trust after marking, then the activity rule). Alternative: 0 (activity applies at once, so a quiet friend never sticks).
4. **Admin rule for large public groups:** recommended trust only chats you *created* plus channels you admin, not supergroups where you are a non-creator admin. Alternative: the user's literal wording (any admin), which trusts strangers' media in big groups you moderate.
5. **Trusted sender inside an untrusted group (rule 8):** recommended on. Alternative: chat-level only, simpler mental model.
6. **Android: own activity table now, or accept the cleared-database gap?** Recommended: accept for v1, add the table if the user ever clears the database.
7. **Desktop: allow the lazy server seed (up to 50 history requests a day)?** Recommended: yes. Alternative: log only, so active contacts become trusted only after N new days of messages after install.
8. **Android cached-media autoplay (8 edits in the churniest file):** recommended: skip in v1.
9. **Desktop: honour the stock "Always"/"Never" exception lists as trust marks?** Recommended: yes.
10. **Static stickers / custom emoji in untrusted chats:** recommended: stickers in v2 (cheap, both platforms), custom emoji not planned.
11. **Telegram service account (777000) trusted by default?** Recommended: yes (login codes and security notices come from it; its media is Telegram's own).
