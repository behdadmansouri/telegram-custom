# Review: desktop patch 0009 (trust model), origin/feat/trust-desktop

Patch lines = line numbers in `desktop/patches/0009-Trust-model-media-from-untrusted-chats-waits-for-a-tap.patch`. Upstream lines = tdesktop 7.2.5 with 0001-0009 applied.

## High

1. **Any user whose id is divisible by 1000 counts as "the service account" and is fully trusted, P2P calls included.** Patch 407 (`Compute`: `user->isServiceUser() ? Kind::Service`). Upstream `data/data_peer.h:298`: `isServiceUser()` is `isUser() && !(id.value % 1000)`. That is a heuristic, not a check for 777000. So 1 in 1000 ordinary accounts (bots too: it is tested before `isBot()`) gets `Why::Own`: all media auto-loads and `CallP2PAllowed` lets calls go peer-to-peer (IP exposed). Someone who wants in only has to register accounts until one lands on a round id. Fix: `user->id == PeerId(kServiceNotificationsId)` (777000), or `isNotificationsUser()` if 333000 should count too. Add a test row: Person with id 123456000 is Untrusted.

2. **Video cover photos and video thumbnails load in untrusted chats, and the gated autoplay is what triggers the second one.** Upstream `history/view/media/history_view_gif.cpp`:
   - `:2044-2047` `dataMediaCreated()` calls `_videoCoverMedia->wanted(PhotoSize::Large, ...)` unconditionally whenever the video has a cover (the sender picks the cover image, so it is attacker-controlled). That is a full-size photo.
   - `:256-260` and `:1213-1214` call `_videoCover->load(Small)` with no check.
   - `:264-265` and `:2051-2052`: `if (!autoplayEnabled()) loadVideoThumbnail / videoThumbnailWanted`. Patch 1153 makes `autoplayEnabled()` false in untrusted chats, so any video or GIF that has a `video_thumbs` entry now fetches that MP4 preview and decodes it with FFmpeg. `DocumentData::loadVideoThumbnail` (`data/data_document.cpp:927`) has no hook; the loadThumbnail hook (patch 1007-1017) covers only `loadThumbnail`.

   Fix: in Gif, wrap the cover `wanted`/`load` calls and the `videoThumbnailWanted`/`loadVideoThumbnail` calls in `Custom::Allows(_realParent)`. Alternatively, put the same FullMsgId-origin gate as `loadThumbnail` into `DocumentData::loadVideoThumbnail`, and gate the cover inside `Gif::dataMediaCreated`. The CI guard cannot see this: the pattern `thumbnailWanted(` is case-sensitive and does not match `videoThumbnailWanted(`; `loadThumbnail(` does not match `loadVideoThumbnail(`. Add both patterns, plus `VideoPreload`.

## Medium

3. **D6 does not catch direct-URL documents: they bypass `FromWebDocument`.** Upstream `data/data_session.cpp:4171-4189`: `documentFromWeb(const MTPDwebDocumentNoProxy&)` does `setContentUrl(url)`, and `DocumentData::save` (`data/data_document.cpp:1309-1312`) downloads it with `webFileLoader` from your own IP. Caller: inline bot results (`inline_bots/inline_bot_result.cpp:123`). In the results panel, GIF items go through `VideoPreviewState::automaticLoad` → `automaticLoad(origin, nullptr)`, then the peerless `Should(data, document)`, which has no gate. Scenario: type `@somebot q`, the bot returns noproxy GIF or video content, and the client fetches each URL directly, so the bot operator gets your IP. The spec says these never load while the model is on. Fix: in `documentFromWeb(NoProxy)`, `if (Custom::TrustOn()) skip setContentUrl` (or return nullptr; the caller at :123 already handles a null document). Add `setContentUrl(`/`webFileLoader` to the guard patterns: `PlainUrlLocation` does not match this path.

4. **Rule 8 overrides a "never trust" mark.** Patch 566-579: `Allows` falls through to rule 8 whenever the chat verdict is not trusted, including `Why::Never`. The spec says first match wins and rule 1 beats rule 8. Scenario: rule 8 on, the user marks a group "Never", and a trusted contact's photos in that group still auto-load. Fix: `const auto why = Verdict(peer); if (IsTrusted(why)) return true; if (why != Why::Never && sender && ...)`.

5. **Rich-message slideshow preloads its neighbours with no gate.** Upstream `iv/markdown/iv_markdown_history_view_media.cpp:1481-1530`: for the next/previous slide, a photo falls back to `wanted(PhotoSize::Small)`, and a video starts a `Data::VideoPreload` (real video bytes) whenever `VideoPreload::Can()` is true; neither call checks anything. `updatePreloads` (`:1583-1611`) runs on every `downloaderTaskFinished` (`:973-976`) once the active slide is ready. Scenario: in an untrusted group, the user taps slide 1 of a rich-message slideshow; slides 2 and N then preload video data automatically. This is the desktop counterpart of the Android `RichMessageLayout` leak the spec called out. Fix: `if (!Custom::Allows(_host->item())) { entry.ready = true; return; }` at the top of `startPreload`. The file is already in `media-callers.txt`, which shows the guard counted it but nobody classified it.

6. **A chat wallpaper set by the peer downloads with no gate** (outside the spec's surface list, and not listed under "not covered" either). Upstream `window/window_session_controller.cpp:3725` `use.loadDocument()` → `WallPaper::loadDocument` → `document->save(...)`. Scenario: a stranger with Premium sets a wallpaper "for both" in your private chat, and the image downloads and decodes when you open the chat. Fix: gate on `AllowsPeer(peer)` where the chat theme is resolved, or list it as an accepted exception in trust.md.

## Low

7. **Own messages win over "never trust".** Patch 562-563 checks `out()` before the verdict; spec rule 1 sits above rule 2. Only your own media is affected, so it is harmless, but it is a precedence mismatch. Fix: check `Why::Never` first, or document it.

8. **A chat you marked Never still gets the toast.** Patch 580 calls `MaybeToast(peer)` for every refusal, including `Why::Never`. In a chat you explicitly distrusted, a once-per-session toast offers "Trust this chat", and a stray click flips it to Trusted (patch 530). Fix: skip the toast when the verdict is `Never`.

9. **Dice and big animated emoji go blank in untrusted chats.** Patch 1173-1175 treats every `HistoryView::Sticker` alike. `Dice` (`history_view_dice.cpp:28`, Telegram's official dice packs) shows its result only on the animation's last frame, and TGS emoji have no raster thumbnail, so the dice/slot result is unreadable. Fix: exempt official dice/emoji packs (e.g. skip the gate when `_diceIndex >= 0` or `_parent->media()` is a `Dice`/emoji-only message).

10. **The premium sticker effect still downloads.** Upstream `history_view_sticker.cpp:104-107` and `:585-587` call `loadVideoThumbnail` for premium stickers in any chat. It never plays (the player is gated), but the file is fetched. Fold this into the fix for finding 2.

11. **A gated reply-preview document thumbnail never retries after you trust the chat.** Upstream `data/data_reply_preview.cpp:76-79` calls `thumbnailWanted` only when `_documentMedia` is first created; a blocked load leaves `_good` false and `_documentMedia` alive, so the call never repeats. After trusting, replies quoting a file or video stay blurred until restart. Fix: reset `_documentMedia` (or the ReplyPreview) in `Refresh()`, or call `thumbnailWanted` again when `!_good`.

12. **The `loadThumbnail` gate also blocks thumbnails you opened yourself.** Patch 1007-1017 gates on the origin alone, so in the media viewer (`media_view_overlay_widget.cpp`), the shared-media grid (`overview_layout.cpp`) and the downloads list, an untrusted chat's video/file shows no thumbnail. The `media && media->loaded()` escape fails when there is no active media view. The spec says viewers load. Fix: only gate when called from a history view (move the check to the four view call sites), or accept and document it.

13. **A corrupt `trust_<id>.json` silently erases every mark.** Patch 287-347: if the parse fails, `LoadAccount` gets `{}`, and the next `SaveAccount` (any new activity day, after 10 s) overwrites the file. Fails closed, but the user's marks are gone with no undo. Fix: on a parse error with a non-empty file, rename it to `.corrupt-<time>` before the first save.

14. **Caches keyed by raw `PeerData*` outlive the session.** Patch 204 (`verdicts`) and 212 (`toasted`) survive logout, because `Account` is keyed by user id. If the same account logs back in during that process run, a reused address can return a stale verdict for up to 60 s (fail-open in theory). Patch 517-531: the toast's filter captures the raw `peer` and calls `SetMark(peer)` on click, which is a use-after-free if the account logs out while the toast is up. Fix: clear the account's caches on session destruction (`session->lifetime()`), and capture `base::make_weak(peer->session())` or a PeerId in the toast.

15. **Saving the settings box refreshes only one account.** Patch 740-742: the settings are global, but only `session->data()` gets `photo/documentLoadSettingsChanged()`, and nothing repaints. Other accounts' open chats keep their old gate state until something repaints. Fix: loop over `Core::App().domain().accounts()`.

## Checked, no defect found
- `Decide()` against §1: rules 0-7 and 9, decay/dormant, grace boundary, bots only by hand, non-contacts only by hand, rule 4 scope (`amCreator() || isBroadcast() && hasAdminRights()`, megagroup creator only), rule 8 default off. All match, apart from findings 4 and 7.
- Missing or corrupt `custom.json` → defaults, model on (fails closed). The read-modify-write in both `custom_settings::Save` and `SaveSettings` keeps the other module's keys; everything runs synchronously on the main thread, so there is no in-process race.
- Account file name `trust_<uniqueId>` = user id, plus a test-mode bit: stable across restarts and distinct per account. Missing file → empty.
- Story gate: `preloadFinished(id, false)` removes the id and does not loop. The P2P gate covers all three `f_udp_p2p` sites plus `enableP2P` (apart from finding 1).
- Settings box ownership: children are parented to the box and the wrap; button lambdas capture box-owned raw pointers. Safe.
- `.github/media-callers.sh`: it does fail on a new caller file and on a vanished one; errors in `git grep` fail closed (empty current list → every row reported as gone). Its weakness is the pattern list (findings 2, 3, 5), not the script logic.
