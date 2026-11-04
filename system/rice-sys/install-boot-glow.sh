#!/bin/sh
# Back to the blue "arch-glow" boot look. Run with sudo.
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
B=.bak-2026-11-04
sed -i 's#^GRUB_THEME=.*#GRUB_THEME="/boot/grub/themes/arch-glow/theme.txt"#' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
for f in config.toml vtrgb; do [ -e /etc/tuigreet/$f$B ] && cp /etc/tuigreet/$f$B /etc/tuigreet/$f; done
plymouth-set-default-theme arch-glow
mkinitcpio -P
