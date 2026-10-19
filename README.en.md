<div align="center">

<img src="data/cove.svg" width="96" alt="Cove">

# cove

A desktop environment on Hyprland: a custom Quickshell shell, an editor, a terminal setup and a Firefox theme.
The colors of the whole system come from the wallpaper, and settings are changed in a settings window instead of config files.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=flat-square&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?style=flat-square&logo=hyprland&logoColor=black)](https://hypr.land)
[![Quickshell](https://img.shields.io/badge/Quickshell-41CD52?style=flat-square&logo=qt&logoColor=white)](https://quickshell.org)
[![GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-cba6f7?style=flat-square)](LICENSE)

[Русский](README.md) | **English**

<img src="docs/screens/desktop.webp" alt="Desktop" width="100%">

</div>

## Screenshots

The screenshots show the Russian interface. English can be selected in Settings.

| | |
|:---:|:---:|
| <img src="docs/screens/launcher.webp" alt="Launcher"> | <img src="docs/screens/control.webp" alt="Control center"> |
| Launcher | Control center |
| <img src="docs/screens/dashboard.webp" alt="Dashboard"> | <img src="docs/screens/settings.webp" alt="Settings"> |
| Dashboard | Settings |
| <img src="docs/screens/wallpaper.webp" alt="Wallpapers"> | <img src="docs/screens/lock.webp" alt="Lock screen"> |
| Wallpaper picker | Lock screen |
| <img src="docs/screens/code.webp" alt="Cove Code"> | <img src="docs/screens/fetch.webp" alt="Terminal"> |
| Cove Code | Terminal and fastfetch |
| <img src="docs/screens/cheatsheet.webp" alt="Cheatsheet"> | <img src="docs/screens/session.webp" alt="Power menu"> |
| Hotkey cheatsheet | Power menu |

## Features

### Shell

- **Bar.** 8 styles: Notch, Drops, Capsules, Glass, Islands, Tiles, Outline, Classic. Modules are toggled and rearranged with the mouse.
- **Dynamic island.** Clock, player with a spectrum, notifications, volume, screenshot preview. Expands on hover and shows buttons.
- **Launcher.** Apps, calculator, files, windows, clipboard, emoji, timers and an assistant. The mode is picked by the first character, see the list below.
- **Control center.** Wi-Fi, Bluetooth, audio, night light, Do Not Disturb, game mode.
- **Desktop widgets.** 19 of them: clock, weather, player, spectrum, tasks, calendar and more. The editor opens right on the desktop.
- **Wallpapers.** Day and night schedule, a separate wallpaper per workspace, slideshow, video wallpapers.
- **Tools.** Screenshots with an editor, screen recording, text and QR recognition from the screen, color picker, notes, focus timer, alarms, window overview.
- **Lock screen, login screen and boot splash** (Plymouth and Limine) in the same style. The lock and login screens show the current wallpaper.
- **Settings.** 19 sections: hotkeys with shortcut recording, window rules, style profiles, input, autostart, dotfiles backup to git.
- Russian and English interface.

### Colors from the wallpaper

The palette is computed from the current wallpaper or from the cover of the playing track. It is applied to the shell, kitty, fish, starship, Cove Code, Firefox, GTK and Qt, as well as Telegram, btop, mpv, yazi, Vesktop and Obsidian. Nothing needs a restart.

### Cove Code

A terminal editor built on Textual. It works like a regular editor, without modes: mouse, tabs, file tree, menus, find and replace, <kbd>Ctrl</kbd>+<kbd>C</kbd> and <kbd>Ctrl</kbd>+<kbd>V</kbd>. Highlighting for Python, C/C++, QML, Lua, TypeScript and other languages. Run it with `cove`. The old Neovim-based version is still available as `cove-nvim`.

### Firefox and the terminal

Firefox changes colors together with the theme. There are 5 layouts (floating, single row, island, vertical tabs, classic) and a custom start page.

Terminal: kitty, fish and starship. The `ff` command shows fastfetch with the Cove logo, and a short version is printed when a terminal opens. Terminal programs only use ANSI colors, so they follow the wallpaper too.

## Launcher

| Prefix | Mode | Example |
|:---:|---|---|
| | apps | `fire` |
| `=` | calculator, unit and currency conversion | `=2^10`, `=100 usd in eur` |
| `/` | files | `/report` |
| `>` | run a command in the terminal | `>htop` |
| `!` | site search | `!yt cats` |
| `?` | web search | `?weather` |
| `@` | open windows | `@telegram` |
| `:` | clipboard | `:` |
| `;` | emoji | `;fire` |
| `+` | timer | `+25m tea` |
| `<` | history | `<` |
| `#` | shell commands | `#wallpaper` |
| `*` | assistant | `*how to compress a video` |

## Install

Requires Arch Linux or an Arch-based distribution. All packages come from the official repositories, no AUR needed.

```sh
git clone https://github.com/cvsqwe/cove ~/cove
cd ~/cove
./install.sh
```

The installer asks about optional parts: the wallpaper pack (about 700 MB), cursors, Firefox setup, login screen, boot splash and fish as the default shell. After installing, log into a Hyprland session.

Individual steps can be run later, for example `./install.sh firefox` or `./install.sh greeter`. Full list: `./install.sh --help`.

### How the install works

Configs are installed as symlinks into your clone of the repository, the list is in `links.txt`. Files that were in their place are moved to `~/.local/state/cove/backup-<date>/`.

- Update: `cd ~/cove && git pull`.
- Uninstall: `./uninstall.sh` removes the symlinks and restores your old files.
- Your settings are stored in `config/quickshell/settings.json` and are not tracked by git.
- Monitors (refresh rate, layout) are configured in `~/.config/hypr/monitors.lua`, which is local as well.

## Hotkeys

| Keys | Action | Keys | Action |
|---|---|---|---|
| <kbd>Super</kbd> <kbd>Space</kbd> | launcher | <kbd>Super</kbd> <kbd>Q</kbd> | terminal |
| <kbd>Super</kbd> <kbd>,</kbd> | settings | <kbd>Super</kbd> <kbd>E</kbd> | files |
| <kbd>Super</kbd> <kbd>/</kbd> | cheatsheet | <kbd>Super</kbd> <kbd>B</kbd> | browser |
| <kbd>Super</kbd> <kbd>N</kbd> | control center | <kbd>Super</kbd> <kbd>C</kbd> | close window |
| <kbd>Super</kbd> <kbd>A</kbd> | dashboard | <kbd>Super</kbd> <kbd>Tab</kbd> | window overview |
| <kbd>Super</kbd> <kbd>W</kbd> | wallpapers | <kbd>Super</kbd> <kbd>Shift</kbd> <kbd>S</kbd> | area screenshot |
| <kbd>Super</kbd> <kbd>L</kbd> | lock | <kbd>Super</kbd> <kbd>Shift</kbd> <kbd>T</kbd> | text from screen |
| <kbd>Super</kbd> <kbd>Esc</kbd> | power menu | <kbd>Super</kbd> <kbd>Shift</kbd> <kbd>A</kbd> | assistant |

Any shortcut can be changed in the Hotkeys section of the settings.

## Credits

Built on [Hyprland](https://hypr.land), [Quickshell](https://quickshell.org), [Textual](https://textual.textualize.io), [Neovim](https://neovim.io), [Pywalfox](https://github.com/Frewacom/pywalfox) and [Material Symbols](https://fonts.google.com/icons).

Wallpapers are downloaded from [dharmx/walls](https://github.com/dharmx/walls), [D3Ext/aesthetic-wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) and [orangci/walls-catppuccin-mocha](https://github.com/orangci/walls-catppuccin-mocha), all rights belong to their authors. Cursors: [Bibata](https://github.com/ful1e5/Bibata_Cursor), [Catppuccin](https://github.com/catppuccin/cursors), [Google](https://github.com/ful1e5/Google_Cursor), [macOS](https://github.com/ful1e5/apple_cursor), [phinger](https://github.com/phisch/phinger-cursors).

## License

[GPL-3.0](LICENSE)
