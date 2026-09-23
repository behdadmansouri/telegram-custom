# Using Telegram Custom 📨

## 🖥️ desktop
1. Build deps, once (build-only, safe to remove later):
   `sudo pacman -S --needed boost boost-libs cmake git glib2-devel gobject-introspection qt6-shadertools gperf libtg_owt microsoft-gsl ninja python range-v3 tl-expected vulkan-headers`
2. `desktop/build.sh` (first run ~30-60 min; `JOBS=6` to go faster, at the cost of RAM)
3. Launch **Telegram Custom** from the app menu. Its data lives in `~/.local/share/TelegramCustom`,
   separate from the official client, so it needs its own login.

## 📱 android
1. GitHub → `telegram-custom` repo → Actions → **android** → latest run → download the APK artifact
   (a push touching `android/` builds automatically; "Run workflow" builds on demand).
2. Install it; it sits next to the official Telegram as **TG Custom**.
3. No Google push for this build: in Settings → Notifications, turn on **Keep-alive service** and
   **Background connection**, or notifications arrive late.

## 🔁 updating from upstream
- Desktop: edit `desktop/UPSTREAM` (version + the two hashes from the Arch PKGBUILD at that tag), rerun `desktop/build.sh`.
- Android: paste the newest `update to X` commit sha from DrKLO/Telegram into line 1 of `android/UPSTREAM`, push.

## ✏️ writing a desktop patch
1. Edit inside `~/.cache/telegram-custom/src/tdesktop-<ver>-full` (a git tree; branch `custom` = upstream + our patches), commit.
2. From the project root: `git -C ~/.cache/telegram-custom/src/tdesktop-<ver>-full format-patch -N --zero-commit upstream -o "$PWD/desktop/patches"`
3. `desktop/build.sh` resets the tree and re-applies the whole series, so the patch files are the truth.
