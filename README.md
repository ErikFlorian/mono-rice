# mono rice

Monochrome, terminal-flavoured desktop for **niri** on Arch: a hand-written
[Quickshell](https://quickshell.org) shell, colours taken from the wallpaper with
matugen, ASCII wallpapers, and a grey boot → login → lock chain.

![wallpaper](wallpapers/ascii-hands.png)

## What's in it

| | |
|---|---|
| **Bar** | workspaces with a sliding underline, focused window, clock (date on hover), vol / net / bat, tray (greyscale icons, own menus), caffeine + notification marks |
| **Launcher** `Mod+Space` | apps · `= 2^10` calculator · `> cmd` run · `>> cmd` run in foot · `: smile` emoji |
| **Control panel** `Mod+A` | vol / mic / brightness sliders, wifi, bluetooth, caffeine, do-not-disturb, live wallpaper, mono/colour theme, power profile, media player, wifi + bluetooth lists, notification history |
| **Other panels** | wallpapers `Mod+W` (`A` = turn picture into ASCII, `Tab` = mono/colour), clipboard `Mod+C`, windows `Mod+Tab`, session `Mod+X`, caffeine `Mod+I` |
| **Notifications / OSD** | Quickshell is the notification daemon; volume / brightness OSD as `[████░░░░]` |
| **Colours** | `setwall.sh` → awww + matugen → bar, niri borders, foot, GTK3/4, Thunar, btop, yazi, nvim, Vesktop, Zen, hyprlock |
| **ASCII** | `local/share/ascii-wall/`: `gen.py` (Creation of Adam hands), `asciify.py` (any picture), `fetchcross.py` (fastfetch logo) |
| **Lock / boot** | hyprlock (dimmed wallpaper, thin clock), grey GRUB, Plymouth and tuigreet (`system/`) |
| **Prompt** | grey powerlevel10k (`p10k-rice.zsh`), fastfetch with an ASCII cross |

## Layout

```
config/            -> ~/.config/...      quickshell, niri, matugen (+templates), foot, fastfetch, swayidle, systemd unit
local/             -> ~/.local/...       lock script, ASCII tools, emoji list, dbus overrides (keep swaync/dunst off)
p10k-rice.zsh      -> ~/.p10k-rice.zsh
wallpapers/        -> ~/Wallpapers
system/            -> ~/.local/share/... boot themes + root scripts (installed with --boot)
manifest.sh        list of everything above
```

Generated files (matugen output) are not in the repo; `setwall.sh` rebuilds them.

## Use

```sh
./install.sh            # configs, service, colours
./install.sh --boot     # + grey GRUB / Plymouth / tuigreet (sudo, rebuilds the initramfs)
./sync.sh               # copy the live configs back into the repo, then commit
```

Quickshell runs as `quickshell.service` (`systemctl --user restart quickshell`).
Back to the blue boot look: `sudo sh ~/.local/share/rice-sys/install-boot-glow.sh`.

`system/rice-sys/e1000e-reload` is a laptop-specific fix (Intel NIC not receiving after
resume) and is not installed by default.
