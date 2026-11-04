#!/usr/bin/env python3
"""fetchlogo.py [COLS] - small ASCII version of the Creation of Adam hands for fastfetch.
Writes ~/.config/fastfetch/hands.txt (plain text, fastfetch colors it)."""
import os, sys
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

HERE = os.path.dirname(os.path.abspath(__file__))
COLS = int(sys.argv[1]) if len(sys.argv) > 1 else 56
RAMP = " .:-=+*o#%@"
BOX = (322, 196, 592, 292)   # just the two hands (1200px-wide preview coordinates)

src = Image.open(os.path.join(HERE, "creation-of-adam.jpg")).convert("RGB")
S = src.width / 1200
crop = src.crop(tuple(int(v * S) for v in BOX))
rows = round(COLS * (BOX[3] - BOX[1]) / (BOX[2] - BOX[0]) * 0.5)
small = crop.resize((COLS, rows), Image.LANCZOS).filter(ImageFilter.SMOOTH)

def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)

def ink(r, g, b):
    l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    skin = max(smooth(44, 62, r - b), smooth(0.62, 0.45, l))
    skin *= 1 - 0.85 * smooth(55, 85, r - g)
    if skin < 0.2:
        return 0.0
    return skin * (0.25 + 0.75 * smooth(0.18, 0.80, l))

px = small.load()
lines = ["".join(RAMP[int(ink(*px[x, y]) * (len(RAMP) - 1))] for x in range(COLS)).rstrip() for y in range(rows)]
while lines and not lines[0].strip(): lines.pop(0)
while lines and not lines[-1].strip(): lines.pop()
out = os.path.expanduser("~/.config/fastfetch/hands.txt")
open(out, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
