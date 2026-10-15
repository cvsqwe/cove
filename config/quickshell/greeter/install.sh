#!/usr/bin/env bash
# Ставит экран входа на Quickshell вместо tuigreet.
# Откат: sudo cp /etc/greetd/config.toml.tuigreet /etc/greetd/config.toml
# (если вход сломался — Ctrl+Alt+F2, войти в консоль и выполнить команду выше).
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DST=/etc/greetd/qs-greeter
THEME="$HOME/.config/kitty/theme.conf"
STATE="$HOME/.local/state/quickshell/state.json"

pick() { grep -m1 "^$1 " "$THEME" 2>/dev/null | awk '{print $2}'; }
ACCENT=$(pick cursor);           ACCENT=${ACCENT:-#cba6f7}
BASE=$(pick background);         BASE=${BASE:-#1e1e2e}
TEXT=$(pick foreground);         TEXT=${TEXT:-#cdd6f4}
DIM=$(pick color15);             DIM=${DIM:-#a6adc8}
WALL=$(python3 -c "import json;print(json.load(open('$STATE'))['wallpaper'])" 2>/dev/null || echo "$SRC/../assets/wallpapers/cove-dark.png")

echo "==> Копирую гритер в $DST (акцент $ACCENT)"
sudo mkdir -p "$DST"
sed -e "s|@USER@|$USER|" -e "s|@ACCENT@|$ACCENT|" -e "s|@BASE@|$BASE|" -e "s|@TEXT@|$TEXT|" -e "s|@DIM@|$DIM|" \
    "$SRC/shell.qml" | sudo tee "$DST/shell.qml" >/dev/null
sudo install -m644 "$SRC/hyprland.lua" /etc/greetd/hyprland-greeter.lua
sudo install -m644 "$WALL" "$DST/wallpaper"
sudo chmod -R a+rX "$DST"

echo "==> Сохраняю текущий конфиг greetd в config.toml.tuigreet"
[ -f /etc/greetd/config.toml.tuigreet ] || sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.tuigreet

sudo tee /etc/greetd/config.toml >/dev/null <<'TOML'
[terminal]
vt = 1

[default_session]
command = "env XDG_CACHE_HOME=/tmp/greeter/cache XDG_STATE_HOME=/tmp/greeter/state XDG_DATA_HOME=/tmp/greeter/data start-hyprland -- -c /etc/greetd/hyprland-greeter.lua"
user = "greeter"
TOML

echo "==> Готово. Экран входа сменится после перезагрузки."
echo "    Откат: sudo cp /etc/greetd/config.toml.tuigreet /etc/greetd/config.toml"
