#!/bin/sh
# ipc.sh <target> <fallback command...>
# Toggle a Quickshell panel in the qs running on THIS Wayland display;
# if there is none (e.g. Noctalia session), run the fallback instead.
target="$1"; shift
for pid in $(pgrep -x qs; pgrep -x quickshell); do
    if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -qx "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"; then
        exec qs ipc --pid "$pid" call "$target" toggle
    fi
done
[ $# -gt 0 ] && exec "$@"
