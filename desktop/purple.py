#!/usr/bin/env python3
"""Rotate the blue of Telegram's logo toward purple, in every app icon PNG.

Run by desktop/build.sh on the patched tree (generated, so no binary patches to
rebase). Only saturated blue pixels move: the white plane and the transparent
edge stay. Needs python-pillow + python-numpy.

Usage: desktop/purple.py <tdesktop tree> [degrees]
Import: from purple import rotate  (android/ reuses it for launcher icons)
"""
import glob
import sys

import numpy as np
from PIL import Image

SHIFT = 60  # 202° (Telegram blue) -> 262°; below ~60 reads royal blue, not purple
HUE_BAND = (180, 235)   # degrees that count as "Telegram blue"
MIN_SAT = 0.2


def rotate(path, shift=SHIFT):
    img = Image.open(path).convert("RGBA")
    rgba = np.asarray(img).astype(np.float64) / 255
    rgb, alpha = rgba[..., :3], rgba[..., 3:]
    mx, mn = rgb.max(-1), rgb.min(-1)
    delta = mx - mn
    sat = np.where(mx > 0, delta / np.where(mx > 0, mx, 1), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    d = np.where(delta > 0, delta, 1)
    hue = np.select(
        [mx == r, mx == g],
        [((g - b) / d) % 6, (b - r) / d + 2],
        (r - g) / d + 4) * 60
    move = (delta > 0) & (sat >= MIN_SAT) & (hue >= HUE_BAND[0]) & (hue <= HUE_BAND[1])
    h = np.where(move, (hue + shift) % 360, hue) / 60
    c = delta
    x = c * (1 - np.abs(h % 2 - 1))
    z = np.zeros_like(c)
    i = np.floor(h).astype(int) % 6
    out = np.stack([
        np.choose(i, [c, x, z, z, x, c]),
        np.choose(i, [x, c, c, x, z, z]),
        np.choose(i, [z, z, x, c, c, x]),
    ], -1) + mn[..., None]
    out = np.where(move[..., None], out, rgb)
    result = np.concatenate([out, alpha], -1)
    Image.fromarray((result * 255).round().astype(np.uint8), "RGBA").save(path)
    return int(move.sum())


if __name__ == "__main__":
    shift = float(sys.argv[2]) if len(sys.argv) > 2 else SHIFT
    art = sys.argv[1] + "/Telegram/Resources/art/"
    files = sorted(glob.glob(art + "icon[0-9]*.png") + glob.glob(art + "logo_256*.png")
                   + glob.glob(art + "icon_round*.png"))
    for f in files:
        rotate(f, shift)
    print(f"{len(files)} icons rotated {shift:g}°")
