#!/usr/bin/env python3
"""Rotate the blue accents of tdesktop's default ("Classic") palette toward purple.

Rewrites Telegram/lib_ui/ui/colors.palette in place. Only saturated blues
move; greys, greens (outgoing bubbles), reds stay. Re-run on a fresh upstream
tree when the palette patch stops applying, then re-export the patch.

Usage: desktop/purple.py <tdesktop tree> [degrees]
"""
import colorsys
import re
import sys

SHIFT = float(sys.argv[2]) if len(sys.argv) > 2 else 60  # 202° (Telegram blue) -> 262°; below ~60 reads royal blue, not purple
HUE_BAND = (180, 235)   # what counts as "Telegram blue"
MIN_SAT = 0.2           # leave near-greys alone

path = sys.argv[1] + "/Telegram/lib_ui/ui/colors.palette"


def shift(match):
    hexpart = match.group(1)
    rgb, alpha = hexpart[:6], hexpart[6:]
    r, g, b = (int(rgb[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if s < MIN_SAT or not HUE_BAND[0] <= h * 360 <= HUE_BAND[1]:
        return match.group(0)
    r, g, b = colorsys.hls_to_rgb((h * 360 + SHIFT) / 360 % 1, l, s)
    return "#" + "".join(f"{round(c * 255):02x}" for c in (r, g, b)) + alpha


text = open(path).read()
out, n = re.subn(r"#([0-9a-fA-F]{8}|[0-9a-fA-F]{6})\b", shift, text)
open(path, "w").write(out)
changed = sum(a != b for a, b in zip(text.splitlines(), out.splitlines()))
print(f"{changed} palette lines shifted by {SHIFT:g}°")
