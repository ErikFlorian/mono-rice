#!/usr/bin/env python3
"""ASCII wallpaper: the hands from Michelangelo's Creation of Adam.

python3 gen.py [out.png] [--w 1920 --h 1080 --cell 10]
Skin/robe pixels become characters (density = shading), the plaster background
becomes almost nothing, so the hands float on black.
"""
import argparse, colorsys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "creation-of-adam.jpg")
FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Regular.ttf"
RAMP = " .`':-,;~=+*!ic7?vxzoYJ0UOX#%@"  # light -> heavy

ap = argparse.ArgumentParser()
ap.add_argument("out", nargs="?", default=os.path.expanduser("~/Wallpapers/ascii-hands.png"))
ap.add_argument("--w", type=int, default=1920)
ap.add_argument("--h", type=int, default=1080)
ap.add_argument("--cell", type=int, default=10, help="font size in px")
ap.add_argument("--fg", default="#d8d8d8")
ap.add_argument("--bg", default="#0a0a0a")
a = ap.parse_args()

src = Image.open(SRC).convert("RGB")
S = src.width / 1200  # crop box was picked on a 1200px-wide preview
BOX = (300, 178, 640, 312)  # the two hands
crop = src.crop(tuple(int(v * S) for v in BOX))

font = ImageFont.truetype(FONT, a.cell)
cw = font.getbbox("M")[2]
ch = int(a.cell * 1.25)
cols, rows = a.w // cw, a.h // ch

# The art sits a bit lower than centre (room for the bar) and leaves a margin.
art_cols = int(cols * 0.96)
art_rows = int(art_cols * (BOX[3] - BOX[1]) / (BOX[2] - BOX[0]) * cw / ch)
small = crop.resize((art_cols, art_rows), Image.LANCZOS).filter(ImageFilter.SMOOTH)


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def ink(r, g, b):
    # plaster: r-b ~30-38, light; skin: r-b 50-90 or dark shadows
    l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    skin = max(smooth(44, 62, r - b), smooth(0.62, 0.45, l))
    skin *= 1 - 0.85 * smooth(55, 85, r - g)  # God's red cloak: fade out
    if skin < 0.15:
        return 0.0
    # positive image: lit skin = dense chars, deep shadow = sparse
    shade = 0.10 + 0.90 * smooth(0.18, 0.80, l)
    return skin * shade


img = Image.new("RGB", (a.w, a.h), a.bg)
d = ImageDraw.Draw(img)
ox = (cols - art_cols) // 2
oy = (rows - art_rows) // 2 + 1
px = small.load()
for y in range(art_rows):
    line = []
    for x in range(art_cols):
        v = ink(*px[x, y])
        line.append(RAMP[int(v * (len(RAMP) - 1))])
    d.text(((ox) * cw, (oy + y) * ch), "".join(line), font=font, fill=a.fg)

# tiny caption, bottom right
cap = "// creatio adami — michelangelo, c. 1512"
d.text((a.w - font.getlength(cap) - 3 * cw, a.h - 2 * ch), cap, font=font, fill="#5a5a5a")

os.makedirs(os.path.dirname(a.out), exist_ok=True)
img.save(a.out)
print(a.out, f"{cols}x{rows} cells")
