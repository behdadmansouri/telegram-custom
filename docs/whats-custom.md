# what's custom 🃏

Design for [plan.md](plan.md) batch 2 step 7: a section in each client with one card per patch. Each card holds a stock-vs-ours picture, one line, its toggle where it has one, and a "Show me" button that jumps to where the feature lives. Anchors are stock Android 13.0.3 (`0aae9598`) and tdesktop 7.2.5, read 2026-10-25; "after 0004" means the line patch 0004 (Ghost mode) inserts next to that stock line. Patch set: `origin/batch-2` (Android 0001-0009, desktop 0001-0008). Draft: nothing built.

## 0. 🧱 v1 build list (go straight down it)

One patch per platform, last in the series: `0010-Whats-custom` (Android), `0009-Whats-custom` (desktop). It must come after every feature patch it shows, because it calls their settings. A later feature patch (trust, hardening) adds its own card to the registry this patch creates (section 1).

**Android (13.0.3)**

| # | Piece | Anchor | Lines |
|---|---|---|---|
| A1 | `messenger/WhatsCustom.java` (new): the registry. `Feature` record, `ALL` array of 9 entries, show-me helpers | new file | 90 |
| A2 | `ui/Components/WhatsCustomPicture.java` (new): the primitive painter (section 2) and a `View` that draws two panels | new file | 110 |
| A3 | The 9 pictures, as painter lambdas inside A1's entries | inside A1 | 110 |
| A4 | `ui/WhatsCustomActivity.java` (new) `extends UniversalFragment` (`ui/Components/UniversalFragment.java:28`, abstract `getTitle`/`fillItems`/`onClick`/`onLongClick` at `:75-78`) | new file | 90 |
| A5 | `CustomSettings.java`: `hideLockedEmoji` key (getter, setter) | our file | 8 |
| A6 | Emoji guard: 0002's `if (false && premiumEmojis.size() > 0)` becomes `if (!CustomSettings.isHideLockedEmoji() && ...)`; 0002's `if (premium && !isPremium) continue;` gains `&& CustomSettings.isHideLockedEmoji()` | `ui/Components/EmojiView.java:7658`, `:7702` (lines 0002 already changes) | 0 new |
| A7 | Settings row 102 below 0004's Ghost mode row 100 (and below trust's row 101 if that lands first), `R.drawable.msg_customize` | after 0004 at `ui/SettingsActivity.java:708` (stock row 10) | 1 |
| A8 | `case 102:` opens A4 with a callback that refreshes the list on close (Settings has no `onResume` refresh, so the Ghost row's On/Off would go stale) | after 0004's `case 100:`, which follows stock `case 10:` at `ui/SettingsActivity.java:845` | 3 |
| A9 | `openAttachMenu()` private to public, so "Show me" can open the attach sheet | `ui/ChatActivity.java:13638` | 1 changed |
| | **Android total** | | **~410, ~5 inside upstream files** |

**Desktop (7.2.5)**

| # | Piece | Anchor | Lines |
|---|---|---|---|
| D1 | `custom/custom_whats_custom.{h,cpp}` (new): registry `Features()`, `Feature` struct, show-me helpers, the box | new files | 160 |
| D2 | `custom/custom_whats_custom_pictures.cpp` (new): primitive painter, `PictureWidget`, the 8 pictures | new file | 150 |
| D3 | `Telegram/CMakeLists.txt`: 3 source lines beside 0003's `custom/custom_settings.*` | `Telegram/CMakeLists.txt:543` (stock `chat_helpers/ttl_media_layer_widget.h`) | 3 |
| D4 | `custom_settings.{h,cpp}`: `NotifyWithoutDelay`, `HideLockedEmoji` keys, plus `GhostModeValue()` producer | our files | 30 |
| D5 | Notify guard: 0005's `if (true) {` becomes `if (Custom::NotifyWithoutDelay()) {` | `window/notifications_manager.cpp:403` (the line 0005 already replaces) | 0 new |
| D6 | Emoji guard: 0002's `\|\| (!session->premium() && !_allowWithoutPremium)` gains `&& Custom::HideLockedEmoji()` | `chat_helpers/emoji_list_widget.cpp:3517` (0002's lines) | 0 new |
| D7 | Main menu: "What's custom" action (`&st::menuIconCustomize`, `ui/menu_icons.style:94`) after 0004's Ghost mode action, which follows stock Settings action `window/window_main_menu.cpp:743-748`. 0004's toggle switches `rpl::single(Custom::GhostMode())` to `Custom::GhostModeValue()` so it follows the box | after 0004 at `window/window_main_menu.cpp:748` | 6 |
| | **Desktop total** | | **~350, ~8 inside upstream files** |

**CI (both)**

| # | Piece | Where | Lines |
|---|---|---|---|
| C1 | Card check: every `*/patches/00NN-*.patch` (except Whats-custom and the identity patches listed in the script) has a registry entry whose `patch` field is `00NN` | `.github/whats-custom-check.sh`, a step in `patch-lint.yml` | 25 |

## 1. 📇 one registry per platform

The registry is the only list. The screen, the card count in its header and C1 all read it. It lives in our own new file, so adding to it never touches upstream code.

**Android** (`messenger/WhatsCustom.java`):

```java
public static final class Feature {
    final String patch;           // "0004": C1 matches it to android/patches/0004-*.patch
    final String title, line;     // card title, one line
    final Toggle toggle;          // null = always on
    final ShowMe showMe;          // null = no button
    final Pic.Painter stock, ours;
}
public interface Toggle { boolean get(); void set(boolean on); }
public interface ShowMe { void open(BaseFragment from); }
static final Feature[] ALL = { ... };
```

**Desktop** (`custom/custom_whats_custom.cpp`): the same fields as a struct; `toggle` is `std::optional<Toggle>` with `Fn<bool()> get` and `Fn<void(bool)> set`, `showMe` is `Fn<void(not_null<Window::SessionController*>)>` (empty = no button), pictures are `Fn<void(Pic&)>`. `const std::vector<Feature> &Features()`.

**Show-me is a lambda, not an enum,** so a new target never means editing the screen. Shared helpers in the registry cover the common jumps: `savedMessages(hint)`, `attachSheet(hint)`, `chatList(hint)`, `settings(type)`. The hint is a toast saying what to press once there.

**A new patch adds its card in one place:** one entry appended to `ALL` / `Features()` (patch number, title, line, toggle or null, show-me or null, two painters, about 15 lines). Nothing else. C1 fails the build when a new patch forgets.

## 2. 🎨 the pictures

**Drawn in code from a small set of primitives, not VectorDrawable XML or SVG files.** Telegram's themes do not use Android `?attr` colors: every color comes from `Theme.getColor(key)` at draw time, so a multi-color VectorDrawable cannot follow light/dark (one `setTint` recolors everything). Code-drawn shapes read `Theme.getColor(...)` / `st::...->c` on every paint, so they follow theme switches for free, can reuse the apps' real icons, and use the real UI font. They live in the patch as plain text, readable in review like any other line, with no binary assets and no `res/` churn. Qt Svg is already linked (`cmake/external/qt/CMakeLists.txt:22`, `QSvgRenderer` used in `ui/empty_userpic.cpp:196` with a color substituted into the SVG), and `androidx.core.graphics.PathParser` is already used (`ui/Components/CubicBezierInterpolator.java:18`), so an odd shape can be one SVG path string on either platform with no new dependency. Treat that as the escape hatch, not the default.

**Primitives** (same names on both platforms; coordinates in a 160 x 96 panel, scaled to the panel's real size):

| Primitive | Draws | Android color | Desktop color |
|---|---|---|---|
| `box(x,y,w,h,role)` | rounded rectangle | role | role |
| `bubble(x,y,w,h,out)` | message bubble | `key_chat_inBubble` / `key_chat_outBubble` | `st::msgInBg` / `st::msgOutBg` |
| `bars(x,y,w,n)` | n grey text lines | `key_windowBackgroundWhiteGrayText` | `st::windowSubTextFg` |
| `text(x,y,s,role)` | a real word ("Sponsored", "online") | role | role |
| `badge(x,y,s)` | unread pill | `key_chats_unreadCounter` | `st::dialogsUnreadBg` |
| `dot(x,y,r,role)` | avatar circle | role | role |
| `icon(i,x,y,size,role)` | an existing app icon, tinted | e.g. `R.drawable.msg_premium_lock2`, `msg_stories_stealth`, `msg_delete` | e.g. `st::menuIconStealth` |
| `strike(x,y,w,h)` | red cross-out | `key_windowBackgroundWhiteRedText` | `st::attentionButtonFg` |

Roles map to: `bg` (`key_windowBackgroundWhite` / `st::windowBg`), `fg` (`..BlackText` / `st::windowFg`), `sub`, `accent` (`key_featuredStickers_addButton` / `st::windowBgActive`). The panel itself is `key_windowBackgroundGray` / `st::windowBgOver`; the left panel is labelled "Telegram" in `sub`, the right "TG Custom" in `accent`.

**Example** (Android, folder counters): `stock: p.text(8,24,"All",FG); p.badge(28,14,"12"); p.text(64,24,"News",FG); p.badge(98,14,"48");` and `ours:` the same minus the second badge. That is the whole picture.

**What each card shows** (left = stock, right = ours):

| Patch | Card | Stock | Ours | Platforms |
|---|---|---|---|---|
| 0001 | No ads | a channel's posts, then a bubble labelled "Sponsored" with a button | the same posts, nothing after them | both |
| 0002 | Locked emoji hidden | emoji grid row of greyed squares with a lock icon each | only the free squares, packed | both |
| 0003 | Folder counters | tab strip "All 12 / News 48" | "All 12 / News" | both |
| 0004 | Ghost mode | what the other side sees: header "online", "typing...", their message with two checks | header "last seen recently", one check | both |
| A0005 | Gallery folders | "All media" grid mixing photos with document scans (`msg_filehq` icons) | photos only; album list row "Documents · hidden" | Android |
| A0006 | Send and move to trash | after sending: chat bubble, and the photo still in the gallery | chat bubble, the photo replaced by a trash icon | Android |
| A0007 / D0007 | Build number | "v13.0.3 (7183)" / "Version 7.2.5" | the live label, from `CustomSettings.buildLabel()` / `CurrentVersionText` | both |
| A0008 | Captions kept | one album bubble of 3 photos, no captions | 3 bubbles, each with a caption bar | Android |
| A0009 / D0008 | 8 accounts | 3 avatars and a lock "Premium for more" | 8 avatars | both |
| D0005 | No notification delay | timeline: message dot, a gap marked "~3 s", then a bell | message dot and bell together | desktop |
| D0006 | Own app id | dock: one blue icon standing for both clients | blue icon and purple icon side by side (purple is the logo's fixed color, not a theme color) | desktop |

**Budget:** at most 12 primitive calls and 15 lines per picture; all pictures together under 120 lines per platform. Panel height 96dp / 96px. No text beyond a few real words: the one-liner under the picture carries the explanation.

## 3. 🤖 Android UI

**Entry point:** Settings row 102, "What's custom", subtitle "9 changes from Telegram", directly below 0004's Ghost mode row (`SettingsActivity.java:708` stock row 10, then 0004's row 100). `case 102:` (after 0004's `case 100:`, stock `case 10:` at `:845`) calls `presentSettingFragment(new WhatsCustomActivity(() -> listView.adapter.update(true)))`; the fragment runs the callback in `onFragmentDestroy`, so the Ghost row's On/Off is right on return.

**Screen:** `WhatsCustomActivity extends UniversalFragment`, the base class `UserInfoActivity` and `BusinessLinksActivity` already use (one `UniversalRecyclerView`, items rebuilt by `fillItems`, clicks to `onClick`). Header item: `UItem.asTopViewStatic("Stock Telegram 13.0.3 plus 9 patches" + buildLabel(), R.drawable.msg_customize)`.

**A card is four stock items in one white section:** `UItem.asCustom(cardView)` (picture, title, one-liner; one custom view, ~40 of A2's lines), `UItem.asCheck(id, "On").setChecked(t.get())` when the feature has a toggle, `UItem.asButton(id, "Show me").accent()` when it has a target, then `UItem.asShadow(null)` as the gap. White section between shadows is how every Telegram settings group already looks, so the card needs no new styling. Ids: `1000 + 10*i + {0 check, 1 button}`.

**Toggle wiring:** `onClick` finds feature `i` from the id, calls `toggle.set(!toggle.get())`, then `((TextCheckCell) view).setChecked(...)`. Ghost mode's setter is `CustomSettings.setGhostMode`, which already sends the offline status for every account; ungroup uses the existing `setAutoUngroupCaptioned` (0008 says "no settings UI yet": this is it).

**Show-me per feature:**

| Patch | Target | How |
|---|---|---|
| 0001 No ads | none | nothing to point at: the ad slot is simply empty |
| 0002 Emoji | Saved Messages, toast "Open the emoji panel" | `Bundle args; args.putLong("user_id", getUserConfig().getClientUserId()); presentFragment(new ChatActivity(args))` |
| 0003 Folder counters | chat list, toast "Long-press a folder tab" | `finishFragment()`, then find `MainTabsActivity` in `getParentLayout().getFragmentStack()` and call its public `onBackPressed(true)` (`ui/MainTabsActivity.java:782`), which scrolls the pager back to the chats tab. No tab strip (no folders)? toast "Create a folder first" instead |
| 0004 Ghost mode | none | the toggle is on the card |
| 0005 Gallery folders | Saved Messages, attach sheet open, toast "Long-press a folder in the album menu" | open Saved Messages as above, then `chat.openAttachMenu()` (A9) once `chat.openAnimationEnded` (public field, `ChatActivity.java:848`) is true, polled every 100 ms for at most 1 s |
| 0006 Send and trash | same sheet, toast "Pick photos, long-press Send" | as 0005 |
| 0007 Build number | none | the card shows the live label |
| 0008 Captions kept | same sheet, toast "Give two photos different captions" | as 0005 |
| 0009 8 accounts | account list | `presentFragment(new UserInfoActivity())`, the same screen Settings `case 1:` opens (`SettingsActivity.java:822`) |

## 4. 🖥️ desktop UI

**Entry point:** main menu action "What's custom" (`&st::menuIconCustomize`) right after 0004's Ghost mode toggle (stock Settings action `window_main_menu.cpp:743-748`), `controller->show(Box(Custom::WhatsCustomBox, controller))`. Main menu only, as plan step 7 says; no Settings entry.

**Box, not a Settings section.** `WhatsCustomBox(not_null<Ui::GenericBox*>, not_null<Window::SessionController*>)`, modelled on `ArchiveSettingsBox` (`settings/sections/settings_advanced.cpp:1957`): `setTitle`, `setWidth(st::boxWideWidth)`, one "Done" button, everything in `box->verticalLayout()`, which scrolls. A box sits over whatever is open and closes itself before a show-me jump; a `Settings::Section<T>` would push a page into the settings stack and need its own back handling for no gain.

**A card:** `PictureWidget` (an `Ui::RpWidget`, `paintRequest` draws the two panels with current `st::` colors, `style::PaletteChanged()` calls `update()`), a title `Ui::FlatLabel` (`st::boxTitle`-like bold), the one-liner (`st::boxDividerLabel`), a `Settings::Button` with `st::settingsButtonNoIcon` `->toggleOn(rpl::single(get()))->toggledChanges() | rpl::on_next(set)` when the feature has a toggle (the same chain as `settings_advanced.cpp:1978-1983`), and a `Ui::LinkButton` "Show me" when it has a target. `AddSkip` and a divider between cards, as `ArchiveSettingsBox` does (`:1975`, `:2000`).

**Toggle wiring:** setters write `custom.json` through `custom_settings.cpp` (0003's `QSaveFile` atomic write) and fire its `changes` stream. Ghost mode's setter also calls `controller->session().updates().updateOnline(crl::now())`, copied from 0004's menu handler. The main-menu toggle reads `GhostModeValue()` (D7), so both switches agree.

**Show-me per feature:** each one first calls `box->closeBox()`.

| Patch | Target | Call |
|---|---|---|
| 0001 No ads | none | |
| 0002 Emoji | Saved Messages, toast "Open the emoji panel" | `controller->showPeerHistory(controller->session().user())` (as `window_main_menu.cpp:719`), `controller->showToast(...)` (`window_session_controller.h:335`) |
| 0003 Folder counters | toast "Right-click a folder tab" | `controller->showToast(...)` only: the tabs are already on screen |
| 0004 Ghost mode | none | toggle on the card |
| 0005 Notify delay | Settings > Notifications | `controller->showSettings(Settings::NotificationsId())` (`settings/sections/settings_notifications.h:14`) |
| 0006 App id | none | |
| 0007 Build number | About box | `controller->show(Box(AboutBox))` (`boxes/about_box.h:12`, as the menu footer does at `window_main_menu.cpp:410`) |
| 0008 8 accounts | Settings main, toast "⋮ > Add account" | `controller->showSettings()` (`window_session_controller.h:302`); the menu with Add account is `settings/sections/settings_main.cpp:661` |

## 5. 🎚️ which features get a toggle in v1

**The cost is lower than it looks.** Every always-on patch is already written as a same-line switch (`if (true)`, `if (false && ...)`), so a toggle swaps that constant for a `CustomSettings` call: zero new lines inside upstream files, one key plus a setter in our own file. The real question is whether anyone would ever flip it back.

| Feature | v1 | Why |
|---|---|---|
| Ghost mode | **toggle** | exists (`ghostMode`); turning it off is the everyday use |
| Captions kept (Android) | **toggle** | key exists (`autoUngroupCaptioned`, default on); someone who wants the album look has no other way back |
| No notification delay (desktop) | **toggle, default on** | a real tradeoff: the stock delay suppresses a duplicate ping when the phone already showed the message. Swaps 0005's `if (true)` |
| Locked emoji hidden | **toggle, default on** | swaps 0002's constant; the off position is the honest "see what Premium would add" view |
| No ads | always on | nobody turns ads back on, and "no ads" stays a flat promise in the README |
| Folder counters, gallery folders | no toggle | already a per-item setting where the item lives; the card says how many are hidden ("2 folders") |
| Send and move to trash | no toggle | already opt-in on every send (long-press menu) |
| 8 accounts | always on | an off switch would strand logged-in accounts 4-8 (stock refuses to load more than its limit) |
| Own app id (desktop), build number | always on | identity, fixed at build time |

## 6. 🧪 churn and test plan

**Churn:** almost all code is in our new files, so an upstream change breaks the build loudly rather than the patch apply. The upstream lines (A7-A9, D3, D7) hang on lines 0004 or 0003 already patch, so they port with those patches. The names they call are the risk on each bump: `UniversalFragment`, `UItem.asCheck/asButton/asCustom`, `ChatActivity.openAttachMenu`, `MainTabsActivity.onBackPressed`, `UserInfoActivity` (Android); `Ui::GenericBox`, `Settings::NotificationsId`, `AboutBox`, `showPeerHistory`, `showToast` (desktop). A rename is a compile error in our file, fixed in one place.

**CI checks (no device):** both builds compile every show-me target and every setter; C1 fails a patch with no card; patch-lint stays green because nothing here adds a URL or network call (so no "view the patch on GitHub" link in the app).

**Needs the user's eyes (first install of each platform):**

1. Every picture reads at a glance, in a day and a night theme.
2. Each toggle flips, survives a restart, and Settings' Ghost row (Android) and the main-menu toggle (desktop) agree with the card after you return.
3. Each "Show me" lands where its toast says, including the attach sheet opening on its own.
4. The Android screen scrolls smoothly (9 custom picture views).

## 7. 🤔 open questions (each has a default the build uses)

1. **Toggle set:** Ghost, captions, notify delay, locked emoji get toggles; the rest are always on. Default: section 5 as written.
2. **Ghost mode's own Settings row:** keep it beside the new row, or fold it into What's custom? Default: keep it (one tap for the toggle used most).
3. **Attach-sheet show-me needs one upstream line** (`openAttachMenu` private to public, plus a short poll for the open animation). Default: do it; the fallback is Saved Messages plus a "tap 📎" toast.
4. **Per-item features** (folder counters, gallery folders): count only, or a "Show all again" reset on the card? Default: count only in v1.
5. **Patch file name on each card** (small grey "0004-Ghost-mode" under the title, text only, no link). Default: yes; it ties the screen to the files the README tells people to read.
6. **Picture contact sheet in CI** (render every card to PNG so pictures can be reviewed before install). Default: no for v1; revisit if the first install shows bad pictures. Neither CI image can draw the Android pictures without an emulator.
7. **One picture spec shared by both platforms** (generated into each tree by `customize.sh` / `build.sh`). Default: no; per-platform code, since the pictures should look like each platform anyway.
8. **Order against the trust patch:** trust.md names its patch `0007-Media-trust`, but 0007 is the build number on batch-2. Default: What's custom lands first (Android 0010, desktop 0009); trust renumbers after it and adds its own card, whose show-me opens its settings screen.
9. **Card order:** patch order (default), or toggles first.
10. **Strings:** English literals in code like every existing patch, no `strings.xml` / `lang.strings` entries. Default: yes.
