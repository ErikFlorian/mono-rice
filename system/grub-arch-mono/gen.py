#!/usr/bin/env python3
"""GRUB theme 'arch-mono' — matches the Plymouth theme and tuigreet of the same name.

Black screen, the Arch logo as a glowing outline at the same spot Plymouth draws it,
a minimal centred menu (selected entry = faint blue pill), the countdown as a thin
blue line (like the passphrase line) with a dim "booting in N" under it.

usage: gen.py OUT_DIR
"""
import re, subprocess, sys, tempfile, pathlib
from PIL import Image, ImageDraw, ImageFilter

OUT = pathlib.Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

SW, SH = 1920, 1080
ARCH_BLUE = (200, 200, 200)
LINE = "#e8e8e8"
LOGO_PX, LOGO_CY = 300, 420              # same size/position as the Plymouth theme
MENU_W, MENU_TOP, ITEM_H, ITEM_SP, ITEMS = 520, 630, 44, 8, 5
BAR_W, BAR_Y = 360, 928
FONT_DIR = "/usr/share/fonts/TTF"
RANGE = "0x20-0x7e,0xa0-0x17f,0x2022-0x2022,0x2190-0x2193,0x2500-0x259f,0x25b2-0x25bc"  # ASCII, Latin-1/Ext-A (čřž), •, arrows, box drawing (editor frame)


def save(img, name):
    img.save(OUT / name, optimize=True)


# ------------------------------------------------------------ background ----
svg = pathlib.Path("/usr/share/pixmaps/archlinux-logo.svg").read_text()
D = re.search(r'<path d="([^"]+)" fill-rule', svg).group(1)
BX, BY, BW, BH = 11.62, 12.07, 232.8, 238.4   # logo bbox in svg units
K = LOGO_PX / BH


def render_full(body):
    """Render svg snippet onto the full 1920x1080 frame, logo centred at (960, LOGO_CY)."""
    x0 = BX - (SW / 2 - BW * K / 2) / K
    y0 = BY - (LOGO_CY - BH * K / 2) / K
    doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SW}" height="{SH}" '
           f'viewBox="{x0} {y0} {SW / K} {SH / K}">{body}</svg>')
    with tempfile.TemporaryDirectory() as td:
        src, dst = pathlib.Path(td, "a.svg"), pathlib.Path(td, "a.png")
        src.write_text(doc)
        subprocess.run(["rsvg-convert", "-o", dst, src], check=True)
        return Image.open(dst).convert("RGBA")


def stroke(px, color):
    return (f'<path d="{D}" fill="none" stroke="{color}" stroke-width="{px / K}" '
            f'stroke-linejoin="round" stroke-linecap="round"/>')


bg = Image.new("RGBA", (SW, SH), (0, 0, 0, 255))
glow_src = render_full(stroke(5, "#ffffff")).getchannel("A").filter(ImageFilter.GaussianBlur(12))
glow = Image.new("RGBA", (SW, SH), ARCH_BLUE + (0,))
glow.putalpha(glow_src.point(lambda v: min(255, int(v * 2.2 * 0.5))))   # ~ Plymouth's resting glow
bg.alpha_composite(glow)
bg.alpha_composite(render_full(stroke(2.6, LINE)))
save(bg.convert("RGB"), "background.png")


# ------------------------------------------------------- 9-slice helpers ----
def slices(img, prefix, cap):
    """Cut img into GRUB 9-slice pieces with corner size cap (px)."""
    w, h = img.size
    xs = {"w": (0, cap), "c": (cap, cap + 1), "e": (w - cap, w)}
    ys = {"n": (0, cap), "": (cap, cap + 1), "s": (h - cap, h)}
    for yk, (y0, y1) in ys.items():
        for xk, (x0, x1) in xs.items():
            name = (yk + xk) if yk else xk
            if name == "nc":
                name = "n"
            if name == "sc":
                name = "s"
            save(img.crop((x0, y0, x1, y1)), f"{prefix}_{name}.png")


# selected entry: faint blue pill with a thin blue rim (horizontal 3-slice: w c e)
SS = 4
pill = Image.new("RGBA", (120 * SS, ITEM_H * SS), (0, 0, 0, 0))
dp = ImageDraw.Draw(pill)
dp.rounded_rectangle((SS, SS, 120 * SS - SS - 1, ITEM_H * SS - SS - 1), radius=12 * SS,
                     fill=ARCH_BLUE + (34,), outline=ARCH_BLUE + (200,), width=int(1.5 * SS))
pill = pill.resize((120, ITEM_H), Image.LANCZOS)
save(pill.crop((0, 0, 16, ITEM_H)), "select_w.png")
save(pill.crop((16, 0, 17, ITEM_H)), "select_c.png")
save(pill.crop((120 - 16, 0, 120, ITEM_H)), "select_e.png")

# countdown line: GRUB stretches the bar's centre piece over the whole component and
# won't go below ~24px, so the centre piece is a 24px strip with a 2px line in the middle.
BAR_PAD = 11


def bar_strip(color):
    im = Image.new("RGBA", (1, 2 * BAR_PAD + 2), (0, 0, 0, 0))
    im.putpixel((0, BAR_PAD), color)
    im.putpixel((0, BAR_PAD + 1), color)
    return im


save(bar_strip((42, 50, 58, 255)), "bar_c.png")
save(bar_strip(ARCH_BLUE + (255,)), "bar_hl_c.png")

# terminal / editor box: black with a dim blue frame
tb = Image.new("RGBA", (40, 40), (0, 0, 0, 235))
ImageDraw.Draw(tb).rectangle((0, 0, 39, 39), outline=ARCH_BLUE + (140,), width=1)
slices(tb, "term", 6)

# ----------------------------------------------------------------- fonts ----
fonts = {
    "ArchGlow Mono Regular 22": ("JetBrainsMonoNerdFont-Regular.ttf", 22, "item.pf2"),
    "ArchGlow Label Regular 16": ("JetBrainsMonoNerdFont-Light.ttf", 16, "label.pf2"),
    "ArchGlow Mono Regular 16": ("JetBrainsMonoNerdFont-Regular.ttf", 16, "term.pf2"),
}
for full, (ttf, size, out) in fonts.items():
    family = full.rsplit(" ", 2)[0]  # grub names a font "<family> <Regular|Bold> <size>"
    subprocess.run(["grub-mkfont", "-n", family, "-s", str(size), "-r", RANGE,
                    "-o", OUT / out, f"{FONT_DIR}/{ttf}"], check=True)


def pf2_name(path):
    data = path.read_bytes()
    i = data.index(b"NAME")
    n = int.from_bytes(data[i + 4:i + 8], "big")
    return data[i + 8:i + 8 + n].rstrip(b"\0").decode()


names = {out: pf2_name(OUT / out) for _, (_, _, out) in fonts.items()}
ITEM_FONT, LABEL_FONT, TERM_FONT = names["item.pf2"], names["label.pf2"], names["term.pf2"]

# ------------------------------------------------------------- theme.txt ----
menu_h = ITEMS * ITEM_H + (ITEMS - 1) * ITEM_SP
(OUT / "theme.txt").write_text(f'''# GRUB theme "arch-mono" (generated by ~/.local/share/grub-arch-mono/gen.py)
# Matches the Plymouth theme and tuigreet of the same name. Designed for 1920x1080.

title-text: ""
desktop-image: "background.png"
desktop-color: "#000000"
terminal-font: "{TERM_FONT}"
terminal-box: "term_*.png"
terminal-left: "10%"
terminal-top: "12%"
terminal-width: "80%"
terminal-height: "76%"
terminal-border: "0"

+ boot_menu {{
  left = {(SW - MENU_W) // 2}
  top = {MENU_TOP}
  width = {MENU_W}
  height = {menu_h}
  item_font = "{ITEM_FONT}"
  selected_item_font = "{ITEM_FONT}"
  item_color = "#8a8a8a"
  selected_item_color = "#f2f2f2"
  item_height = {ITEM_H}
  item_padding = 22
  item_spacing = {ITEM_SP}
  icon_width = 0
  icon_height = 0
  item_icon_space = 0
  selected_item_pixmap_style = "select_*.png"
  scrollbar = false
}}

# countdown: thin line like the Plymouth passphrase line, fills as time runs out
+ progress_bar {{
  id = "__timeout__"
  left = {(SW - BAR_W) // 2}
  top = {BAR_Y - BAR_PAD}
  width = {BAR_W}
  height = {2 * BAR_PAD + 2}
  bar_style = "bar_*.png"
  highlight_style = "bar_hl_*.png"
  text = ""
}}

+ label {{
  id = "__timeout__"
  left = 0
  top = {BAR_Y + 18}
  width = 100%
  align = "center"
  font = "{LABEL_FONT}"
  color = "#555555"
  text = "booting in %d"
}}
''')
print("ok:", sorted(p.name for p in OUT.iterdir()))
print("fonts:", names)
