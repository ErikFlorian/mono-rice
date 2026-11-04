#!/usr/bin/env python3
"""fetchgod.py [COLS] - ASCII portrait of God from the Creation of Adam for fastfetch.
Writes ~/.config/fastfetch/god.txt. Grey hair/beard = dense glyphs, skin by its
shading, plaster / robe / red cloak = empty."""
import os, sys
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
COLS = int(sys.argv[1]) if len(sys.argv) > 1 else 40
RAMP = " .:-=+*o#%@"
BOX = (664, 60, 752, 176)   # God's head (1200px-wide preview coordinates)

src = Image.open(os.path.join(HERE, "creation-of-adam.jpg")).convert("RGB")
S = src.width / 1200
crop = src.crop(tuple(int(v * S) for v in BOX))
rows = round(COLS * (BOX[3] - BOX[1]) / (BOX[2] - BOX[0]) * 0.5)
small = crop.resize((COLS, rows), Image.LANCZOS).filter(ImageFilter.SMOOTH)

def ink(r, g, b):
    l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    if r - b < 14 and l > 0.32:            # grey-blue hair and beard
        return 0.35 + 0.65 * l
    if r - b > 42 and r - g < 70:          # skin, shaded
        return 0.12 + 0.55 * l
    return 0.0

px = small.load()
lines = ["".join(RAMP[min(len(RAMP) - 1, int(ink(*px[x, y]) * (len(RAMP) - 1)))] for x in range(COLS)).rstrip() for y in range(rows)]
while lines and not lines[0].strip(): lines.pop(0)
while lines and not lines[-1].strip(): lines.pop()
out = os.path.expanduser("~/.config/fastfetch/god.txt")
open(out, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
