# Using Telegram Custom 📨

## 🖥️ desktop
1. **Built on GitHub only.** A push to `main` touching `desktop/` builds (~1h45 without cache) and
   publishes a Release. Nothing gets built on the laptop.
2. **Install or update:** `desktop/install.sh --release`. It fetches the newest desktop Release,
   checks it was built by this repo's workflow, keeps the current build as `.prev`, and says "up to
   date" when there is nothing new. It refuses (and changes nothing) if a library is missing: update
   Manjaro first, since CI links against the current stable libs. If Telegram Custom is open, quit and
   reopen it to switch.
3. **A feature-branch build** (not released): Actions → **desktop** → Run workflow → pick the branch,
   then `desktop/install.sh --from-ci` (newest successful run on any branch).
4. Launch **Telegram Custom** from the app menu. Its data lives in `~/.local/share/TelegramCustom`,
   separate from the official client, so it needs its own login.
5. Broken build? `desktop/install.sh --rollback` swaps the previous one back.
6. **Ghost mode:** ☰ menu → Ghost mode. **Folder counter:** right-click a folder tab → Hide/Show unread counter.

## 📱 android
1. **Download:** the repo's **Releases** page, newest "Android" release → the `.apk`. A push to
   `main` touching `android/` builds and publishes one (free: the repo is public).
2. **A branch build** (not released): Actions → **android** → Run workflow → pick the branch; the
   APK is the run's artifact.
3. It sits next to the official Telegram as **TG Custom**.
4. No Google push for this build: in Settings → Notifications, turn on **Keep-alive service** and
   **Background connection**, or notifications arrive late.
5. **Hide a gallery folder** (e.g. Documents, Screenshots) from "All media": attach → tap the album
   name at the top → long-press the folder. It stays in the list marked "hidden"; long-press again to undo.
6. **Send and move to trash:** pick photos → long-press send → **Send and move to trash**. After
   everything has uploaded, Android asks once to move the originals to its trash. Nothing is touched
   if any send fails. Android 11+.

## 🔁 updating from upstream
- Desktop: edit `desktop/UPSTREAM` (version + the two hashes from the Arch PKGBUILD at that tag), push to `main`.
- Android: paste the newest `update to X` commit sha from DrKLO/Telegram into line 1 of `android/UPSTREAM`, push.

## 📣 announcements
Every `main` release is posted to a Telegram channel by a bot (the file if under 50 MB, else a
link, with what changed since the last release). Until both secrets exist the step skips with a
notice and releases still publish. Setup:
1. @BotFather → `/newbot` → keep the token it shows.
2. Channel → Administrators → Add admin → the bot, with "Post messages".
3. The channel id: a public channel is `@name` (plain `@`). A private one: forward any post from it
   to @userinfobot, which replies with the id (`-100…`, minus sign included).
4. `gh secret set TELEGRAM_BOT_TOKEN -R behdadmansouri/telegram-custom` (paste at the prompt, so
   it stays out of shell history), then the same for `TELEGRAM_CHANNEL_ID`.
5. Check it without a build: Actions → **announce** → Run workflow; it re-posts the newest release.

## 🌿 branches
`main` = what CI builds and publishes. A new feature lives on its own branch until it has been
tried on the device (a workflow run on the branch), then merges to `main`.

## ✏️ writing an Android patch
A source tree only for the edit (~0.5 GB), deleted after; never a build.
1. Once per patch: `git clone --filter=blob:none https://github.com/DrKLO/Telegram ~/.cache/telegram-custom/android-src`,
   then in it `git checkout -B custom $(head -1 <project>/android/UPSTREAM)` and `git am <project>/android/patches/*.patch`.
2. Edit, commit. From the project root: `git -C ~/.cache/telegram-custom/android-src format-patch -N --zero-commit $(head -1 android/UPSTREAM) -o "$PWD/android/patches"`
3. Push to a branch and run the **android** workflow on it; CI applies the series to a clean checkout, so the patch files are the truth.

## ✏️ writing a desktop patch
A source tree only for the edit (~0.5 GB), deleted after; never a build.
1. `desktop/build.sh --tree` unpacks the pinned tarball into `~/.cache/telegram-custom/src/tdesktop-<ver>-full`
   (a git tree; tag `upstream` = stock, branch `custom` = upstream + our patches).
2. Edit there, commit. From the project root: `git -C ~/.cache/telegram-custom/src/tdesktop-<ver>-full format-patch -N --zero-commit upstream -o "$PWD/desktop/patches"`
3. Push to a branch, run the **desktop** workflow on it, try it with `desktop/install.sh --from-ci`. Then `rm -rf ~/.cache/telegram-custom`.
