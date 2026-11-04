#!/usr/bin/env python3
"""fetchcross.py [ROWS] - ASCII cross with a soft glow for fastfetch.
Writes ~/.config/fastfetch/cross.txt. Solid core, shading from above,
faint halo around it (same glyph ramp as the wallpapers)."""
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROWS = int(sys.argv[1]) if len(sys.argv) > 1 else 17
COLS = ROWS * 2 - 1                       # glyph cells are about 1:2
RAMP = " .:-=+*o#%@"
SS = 40                                   # supersampling per cell

W, H = COLS * SS // 2, ROWS * SS          # square pixels; columns are half as wide
img = Image.new("L", (W, H), 0)
d = ImageDraw.Draw(img)
bw = W * 0.13                             # beam width
cx = W / 2
d.rectangle([cx - bw / 2, H * 0.06, cx + bw / 2, H * 0.94], fill=255)          # upright
arm_y = H * 0.30
d.rectangle([W * 0.18, arm_y - bw / 2, W * 0.82, arm_y + bw / 2], fill=255)   # cross beam

core = img
glow = core.filter(ImageFilter.GaussianBlur(W * 0.05))
# light from above: vertical gradient over the core
grad = Image.linear_gradient("L").resize((W, H))   # top bright, fading down
lit = ImageChops.multiply(core, Image.eval(grad, lambda v: 255 - int(v * 0.6)))
val = ImageChops.lighter(lit, Image.eval(glow, lambda v: int(v * 0.3)))

small = val.resize((COLS, ROWS), Image.LANCZOS)
lines = []
for y in range(ROWS):
    row = ""
    for x in range(COLS):
        v = small.getpixel((x, y)) / 255
        row += RAMP[min(len(RAMP) - 1, int(v * (len(RAMP) - 1) + 0.25))]
    lines.append(row.rstrip())
out = os.path.expanduser("~/.config/fastfetch/cross.txt")
open(out, "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
