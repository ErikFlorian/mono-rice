#!/bin/sh
# install.sh - put the mono rice in place on this machine (Arch + niri).
#
#   ./install.sh          copy configs (existing files are backed up first)
#   ./install.sh --boot   also build + install the grey GRUB / Plymouth / tuigreet look (sudo)
#
# Paths inside the configs are written for /home/kxnvra; they are rewritten to $HOME.
set -e
cd "$(dirname "$0")"
REPO=$(pwd)
. ./manifest.sh

PKGS="niri quickshell awww matugen foot fastfetch hyprlock swayidle cliphist wl-clipboard
brightnessctl power-profiles-daemon networkmanager bluez pipewire wireplumber grim slurp
fuzzel python-pillow ttf-jetbrains-mono-nerd zsh"

echo "== packages"
missing=""
for p in $PKGS; do pacman -Qq "$p" >/dev/null 2>&1 || missing="$missing $p"; done
if [ -n "$missing" ]; then
    echo "missing:$missing"
    echo "install with: sudo pacman -S --needed$missing"
    printf "continue anyway? [y/N] "; read -r a; [ "$a" = y ] || exit 1
fi

echo "== configs"
BK="$HOME/.rice-backup-$(date +%Y%m%d-%H%M%S)"
for entry in $FILES; do
    repo="${entry%%:*}"; rel="${entry#*:}"; dst="$HOME/$rel"
    case "$repo" in system/*) dst="$HOME/.local/share/$(basename "$rel")";; esac
    [ -e "$repo" ] || continue
    if [ -e "$dst" ]; then mkdir -p "$BK/$(dirname "$rel")"; cp -a "$dst" "$BK/$rel"; rm -rf "$dst"; fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$repo" "$dst"
    # /home/kxnvra -> this user's home, in text files only
    grep -rlI "/home/kxnvra" "$dst" 2>/dev/null | while read -r f; do sed -i "s#/home/kxnvra#$HOME#g" "$f"; done
done
[ -d "$BK" ] && echo "old files backed up to $BK"

# Zen: point the matugen output at this machine's profile
zen=$(ls -d "$HOME"/.config/zen/*"Default (release)" 2>/dev/null | head -1)
if [ -n "$zen" ]; then
    sed -i "s#$HOME/.config/zen/[^/']*/chrome#$zen/chrome#g" "$HOME/.config/matugen/rice.toml"
    mkdir -p "$zen/chrome"
    echo '@import "rice-userChrome.css";' > "$zen/chrome/userChrome.css"
    echo '@import "rice-userContent.css";' > "$zen/chrome/userContent.css"
    echo "zen profile: $zen (enable toolkit.legacyUserProfileCustomizations.stylesheets in about:config)"
else
    sed -i '/^\[templates\.zen_/,/^$/d' "$HOME/.config/matugen/rice.toml"
fi

# prompt: powerlevel10k with the grey config
if [ -f "$HOME/.zshrc" ] && ! grep -q p10k-rice "$HOME/.zshrc"; then
    printf '\n# mono rice prompt\n[[ ! -f ~/.p10k-rice.zsh ]] || source ~/.p10k-rice.zsh\n' >> "$HOME/.zshrc"
    echo "prompt: added ~/.p10k-rice.zsh to ~/.zshrc (needs powerlevel10k)"
fi

echo "== services"
systemctl --user daemon-reload
systemctl --user mask swaync.service >/dev/null 2>&1 || true   # quickshell is the notification daemon
systemctl --user enable quickshell.service

echo "== colors + wallpaper"
mkdir -p "$HOME/.local/state/rice"
"$HOME/.config/quickshell/scripts/setwall.sh" "$HOME/Wallpapers/ascii-hands.png" mono || echo "(run setwall.sh again inside niri)"

if [ "$1" = "--boot" ]; then
    echo "== boot look (GRUB, Plymouth, tuigreet)"
    for d in grub-arch-mono plymouth-arch-mono tuigreet-arch-mono; do
        (cd "$HOME/.local/share/$d" && python3 -I gen.py out >/dev/null)
    done
    sudo sh "$HOME/.local/share/rice-sys/install-boot-mono.sh"
fi

echo
echo "done. log out and back into niri (or: systemctl --user start quickshell)."
echo "keys: Mod+Space launcher, Mod+A control panel, Mod+W wallpapers, Mod+C clipboard, Mod+Tab windows, Mod+X session"
