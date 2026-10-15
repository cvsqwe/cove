<div align="center">

<img src="data/cove.svg" width="96" alt="Cove">

# cove

**A whole ecosystem on Hyprland:** shell, editor, terminal and browser in one style.
Everything is configured with the mouse — no config editing required.

[Русский](README.md) · **English**

</div>

---

## What's inside

**A Quickshell-based shell**
- **Bar** — 8 styles (Notch, Drops, Capsules, Glass, Tiles…) plus per-module manual setup.
- **Dynamic island** — clock, player with a spectrum, notifications, volume, screenshot preview;
  expands on hover with quick actions.
- **Launcher** — apps, calculator `=`, files `/`, commands `>`, web searches `!yt cats`,
  windows `@`, clipboard `:`. Fuzzy search, favorites, 5 styles.
- **Control center** — Wi-Fi, Bluetooth, audio, night light, Do Not Disturb, game mode.
- **Desktop widgets** — 16 of them (clock, weather, player, spectrum, tasks, calendar…)
  with an editor right on the desktop.
- **Wallpapers** — day/night schedule, one per workspace, slideshow. The whole system's colors
  come from the wallpaper (or from the cover of the playing track).
- **Screenshots and screen recording** with an editor, color picker, clipboard history, notes,
  focus timer, lock screen, workspace overview.
- **Settings** — 17 sections: hotkeys with shortcut recording, window rules, style profiles,
  input, autostart, dotfiles backup to git.
- Russian and English interface.

**Cove Code** — a terminal IDE powered by Neovim that works like a regular editor:
mouse, tabs, file tree, menus, command palette, LSP, Ctrl+C/Ctrl+V. Run `cove`.

**Firefox in the Cove style** — colors follow the theme live, 5 layouts
(floating, single row, island, vertical tabs, classic), and a custom start page.

**Terminal** — kitty + fish + starship, colors from the wallpaper, fastfetch with the Cove mark.

## Install

Requires **Arch Linux** (or a derivative). All packages come from the official repos — no AUR needed.

```sh
git clone https://github.com/cvsqwe/cove ~/cove
cd ~/cove
./install.sh
```

The installer asks about the optional parts: wallpaper pack (~700 MB), cursors, Firefox setup,
login screen, fish as the default shell. Then log into a **Hyprland** session.

Individual steps can be run later: `./install.sh firefox`, `./install.sh wallpapers`,
`./install.sh cursors`, `./install.sh greeter`. All steps: `./install.sh --help`.

### How it works

Configs are installed as **symlinks** into your clone (see `links.txt`).
Anything that was in their place is moved to `~/.local/state/cove/backup-<date>/`.

- **Update:** `cd ~/cove && git pull`
- **Remove:** `./uninstall.sh` — removes the symlinks and restores your old files.
- **Your settings** live in `config/quickshell/settings.json` and are not tracked by git.
- **Monitors** (refresh rate, layout) go in `~/.config/hypr/monitors.lua`, also local.

## Hotkeys

| Keys | Action |
|---|---|
| `Super + Space` | launcher |
| `Super + ,` | settings |
| `Super + /` | cheatsheet of all hotkeys |
| `Super + Q` | terminal |
| `Super + Esc` | power menu |

Every shortcut can be changed in **Settings → Hotkeys**.

## Credits

[Hyprland](https://hypr.land) · [Quickshell](https://quickshell.org) · [Neovim](https://neovim.io) ·
[Pywalfox](https://github.com/Frewacom/pywalfox) · [Material Symbols](https://fonts.google.com/icons)

Wallpapers are downloaded from [dharmx/walls](https://github.com/dharmx/walls),
[D3Ext/aesthetic-wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) and
[orangci/walls-catppuccin-mocha](https://github.com/orangci/walls-catppuccin-mocha) — all rights belong to their authors.
Cursors: [Bibata](https://github.com/ful1e5/Bibata_Cursor), [Catppuccin](https://github.com/catppuccin/cursors),
[Google](https://github.com/ful1e5/Google_Cursor), [macOS](https://github.com/ful1e5/apple_cursor),
[phinger](https://github.com/phisch/phinger-cursors).

## License

[GPL-3.0](LICENSE) © cvsqwe
