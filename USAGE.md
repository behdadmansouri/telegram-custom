# Using Telegram Custom 📨

## 🖥️ desktop
1. **From GitHub (default):** a push touching `desktop/` builds automatically (Actions → **desktop**).
   Install the newest successful build: `desktop/install.sh --from-ci`
   (needs Manjaro stable up to date: the build links against the current stable libs).
2. **Or locally:** build deps once (build-only, safe to remove later):
   `sudo pacman -S --needed boost boost-libs cmake git glib2-devel gobject-introspection qt6-shadertools gperf libtg_owt microsoft-gsl ninja python range-v3 tl-expected vulkan-headers`
   then `desktop/build.sh` (first run ~30-60 min; `JOBS=6` is faster but uses more RAM). It installs at the end.
3. Launch **Telegram Custom** from the app menu. Its data lives in `~/.local/share/TelegramCustom`,
   separate from the official client, so it needs its own login.
4. Broken build? `desktop/install.sh --rollback` swaps the previous one back.
5. **Ghost mode:** ☰ menu → Ghost mode. **Folder counter:** right-click a folder tab → Hide/Show unread counter.

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
- Desktop: edit `desktop/UPSTREAM` (version + the two hashes from the Arch PKGBUILD at that tag), rerun `desktop/build.sh`.
- Android: paste the newest `update to X` commit sha from DrKLO/Telegram into line 1 of `android/UPSTREAM`, push.

## 🌿 branches
`main` = what CI builds and publishes. A new feature lives on its own branch until it has been
tried on the device (a workflow run on the branch), then merges to `main`.

## ✏️ writing an Android patch
1. Edit inside `~/.cache/telegram-custom/android-src` (branch `custom` = upstream + our patches), commit.
2. From the project root: `git -C ~/.cache/telegram-custom/android-src format-patch -N --zero-commit $(head -1 android/UPSTREAM) -o "$PWD/android/patches"`
3. Push to a branch and run the **android** workflow on it; CI applies the series to a clean checkout, so the patch files are the truth.

## ✏️ writing a desktop patch
1. Edit inside `~/.cache/telegram-custom/src/tdesktop-<ver>-full` (a git tree; branch `custom` = upstream + our patches), commit.
2. From the project root: `git -C ~/.cache/telegram-custom/src/tdesktop-<ver>-full format-patch -N --zero-commit upstream -o "$PWD/desktop/patches"`
3. `desktop/build.sh` resets the tree and re-applies the whole series, so the patch files are the truth.
