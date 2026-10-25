# Caption ungroup (patch 0008), build notes 2026-10-25

Source read at the pin in `android/UPSTREAM` with 0001-0006 applied. Paths under `TMessagesProj/src/main/java/org/telegram/`.

## Where the decision sits
- Every chat send from the attach sheet lands in one place: `ui/ChatActivity.java` `ChatAttachViewDelegate.didPressedButton` (buttons 7/8/4, ~:12583), which builds `SendingMediaInfo` per `PhotoEntry` and calls `prepareSendingMedia(..., groupMedia = arg, ...)` twice (edit-resend and normal). The viewer's own send (`ChatAttachAlertPhotoLayout.sendButtonPressed`, `didPressedButton(7, true, ...)`), the sheet's send buttons (`ChatAttachAlert` `didPressedButton(7, true, ...)`) and "Send without grouping" (`arg = false`) all go through it. Other `ChatAttachViewDelegate` implementations (passport, stories, business intro, rich editor, paint) are not chat media sends.
- The patch computes `customGroupMedia = arg && (button == 4 || forceDocument || editing || !CustomSettings.shouldUngroupCaptioned(selectedPhotos.values()))` once, before the 10-per-album loop, and passes it in place of `arg`. It must run before the loop: the loop calls `photoEntry.reset()`, which clears captions.

## Rules in `shouldUngroupCaptioned`
- Ungroup only when 2+ **different** non-empty (trimmed) captions exist. Reason: "caption for all media" mode (`PhotoViewer.hasCaptionForAllMedia`, set via `setCaption` when the viewer opens with at most one caption) writes the same shown caption into every photo the user swipes past (`PhotoViewer.applyCaption`). The viewer's send nulls items 2..N in that mode, but the sheet's send button does not, so counting raw captions would ungroup a one-caption album. Identical captions keep the stock album.
- Paid media (`PhotoEntry.starsAmount > 0`) keeps the album; stock hides "Send without grouping" then too (`ChatAttachAlertPhotoLayout.onSelectedItemsCountChanged`). The paid-message fee (`payStars`) is per message either way.
- Send as file (`button == 4` / `forceDocument`) keeps the album: document albums show every caption (`MessageObject.GroupedMessages.calculate`, the `!isDocuments` branch).
- Toggle: `CustomSettings` key `autoUngroupCaptioned`, default true, getter `isAutoUngroupCaptioned()`, setter `setAutoUngroupCaptioned()`; no UI yet.

## Merge notes
- `CustomSettings` reference in ChatActivity is fully qualified, so no import hunk to collide with other patches.
- The CustomSettings hunk appends at the end of the class, like 0005 did; a parallel patch appending there too needs a trivial rebase of whichever lands second.
- Not device-tested: no local toolchain, CI compiles.
