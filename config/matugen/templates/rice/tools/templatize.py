#!/usr/bin/env python3
"""templatize.py SRC DST - turn a themed file into a matugen template.

Every #rrggbb(aa) in SRC is replaced by the matugen color whose current value
(monochrome scheme of the ASCII wallpaper) is closest, so the file follows
the wallpaper afterwards. Used once to convert the files Noctalia left behind.
"""
import json, os, re, subprocess, sys

PREFER = [  # tie-break order: plain surface/text roles first
    "background", "surface", "surface_container_lowest", "surface_container_low",
    "surface_container", "surface_container_high", "surface_container_highest",
    "outline_variant", "outline", "on_surface_variant", "on_surface",
    "primary", "on_primary", "primary_container", "on_primary_container",
    "secondary", "tertiary", "error", "on_error", "error_container", "on_error_container",
]
img = os.path.expanduser("~/Wallpapers/ascii-hands.png")
out = subprocess.run(["matugen", "image", img, "-m", "dark", "-t", "scheme-monochrome",
                      "--source-color-index", "0", "--json", "hex", "--dry-run"],
                     capture_output=True, text=True, check=True).stdout
colors = {k: v["color"] if "color" in v else v["default"]["color"] for k, v in json.loads(out)["colors"].items()}
names = sorted(colors, key=lambda n: PREFER.index(n) if n in PREFER else 99)

def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))
def dist(a, b):
    (r1, g1, b1), (r2, g2, b2) = a, b
    return 2 * (r1 - r2) ** 2 + 4 * (g1 - g2) ** 2 + 3 * (b1 - b2) ** 2

def repl(m):
    h, alpha = m.group(1)[:7], m.group(1)[7:]
    best = min(names, key=lambda n: dist(rgb(h), rgb(colors[n])))
    return "{{ colors.%s.default.hex }}%s" % (best, alpha)

src = open(sys.argv[1]).read()
res = re.sub(r"(#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)(?![0-9a-fA-F])", repl, src)
open(sys.argv[2], "w").write(res)
print(sys.argv[2], len(re.findall(r"\{\{ colors", res)), "colors")
