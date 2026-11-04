#!/bin/sh
# setwall.sh [image] [mono|color]  - set wallpaper with awww and recolor everything via matugen.
# No args: re-apply the last wallpaper (used at login).
S="$HOME/.local/state/rice"; mkdir -p "$S"
img="${1:-$(cat "$S/wallpaper" 2>/dev/null)}"
mode="${2:-$(cat "$S/mode" 2>/dev/null || echo mono)}"
[ -f "$img" ] || img="$HOME/Wallpapers/ascii-hands.png"
printf '%s' "$img" > "$S/wallpaper"; printf '%s' "$mode" > "$S/mode"
pgrep -x awww-daemon >/dev/null || { setsid -f awww-daemon >/dev/null 2>&1; sleep 0.4; }
awww img "$img" --transition-type grow --transition-pos 0.5,0.5 --transition-duration 0.9 --transition-fps 60 &
if [ "$mode" = mono ]; then t=scheme-monochrome; else t=scheme-tonal-spot; fi
matugen -q -c "$HOME/.config/matugen/rice.toml" -m dark -t "$t" image "$img" --source-color-index 0
# files matugen can't template (yazi uses {} inline tables)
R="$HOME/.config/matugen/templates/rice"
python3 -I "$R/tools/render.py" "$R/yazi-flavor.toml" "$HOME/.config/yazi/flavors/noctalia.yazi/flavor.toml"
python3 -I "$R/tools/render.py" "$R/yazi-tmtheme.xml" "$HOME/.config/yazi/flavors/noctalia.yazi/tmtheme.xml"
# dimmed, screen-sized copy for the lockscreen
python3 -I -c '
import sys
from PIL import Image, ImageEnhance, ImageOps
im = ImageOps.fit(Image.open(sys.argv[1]).convert("RGB"), (1920, 1080))
ImageEnhance.Brightness(im).enhance(0.38).save(sys.argv[2], quality=92)
' "$img" "$S/lock.jpg" &
wait
