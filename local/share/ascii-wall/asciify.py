#!/usr/bin/env python3
"""asciify.py IMAGE [OUT] - turn any picture into an ASCII wallpaper (light glyphs on black).

Used by the wallpaper picker (key A). Default OUT: ~/Wallpapers/ascii-<name>.png
Brightness picks the glyph, edges are boosted so outlines survive, and the
background (the most common tone) is pushed towards empty space.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps, ImageStat

FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Regular.ttf"
RAMP = " .`':-,;~=+*!ic7?vxzoYJ0UOX#%@"
W, H, CELL = 1920, 1080, 10
FG, BG = "#d8d8d8", "#0a0a0a"

src = sys.argv[1]
name = os.path.splitext(os.path.basename(src))[0]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser(f"~/Wallpapers/ascii-{name}.png")

font = ImageFont.truetype(FONT, CELL)
cw = font.getbbox("M")[2]
ch = int(CELL * 1.25)
cols, rows = W // cw, H // ch

# cover the screen like a wallpaper, then sample one pixel per glyph cell
img = ImageOps.fit(Image.open(src).convert("RGB"), (W, H), Image.LANCZOS)
gray = ImageOps.autocontrast(img.convert("L"), cutoff=1)
small = gray.resize((cols, rows), Image.LANCZOS)
edges = gray.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(3)).resize((cols, rows), Image.LANCZOS)

# the dominant tone is "background": the further a cell is from it, the more ink
hist = small.histogram()
bg_level = max(range(256), key=lambda i: sum(hist[max(0, i - 8):i + 9]))
spread = max(40, ImageStat.Stat(small).stddev[0] * 1.6)
# bright photos (sky, fog): backdrop = the light tones, ink = what is darker
light_bg = ImageStat.Stat(small).mean[0] > 115
if light_bg:
    vals = sorted(small.get_flattened_data())
    bg_level = vals[int(len(vals) * 0.8)]

canvas = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(canvas)
lp, ep = small.load(), edges.load()
for y in range(rows):
    line = []
    for x in range(cols):
        l = lp[x, y] / 255
        e = ep[x, y] / 255
        if light_bg:
            # bright/foggy backdrop (sky...): only what is darker than it gets ink
            sep = min(1.0, max(0, bg_level - lp[x, y]) / spread)
            v = sep ** 1.6 + 0.5 * e ** 1.3
            v = 0.0 if v < 0.22 else v
        else:
            # dark backdrop: whatever stands out from it, brighter = denser
            sep = min(1.0, abs(lp[x, y] - bg_level) / spread)
            v = sep ** 1.4 * (0.45 + 0.55 * l) + 0.7 * e ** 1.2
        v = 0.0 if v < 0.12 else min(1.0, v)   # background stays empty
        line.append(RAMP[int(v * (len(RAMP) - 1))])
    d.text((0, y * ch), "".join(line), font=font, fill=FG)

cap = f"// {name.lower()}"
d.text((W - font.getlength(cap) - 3 * cw, H - 2 * ch), cap, font=font, fill="#5a5a5a")
canvas.save(out)
print(out)
