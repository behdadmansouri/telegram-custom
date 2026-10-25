# Android trust model v1: build log (patch 0010)

Implements [docs/trust.md](../trust.md) §0 Android A1-A11 plus C1 and C2 at DrKLO `0aae9598` (13.0.3), on top of Android patches 0001-0009 (branch `batch-2`). One patch: `android/patches/0010-Media-trust-media-from-untrusted-chats-waits-for-a-tap.patch`. Behavior and wording mirror the desktop patch ([trust-desktop log](2026-10-25-trust-desktop.md)) and fold in the desktop review's findings (origin/main `docs/archive/2026-10-25-trust-desktop-review.md`). Written without a local Android toolchain: every class, method and field used was read at the pin; CI is the compiler.

## 🧩 what each hook does

Lines are in the tree with 0001-0010 applied. Every hook carries a `telegram-custom: media trust` comment (24 sites).

| # | File | Hook |
|---|---|---|
| A1 | `messenger/TrustRules.java` (new) | the rule table as pure static `decide()` and `allowsMessage()`, no Android imports, so CI tests it with plain javac |
| A1 | `messenger/TrustController.java` (new) | per account (`getInstance`, the `DownloadController` pattern): settings, marks, 60 s verdict cache, own-message and rule-8 clauses, tapped set, gate G's `filter`, toast, menu text/action, activity log, backfill |
| A1 | `ui/TrustSettingsActivity.java` (new) | Settings → Media trust, a `UniversalFragment` with the nine rows; numbers through a `NumberPicker` dialog |
| A2 | `MessagesStorage.java:11864` `putMessagesInternal`, `:16082` `putMessages(messages_Messages, ...)` | `noteIncoming(messages, mode)` first thing (the second inside its storage-queue runnable) |
| A3/A4 | `DownloadController.java:610`, `:654`, `:673` (the three `MessageObject` entries), `:865`, `:947` (the two `TLRPC.Message` ones) | `allows()` first statement |
| A5 | `DialogCell.java:5801` | big chat-list thumbnail only when `allowsDialog(currentDialogId)` |
| A5 | `RichMessageLayout.java:6688`, `:7216`, `:8147` | `computeAutoDownload()` false when `!allows(root.messageObject)` (null message: allowed) |
| A6 | `ImageReceiver.java:573` | gate G, first statement of the 11-argument `setImage` |
| A6b | `ChatMessageCell.java:17855` | first statement of `didPressButton`: `noteTapped()` → `forceUpdate`, rebind with the last `setMessageObject` arguments, return |
| A7 | `ImageLocation.java:88` | `getForWebFile`: a noproxy web file returns null while the model is on |
| A8 | `StoriesController.java:580` | `preloadStory` returns for an untrusted peer |
| A9 | `VoIPService.java:1111`, `:1881`, `:3424`, `:4362` | `udp_p2p` (request, confirm, accept) and the engine's `p2p_allowed` ANDed with `callP2P(currentAccount, user)` |
| A10 | `ChatActivity.java:3939` (handler), `:4491` (item after "Set wallpaper"), `:4353` (`onShowSubMenu`) | ⋮ menu item `TrustController.MENU_ID` (9100), relabelled each time the menu opens |
| A11 | `SettingsActivity.java:710`, `:854` | row 101 "Media trust" (subtitle "On · 3 days in 90") below Ghost mode's 100, opens the screen |
| C1 | `.github/media-callers.{sh,txt}`, `android.yml` | script copied unchanged from `feat/trust-desktop`; Android lines from `update android <stock 0aae9598>` (162 pattern/file pairs); step "Media caller guard" right after the DrKLO checkout, counting on `HEAD` (stock) |
| C2 | `android/tests/TrustRulesTest.java`, `android.yml` | step "Trust rule tests" after Customize: `javac` of the patched `TrustRules.java` + the test, `java` runs it. Same cases as `desktop/tests/trust_rules_test.cpp` plus the per-message clauses |

Defaults as §1: on, N 3, D 90, grace 90, rule 4 on, rule 7 on, rule 8 off, tap to load on, relay on. Prefs keys as §2.8 (`trust_on` ... `trust_relay`) in `telegram_custom`.

## ↩️ deviations from the spec

1. **Funnel hooks at the three public `MessageObject` entries, not inside the two private `canDownloadMediaInternal`.** Those are only called from the three entries, and `canDownloadMediaType` (both overloads) has the same forwarded-story branch as `canDownloadMedia(MessageObject)` that returns before the funnel; the spec's A4 line covered only one of the three. Five hunks total, same coverage plus the two story bypasses.
2. **Marks keyed by the account's user id** (`trust_marks_<userId>`), not the account slot: a different login in the same slot must not inherit marks. The snapshot reloads when the slot's user id changes.
3. **Backfill flag is the table itself:** the one-time backfill runs when `tc_activity` does not exist yet. The account database is deleted on logout, so a new login backfills again; a prefs flag would not.
4. **Verdict cache: 60 s TTL** plus clears on mark, setting and activity changes, as desktop, instead of listening to `updateInterfaces`. A contact list or admin change shows within a minute.
5. **Activity peer** is the message's private-chat dialog (`from_id` for incoming, as `MessageObject.getDialogId`), not `peer_id.user_id`: for incoming private messages `peer_id` can be you.
6. **Active-day window** is today plus the `D - 1` days before (desktop counts the same way, ~).
7. **First tap swallow skips voice and music:** the first tap on a waiting voice note or song plays it (stock); for everything else the first tap unlocks and rebinds, as A6b says.
8. **`BackupImageView` in G only as the open chat's bars:** the whitelist also caught the shared-files tab, the downloads list and the legacy media grid (`SharedDocumentCell`, `SharedPhotoVideoCell` use `BackupImageView` with the message as parent), which are surfaces you opened. G now takes a `BackupImageView` only when a `ChatActivity` is on top and the view is not inside a list. Side effect: the music player's cover art (opened from an untrusted chat) stays blank.
9. **Cached photos only:** the "media exists" pass-through is limited to photo messages, so a cached video's cover photo does not fetch from the network.
10. **Toast text** is the Bulletin's title "Media here waits for a tap" with the button "Trust this chat" (desktop: one line with a link).
11. **Menu item** sits after "Set wallpaper" in the lazily built ⋮ menu, hidden in Saved Messages / 777000 / model off. Icon `msg_permissions`.

## 🔎 desktop review findings, Android side

| # | Finding | Android |
|---|---|---|
| 1 | heuristic service user | rule 2 uses `777000` exactly (`TrustRules.SERVICE_USER_ID`); `UserObject.isService()` is exact too (333000, 777000, 42777) but the spec says 777000 only |
| 2 | video covers, video thumbs, previews when autoplay is off | all of them are `ImageReceiver` loads with the message as parent, so G drops them (document locations always, photo locations unless a cached photo message); video preloads go through `canDownloadMediaType` = 2, gated |
| 3 | noproxy documents from inline bots | `getForWebFile` covers the image paths; inline-result files are fetched by `FileLoader.loadFile(WebFile)` through Telegram's `upload.getWebFile` (~, proxied); playing an inline audio result streams its URL after your tap (opened, not covered) |
| 4, 7 | Never beats rule 8 and the own-message clause | `TrustRules.allowsMessage` checks Never first; unit-tested |
| 5 | rich-message slideshow preloads | Android's slideshow pages are `MediaCell`s whose loads hang on `computeAutoDownload` (gated) or a tap; no separate neighbour preload found (~) |
| 6 | chat wallpaper set "for both" by the peer | not covered: the theme delegate loads it with the wallpaper, not a message, as parent |
| 8 | toast in Never chats | skipped |
| 9 | dice / animated emoji | G passes `isDice()`, `isAnimatedEmoji()`, `isAnimatedEmojiStickers()` |
| 10 (desktop 12) | opened surfaces | viewers, shared media, downloads are outside G's whitelist (deviation 8) |
| 11 (desktop 13) | corrupt store erases marks | marks are a prefs `StringSet`; an unparseable entry is skipped on read and kept on every rewrite (only the changed chat's entry is replaced) |
| desktop 14 | caches outlive the session | snapshots and the toast set reset when the slot's user id changes; the toast's action captures the dialog id, not an object |

**Not covered, as the spec says:** custom emoji animate; avatars load; shared-media grid thumbnails load when you open the tab; service-message photos; plus deviation 8's player cover art and finding 6's wallpaper.

## 🔁 compile rounds

| Round | Run | Result |
|---|---|---|
| 1 | 40169152187 | first cut (before deviations 8-9); guard and rule tests green; cancelled during Build once round 2 passed, superseded |
| 2 | 40169455722 | green on the first compile: guard, rule tests, `assembleAfatRelease`, artifact `tg-custom-android-0aae9598…` (37 MB) |

Untested on a device: everything in docs/trust.md 4.3 (Android steps) is the user's phone pass.
