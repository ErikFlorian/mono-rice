#!/usr/bin/env python3
"""Generate the 'arch-mono' Plymouth theme.

Black screen, the Arch logo draws itself as a glowing line, a minimal passphrase
field below it, and after unlocking the logo fills with liquid as the boot progresses.

usage: gen.py OUT_DIR [--test]
"""
import math, re, subprocess, sys, tempfile, pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

HERE = pathlib.Path(__file__).resolve().parent
OUT = pathlib.Path(sys.argv[1])
TEST = "--test" in sys.argv
THEME_DIR = "/usr/share/plymouth/themes/arch-mono"
OUT.mkdir(parents=True, exist_ok=True)

LOGO_SVG = "/usr/share/pixmaps/archlinux-logo.svg"
ARCH_BLUE = (200, 200, 200)
LINE_COLOR = "#e8e8e8"
LOGO_PX = 300          # logo height on a 1080p screen
PAD, GLOW_PAD = 14, 46  # canvas padding in px around the logo
DRAW_N, SHINE_N = 54, 30
AMP, WAVELEN, MARGIN = 7, 90, 10
DOT, MAX_DOTS = 12, 24
LABEL_FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Light.ttf"

# ------------------------------------------------------------ logo path ----
svg = pathlib.Path(LOGO_SVG).read_text()
D_ATTR = re.search(r'<path d="([^"]+)" fill-rule', svg).group(1)  # the logo, not the "TM"


def flatten(d, steps=48):
    """Relative m/c/l/z path -> list of points (only what the Arch logo uses)."""
    toks = re.findall(r"[mclzMCLZ]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?", d)
    pts, i, cmd = [], 0, None
    cx = cy = sx = sy = 0.0
    while i < len(toks):
        t = toks[i]
        if t.isalpha():
            cmd = t
            i += 1
            if cmd in "zZ":
                pts.append((sx, sy))
                cx, cy = sx, sy
            continue
        n = lambda k: float(toks[i + k])
        if cmd == "m":
            cx, cy = cx + n(0), cy + n(1)
            sx, sy = cx, cy
            pts.append((cx, cy))
            i += 2
            cmd = "l"
        elif cmd == "l":
            cx, cy = cx + n(0), cy + n(1)
            pts.append((cx, cy))
            i += 2
        elif cmd == "c":
            p0 = (cx, cy)
            p1 = (cx + n(0), cy + n(1))
            p2 = (cx + n(2), cy + n(3))
            p3 = (cx + n(4), cy + n(5))
            for s in range(1, steps + 1):
                u = s / steps
                a, b, c, e = (1 - u) ** 3, 3 * (1 - u) ** 2 * u, 3 * (1 - u) * u * u, u ** 3
                pts.append((a * p0[0] + b * p1[0] + c * p2[0] + e * p3[0],
                            a * p0[1] + b * p1[1] + c * p2[1] + e * p3[1]))
            cx, cy = p3
            i += 6
        else:
            raise ValueError(f"unsupported path command {cmd}")
    return pts


PTS = flatten(D_ATTR)
xs, ys = [p[0] for p in PTS], [p[1] for p in PTS]
BX, BY, BW, BH = min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)
K = LOGO_PX / BH  # svg units -> px
SEG = [math.dist(PTS[k], PTS[k + 1]) for k in range(len(PTS) - 1)]
LENGTH = sum(SEG)


def point_at(dist):
    for k, s in enumerate(SEG):
        if dist <= s:
            f = dist / s if s else 0
            return (PTS[k][0] + (PTS[k + 1][0] - PTS[k][0]) * f,
                    PTS[k][1] + (PTS[k + 1][1] - PTS[k][1]) * f)
        dist -= s
    return PTS[-1]


def render(pad_px, body):
    """Render an SVG <path> snippet on a canvas = logo bbox + pad_px, returns RGBA."""
    pad = pad_px / K
    w, h = round((BW + 2 * pad) * K), round((BH + 2 * pad) * K)
    doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
           f'viewBox="{BX - pad} {BY - pad} {BW + 2 * pad} {BH + 2 * pad}">{body}</svg>')
    with tempfile.TemporaryDirectory() as td:
        src, dst = pathlib.Path(td, "a.svg"), pathlib.Path(td, "a.png")
        src.write_text(doc)
        subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), "-o", dst, src], check=True)
        return Image.open(dst).convert("RGBA")


def stroke(width_px, color, extra=""):
    return (f'<path d="{D_ATTR}" fill="none" stroke="{color}" stroke-width="{width_px / K}" '
            f'stroke-linejoin="round" stroke-linecap="round" {extra}/>')


def to_canvas(px, py, pad_px):
    return ((px - BX) * K + pad_px, (py - BY) * K + pad_px)


def save(img, name):
    img.save(OUT / name, optimize=True)


def glow_of(img, radius, color, gain):
    a = img.getchannel("A").filter(ImageFilter.GaussianBlur(radius))
    a = a.point(lambda v: min(255, int(v * gain)))
    g = Image.new("RGBA", img.size, color + (0,))
    g.putalpha(a)
    return g


data = []

# outline + the self-drawing intro (with a spark at the pen tip)
outline = render(PAD, stroke(2.6, LINE_COLOR))
save(outline, "outline.png")
for f in range(DRAW_N):
    t = f / (DRAW_N - 1)
    e = t * t * (3 - 2 * t)  # smoothstep
    done = LENGTH * e
    img = render(PAD, stroke(2.6, LINE_COLOR,
                             f'stroke-dasharray="{done:.3f} {LENGTH + 10:.3f}"'))
    if 0 < e < 1:
        x, y = to_canvas(*point_at(done), PAD)
        spark = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(spark)
        d.ellipse((x - 14, y - 14, x + 14, y + 14), fill=ARCH_BLUE + (255,))
        spark = spark.filter(ImageFilter.GaussianBlur(7))
        d = ImageDraw.Draw(spark)
        d.ellipse((x - 3.5, y - 3.5, x + 3.5, y + 3.5), fill=(255, 255, 255, 255))
        img = Image.alpha_composite(img, spark)
    save(img, f"draw-{f:02d}.png")
    data.append(f'draw_file[{f}] = "draw-{f:02d}.png";')


# glow around the line, on a bigger canvas centred on the same point
glow_src = render(GLOW_PAD, stroke(5, "#ffffff"))
save(glow_of(glow_src, 12, ARCH_BLUE, 2.2), "glow.png")

# liquid fill: vertical gradient clipped to the logo
mask = render(PAD, f'<path d="{D_ATTR}" fill="#ffffff" fill-rule="evenodd"/>').getchannel("A")
grad = Image.new("RGBA", mask.size)
top, bottom = (92, 200, 255), (10, 84, 140)
for y in range(mask.size[1]):
    u = y / (mask.size[1] - 1)
    grad.paste(tuple(round(top[k] + (bottom[k] - top[k]) * u) for k in range(3)) + (255,),
               (0, y, mask.size[0], y + 1))
grad.putalpha(mask)
save(grad, "fill.png")

# bloom once the logo is full
fill_big = render(GLOW_PAD, f'<path d="{D_ATTR}" fill="#ffffff" fill-rule="evenodd"/>')
save(glow_of(fill_big, 22, ARCH_BLUE, 1.1), "bloom.png")

# light sweeping through the glow around the outline (glow-sized canvas)
W0, H0 = outline.size
ga = glow_src.getchannel("A").filter(ImageFilter.GaussianBlur(5)).point(lambda v: min(255, v * 3))
ga = ImageChops.lighter(ga, glow_src.getchannel("A"))
GW0, GH0 = ga.size
for f in range(SHINE_N):
    band = Image.new("L", (GW0, GH0), 0)
    d = ImageDraw.Draw(band)
    cxb = -160 + (GW0 + 320) * f / (SHINE_N - 1)
    for k in range(-55, 56):
        v = int(255 * (1 - abs(k) / 55) ** 2)
        x = cxb + k
        d.line((x - GH0 * 0.45, GH0, x + GH0 * 0.45, 0), fill=v, width=1)
    a = ImageChops.multiply(band, ga)
    img = Image.new("RGBA", (GW0, GH0), (205, 238, 255, 0))
    img.putalpha(a)
    save(img, f"shine-{f:02d}.png")
    data.append(f'shine_file[{f}] = "shine-{f:02d}.png";')

# black cover with a wavy bottom edge (scrolls sideways = the liquid surface)
CW, CH = W0 + 2 * MARGIN + WAVELEN, H0 + 2 * AMP + 20
SS = 4
cov = Image.new("L", (CW * SS, CH * SS), 0)
d = ImageDraw.Draw(cov)
poly = [(0, 0), (CW * SS, 0)]
for x in range(CW * SS, -1, -1):
    yy = (CH - AMP - AMP * math.sin(2 * math.pi * (x / SS) / WAVELEN)) * SS
    poly.append((x, yy))
d.polygon(poly, fill=255)
cov = cov.resize((CW, CH), Image.LANCZOS)
cover = Image.new("RGBA", (CW, CH), (0, 0, 0, 255))
cover.putalpha(cov)
save(cover, "cover.png")


# passphrase field
def dot(color):
    im = Image.new("RGBA", (DOT * 4, DOT * 4), (0, 0, 0, 0))
    ImageDraw.Draw(im).ellipse((2, 2, DOT * 4 - 3, DOT * 4 - 3), fill=color)
    return im.resize((DOT, DOT), Image.LANCZOS)


save(dot((235, 245, 252, 255)), "dot.png")
save(dot((255, 95, 95, 255)), "dot-red.png")
for name, rgb in (("px-white", (238, 238, 238)), ("px-red", (255, 95, 95)),
                  ("px-blue", ARCH_BLUE), ("px-black", (0, 0, 0))):
    save(Image.new("RGBA", (1, 1), rgb + (255,)), f"{name}.png")

font = ImageFont.truetype(LABEL_FONT, 17)


def label(text, color, spacing=5):
    w = sum(font.getlength(c) for c in text) + spacing * (len(text) - 1)
    asc, desc = font.getmetrics()
    im = Image.new("RGBA", (math.ceil(w) + 2, asc + desc + 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x = 0
    for c in text:
        d.text((x, 0), c, font=font, fill=color)
        x += font.getlength(c) + spacing
    return im


save(label("PASSPHRASE", (150, 166, 180, 255)), "label-pass.png")
save(label("TRY AGAIN", (255, 110, 110, 255)), "label-wrong.png")

# ---------------------------------------------------------------- script ----
GW, GH = glow_src.size
data += [
    f"DRAW_N = {DRAW_N}; SHINE_N = {SHINE_N};",
    f"LOGO_W = {W0}; LOGO_H = {H0}; GLOW_W = {GW}; GLOW_H = {GH};",
    f"FILL_TOP = {PAD}; FILL_H = {round(BH * K)};",
    f"COVER_W = {CW}; COVER_H = {CH}; AMP = {AMP}; WAVELEN = {WAVELEN}; MARGIN = {MARGIN};",
    f"DOT = {DOT}; MAX_DOTS = {MAX_DOTS};",
]
script = (HERE / "arch-mono.script.in").read_text().replace("@DATA@", "\n".join(data))
if TEST:
    script += (HERE / "test-timeline.script").read_text()
(OUT / "arch-mono.script").write_text(script)
(OUT / "arch-mono.plymouth").write_text(f"""[Plymouth Theme]
Name=Arch Mono
Description=Black screen, self-drawing Arch logo, minimal passphrase field, logo fills with the boot progress
ModuleName=script

[script]
ImageDir={THEME_DIR}
ScriptFile={THEME_DIR}/arch-mono.script
""")
print(f"ok: {len(list(OUT.iterdir()))} files, logo {W0}x{H0}, path length {LENGTH * K:.0f}px")
