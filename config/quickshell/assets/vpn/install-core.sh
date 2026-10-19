#!/bin/sh
# Ядро Mihomo для Cove VPN — из AUR (пакет mihomo-bin). Запускается в терминале из Настройки → VPN.
h=$(command -v yay || command -v paru || true)
if command -v mihomo >/dev/null; then
    echo "Ядро уже стоит: $(command -v mihomo)"
elif [ -n "$h" ]; then
    "$h" -S --needed mihomo-bin
else
    echo "Нужен помощник AUR: yay или paru (https://github.com/Jguer/yay)."
fi
echo
printf 'Enter — закрыть '
read -r _
