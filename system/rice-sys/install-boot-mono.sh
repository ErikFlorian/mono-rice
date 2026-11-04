#!/bin/sh
# Install the grey "arch-mono" GRUB, Plymouth and tuigreet themes (rice, 2026-11-04).
# Back to blue: sh ~/.local/share/rice-sys/install-boot-glow.sh
# Run with: sudo sh ~/.local/share/rice-sys/install-boot-mono.sh
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
S=/home/kxnvra/.local/share
B=.bak-2026-11-04

echo "== GRUB"
rm -rf /boot/grub/themes/arch-mono
install -d /boot/grub/themes/arch-mono
cp -r --no-preserve=ownership "$S/grub-arch-mono/out/." /boot/grub/themes/arch-mono/
[ -e /etc/default/grub$B ] || cp /etc/default/grub /etc/default/grub$B
sed -i 's#^GRUB_THEME=.*#GRUB_THEME="/boot/grub/themes/arch-mono/theme.txt"#' /etc/default/grub
grep -q '^GRUB_THEME=' /etc/default/grub || echo 'GRUB_THEME="/boot/grub/themes/arch-mono/theme.txt"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "== tuigreet"
for f in config.toml vtrgb; do
    [ -e /etc/tuigreet/$f$B ] || cp /etc/tuigreet/$f /etc/tuigreet/$f$B
    install -m 644 "$S/tuigreet-arch-mono/out/$f" /etc/tuigreet/$f
done

echo "== Plymouth (rebuilds the UKI, takes a moment)"
rm -rf /usr/share/plymouth/themes/arch-mono
install -d /usr/share/plymouth/themes/arch-mono
install -m 644 "$S/plymouth-arch-mono/out/"* /usr/share/plymouth/themes/arch-mono/
plymouth-set-default-theme arch-mono
mkinitcpio -P

echo "done - grey boot, GRUB and login from the next reboot"
