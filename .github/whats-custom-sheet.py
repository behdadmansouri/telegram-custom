#!/usr/bin/env python3
"""Contact sheet of the "What's custom" glyphs (docs/whats-custom.md section 2): the Pillow fallback.

Usage: python3 -I .github/whats-custom-sheet.py <tdesktop Telegram/Resources dir> <out dir>
Reads icons/menu/*@3x.png (white on black, used as masks) and art/logo_256.png from the
tdesktop 7.2.5 full tarball; writes 2026-10-25-whats-custom-sheet-day.png and -night.png at 2x.
CARDS mirrors the glyph table in the doc: keep the two in step by hand (modifier strings are
the same ones the Qt painter will use: badge:N, sub:<icon>, strike, label:<text>).
"""
import colorsys, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# slug, title, shown on, icon, stock mods, ours mods, one-liner.  icon "logo*" = purple app logo.
CARDS = [
    ("No-ads", "No ads", "both", "channel", ["label:Sponsored"], ["label:Sponsored", "strike"],
     "Sponsored messages, search ads and promoted chats are gone."),
    ("Hide-premium-custom-emoji", "Locked emoji hidden", "both", "emoji", ["sub:lock"], ["label:sendable only"],
     "Premium-only custom emoji are hidden instead of shown locked."),
    ("Per-folder-unread-counter", "Folder counters", "both", "read", ["badge:48"], [],
     "Hide the unread counter of folders you choose."),
    ("Ghost-mode", "Ghost mode", "both", "stealth", ["label:online, read"], ["label:offline, unread"],
     "No read receipts, typing status or online status."),
    ("Hide-gallery-folders", "Gallery folders", "Android", "image", ["sub:file"], ["label:photos only"],
     "The attach sheet lists only the gallery folders you pick."),
    ("Send-and-move-to-trash", "Send and trash", "Android", "send", [], ["sub:delete"],
     "Long-press Send to send a photo and move the original to trash."),
    ("Build-number", "Build number", "both", "info", ["label:7.2.5"], ["label:7.2.5 TG Custom"],
     "The version line says it is a custom build (live label in the app)."),
    ("Send-captioned-photos-separately", "Captions kept", "Android", "photo_set",
     ["label:0 of 3 captions"], ["label:3 of 3 captions"],
     "Photos with their own captions are sent separately, not merged into an album."),
    ("Eight-accounts", "8 accounts", "both", "name_show", ["badge:3"], ["badge:8"],
     "Log in up to eight accounts instead of three."),
    ("No-notification-delay", "Instant notifications", "desktop", "info_notifications",
     ["label:after ~3 s"], ["label:at once"],
     "Desktop notifications appear at once, without the built-in delay."),
    ("Own-Linux-app-id", "Own app id", "desktop", "logo", ["label:grouped with Telegram"],
     ["label:its own icon"], "Desktop runs under its own app id and icon, not grouped with Telegram."),
    ("Media-trust", "Media trust", "both", "image", ["label:loads by itself"],
     ["sub:lock", "label:tap to load"], "Photos and files load only after you tap them."),
]
THEMES = {  # base icon, glyph disc, grey text, accent, red, page bg, row line
    "day": dict(fg="#222222", disc="#eef1f4", sub="#8a949e", accent="#168acd", red="#d14e4e", bg="#ffffff", line="#e3e6e9"),
    "night": dict(fg="#f5f5f5", disc="#2b3947", sub="#8b9aa6", accent="#6ab3f3", red="#ec6a6a", bg="#17212b", line="#26333f"),
}
K, OUT = 4, 2            # draw at K x, save at OUT x (1 unit = 1 dp-like px)
W, ROW, HEAD = 940, 96, 74
GX = {"stock": 290, "arrow": 380, "ours": 470}   # glyph centre columns, in units
FONTS = Path("/usr/share/fonts/noto")


def font(size, bold=False):
    return ImageFont.truetype(str(FONTS / ("NotoSans-Bold.ttf" if bold else "NotoSans-Regular.ttf")), int(size * K))


def tint(res, name, size, color):
    """White-on-black icon mask -> `size` units square image in `color`."""
    mask = Image.open(res / "icons" / "menu" / f"{name}@3x.png").convert("L").resize((int(size * K),) * 2, Image.LANCZOS)
    img = Image.new("RGBA", mask.size, color)
    img.putalpha(mask)
    return img


def logo(res, purple):
    img = Image.open(res / "art" / "logo_256.png").convert("RGBA").resize((46 * K,) * 2, Image.LANCZOS)
    if purple:  # the app ships its own purple icon: shift hue blue -> purple
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                r, g, b, a = px[x, y]
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                r, g, b = colorsys.hsv_to_rgb((h + 0.2) % 1, s, v)
                px[x, y] = (int(r * 255), int(g * 255), int(b * 255), a)
    return img


def glyph(im, res, cx, top, icon, mods, t):
    """One 56-unit glyph: disc + icon + at most two modifiers. cx = centre x, top = disc top (units)."""
    d, u = ImageDraw.Draw(im), lambda v: int(v * K)
    x0 = cx - 28
    d.ellipse([u(x0), u(top), u(x0 + 56), u(top + 56)], fill=t["disc"])
    if icon.startswith("logo"):
        im.alpha_composite(logo(res, icon.endswith("*")), (u(cx - 23), u(top + 5)))
    else:
        im.alpha_composite(tint(res, icon, 36, t["fg"]), (u(cx - 18), u(top + 10)))
    for m in mods:
        kind, _, arg = m.partition(":")
        if kind == "sub":   # small second icon bottom-right on a bg disc
            d.ellipse([u(x0 + 31), u(top + 31), u(x0 + 57), u(top + 57)], fill=t["bg"])
            im.alpha_composite(tint(res, arg, 20, t["fg"]), (u(x0 + 34), u(top + 34)))
        elif kind == "badge":
            w = 14 + 7 * len(arg)
            d.rounded_rectangle([u(x0 + 50 - w / 2 - 2), u(top - 4), u(x0 + 50 + w / 2 + 2), u(top + 16)], u(10), fill=t["bg"])
            d.rounded_rectangle([u(x0 + 50 - w / 2), u(top - 2), u(x0 + 50 + w / 2), u(top + 14)], u(8), fill=t["accent"])
            d.text((u(x0 + 50), u(top + 6)), arg, font=font(11, True), fill="#ffffff", anchor="mm")
        elif kind == "strike":
            d.line([u(x0 + 8), u(top + 8), u(x0 + 48), u(top + 48)], fill=t["bg"], width=u(7))
            d.line([u(x0 + 8), u(top + 8), u(x0 + 48), u(top + 48)], fill=t["red"], width=u(3.5))
        elif kind == "label":
            d.text((u(cx), u(top + 68)), arg, font=font(11), fill=t["sub"], anchor="mm")


def wrap(d, text, f, width):
    lines, cur = [], ""
    for w in text.split():
        if d.textlength(cur + " " + w, font=f) > width * K and cur:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    return lines + [cur]


def render(res, name, t):
    h = HEAD + ROW * len(CARDS) + 14
    im = Image.new("RGBA", (W * K, h * K), t["bg"])
    d, u = ImageDraw.Draw(im), lambda v: int(v * K)
    d.text((u(24), u(22)), "What's custom: glyph preview", font=font(18, True), fill=t["fg"], anchor="lm")
    d.text((u(24), u(46)), f"{name}  |  12 cards, icons from tdesktop 7.2.5", font=font(11), fill=t["sub"], anchor="lm")
    d.text((u(GX["stock"], ), u(HEAD - 16)), "Telegram", font=font(12, True), fill=t["sub"], anchor="mm")
    d.text((u(GX["ours"]), u(HEAD - 16)), "TG Custom", font=font(12, True), fill=t["accent"], anchor="mm")
    for i, (slug, title, on, icon, stock, ours, line) in enumerate(CARDS):
        y = HEAD + i * ROW
        d.line([u(24), u(y), u(W - 24), u(y)], fill=t["line"], width=u(1))
        d.text((u(24), u(y + 28)), f"{i + 1}. {title}", font=font(14, True), fill=t["fg"], anchor="lm")
        d.text((u(24), u(y + 50)), slug, font=font(9.5), fill=t["sub"], anchor="lm")
        d.text((u(24), u(y + 66)), "on: " + on, font=font(9.5), fill=t["sub"], anchor="lm")
        glyph(im, res, GX["stock"], y + 10, icon, stock, t)
        glyph(im, res, GX["ours"], y + 10, icon + ("*" if icon == "logo" else ""), ours, t)
        ax = GX["arrow"]
        d.line([u(ax - 14), u(y + 38), u(ax + 10), u(y + 38)], fill=t["sub"], width=u(2))
        d.polygon([(u(ax + 14), u(y + 38)), (u(ax + 6), u(y + 32)), (u(ax + 6), u(y + 44))], fill=t["sub"])
        f = font(12.5)
        for j, ln in enumerate(wrap(d, line, f, 330)):
            d.text((u(580), u(y + 30 + j * 19)), ln, font=f, fill=t["fg"], anchor="lm")
    return im.convert("RGB").resize((W * OUT, h * OUT), Image.LANCZOS)


if __name__ == "__main__":
    res, out = Path(sys.argv[1]), Path(sys.argv[2])
    for name, t in THEMES.items():
        render(res, name, t).save(out / f"2026-10-25-whats-custom-sheet-{name}.png")
