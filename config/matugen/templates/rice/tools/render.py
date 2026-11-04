#!/usr/bin/env python3
"""render.py TEMPLATE OUT - fill {{ colors.X.default.hex }} from ~/.local/state/rice/palette.json."""
import json, os, re, sys
pal = json.load(open(os.path.expanduser("~/.local/state/rice/palette.json")))
src = open(sys.argv[1]).read()
open(sys.argv[2], "w").write(re.sub(r"\{\{ colors\.(\w+)\.default\.hex \}\}", lambda m: pal[m.group(1)], src))
