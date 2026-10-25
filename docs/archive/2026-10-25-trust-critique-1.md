# Trust model critique, round 1 (2026-10-25)

Target: `docs/trust.md` as of 2026-10-25, against plan.md batch 2 step 5 and CLAUDE.md. Sources checked: DrKLO/Telegram at `9552e554` (the doc's pin, 12.10.3) and `0aae9598` (13.0.3, the new pin), tdesktop `v7.2.5`. Paths below are relative to `TMessagesProj/src/main/java/org/telegram/` (Android) and `Telegram/SourceFiles/` (desktop); `A:` means the old Android pin, `B:` the new one. Every line reference here was read in the source, not copied from the doc.

## objections

### 1. The literal requirement "nothing loads on its own (only the blurred thumbnail)" is not met on Android for videos, GIFs and replies, and the doc does not know it

Claim: in an untrusted chat the Android cell still downloads and decodes the document's real thumbnail (the 320 px "m" JPEG) for every video and GIF, and the replied-to message's photo thumbnail for every reply, with no gate.

Why it matters: the user's stated reason for the gate is the image decoder, not bandwidth (plan.md, last paragraph). A network JPEG decoded on every untrusted video message is exactly the surface the design claims to close. The doc's section 2.4 says the download gate leaves only "the thumbnail embedded in the message"; that is true for photos with a stripped thumb and false for documents.

Evidence: `ui/Cells/ChatMessageCell.java` A:8707 (video branch, no autoplay) calls `photoImage.setImage(ImageLocation.getForObject(currentPhotoObject, ...), currentPhotoFilter, ImageLocation.getForObject(currentPhotoObjectThumb, ...), ...)` where `currentPhotoObject` is the document thumb picked at A:8287 by `getClosestPhotoSizeWithSize(photo.sizes, AndroidUtilities.getPhotoSize(), true)`, a network size. GIF/round branch A:8731 (no autodownload) loads `ImageLocation.getForDocument(currentPhotoObject, documentAttach)`, same thing. Reply thumbnails A:19310 and A:19327 load `ImageLocation.getForObject(photoSize, photoObject)` at "50_50" with no `canDownloadMedia` anywhere in that block. The desktop half of the doc (3.3) does see the equivalent (`loadThumbnail` at 3 sites) but files it as "~3 lines", not as a requirement gap.

Fix: either state in section 1 that "thumbnail" means the server-generated small size (so the decoder still runs on a Telegram-produced JPEG, which is a real but smaller risk), or gate the thumb loads too: in the three Android branches pass `null` for the network thumb and keep `currentPhotoObjectThumbStripped` when untrusted (3 edits), and gate `replyImageReceiver.setImage` on the replied message's trust (1 edit). Pick one and write it down; right now the spec and the implementation disagree.

### 2. The doc's explanation of why only the stripped thumb shows is wrong

Claim: "`getClosestPhotoSizeWithSize(sizes, 40)` picks the largest size ≤ 40 px, and the stripped one is the only one that small" is false; the stripped size is never selected by the size test.

Why it matters: the link-preview and photo fallback paths rely on this reasoning; when it is wrong by luck of list order it will break silently on a photo whose sizes arrive in a different order or that has no stripped size.

Evidence: `tgnet/TLRPC.java` A:43469 sets `w = h = 50` for `TL_photoStrippedSize`, so `currentSide <= side` with side 40 fails (`messenger/FileLoader.java` A:1457-1487, the `else` branch). It is chosen only via `closestObject == null` (first entry) or never. Separately, `ChatMessageCell` A:8239-8242 uses `currentPhotoObjectThumb` only when `strippedThumb == null`, which is the real reason photos usually show the stripped one.

Fix: replace the paragraph with the actual mechanism (stripped shows because `strippedThumb != null`; when it is null the first listed size is fetched), and gate the `currentPhotoObjectThumb` fallback for untrusted messages explicitly rather than relying on list order.

### 3. Stickers and custom emoji autoplay unconditionally in untrusted chats, and v1 ships that as default

Claim: the "untrusted means nothing autoplays" clause is violated by default: video stickers (webm, ffmpeg/libvpx) and animated stickers (TGS, rlottie) play on arrival in any chat; the doc makes the fix optional and default off.

Why it matters: a stranger in a public group can send a webm sticker; that is one of the few remaining paths where attacker-influenced bytes reach a native decoder with zero taps. Telegram's server validates sticker uploads, so the risk is lower than for arbitrary documents, but "nothing autoplays" was the user's words, and the toggle table (section 1) lists "static stickers/custom emoji: off" as if it were a preference rather than a hole. Plan step 6 does carve stickers out as a separate hardening item, so the user half-expects this; the trust doc should say so in its own "what untrusted means" paragraph instead of quietly scoping it out.

Evidence: `ChatMessageCell.java` A:9760-9770 loads `ImageLocation.getForDocument(messageObject.getDocument())` with `AUTOPLAY_FILTER` for video stickers and the full document for the rest, no `canDownloadMedia`. Desktop `history/view/media/history_view_sticker.cpp:103` loads the thumbnail unconditionally and `data/data_auto_download.cpp` returns `true` for any `document->sticker()` before consulting peer overrides (lines 356, 371, 398, 430 as the doc says, confirmed).

Fix: move "static stickers in untrusted chats" into v1 for both platforms (the doc's own estimate is 15 lines Android, 20-30 desktop) and keep custom emoji as the documented residual. At minimum, the section 1 paragraph "What untrusted means" must end with "except stickers and custom emoji, which still play (see 2.9/3.8)".

### 4. An IP leak the design misses while gating the one it knows about: direct URL fetches for `webDocumentNoProxy`

Claim: both clients fetch `TL_webDocumentNoProxy` URLs straight from the user's IP (no Telegram proxy), triggered by inline bot results' thumbnails and some bot media, with no trust gate anywhere.

Why it matters: the relay-only call rule exists because "a direct call shows the other side your IP". Answering an inline query (`@somebot text`) with a result whose thumb is a noProxy URL to a server the bot controls does the same thing for one keystroke of effort, and the client fetches it on display. The design gates P2P in 4-6 lines and leaves this open, so the "P2P only with trusted people" clause gives false comfort.

Evidence: Android `messenger/WebFile.java` A:61-70 builds the noproxy WebFile; `messenger/ImageLocation.java` A:84-96 turns it into `imageLocation.path = webFile.url`; `messenger/ImageLoader.java` A:504, A:520 (`HttpImageTask`) performs the plain HTTP download; `ui/Cells/ContextLinkCell.java` A:293, A:371, A:395 load it when inline results render, and `messenger/RichMessageLayout.java` A:7308 does the same for rich messages. Desktop `ui/image/image_location_factory.cpp:320` maps `MTPDwebDocumentNoProxy` to a `PlainUrlLocation`, downloaded by `storage/file_download_web.cpp:68-160` (`WebLoadManager`, `QNetworkAccessManager`); `inline_bots/inline_bot_result.cpp:42-43`, `:454-456` carry the URL through.

Fix: one gate per platform: refuse noproxy loads unless the bot is trusted (Android: return `null` from `ImageLocation.getForWebFile` when `webFile.noproxy` and the owning bot is untrusted, or simpler, drop the noproxy branch entirely so those thumbs show blank, ~3 lines; desktop: in `image_location_factory.cpp:320` return an empty location unless trusted, ~3 lines). Add "direct URL web documents" to the section 1 list of what untrusted blocks.

### 5. Rule 8 contradicts the user's own wording and should default off

Claim: "In an untrusted chat nothing loads on its own" is the user's sentence; rule 8 loads a trusted contact's media inside an untrusted group by default.

Why it matters: it is a reasonable widening (stock already classes contact media in groups as contact media, `messenger/DownloadController.java` A:711-727, confirmed), but it is the one rule that makes "this chat is untrusted" not mean what it says. A user who sees a photo load in a hostile group will assume the gate failed. The forwarded-content argument also bites harder here: the contact's message can be a forward from anywhere.

Evidence: section 1 rule 8 and setting "Trusted sender widens a group message: on". Plan.md step 5 has no per-sender clause.

Fix: keep the rule, default it off, and let open question 5 be a real question to the user instead of a recommendation already baked into defaults.

### 6. Count arrivals, not retained rows: the Android SQL approach breaks on auto-delete and gives two different models across platforms

Claim: counting active days from `messages_v2` counts what is still stored, so any contact with an auto-delete timer (1 day, 1 week) or a cleared history has zero active days forever; and it makes Android (query a DB) and desktop (own log fed by a hook) two different mechanisms to maintain.

Why it matters: auto-delete timers are common precisely among the people the user trusts most, which turns the rule's intended output upside down for them. The cost of the alternative is already in the doc (the `tc_activity` table, "~25 lines") and the desktop design is already that model (option A). One model, one hook per platform, one test.

Evidence: `messenger/MessagesStorage.java` A:551-553 index confirmed; `putMessagesInternal` A:11862 (B:11863) confirmed as the single materialisation point. TTL deletion and "clear history" remove rows from `messages_v2`, so a per-row count depends on retention. The doc's own "a few hundred ms for a few hundred candidates" is unmeasured and the candidate set (phonebook-synced contacts) can be thousands.

Fix: make the own table the v1 design on Android (fed at the top of `putMessagesInternal` for `!out` private-chat messages, keyed `(uid, day)`), drop the per-candidate SQL and the `EXPLAIN QUERY PLAN` test, and describe both platforms as the same thing: an activity log written at message materialisation. Note the one remaining asymmetry honestly: Android's log can be backfilled from `messages_v2` once at first run (one query), desktop's cannot.

### 7. Drop the desktop server seeding (option C) entirely

Claim: 50 `messages.getHistory` requests a day, a per-peer "seeded" flag, a 2 s queue and a day counter buy a shortcut for the first weeks after install, at the price of new network behaviour and the most complex part of `custom_trust.cpp`.

Why it matters: CLAUDE.md promises "no new network endpoints"; `patch-lint.sh` would not flag this (same endpoint), but the README spirit is "our patches add no traffic the stock client would not send", and this adds traffic in the background on a schedule. It is also wrong as written: `limit=100` on a chatty contact covers one afternoon, not 90 days, so the seed under-counts exactly the people who should pass; fixing that means paging by `offset_date`, more requests, more code. The gap it closes closes itself whenever the user opens a chat (history pages feed the log, section 3.2 says so).

Evidence: section 3.2 recommendation and the 260-line estimate for `custom_trust.cpp`; `history/history.cpp:576-596` confirmed as the hook where history pages also pass through `createItem`, so opening a chat does backfill the log.

Fix: option A alone. Say "on desktop a contact becomes trusted once their private chat has been opened or they have messaged you on N days since install". One sentence of honest UX beats 80 lines of seeding logic.

### 8. The design is twice as large as the protection needs; cut the settings screens and the five "untrusted means" toggles

Claim: ~900 lines across both platforms, of which ~360 are settings UI (`TrustSettingsActivity` 205, desktop box 160), to expose knobs the user will set once.

Why it matters: every line in a settings screen is a line to re-port on each upstream release with CI as the only compiler (a failed Android port costs a 30-minute CI loop per attempt). The user asked that "every number and rule is a setting", not that every setting has a slider on day one.

Evidence: section 2.7 and 3.7 tables. Patch 0004 (Ghost mode) already has a settings row pattern on Android and a `custom.json` on desktop.

Fix for v1: one "Media trust" row with the master switch and the N/D numbers (two number rows), the admin and contacts toggles; the manual lists are managed from the chat menu only (no list screen, no "dormant" list: the chat menu label shows the state); the five "Untrusted: block X" toggles collapse to one ("untrusted chats: tap to load") plus the P2P one, since nobody will want link-preview images blocked but GIF autoplay allowed. Desktop: `custom.json` keys plus the same two toggles in the advanced section, no `GenericBox`. That is roughly 90 lines of UI instead of 360 and keeps every number adjustable.

### 9. Eight gate sites on Android where two would do

Claim: the doc gates `canDownloadMedia(MessageObject)`, two `canDownloadMediaType` overloads, two `canDownloadMedia(TLRPC.Message, ...)` overloads and wraps three peerless callers; the two private `canDownloadMediaInternal` overloads plus the two `TLRPC.Message` entry points are the funnel, and the peerless `canDownloadMedia(int,long)` wraps can be avoided by changing those callers to the peer-aware overload.

Why it matters: fewer hunks in upstream files is the whole game under per-release re-porting. `DownloadController.java` did not change at all between the two pins in the gated region (identical line numbers 609/627/652/670/688/861/942 in A and B; the only diff is in the downloads-list code around 1489-1660), so it is the right file to concentrate in.

Evidence: `canDownloadMedia(MessageObject)` A:609 and both `canDownloadMediaType` overloads A:652, A:670 end in `canDownloadMediaInternal(...)`; the story and sponsored early returns at A:610-620 sit above that funnel, which is why the doc gates each public method. `canDownloadMedia(TLRPC.Message)` A:861 and `(Message, MessageMedia)` A:942 are separate funnels.

Fix: put the trust check at the top of the two `canDownloadMediaInternal` overloads (covers the three `MessageObject` entry points) plus the tops of the two `TLRPC.Message` methods, and move the story early-return under the trust check by one extra line in `canDownloadMedia(MessageObject)` only if forwarded public stories matter. Four hunks in one stable file. For the peerless callers (`DialogCell` A:5749, `RichMessageLayout` A:7209, A:8139), verify first whether they already have a `MessageObject` in scope; if so, swap the call rather than wrap it.

### 10. Hooks in `ChatActivity` and `ProfileActivity` are the real churn, not the gates

Claim: the chat menu and profile menu insertions (35 lines) sit in two files of 47k and 13k lines whose menu blocks move every release; the 12.10.3 to 13.0.3 bump alone moved the anchor lines by 16 and 46 (`add_shortcut` A:1640 to B:1656; `lazilyAddSubItem(open_direct` A:4399 to B:4445).

Why it matters: `android/customize.sh:18` applies patches with plain `git apply` (no `--3way`), which is correct for safety but means every context drift is a hard CI failure to fix blind.

Evidence: line drift measured on the two pins (above); `ChatActivity.java` grew 238 lines in one release; `ChatMessageCell.java` moved the autoplay sites by 10 lines (A:8691/8707 to B:8701/8721).

Fix: v1 adds the trust item to the chat ⋮ menu only (one hunk, widest possible context: anchor on the `add_shortcut` block, which has been stable); skip the profile menu; skip every `ChatMessageCell` edit in v1 (doc already recommends that for autoplay; apply the same verdict to stickers only if objection 3 is overruled). Also re-pin the doc to `0aae9598` now: all the hooks checked exist there with small offsets (DownloadController unchanged; `preloadStory` B:576 with `canPreloadStories` B:580; VoIP B:1111, B:1880, B:3423, B:4360; `MessageObject.isPhoto` B:10644; `messages_v2` index B:553).

### 11. The CI guard is described but not designed; make it a script with a frozen caller table

Claim: "re-run the caller greps after every upstream bump and diff against this doc" is a human step that will be skipped on the first auto-upstream bump (plan step 1 fast-forwards `main` when the build is green).

Why it matters: section 5 says it itself: the real risk is a new caller, which compiles fine. The auto-upstream workflow will publish a Release with the leak.

Evidence: `.github/workflows/upstream.yml` exists; `patch-lint.sh` checks only the patches, not the upstream tree. Desktop today has 9 files calling `AutoDownload::Should`/`ShouldAutoPlay` outside `data_auto_download.cpp` (`data_document_media.cpp` 2, `data_media_preload.cpp` 1, `data_photo_media.cpp` 2, `history_admin_log_inner.cpp` 1, `history_inner_widget.cpp` 1, `history_view_context_menu.cpp` 1, `history_view_gif.cpp` 1, `history_view_photo.cpp` 1, `iv_markdown_history_view_media.cpp` 1); Android has 1 caller of `canPreloadStories()` outside `DownloadController` (`StoriesController.java:585`).

Fix: `.github/media-callers.txt` with `file: count` per platform for `canDownloadMedia(`, `canPreloadStories(`, `AutoDownload::Should`, `ShouldAutoPlay(`, `startPreloading(`, `getForWebFile(`, `PlainUrlLocation`; a 20-line script in the build job fails when the table differs, and the upstream workflow's red path (an issue naming the failed step) then names the new caller. Update the table in the same commit as each port.

### 12. Trust is per device and the doc never says so

Claim: manual marks and the activity log live on each device; the phone and the laptop will disagree for weeks (desktop starts empty, Android has history), and a chat trusted on the phone is untrusted on the laptop until marked again.

Why it matters: the user runs both. The first time a photo loads on the phone and not on the laptop, the gate looks broken. Syncing through Telegram cloud storage (saved messages, `account.saveSecureValue`, bot storage) would be new traffic, so the right answer is to not sync and to say it.

Evidence: sections 2.5 and 3.5 store locally; no sync anywhere; no sentence about multiple devices.

Fix: one paragraph in section 1 "Scope": per device, no sync, by design; expect to mark a chat twice.

### 13. UX: the user will not know why a photo stayed blurred, and the fix is one toast, not a shield

Claim: v1 shows trust state only as a menu label two taps away; a blurred photo in an untrusted chat is indistinguishable from stock "auto-download off".

Why it matters: the user asked for the model; they will still forget which chats are untrusted. The doc's alternative (a shield in the header) is rightly rejected as layout churn, but it leaves nothing.

Evidence: section 2.6 "Visible state" and 3.6.

Fix: the first time a message in a chat is blocked by trust during a session, show a one-line `Bulletin` (Android) or `Ui::Toast` (desktop): "Media here waits for a tap. Trust this chat" with the action; about 15 lines each, hooked where the gate returns false with a message in hand (the `canDownloadMediaInternal` funnel can post it through `NotificationCenter` to the open `ChatActivity`). Also change the menu labels to state first, action second ("Untrusted · Trust this chat", "Trusted (admin) · Untrust") so the reason is visible.

### 14. Smaller errors and unverified claims in the doc

Claim: a list of things that are wrong or not shown.

Why it matters: a doc marked ✓ is trusted by the next porter.

Evidence and fixes, one per line: (a) Section 5 lists "a contact who calls but never texts" as false untrust, but incoming calls store an incoming `messageActionPhoneCall` row in `messages_v2` with `out = 0`, so they count under the SQL design; under the table design decide explicitly whether service messages count (recommend no: match on `message.action == null` at the hook). (b) Section 2.4 says a webpage photo "counts as a photo" via `MessageObject.isPhoto` A:10601-10602, confirmed, but the Android webpage branch falls into the generic photo `else` at A:8731 where `hasGamePreview || ... || isSponsored()` short-circuits, so game previews from bots load regardless; add games to the leak list or gate them. (c) `isTrusted` on the bind path reads `ContactsController.contactsDict` (a `ConcurrentHashMap`, A:238, fine) and `MessagesController.getChat` (a `ConcurrentHashMap`, A:145, fine); state that the manual sets must also be concurrent or copied, since `refresh()` writes them off-thread. (d) Section 3.3 story preload: `startPreloading` begins with `Expects(!_preloaded.contains(...))` (`data/data_stories.cpp:2612`); calling `preloadFinished(id, false)` from inside it is safe (it erases the id from both queues, `:2624-2637`), but put the check before `make_unique<StoryPreload>` or the loader starts anyway. (e) Section 2.4 claims the 8 gated sites "cover every caller found"; the `getForWebFile` path (objection 4) and the reply thumbnails (objection 1) are callers of the image loader that never ask `DownloadController`, so the sentence should be "every caller of `canDownloadMedia`", which is a weaker claim. (f) The desktop `Photo::draw` re-evaluation argument (`history_view_photo.cpp:340-348`, confirmed) is used to justify seeding; without seeding it still matters: a trust change must trigger a repaint, so `setManual` on desktop needs `session().data().requestItemRepaint` or similar for the open history, otherwise the chat stays blurred until scrolled. (g) "Group calls go through Telegram's servers anyway (~)" is fine but note the opposite direction too: the server-side P2P privacy rule is what protects you when the other side initiates; the client flag only governs your own advertising and engine, so keep the stock setting at "My contacts" or "Nobody" as the floor and say so in the test plan.

## verdict

Ship-blocking (the design does not do what the spec sentence says, or leaves a hole of the same class it claims to close): objections 1 (Android document and reply thumbnails load ungated; say so or gate them), 3 (stickers autoplay by default; include in v1 or write the exception into the spec), 4 (direct URL fetch for noProxy web documents leaks the IP with no gate), 5 (rule 8 default contradicts the user's sentence; default off, ask), 6 (per-row SQL count breaks on auto-delete; use the own table on Android, one model across platforms), 12 (per-device trust unstated).

Strongly recommended cuts before building (they shrink the port surface by about half and remove new network behaviour): 7 (no server seeding), 8 (one settings row, two toggles, no list screens), 9 (four hunks in `DownloadController`, not eight), 10 (chat menu only, no profile menu, no `ChatMessageCell` edits in v1; re-pin to `0aae9598`).

Nice to have: 11 (caller table in CI, do it in the same PR as the gates), 13 (one toast with a trust action), 14 (doc fixes).

What survives intact: the rule table and the "dormant mark" semantics match the user's words; `DownloadController` as the Android funnel and `data_auto_download.cpp` as the desktop funnel are the right choice and are stable across the 12.10.3 to 13.0.3 bump; the stories and P2P hooks are correct and cheap; reusing desktop's stock Always/Never lists as marks is sound.
