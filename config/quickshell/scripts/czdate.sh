#!/bin/sh
# "středa 4. listopadu" without needing the cs_CZ locale (used by hyprlock).
set -- $(date '+%u %-d %-m')
d=$(echo "pondělí úterý středa čtvrtek pátek sobota neděle" | cut -d' ' -f"$1")
m=$(echo "ledna února března dubna května června července srpna září října listopadu prosince" | cut -d' ' -f"$3")
printf '%s %s. %s\n' "$d" "$2" "$m"
