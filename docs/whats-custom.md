# what's custom 🃏

Design for [plan.md](plan.md) batch 2 step 7: a section in each client with one card per patch. Each card holds a before/after glyph, one line, its toggle where it has one, and a "Show me" button that jumps to where the feature lives. Anchors are stock Android 13.0.3 (`0aae9598`) and tdesktop 7.2.5 (the full release tarball, submodules included, so lib_ui palette and style names were checked too), read 2026-10-25. "After 0004" means the line patch 0004 (Ghost mode) inserts next to that stock line. Patch set: `origin/batch-2` (Android 0001-0009, desktop 0001-0008). Revised after [critique 1](archive/2026-10-25-whats-custom-critique-1.md). Nothing built.

## 0. 🧱 v1 build list (go straight down it)

**Numbering:** trust and What's custom go last, trust first. Android: `0010-Media-trust`, `0011-Whats-custom`. Desktop: `0009-Media-trust`, `0010-Whats-custom`. Trust adds its own card in its own patch only if it lands after this one; in this order, What's custom ships the trust card itself.

**Step 1: fold the toggle guards into their own patches** (rewrite the `.patch` files on `batch-2`; same behaviour, default on, no UI). The What's custom patch is then purely additive apart from its entry points.

| # | Patch | Change | Lines |
|---|---|---|---|
| G1 | desktop 0005 | `if (true) {` becomes `if (Custom::NotifyWithoutDelay()) {` (`window/notifications_manager.cpp:403`); key `notifyWithoutDelay` in `custom_settings.{h,cpp}` | +12 |
| G2 | desktop 0004 | adds `GhostModeValue()` (built on 0003's `changes` stream); the menu toggle uses it instead of `rpl::single(Custom::GhostMode())`, so it follows any other switch | +8 |
| G3 | Android 0008 | nothing: `isAutoUngroupCaptioned` / `setAutoUngroupCaptioned` already exist | 0 |

The locked-emoji toggle is not in v1 (section 5): its guard would sit in 0002, which comes before 0003 creates the settings module, so it means restructuring two patches per platform.

**Step 2: the What's custom patch.**

**Android (13.0.3)**

| # | Piece | Anchor | Lines |
|---|---|---|---|
| A1 | `messenger/WhatsCustom.java` (new): `Feature` record, `ALL` (9 entries plus trust), glyph rows, show-me helpers | new file | 90 |
| A2 | `ui/Components/WhatsCustomGlyph.java` (new): paints one icon plus at most two modifiers (section 2), one `View` with the stock and ours glyph side by side | new file | 70 |
| A3 | `ui/WhatsCustomActivity.java` (new) `extends UniversalFragment` (`ui/Components/UniversalFragment.java:28`, abstract methods `:75-78`) | new file | 90 |
| A4 | Settings row 102 below 0004's Ghost mode row 100 (trust's row 101 sits between them), icon `R.drawable.msg_customize` | after 0004 at `ui/SettingsActivity.java:708` (stock row 10) | 1 |
| A5 | `case 102:` opens A3 with a callback that runs `listView.adapter.update(true)` on close (Settings has no `onResume` refresh; the card is the only other place Ghost mode flips on Android) | after 0004's `case 100:`, which follows stock `case 10:` at `:845` | 3 |
| | **Android total** | | **~255, 4 lines inside upstream files** |

**Desktop (7.2.5)**

| # | Piece | Anchor | Lines |
|---|---|---|---|
| D1 | `custom/custom_whats_custom.{h,cpp}` (new): registry `Features()`, glyph rows (Android-only rows included, flagged), show-me helpers, the box | new files | 170 |
| D2 | `custom/custom_whats_custom_glyph.cpp` (new): the glyph painter and `GlyphWidget` | new file | 60 |
| D3 | `custom/whats_custom_sheet.cpp` + `whats_custom_sheet.cmake` (new): the contact-sheet executable (section 2) | new files | 70 |
| D4 | `Telegram/CMakeLists.txt`: 3 source lines beside 0003's `custom/custom_settings.*` (`:543`, stock `chat_helpers/ttl_media_layer_widget.h`), plus one `include(...)` of D3's cmake file at the end | `Telegram/CMakeLists.txt:543`, end of file | 4 |
| D5 | Main menu: "What's custom" action (`&st::menuIconCustomize`, `ui/menu_icons.style:94`) after 0004's Ghost mode action, which follows the stock Settings action | after 0004 at `window/window_main_menu.cpp:748` (Settings action `:743-748`) | 6 |
| | **Desktop total** | | **~310, ~10 lines inside upstream files** |

**CI**

| # | Piece | Where | Lines |
|---|---|---|---|
| C1 | Card check (section 6): every patch has a card, every card title is a README row, shared cards have the same glyph row on both platforms | `.github/whats-custom-check.sh`, a step in `patch-lint.yml` | 40 |
| C2 | Contact sheet: build D3 in the desktop build tree, run it offscreen, upload `whats-custom-sheet.png` | `desktop.yml`, after the build step | 12 |

## 1. 📇 one registry per platform

The registry is the only list on each platform. The screen, the header count, C1 and the sheet all read it. It lives in our own new file, so adding to it never touches upstream code.

**Join key: the patch slug, not its number.** `patch = "Ghost-mode"` is the file name minus `00NN-` and `.patch`. Numbers differ between platforms (0005 is gallery folders on Android, notification delay on desktop) and change when patches are reordered; slugs do neither. The card shows the full file name in small grey text under its title.

**Android** (`messenger/WhatsCustom.java`):

```java
public static final class Feature {
    final String patch;          // slug: "Ghost-mode"
    final String title, line;    // card title (also the README row), one line
    final Glyph glyph;           // icon + modifiers, stock and ours (section 2)
    final Toggle toggle;         // null = always on
    final ShowMe showMe;         // null = no button
}
public interface Toggle { boolean get(); void set(boolean on); }
public interface ShowMe { void open(BaseFragment from); }
static final Feature[] ALL = { ... };
```

**Desktop** (`custom/custom_whats_custom.cpp`): the same fields as a struct. `toggle` is `std::optional<Toggle>` with `Fn<bool()> get` and `Fn<void(bool)> set`; `showMe` is `Fn<void(not_null<Window::SessionController*>)>`, empty for no button; a `bool androidOnly` marks rows that exist only so the sheet can show Android's cards. `const std::vector<Feature> &Features()`.

**Show-me is a lambda, not an enum,** so a new target never edits the screen. Helpers cover the common jumps: `savedMessages(hint)`, `attachSheet(hint)`, `hint(text)` (toast only), `settings(type)`.

**A new patch adds its card in one place:** one entry appended to `ALL` / `Features()` (slug, title, line, glyph row, toggle or null, show-me or null, about 8 lines), plus its README row. C1 fails the build when either is missing.

**Getters are in-memory reads.** Android `CustomSettings` caches the ghost flag and `SharedPreferences.getBoolean` is a map lookup after first load; desktop `Custom::*` read the in-memory `State` (0003). Safe on the per-notification path (G1).

## 2. 🎨 the glyphs

**One large before/after glyph per card, built from the app's own icon plus at most two modifiers.** No miniature screens. This is the visual language Telegram already uses for feature lists (Premium features, Power saving: one big icon, one line), it reuses icons the apps ship, and it is small enough to review as text. Glyph size 56dp / 56px, stock on the left, ours on the right, an arrow between, captions "Telegram" (`sub` color) and "TG Custom" (`accent`).

**Modifiers** (identical strings on both platforms; this string is what C1 compares):

| Modifier | Draws | Android color | Desktop color |
|---|---|---|---|
| `badge:N` | unread pill on the icon's top-right | `key_chats_unreadCounter` | `st::dialogsUnreadBg` |
| `sub:<icon>` | small second icon on the bottom-right, on a `bg` disc | icon tinted `fg` | icon tinted `fg` |
| `strike` | red diagonal through the glyph | `key_text_RedRegular` (`ui/ActionBar/Theme.java:2646`) | `st::attentionButtonFg` |
| `label:<text>` | one short line under the glyph | `key_windowBackgroundWhiteGrayText` | `st::windowSubTextFg` |

Base icon tint: `key_windowBackgroundWhiteBlackText` / `st::windowFg`; glyph background disc: `key_windowBackgroundGray` / `st::windowBgOver`. Android calls `Theme.getColor(key, resourcesProvider)` with the fragment's `getResourceProvider()` (`ui/ActionBar/BaseFragment.java:1172`), as stock cells do; desktop reads `st::...->c` on every paint and repaints on `style::PaletteChanged()`. Both follow light/dark with no extra code.

**The glyph set** (every icon checked in the pinned trees; the icon is the one the feature's own menu entry or screen uses wherever possible):

| Patch slug | Android icon | Desktop icon | Stock | Ours | Card on |
|---|---|---|---|---|---|
| No-ads | `msg_channel` | `st::menuIconChannel` | `label:Sponsored` | `label:Sponsored` `strike` | both |
| Hide-premium-custom-emoji | `msg_emoji_smiles` | `st::menuIconEmoji` | `sub:lock` | `label:sendable only` | both |
| Per-folder-unread-counter | `msg_markunread` | `st::menuIconMarkRead` | `badge:48` | (none) | both |
| Ghost-mode | `msg_stories_stealth` | `st::menuIconStealth` | `label:online, read` | `label:offline, unread` | both |
| Hide-gallery-folders | `msg_gallery` | `st::menuIconPhoto` | `sub:file` | `label:photos only` | Android |
| Send-and-move-to-trash | `msg_send` | `st::menuIconSend` | (none) | `sub:delete` | Android |
| Build-number | `msg_info` | `st::menuIconInfo` | `label:<stock version>` | `label:<live label>` | both |
| Send-captioned-photos-separately | `msg_photos` | `st::menuIconPhotoSet` | `label:0 of 3 captions` | `label:3 of 3 captions` | Android |
| Eight-accounts | `msg_contacts` | `st::menuIconUserShow` | `badge:3` | `badge:8` | both |
| No-notification-delay | `msg_notifications` | `st::menuIconNotifications` | `label:after ~3 s` | `label:at once` | desktop |
| Own-Linux-app-id | (none) | the app logo, `Window::Logo()` (`window/main_window.h:38`) | `label:grouped with Telegram` | `label:its own icon` | desktop |
| Media-trust | `msg_photos` | `st::menuIconPhoto` | `label:loads by itself` | `sub:lock` `label:tap to load` | both |

`sub:` icons: `lock` = `msg_premium_lock2` / `st::menuIconLock`, `file` = `msg_filehq` / `st::menuIconFile`, `delete` = `msg_delete` / `st::menuIconDelete`. The build-number labels are live: `CustomSettings.buildLabel()` and `BuildVars.BUILD_VERSION_STRING` on Android, `CurrentVersionText` / `AppVersionStr` on desktop, never a hardcoded version.

**Approving one approves both.** Each row is the same composition on both platforms: same modifiers, same labels, same layout constants, only the icon artwork differs, and both icons are Telegram's own drawings of the same symbol. The desktop registry carries every row, including the three Android-only ones (flagged `androidOnly`, drawn with the desktop icon in the table above, never shown in the desktop box), so the desktop sheet shows all 12 cards. C1 fails when an Android row's modifier string differs from its desktop twin.

**Contact sheet (C2).** A small executable `WhatsCustomSheet` (D3) links the same `tdesktop::td_ui` and `lib_ui` the app links (`Telegram/CMakeLists.txt:39`, `:75`) plus D2 and the registry rows, calls `style::StartManager(100)` (`lib_ui/ui/style/style_core.h:38`), and paints every row into one PNG: one row per card, columns day stock, day ours, night stock, night ours. Night: CI unzips `Telegram/Resources/night.tdesktop-theme`, the sheet reads its `colors.tdesktop-theme` and applies each line with `style::main_palette::setColor(name, value)` (`lib_ui/ui/style/style_core_palette.h:67-68`), then paints again. Run under `QT_QPA_PLATFORM=offscreen`; `actions/upload-artifact` as `whats-custom-sheet`. The desktop build of the branch produces it, so the user approves the whole set before any APK is installed. ~ Unverified: whether `td_ui` links into a standalone executable without symbols from the app target. If it does not, the fallback is a Python/Pillow sheet (~80 lines) that reads the glyph rows from the desktop registry source with a regex and composes the stock icon PNGs (`Telegram/Resources/icons/...`); no build needed, same rows, slightly less faithful text rendering.

**Budget:** one table row per card; the painter is the only drawing code (A2 70, D2 60 lines).

**v2 escape hatch:** if a glyph reads too thin on the device, the two cards whose feature is a message cell (No-ads, captions kept) can become live cells with fake data, the way theme previews do it: Android `ui/ThemePreviewActivity.java:4814` (`new DialogCell(...)`), `:4857-4938` (fake `TL_message` objects into `new MessageObject(...)`); desktop `window/themes/window_theme_preview.cpp:92` (`Generator`), `boxes/peers/edit_peer_color_box.cpp:187-245` (`PreviewWrap` with real `HistoryView::Element`s). About 40-60 lines each, in the churniest classes, so only if a glyph fails on the device.

## 3. 🤖 Android UI

**Entry point:** Settings row 102, "What's custom", subtitle "N changes from Telegram" (N = `ALL.length`), below Ghost mode. `case 102:` calls `presentSettingFragment(new WhatsCustomActivity(() -> listView.adapter.update(true)))`; the fragment runs the callback in `onFragmentDestroy`.

**Screen:** `WhatsCustomActivity extends UniversalFragment`, the base `UserInfoActivity` and `BusinessLinksActivity` already use. Header: `UItem.asTopViewStatic("Telegram " + BuildVars.BUILD_VERSION_STRING + " plus N patches" + CustomSettings.buildLabel(), R.drawable.msg_customize)` (`UItem.java:219`).

**A card is stock items in one white section:** `UItem.asCustom(cardView)` (glyph pair, title, patch file name, one line; `UItem.java:88`), `UItem.asCheck(id, "On").setChecked(t.get())` (`:303`) when it has a toggle, `UItem.asButton(id, "Show me").accent()` (`:227`) when it has a target, then `UItem.asShadow(null)` (`:341`). Ids `1000 + 10*i + {0 check, 1 button}`. `onClick` flips the toggle and calls `((TextCheckCell) view).setChecked(...)`.

**Show-me per feature:**

| Slug | Target | How |
|---|---|---|
| No-ads | none | nothing to point at |
| Hide-premium-custom-emoji | Saved Messages, emoji panel open | open Saved Messages (`args.putLong("user_id", getUserConfig().getClientUserId())`, `new ChatActivity(args)`), then `chat.getChatActivityEnterView().getEmojiButton().performClick()` (`ChatActivity.java:13852`, `ChatActivityEnterView.java:10360`) |
| Per-folder-unread-counter | toast "Open Chats, then long-press a folder tab"; without folders "Create a folder first" | toast only, stays on Settings: no navigation by back press |
| Ghost-mode | none | toggle on the card |
| Hide-gallery-folders | attach sheet in Saved Messages, toast "Long-press a folder in the album menu" | `chat.getChatActivityEnterView().getAttachButton().performClick()` (`ChatActivityEnterView.java:10301`, whose listener calls `didPressAttachButton` and stock `openAttachMenu`); no upstream change |
| Send-and-move-to-trash | same sheet, toast "Pick photos, long-press Send" | as above |
| Build-number | none | the glyph shows the live label |
| Send-captioned-photos-separately | same sheet, toast "Give two photos different captions" | as above |
| Eight-accounts | account list | `presentFragment(new UserInfoActivity())`, as Settings `case 1:` (`SettingsActivity.java:822`) |
| Media-trust | trust settings | `presentFragment(new TrustSettingsActivity())` (trust.md A11) |

**Timing for the chat jumps:** poll `chat.openAnimationEnded` (public, `ChatActivity.java:848`) every 100 ms; if it is not true within 1.5 s, show the toast "Tap 📎" (or "Tap 😊") instead of clicking.

## 4. 🖥️ desktop UI

**Entry point:** main-menu action "What's custom" right after 0004's Ghost mode toggle, `controller->show(Box(Custom::WhatsCustomBox, controller))`. Main menu only, as plan step 7 says.

**Box, not a Settings section.** `WhatsCustomBox(not_null<Ui::GenericBox*>, not_null<Window::SessionController*>)`, modelled on `ArchiveSettingsBox` (`settings/sections/settings_advanced.cpp:1957`): `setTitle`, `setWidth(st::boxWideWidth)`, one "Done" button, cards in `box->verticalLayout()`, which scrolls. A box closes itself before a show-me jump; a `Settings::Section` would need its own back handling for no gain. Rows with `androidOnly` are skipped.

**A card:** `GlyphWidget` (an `Ui::RpWidget`, painted by D2), a bold title `Ui::FlatLabel`, the patch file name and the one line (`st::boxDividerLabel`), a `Button` with `st::settingsButtonNoIcon` `->toggleOn(rpl::single(get()))->toggledChanges() | rpl::on_next(set)` when it has a toggle (the chain at `settings_advanced.cpp:1978-1983`), a `Ui::LinkButton` "Show me" when it has a target, `AddSkip` and `AddDividerText`-style gaps between cards (`:1975`, `:2000`).

**Toggle wiring:** setters write `custom.json` through 0003's atomic `QSaveFile` write and fire its `changes` stream. Ghost mode's setter also calls `controller->session().updates().updateOnline(crl::now())`, as 0004's menu handler does; the menu toggle follows through `GhostModeValue()` (G2).

**Show-me per feature** (each closes the box first; a button is offered only when its target can be shown now):

| Slug | Target | Call |
|---|---|---|
| No-ads | none | |
| Hide-premium-custom-emoji | Saved Messages, toast "Open the emoji panel" | `controller->showPeerHistory(controller->session().user())` (as `window_main_menu.cpp:717`), `controller->showToast(...)` (`window_session_controller.h:335`) |
| Per-folder-unread-counter | toast "Right-click a folder tab"; with one folder or none, "Create a folder first" | `controller->session().data().chatsFilters().list().size() > 1` (`data/data_chat_filters.h:164`) picks the text |
| Ghost-mode | none | toggle on the card |
| No-notification-delay | none | no stock screen shows the delay |
| Own-Linux-app-id | none | |
| Build-number | About box | `controller->show(Box(AboutBox))` (`boxes/about_box.h:12`, as `window_main_menu.cpp:410`) |
| Eight-accounts | Settings, toast "⋮ > Add account" | `controller->showSettings()` (`window_session_controller.h:302`); the menu is `settings/sections/settings_main.cpp:661` |
| Media-trust | trust box | trust.md D10's box |

## 5. 🎚️ which features get a toggle in v1

| Feature | v1 | Why |
|---|---|---|
| Ghost mode | **toggle** | exists (`ghostMode`); turning it off is the everyday use |
| Captions kept (Android) | **toggle** | key exists (`autoUngroupCaptioned`, default on); the only way back to the album look |
| No notification delay (desktop) | **toggle, default on** | a real tradeoff: the stock delay suppresses a duplicate ping when the phone already showed the message. Guard lives in 0005 (G1) |
| Locked emoji hidden | always on in v1 | the off position ("see what Premium adds") is worth little, and its guard needs the settings module that 0003 creates after 0002 |
| No ads | always on | nobody turns ads back on; "no ads" stays a flat promise in the README |
| Folder counters, gallery folders | no toggle | per-item settings where the item lives; the card shows how many are hidden, from `CustomSettings.isFolderCounterHidden` / 0003 desktop's `hiddenFolderCounters` and `CustomSettings.hiddenGalleryBuckets()` |
| Send and move to trash | no toggle | already opt-in on every send |
| 8 accounts | always on | an off switch would strand logged-in accounts 4-8; the card's line says so |
| Own app id, build number | always on | identity, fixed at build time |

## 6. 🧪 churn and test plan

**Churn:** after step 1 the What's custom patch touches upstream in four places: the Settings row and `case` (Android, both on 0004's lines), the main-menu action (desktop, on 0004's lines) and `CMakeLists.txt`. Everything else is in new files, so an upstream rename breaks the build in our file, not the patch apply. Names to watch on each bump: `UniversalFragment`, `UItem.asCheck/asButton/asCustom`, `getAttachButton`, `getEmojiButton`, `openAnimationEnded`, `UserInfoActivity` (Android); `Ui::GenericBox`, `AboutBox`, `showPeerHistory`, `showToast`, `chatsFilters`, `td_ui` (desktop).

**CI checks (no device):**

1. Both builds compile every show-me target and setter.
2. C1: every `*/patches/*.patch` slug has a registry entry on its platform (exempt: Whats-custom itself); every registry title appears in `README.md`'s feature table; every Android row's modifier string equals its desktop twin.
3. C2: the contact sheet, day and night, as a workflow artifact on every desktop build.
4. patch-lint stays green: nothing here adds a URL or network call (so no "view the patch on GitHub" link in the app).

**Needs the user's eyes:**

1. The contact sheet: approve all 12 glyph pairs in day and night before the first install.
2. On each device: every toggle flips, survives a restart, and Settings' Ghost row (Android) and the main-menu toggle (desktop) agree after you return.
3. Each "Show me" lands where its toast says, including the attach sheet and emoji panel opening on their own.

## 7. 🤔 open questions (each has a default the build uses)

1. **Picture style.** (a) **Glyphs** [default]: one icon plus at most two modifiers, ~70 lines per platform, previewed on the CI sheet. (b) Live mini-demos: real cells with fake data, ~40-60 lines per card, ~400-500 per platform in the churniest classes, no preview. (c) Schematic screens (round 1): ~230 lines per platform of hand-placed coordinates, no preview for Android. Default (a), with (b) for No-ads and captions only if their glyphs fail on the device.
2. **Ghost mode's own Settings row:** keep it beside the new row, or fold it into What's custom? Default: keep it (one tap for the toggle used most).
3. **Locked-emoji toggle:** add it later by moving the settings module's creation into 0002 (two patches rewritten per platform)? Default: no.
4. **Per-item features** (folder counters, gallery folders): count only, or a "Show all again" reset on the card? Default: count only.
5. **Card order:** patch order (default), or toggles first.
6. **Strings:** English literals in code like every existing patch, no `strings.xml` / `lang.strings` entries. Default: yes.
7. **Shared registry data file** (`whats-custom.tsv` generating both registries and the README table): removes the third list. Default: not in v1; C1's README grep covers the drift.
