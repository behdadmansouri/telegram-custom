# Trust model critique, round 2 (2026-10-25)

Target: `docs/trust.md` revised after round 1 (pinned to DrKLO `0aae9598` = 13.0.3 and tdesktop `v7.2.5`). Sources re-cloned at those pins; every anchor in section 0 and every line this file cites was read in the tree, not copied. Paths relative to `TMessagesProj/src/main/java/org/telegram/` and `Telegram/SourceFiles/`. "R1-n" refers to a round 1 objection.

## the two claims the coordinator asked about first

**Gate G at `ImageReceiver.setImage` (A6).** Confirmed as a funnel: the 11-argument `setImage` at `messenger/ImageReceiver.java:572` is the body, and all nine other `setImage` overloads (`:400`, `:404`, `:408`, `:412`, `:416`, `:564`, `:568`) delegate to it. `setForceLoading(true)` appears in exactly four places in the whole tree, all inside `ChatMessageCell.didPressButton` (`ui/Cells/ChatMessageCell.java:17896`, `:17909`, `:17926`, `:17938`), so a tap is the only thing that sets it; the reset points are `:7207` (rebind) and `:17951` (cancel). The flagged branch near `:17935` is the wallpaper document case (`DOCUMENT_ATTACH_TYPE_WALLPAPER`, `setImage` with no `forceLoading`), harmless. The all-null early branch at `:600-640` calls `setStaticDrawable(thumb)`, so dropping every location while keeping the `thumb` drawable does show the stripped image as the doc says. The real problem with G is not the branch at `:17935`, it is objection 1 below.

**`tc_activity` fed at two points (A2).** `putMessagesInternal` (`messenger/MessagesStorage.java:11863`) and `putMessages(TLRPC.messages_Messages, ...)` (`:16079`, posts itself to `storageQueue` at `:16080`, inserts at `:16244`) are both real and are the two that carry message traffic. There are five `REPLACE INTO messages_v2` sites in total: `:4783` (`emptyMessagesMedia`, rewrites existing rows, irrelevant), `:12174` (`putMessagesInternal`), `:15887` (`replaceMessageIfExists`, edits, irrelevant), `:16244` (history pages), `:17346` (`putDialogsInternal`, the top message of every dialog when the chat list loads). The fifth matters only on a fresh login, when the dialog tops are the only messages known; one message per dialog, so a few active days are under-counted for a while. Not worth a third hook; worth one sentence in 2.2.

## objections

### 1. Tap-to-load is broken for GIFs, videos and round videos under G: the download happens, the playback never does

Claim: G unlocks a message only when `isForceLoding()` is true at `setImage` time. The tap paths for GIF, video, round video (secret) and files do not call `setImage`; they call `FileLoader.loadFile` directly, and the cell later re-enters `setImage` from `onSuccessDownload` with the document location, the message as `parentObject` and `forceLoading` false. G drops the location again and the user sees the blurred thumb after a completed download, with no further tap doing anything different.

Why it matters: "A tap always loads that one item" is the one promise that makes the gate tolerable day to day. As designed, GIFs in untrusted groups cannot be played at all on Android, and a tapped video downloads then shows nothing until the user opens it a second way. The user will read this as a broken build, not a feature.

Evidence: `ui/Cells/ChatMessageCell.java:17899` (`TYPE_GIF`: `FileLoader.loadFile(documentAttach, currentMessageObject, ...)`, no `setForceLoading`), `:17915` (`TYPE_FILE`), `:17920` (`DOCUMENT_ATTACH_TYPE_VIDEO`), `:17933` (`DOCUMENT_ATTACH_TYPE_DOCUMENT`). `onSuccessDownload` then calls `photoImage.setImage(ImageLocation.getForDocument(documentAttach), ImageLoader.AUTOPLAY_FILTER, ..., currentMessageObject, 0)` for round (`:17970`), video (`:17979`) and GIF (`:17992`), with `startAnimation()` after, and nothing sets `forceLoading` on that path. For a GIF already on disk the tap path is the same `loadFile` on an existing file, so no `onSuccessDownload` and no second `setImage` happen at all.

Fix: one additive hunk at the top of `didPressButton` (`:17854`): `if (TrustController.noteTapped(currentMessageObject)) { currentMessageObject.forceUpdate = true; setMessageObject(currentMessageObject, currentMessagesGroup, pinnedBottom, pinnedTop); return; }` where `noteTapped` returns true only the first time it adds the message to the tapped set. That makes the first tap a rebind under "allowed" (autoplay and existing-file paths then run as stock) and every later tap stock. Keep the `isForceLoding()` rule in G as a belt. It is one line in the churny file, anchored on a method signature that has not moved in years; cheaper than the four alternatives (hooking `FileLoader.loadFile`, which has no notion of a tap; gating by priority, which GIF and video disagree on; adding a notification; or leaving it).

### 2. Your own outgoing messages are untrusted too, and nothing in the rule table says otherwise

Claim: the rules key on the chat, so a photo you send to a stranger (or into an untrusted group) is gated like theirs: on the phone the local upload path saves it (`mediaExists`), on the laptop the same message arrives from the server and stays blurred until tapped; a video you sent from the phone will not autoplay on the laptop.

Why it matters: this will happen the first day, in every new conversation, and it is pure friction with zero protection (you produced the bytes). It also makes the desktop test plan step 1 ambiguous.

Evidence: section 1 rule table has no `out` clause; section 2.4 G filter and 3.3 gates have none; `grep -i "out()\|outgoing"` over `trust.md` hits only the activity feed and the test list. `data/data_auto_download.cpp` has no `out()` check of its own (0 hits), so stock would download your own media under the normal peer rules and the gate removes that.

Fix: rule 2 becomes "Saved Messages, the service account, or a message you sent (`out`, not a forward of someone else's media)". One condition in `allows()` on both platforms. Say in the spec that your own forwards of untrusted media stay gated (you opened them once already, the laptop has not).

### 3. G's whitelist leaves three ungated 50 px network thumbnails in the open chat, and the spec sentence still claims none

Claim: section 1 says no network thumbnail shows for photos, replies and link previews in an untrusted chat. G only fires when `getParentView()` is a `ChatMessageCell` or `DialogCell`, so the pinned-message bar, the reply/edit bar of the composer and the shared media grid all load server thumbnails as before.

Why it matters: the pinned bar is automatic (it loads when the chat opens, and in a private chat either side can pin). The composer bars are user-initiated. The shared media grid is user-opened but downloads a full grid of thumbnails for every message in the chat at once, which is the largest single decode burst the client does, in an untrusted chat, on a tap of a tab. None of the three is in the "Not covered, said plainly" list.

Evidence: `ui/ChatActivity.java:28630` and `:29947` (`pinnedMessageImageView[..].setImage(ImageLocation.getForObject(pinnedImageLocation, ...), "50_50", ...)`, a `BackupImageView`), `:29943` (reply bar, same), `ui/Cells/SharedPhotoVideoCell2.java:79-80` (`new ImageReceiver()` with no parent view, so `getParentView()` is null). `getParentView()` is `messenger/ImageReceiver.java:3254`, set only by the constructor (`:368-369`) and `setParentView` (`:2378`).

Fix: either add the three to "Not covered" with one sentence each, or change G's test from a parent-view whitelist to a blacklist of the user-opened surfaces (the photo viewer, story viewer and instant view each own their `ImageReceiver`s; check their classes once and list them in the doc), which also covers any future cell for free. The blacklist is the better guard and the same line count; the risk is a viewer whose receivers have no parent view, which is why the doc has to list them after reading the code, not guess.

### 4. G blanks the static map of a shared location in untrusted chats, and the doc does not know

Claim: a geo or venue message loads its map tile through `ImageLocation.getForWebFile(currentWebFile)` with the message as `parentObject`; the location is neither stripped, nor a path, nor `mediaExists`, so G drops it. The map (fetched through Telegram's `upload.getWebFile`, not from your IP) goes blank, with nothing to tap.

Why it matters: a blank location bubble in an untrusted chat is a bug report waiting to happen, and the doc's "Anything else keeps a location only if it is local" rule is wider than its author knows.

Evidence: `ui/Cells/ChatMessageCell.java:9602-9603` (`photoImage.setImage(ImageLocation.getForWebFile(currentWebFile), null, lastLocation, null, locationLoadingThumb, messageObject, 0)`); `messenger/ImageLocation.java:84-96` sets `imageLocation.webFile` (proxied) for non-noproxy web files.

Fix: in G, pass through any location whose `webFile != null` and `!webFile.noproxy` (Telegram-proxied web files: maps, proxied bot thumbs), or at least maps. One condition. Add "static maps" to the test plan as "still show".

### 5. Backfill on a database that has already been trimmed is the one `tc_activity` write that can lie, and the fixed time-zone makes day boundaries drift

Claim: the one-shot backfill `INSERT ... SELECT uid, (date + ?tz)/86400 FROM messages_v2 WHERE uid > 0 AND out = 0` cannot exclude service rows (no `action` column, the doc says so) and uses one offset for a year of history, so a user who moved time zones or crossed DST gets days split at the wrong hour for the whole year, and incoming calls, "joined Telegram" and chat-photo-changed rows count as activity.

Why it matters: it is a one-time seed, so the error is bounded and fades after `D` days of live feeding; but the doc marks it as a strength ("Android simply starts better") when it is also the one path that can grant trust to a contact who only ever called you. Rule 7 is the only rule that trusts without a user action, so its inputs deserve the strict version.

Evidence: `messenger/MessagesStorage.java:551` (`messages_v2` columns: no action column, the message is in the `data` blob); the backfill SQL in 2.2.

Fix: run the backfill in Java instead of SQL: iterate `SELECT uid, date, data FROM messages_v2 WHERE uid > 0 AND out = 0 AND date >= ?`, deserialize `data` (`TLRPC.Message.TLdeserialize`, the same call `MessagesStorage` uses everywhere), skip `action != null`, compute the day with the device zone at that date. Same one full scan, a few more lines, exactly the live feed's rules. Or keep SQL and drop the "starts better" framing to "starts with an approximation".

### 6. The anchors inside already-patched files are checked against the wrong tree

Claim: A11 cites `ui/SettingsActivity.java:708` as "after Ghost mode's row 100". In the stock tree line 708 is `SettingCell.Factory.of(10, ...)` and `:845` is `case 10:`; Ghost mode's row 100 exists only after patch 0004 applies. The ✓ there is a stock line that is not the thing described.

Why it matters: the build list says "go straight down it" and the porter will search for row 100 at line 708 and find row 10. Small, but it is the kind of ✓ that spends the credibility of the others.

Evidence: `ui/SettingsActivity.java:708`, `:845` at `0aae9598`.

Fix: for every anchor in a file that an earlier patch touches (`SettingsActivity` by 0004, `data_stories.cpp` by desktop 0004), say "after 0004 applies" and cite the stock line of the nearest stock row instead.

### 7. The caller-count guard counts the upstream tree, so it will fire on every upstream bump and teach the porter to update the table blind

Claim: C1 counts patterns on the upstream tree before patches apply and fails the build on any change. Upstream touches `ChatMessageCell.java` and `ChatActivity.java` every release; a count of `canDownloadMedia(` in a 29k-line file that is "rewritten every release" (the doc's own words in round 1) will change often for reasons that are not new leaks (a refactor splitting a call, a removed branch).

Why it matters: the auto-upstream workflow fast-forwards `main` only when green, so every count wobble is a red build, an issue, and a human running `update` to make it green. After the third false alarm the table gets updated without reading the diff, and the guard is worse than none because it is trusted.

Evidence: 4.1 as written; `ChatActivity.java` grew 238 lines between the two pins, `ChatMessageCell.java` 14, and the sites moved 10 lines, so even in one minor release the file churned around the counted calls.

Fix: count per pattern per file as the doc says, but fail only when a **new file** appears for a pattern, or when a count **drops to zero** in a file that had one, or when a pattern gains callers in a file outside the gated set; a count change within an already-known file produces a warning line in the build log and the port commit message, not a failure. Add `ImageReceiver.setImage(` with the whitelist classes as a pattern too, since G is now load-bearing.

### 8. `isTrusted` recomputes rule 4 on every `setImage` and every cell bind; cache the per-dialog verdict

Claim: `allows(message)` walks the rule table each call: marks map, `getChat()` for creator/admin, `contactsDict`, active set, plus the tapped set and parent-view `instanceof` checks in G. `setImage` is called several times per cell bind and `canDownloadMedia` several times per cell; while scrolling a group that is thousands of calls a second.

Why it matters: each step is O(1), so it is not a correctness problem, but it is unnecessary work in the hottest path in the app, and rule 4 depends on `TLRPC.Chat` fields that only change with an update.

Evidence: 2.1 and 2.4 describe the per-call evaluation; `messenger/MessagesController.java:147` and `messenger/ContactsController.java:238` are the concurrent maps it reads.

Fix: a `LongSparseArray<Byte>` of dialog verdicts in `TrustController`, filled lazily, cleared on `refresh()`, on a mark change, and on `NotificationCenter.updateInterfaces` with the chat-info or contacts flags. `allows(message)` then does one array lookup plus the `out` and rule 8 checks. ~15 lines inside A1, no upstream hunks.

### 9. Smaller points

(a) D3 says to put the trust check "before `if (document->sticker()) return true;` for non-stickers and before `isGifv() → true`": one check before the sticker line covering `!document->sticker()` is enough, since everything else below it is reached only by non-stickers (`data/data_auto_download.cpp:367-380`). Say "one check at `:371`, skip stickers", so the porter does not add two. (b) D5 is sound: `checkStickerLarge()` is called only from `readyToDrawAnimationFrame` in that view (`history/view/media/history_view_sticker.cpp:190`), and `setupPlayer()` right after it (`:194`), so skipping both there blocks download and decode of the large sticker while the thumbnail from `:103` keeps drawing. (c) D4's `DocumentData::loadThumbnail(FileOrigin)` (`data/data_document.cpp:870`) is the right funnel: `DocumentMedia::thumbnailWanted` (`data/data_document_media.cpp:242-245`) and the reply preview (`data/data_reply_preview.cpp:78`) both go through it; the origin check needs `origin.data` to be a `FileOriginMessage` and the item looked up via `session().data().message(...)`, which can return null for a reply whose target is not loaded, so fail open there (stock behaviour) and say so. (d) The reply photo path on desktop is gated by `autoLoadThumbnailAllowed(context)` only when the inline thumbnail bytes are present (`data/data_reply_preview.cpp:110-114`): when `inlineThumbnailBytes.isEmpty()` it calls `wanted(Size::Small)` regardless, so a reply to an old photo with no inline thumb still fetches the small size. One more condition at `:110`, or list it. (e) 2.5 blocks noproxy web documents for trusted bots too and sends the user an empty thumbnail; fine for v1, but note that `ContextLinkCell` has the inline result's `bot_id` in reach (`inlineResult` → the query's bot), so the v2 is ~5 lines, not "20 caller files". (f) `putDialogsInternal` as a third `messages_v2` writer: one sentence in 2.2 (see the claims section above). (g) `ImageReceiver.setImage` stores its arguments and returns early when `allowLoadingOnAttachedOnly && !attachedToWindow` (`:573-588`); G at the very top runs before that and again on the replay via `setBackupImage()`, so the hunk must sit above the backup block, not after it. Say "line 573, first statement".

## verdict

Ship-blocking: objection 1 (tap-to-load does not work for GIFs, videos, round videos and cached GIFs under G; fix is one additive line at the top of `didPressButton` plus a forced rebind), objection 2 (your own sent media is gated like a stranger's; add the `out` clause to rule 2), objection 3 (the spec sentence "no network thumbnail" is still false for the pinned bar, the composer bars and the shared media grid; either list them or switch G to a viewer blacklist), objection 4 (G blanks static maps; pass proxied web files through).

Nice to have, in order of value: 7 (make the caller guard fail on new files and zero counts, warn on count changes, or it will be updated blind), 8 (cache per-dialog verdicts), 5 (do the backfill in Java with the live feed's rules), 9d (desktop reply with no inline thumb), 6 and 9a/c/g (doc accuracy for the porter), 9e/9f (notes).

Resolved from round 1 and verified here: R1-1 and R1-2 (document and reply thumbnails now go through G, which funnels every `setImage` overload; the stripped-thumb explanation is corrected), R1-3 (stickers static in v1 on both platforms, custom emoji a stated exception), R1-4 (noproxy web documents blocked; `ImageLocation.java:89` and `image_location_factory.cpp:320-331` are the right two lines), R1-5 (rule 8 default off), R1-6 (own `tc_activity` table fed at the two live sites, same arrival model as desktop), R1-7 (seeding dropped), R1-9 and R1-10 (four funnel hunks in a file that did not change across the bump; chat menu only; all section 0 Android and desktop anchors exist at the stated lines, including `DialogCell.java:5779/5801`, `RichMessageLayout.java:6687/7214/8144`, `LaunchActivity.java:8784`, `ChatActivity.java:1760/3939/12888`, `BulletinFactory.java:447`, `MessageObject.java:252/10271/10283/10308`, `ChatObject.java:2085/2123/2127`, `data_session.h:408`, `window_controller.h:84`), R1-12 (per-device scope stated), R1-14d (stories check before `make_unique`).
