# Desktop trust model v1: build log (patch 0009)

Implements [docs/trust.md](../trust.md) §0 desktop D1-D10 plus C1 and C2 at tdesktop v7.2.5, on top of desktop patches 0001-0008 (branch `batch-2`). One patch: `desktop/patches/0009-Trust-model-media-from-untrusted-chats-waits-for-a-tap.patch` (the spec's "0007" number was taken by the build label and 8 accounts patches). Written without a local build; CI is the compiler.

## 🧩 what each hook does

| # | File (upstream unless noted) | Hook |
|---|---|---|
| D1 | `custom/custom_trust_rules.h` (new) | the rule table as a pure `constexpr Decide()`, no Qt, so CI can test it |
| D1 | `custom/custom_trust.{h,cpp}` (new) | settings (`custom.json` key `trust`), per-account `trust_<uniqueId>.json` (marks, stock-list first-seen dates, activity days), 60 s verdict cache per peer, own-message and rule-8 clauses, toast, menu text/action, settings box |
| D1 | `CMakeLists.txt` | the three new files, beside `custom_settings` |
| D1 | `custom/custom_settings.cpp` (ours, patch 0003) | `Save()` now starts from the file so it keeps the `trust` key |
| D2 | `history/history.cpp` `History::createItem` | `NoteIncoming(result)` for every new item: incoming, regular, non-service, private chat, not self; logs the local day, keeps 365 |
| D3 | `data/data_auto_download.cpp` | `AllowsPeer(peer)` in `Should(peer, document)` (after the sticker pass, above `isGifv`), `Should(peer, photo)`, both `ShouldAutoPlay` |
| D3 | `data/data_photo_media.cpp`, `data/data_document_media.cpp`, `history/view/media/history_view_gif.cpp` | `TrustItemScope` around the item-carrying callers (see deviation 1) |
| D4 | `data/data_photo_media.cpp` `autoLoadThumbnailAllowed` | false when untrusted |
| D4 | `data/data_document.cpp` `loadThumbnail` | message origin, item found, not a sticker, not loaded or loading, not allowed: return. No item: stock |
| D4 | `history/view/media/history_view_web_page.cpp` | side thumbnail only when allowed |
| D4 | `data/data_reply_preview.cpp` | the no-inline-bytes `Small` fetch also needs `AllowsPeer` |
| D5 | `history/view/media/history_view_sticker.cpp` `readyToDrawAnimationFrame` | animated/video sticker in an untrusted chat: return before `checkStickerLarge`, the view draws its thumbnail |
| D6 | `ui/image/image_location_factory.cpp` `FromWebDocument` | `webDocumentNoProxy` → empty location while the model is on |
| D7 | `data/data_stories.cpp` `startPreloading` | untrusted peer and not in `_toPreloadViewer`: `preloadFinished(id, false)` before the loader exists |
| D8 | `calls/calls_call.cpp` | `f_udp_p2p` only when `CallP2PAllowed(_user)` (3 sites), `enableP2P` ANDed, one extra log line `telegram-custom trust allows P2P: true/false` beside the stock one |
| D9 | `window/window_peer_menu.cpp` | `Filler::addToggleTrust()` after "No forwards" in `fillHistoryActions` |
| D10 | `settings/sections/settings_advanced.cpp` | "Media trust" button (subtitle "On · 3 days in 90") at the end of the auto-download section, opens the box |
| C1 | `.github/media-callers.sh` + `.txt`, `desktop.yml` | `build.sh --tree`, then `check desktop <tree> upstream` (counts on the stock tag, so our patches never count), before Build |
| C2 | `desktop/tests/trust_rules_test.cpp`, `desktop.yml` | g++ test of `Decide()` against the patched tree's header, same step |

Defaults as §1: on, N 3, D 90, grace 90, rule 4 on, rule 7 on, rule 8 off, tap to load on, relay on.

## ↩️ deviations from the spec

1. **Own-message clause reaches the peer-only gates through a scope.** `data_auto_download.cpp` sees only the peer, so rule 2 (your own non-forwarded message loads) could not apply there. `Custom::TrustItemScope` (RAII, main thread) is set in `PhotoMedia::automaticLoad(origin, item)`, `DocumentMedia::automaticLoad(origin, item)` and `Gif::autoplayEnabled`; the gate uses that item when it belongs to the peer. Three one-line hooks the build list does not name. Not covered: `Photo::videoAutoplayEnabled` (video photos you sent need a tap to play).
2. **No tapped set on desktop.** Stock taps already do the work: a photo tap opens the viewer (loads it, then the bubble shows it), GIF/video/file taps download, after which the thumbnail gate passes (`loaded or loading`). Nothing in D1-D10 asked for one.
3. **Stock "Always" list as a mark** needs a date: the first time the verdict sees the override is stored as `stock` in the account file (grace counts from then). Our menu's Clear/Untrust writes an explicit "none" mark, which hides the stock lists for that chat, so the menu always wins.
4. **Global settings key**: `custom.json` → `"trust": {...}`; `custom_settings.cpp`'s `Save()` was rewriting the file from scratch, so it now starts from the file (our own file, 4 lines).
5. **Settings box** is a plain `GenericBox`: six checkboxes, three number fields with a label above each, Save/Cancel. Numbers are clamped to the §1 ranges on save; an empty field keeps the old value.
6. **Photo bubbles with no inline thumbnail** still fetch `Small` (`Photo` constructor and `dataMediaCreated`, `history_view_photo.cpp:165`, `:186`): not in D4, rare (photos almost always carry a stripped thumbnail). Left as stock; noted for v2.
7. **Link preview side image** is decided once, when the view's photo media is created: after trusting a chat it loads when the message view is rebuilt (scroll away and back, or reopen the chat), not instantly.
8. **C1 desktop only.** The script knows the Android patterns and paths, but the table has no Android lines and `android.yml` has no step; whoever builds the Android side runs `update android <checkout>` once and adds the step.

## 🔁 compile rounds

| Round | Run | Result |
|---|---|---|
| 1 | 40164174984 | guard + rule tests green; one compile error (`GenericBox::addRow` needs an `RpWidget`, `NumberInput` is a `QLineEdit`): wrapped each number field in a `FixedHeightWidget`, as `send_files_box.cpp` does. Every other file compiled (`-k 0`) |
