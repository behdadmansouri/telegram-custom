# What's custom critique, round 1 (2026-10-25)

Target: `docs/whats-custom.md` (draft, nothing built) against plan.md batch 2 step 7 ("one card per patch with a stock-vs-ours picture, one line, its toggle where it has one, and Show me jumping to where it lives"; Settings on Android, main menu on desktop). Sources: DrKLO `0aae9598` (13.0.3) via the `port13b` tree, tdesktop `v7.2.5` (fresh clone, deleted after), the `origin/batch-2` patch series (Android 0001-0009, desktop 0001-0008). Paths relative to `TMessagesProj/src/main/java/org/telegram/` and `Telegram/SourceFiles/`. Every anchor cited below was read in the tree; where I could not check (lib_ui submodule) I say so.

## anchors: what held and what did not

Held on Android: `UniversalFragment` abstract methods (`ui/Components/UniversalFragment.java:28`, `:75-78`), `UItem.asCustom(View)` (`ui/Components/UItem.java:88`), `asTopViewStatic` (`:219`), `asButton(id, text)` (`:227`), `asCheck(id, text)` (`:303`), `asShadow(text)` (`:341`); `openAttachMenu()` private at `ui/ChatActivity.java:13638` (its only early return is slow mode); `openAnimationEnded` public at `:848`; `MainTabsActivity.onBackPressed(boolean)` public at `ui/MainTabsActivity.java:782`; `UserInfoActivity` is the account screen (`ui/UserInfoActivity.java:74`, `BUTTON_ADD_ACCOUNT` at `:425`) and Settings `case 1` opens it (`ui/SettingsActivity.java:822`); `PathParser` in `ui/Components/CubicBezierInterpolator.java:18`; drawables `msg_premium_lock2`, `msg_stories_stealth`, `msg_delete`, `msg_filehq`, `msg_customize` all exist; 0004's row 100 and `case 100` (`patches/0004` lines 154, 162-163), 0002's two constants (0002 lines 23, 31), 0008's `isAutoUngroupCaptioned`/`setAutoUngroupCaptioned` (0008 lines 38-43).

Held on desktop: `ArchiveSettingsBox` (`settings/sections/settings_advanced.cpp:1957`) and its toggle chain (`:1978-1983`), `AddDividerText` (`:2000`), main menu `AboutBox` (`window/window_main_menu.cpp:410`), Settings action (`:743-748`), `menuIconCustomize` (`ui/menu_icons.style:94`), `NotificationsId()` (`settings/sections/settings_notifications.h:14`), `AboutBox` (`boxes/about_box.h:12`), `showSettings` / `showToast` (`window/window_session_controller.h:302`, `:335`), add-account menu (`settings/sections/settings_main.cpp:661`), `QSvgRenderer` (`ui/empty_userpic.cpp:196`), 0005's stock line (`window/notifications_manager.cpp:403`), 0002's region (`chat_helpers/emoji_list_widget.cpp:3517`), `Telegram/CMakeLists.txt:543`; 0004's menu toggle uses `rpl::single(Custom::GhostMode())` (0004 lines 15-16) and 0003's `custom_settings.cpp` has an `rpl::event_stream<> changes` (0003 line 54) to build `GhostModeValue()` on.

Did not hold: `key_windowBackgroundWhiteRedText` does not exist in 13.0.3 (`ui/ActionBar/Theme.java` has `key_text_RedRegular` and `key_text_RedBold` at `:2646-2647`); `showPeerHistory(session().user())` is at `window_main_menu.cpp:717`, not `:719` (harmless). Not checkable from the tdesktop repo: palette names (`msgInBg`, `windowSubTextFg`, `dialogsUnreadBg`, `attentionButtonFg`, `windowBgActive`, `windowBgOver`), `boxWideWidth`, `boxDividerLabel`, `Ui::LinkButton`, and `cmake/external/qt/CMakeLists.txt:22`: all live in submodules (lib_ui, cmake_helpers). The names are the standard ones, but the doc marks them ✓ without having had the submodules, so say ~.

## objections

### 1. The schematic pictures are the most expensive part of the design and the only part nobody can see before the user installs both apps

Claim: 220 lines of hand-placed coordinates in a 160 x 96 panel (A3 110 + D2 150 minus the painter) for eleven miniature wireframes, written blind on both platforms (open question 6 admits CI cannot render Android), reviewed as text, first seen on the phone and the laptop. The one-liner under each picture already carries the whole message; the pictures add decoration whose quality is unknown until the user looks, and a CI port cycle each time one looks wrong.

Why it matters: this is the piece the user will judge by eye ("will it look amateurish"), and the design has no feedback loop for exactly that piece. A 160 x 96 scene with a bubble, two grey bars and the word "Sponsored" at pixel coordinates is a wireframe. Telegram's own in-app explanations never show miniature screens drawn from primitives: they show either a real cell with fake data (theme previews) or one large icon with a short line (Premium features, Power saving). The design picked the one visual language the apps do not use.

Evidence: section 2 primitives table and the "what each card shows" table; open question 6 ("Neither CI image can draw the Android pictures without an emulator"); `ui/ThemePreviewActivity.java:4814` (`new DialogCell(null, mContext, false, false)`), `:4857-4938` (fake `TLRPC.TL_message` objects, about 35 field assignments for three messages, fed to `new MessageObject(currentAccount, message, true, false)` at `:4873`, `:4921`, `:4938`); desktop `window/themes/window_theme_preview.cpp:92` (`class Generator` with `addTextBubble`, `addPhotoBubble`, `paintBubble` at `:156-172`, `:292-318`) and `boxes/peers/edit_peer_color_box.cpp:187-245` (`PreviewWrap` rendering real `HistoryView::Element`s from fake items).

Fix, in order of preference: (a) Shrink the picture to the one element that differs, drawn large, not a mini screen: the sponsored bubble alone (a bubble with "Sponsored" and a strike), one locked emoji square versus one plain square, one tab "News 48" versus "News", one avatar row of three with a lock versus eight, a message dot and a bell with and without a gap. That is 3-5 primitive calls per side at 40-56 dp, reads as deliberate iconography, and the budget drops to about a third. (b) For the two cards whose feature is a message cell (0001 no ads, A0008 captions kept), consider a real `ChatMessageCell` with a fake `MessageObject` the way `ThemePreviewActivity` does it; honest cost: 0001 needs the sponsored fields set and A0008 needs a `GroupedMessages` layout for the album side, each 40-60 fragile lines, so do it only if (a) looks thin on the device. (c) Whatever is drawn, give it a contact sheet on desktop: a tiny test target that paints every `Feature`'s two panels into a PNG under `QT_QPA_PLATFORM=offscreen` and uploads it as a CI artifact (~40 lines, no upstream code); then make the picture spec data shared by both platforms (open question 7, flip the default) so the desktop sheet previews Android too. One sheet before the first install replaces two blind device rounds.

### 2. `openAttachMenu` does not need to become public: the attach button is already reachable

Claim: A9 changes one upstream line in the 47k-line `ChatActivity.java` to open the attach sheet. The same sheet opens through public stock API with no patch hunk.

Why it matters: every hunk in `ChatActivity` is a re-port on every release (the menu block moved 46 lines in one release, round 1 of the trust critique). A9 is the only non-0004-anchored upstream hunk on Android; removing it makes the Android patch purely additive except for the two Settings lines.

Evidence: `ui/ChatActivity.java:13852` `public ChatActivityEnterView getChatActivityEnterView()`; `ui/Components/ChatActivityEnterView.java:10301` `public ImageView getAttachButton()`; its click listener at `:2841-2845` calls `delegate.didPressAttachButton()`, which `ChatActivity` implements at `:2426-2431` and which calls `openAttachMenu()` at `:2430`.

Fix: `chat.getChatActivityEnterView().getAttachButton().performClick()` once the chat is open. Drop A9 and open question 3. Keep the 100 ms poll on `openAnimationEnded` but replace the silent 1 s give-up with the toast fallback the doc already names ("tap 📎").

### 3. Show-me for folder counters rides on a back-press side effect

Claim: `finishFragment()` then `MainTabsActivity.onBackPressed(true)` to scroll the pager to the chats tab works only because `ViewPagerActivity.onBackPressed` happens to return true when no sheet is shown and the current page does not consume the press, after which `MainTabsActivity` scrolls to `getStartPosition()`.

Why it matters: it is a navigation call spelled as a back press. If a sheet is open or the Settings page consumes back (search open, a dialog), nothing scrolls and the toast "Long-press a folder tab" points at the wrong screen. Upstream can also change what back does on the tabs at any release and the compile will not tell you.

Evidence: `ui/MainTabsActivity.java:782-794` (`super.onBackPressed(invoked)` first; scroll only `if (result)`), `ui/ViewPagerActivity.java:229-237` (`hasShownSheet()` returns false before scrolling; `fragment.onBackPressed(invoked)` false returns false). No public `scrollToTab`/`switchTab` helper exists on `MainTabsActivity` (grep of `public .*Tab`, `public .*scrollToPosition` found none).

Fix: either accept the Settings tab as the landing (a toast "Open Chats, long-press a folder tab", zero risk), or add a two-line public `showChatsTab()` to `MainTabsActivity` beside `onBackPressed` (one additive upstream hunk anchored on a stable method). The first is the better trade for a hint whose target is one tap away anyway.

### 4. The toggle guards and `GhostModeValue()` edit lines that belong to earlier patches; fold them into those patches

Claim: A6, D5, D6 and D7 modify text that 0002, 0005 and 0004 added ("0 new lines"), from the last patch in the series. That couples the registry patch to the exact wording of three earlier patches: when 0004 is re-ported with a different context, 0010/0009 fails too, in the same CI loop, and the fix is in two files.

Why it matters: the series is ours; a patch that fixes a patch is the one place where rewriting history is correct and cheap (`git rebase -i` the branch, or edit the `.patch` file). The whole point of the "surgical patches" rule is that each `.patch` stands alone against upstream.

Evidence: section 0 A6, D5, D6, D7 and section 5 "swaps 0005's `if (true)`", "swaps 0002's constant"; 0002's lines (`patches/0002` 23 and 31), 0005's `if (true)` (`patches/0005` line 21), 0004's `rpl::single(Custom::GhostMode())` (`patches/0004` lines 15-16).

Fix: 0002 and 0005 ship with `CustomSettings.isHideLockedEmoji()` / `Custom::NotifyWithoutDelay()` / `Custom::HideLockedEmoji()` guards and their keys (default on, same behaviour, no UI); 0004 ships `GhostModeValue()` and uses it in the menu. The What's custom patch then touches upstream in exactly three places: the Settings row and `case` (Android, anchored on 0004) and the main-menu action plus `CMakeLists.txt` (desktop). Section 6's churn claim becomes true instead of nearly true.

### 5. Three lists can drift and C1 checks one of the three edges

Claim: the patch files, the registry, and the README "what's changed" table (the public trust document) describe the same set; C1 checks patches versus registry only. The README is hand-written (10 rows today, `origin/batch-2:README.md:26-35`), and nothing fails when a patch lands with a card but no README row, or the README says "3 accounts" after the registry says "8".

Why it matters: the README is what the plan's trust section (§🤝) sells to strangers; the in-app screen is what the user sees. A mismatch between them undercuts the "small readable diff" story more than a missing card does.

Evidence: `.github/patch-lint.sh` (patches only), section 0 C1 (`patch` field versus `*/patches/00NN-*.patch`), `README.md:24-35` on `origin/batch-2`.

Fix: make C1 also grep the README for each registry title (or for the patch number), and fail when one is missing. The stronger version, a single data file (`whats-custom.tsv`: patch, title, line, platforms) from which `customize.sh` and `build.sh` generate the two registries and CI renders the README table, also answers open question 7 and objection 1c; it costs a generator script of about 40 lines and removes the third copy outright. Recommend the grep now, the data file when the trust patch adds its card.

### 6. Toggle set: right calls, two notes

Claim: section 5 is sound: Ghost, captions, notify delay and locked emoji get toggles; ads, 8 accounts, app id and build number stay fixed; per-item features show counts. Two things are missing.

Why it matters: a toggle that reads a preference on a hot path, and a toggle whose off state leaves state behind, are the two classic regressions.

Evidence: `Custom::NotifyWithoutDelay()` will be read per notification (`notifications_manager.cpp:403` path), `CustomSettings.isHideLockedEmoji()` per emoji panel refresh (`EmojiView.java:7658`, `:7702`); `SharedPreferences.getBoolean` is a map lookup after first load, fine, but say so; the desktop `Custom::*` getters read an in-memory `State` (0003 line 50-55), fine. Captions toggle: 0008's setting is read at send time only, so flipping it has no residue. The 8-accounts reasoning ("an off switch would strand accounts 4-8") is correct and should stay in the card's one-liner as the reason there is no toggle.

Fix: one sentence in section 5 that every getter is an in-memory read; the "Folder counters" card's count comes from `CustomSettings.hiddenCounters` and 0003's `hiddenFolderCounters` set (0003 desktop line 51), name the calls so the porter does not invent them.

### 7. Show-me targets that point at nothing

Claim: desktop 0005 (no notification delay) sends the user to Settings > Notifications where no stock control shows the delay, and the toast cannot say what to look at; Android 0003's toast assumes the user has folders (handled) and desktop 0003's toast assumes folder tabs are visible (they are hidden when there is one folder or in the narrow layout).

Why it matters: a "Show me" that lands somewhere with nothing to see teaches the user to ignore the button.

Evidence: section 4 table rows 0005 and 0003; the stock delay has no UI (feasibility D-notes; 0005 replaces an unconditional `if`).

Fix: desktop 0005 gets no Show me (like 0001 and 0006); desktop 0003 shows the toast only when `session().data().chatsFilters().list().size() > 1`, else "Create a folder first", mirroring the Android rule. Add to section 4: a Show me is only offered when its target can be shown now (the doc already does this for Android 0003, make it the rule).

### 8. Android picture code must use the fragment's resources provider and the right red

Claim: `Theme.getColor(key)` without the `resourcesProvider` ignores a chat-specific or preview theme; in a settings screen it is harmless today, but `UniversalFragment` hands every item a provider and the stock cells use it. And `key_windowBackgroundWhiteRedText` will not compile.

Why it matters: the first Android build of the series fails on a name, one CI loop for nothing.

Evidence: `ui/ActionBar/Theme.java:2646-2647` (`key_text_RedRegular`, `key_text_RedBold`); no `RedText` key exists.

Fix: `strike` uses `key_text_RedRegular`; the painter takes `Theme.ResourcesProvider` from the fragment and calls `Theme.getColor(key, resourcesProvider)`.

### 9. Smaller points

(a) Section 3 says Settings has no `onResume` refresh so A8 adds a close callback; `UniversalFragment` rebuilds on `adapter.update(true)`, fine, but the Ghost row's "On/Off" also goes stale when the main-menu toggle (desktop) or the card toggle changes it while Settings is below in the stack; the desktop side already solves this with `GhostModeValue()`, Android should listen to a `NotificationCenter` id or re-run `update(true)` in `onResume` of `SettingsActivity` through the same 0004 hunk. (b) The header "Stock Telegram 13.0.3 plus 9 patches" hardcodes the version: read it from `BuildVars`/`BuildConfig.VERSION_NAME` and `AppVersion` so the auto-upstream bump does not leave a stale number on the one screen that claims accuracy. (c) Open question 8: trust.md names its patch `0007-Media-trust` and this doc says 0010/0009 land first; settle it in plan.md now, since both docs are "go straight down it" lists and one of them is wrong. (d) Open question 5 (patch file name on the card): yes, and make it the C1 join key, which it already is. (e) Desktop D4 lists `NotifyWithoutDelay` and `HideLockedEmoji` keys plus `GhostModeValue()` under this patch; after objection 4 they move to 0005, 0002 and 0004, and D4 shrinks to nothing. (f) Section 2 claims Qt Svg is linked via `cmake/external/qt/CMakeLists.txt:22`: that file is in the `cmake_helpers` submodule, not in the tdesktop clone; `empty_userpic.cpp:196` using `QSvgRenderer` is enough evidence, cite that alone.

## verdict

Ship-blocking: none in the sense of "the design cannot do what step 7 asks": the structure (card, line, toggle, Show me, Settings/main menu) matches the requirement and every API it leans on exists at the pins, with one compile error (objection 8) and one off-by-two line. What I would not ship as written: objection 1 (eleven blind wireframes with no preview path; cut to one large differing element per side and add the desktop contact sheet) and objection 4 (guard swaps and `GhostModeValue()` belong in 0002/0004/0005, not in the last patch). Both are design decisions, not bugs, and both are cheaper to take now than after the first device round.

Nice to have, in order: 2 (drop A9, use `getAttachButton().performClick()`), 3 (do not navigate by back press), 5 (C1 also checks the README; data file later), 7 (no Show me without a target), 8 (red key, resources provider), 6 and 9.

Schematic pictures versus live mini-demos, my take: live cells with fake data are the Telegram-native way to show a chat-level difference and both apps have the precedent, but only two of eleven cards are chat cells, and each would cost 40-60 fragile lines (sponsored fields, a grouped album layout) in the churniest classes. The schematic as specified (miniature screens at 160 x 96) is the worst of both: wireframe look, unreviewable coordinates, no preview. The right middle is a large before/after glyph per card built from the apps' own icons plus one or two primitives, with a desktop-rendered contact sheet in CI so the user approves the set before any APK is built.
