#!/usr/bin/env bash
# Откат Cove: убирает симлинки и возвращает файлы из последнего бэкапа установщика,
# по вопросу — экран входа, заставку загрузки, вид Firefox, оболочку и окружения Python.
# Пакеты, обои, курсоры, ваши настройки (settings.json) и сам репозиторий не трогает.
#   ./uninstall.sh       спросит про каждый пункт
#   ./uninstall.sh -y    всё, кроме системного (экран входа, загрузка): про них всё равно спросит
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
YES=0; [ "${1:-}" = -y ] && YES=1
last="$HOME/.local/state/cove/last-backup"
BACKUP=$( [ -f "$last" ] && cat "$last" || true )

ask() { # ask "вопрос" [system] — 0 на «да»; системное с -y всё равно спрашиваем
    local a
    if [ $YES = 1 ] && [ "${2:-}" != system ]; then return 0; fi
    read -r -p "$1 [y/N] " a || true
    [[ "$a" =~ ^[YyДд] ]]
}

# звуковые эффекты Cove (Настройки → Звук) — юниты systemd-run, без шелла их некому выключить
for u in cove-sound-out cove-sound-mic; do
    systemctl --user stop "$u" 2>/dev/null && echo "  остановил $u" || true
done

if ask "Убрать конфиги Cove из ~/.config (вернуть прежние из бэкапа)?"; then
    while read -r src dst; do
        [[ -z "$src" || "$src" == \#* ]] && continue
        t="$HOME/$dst"
        if [ -L "$t" ] && [ "$(readlink -f "$t")" = "$(readlink -f "$REPO/$src")" ]; then
            rm "$t"
            if [ -n "$BACKUP" ] && { [ -e "$BACKUP/$dst" ] || [ -L "$BACKUP/$dst" ]; }; then
                mv "$BACKUP/$dst" "$t"; echo "  вернул $dst"
            else
                echo "  убрал $dst"
            fi
        fi
    done < "$REPO/links.txt"
    # без шелла generated.lua с хоткеями Cove не нужен
    [ -f "$HOME/.config/hypr/generated.lua" ] && mv "$HOME/.config/hypr/generated.lua" "$HOME/.config/hypr/generated.lua.cove-off" && echo "  generated.lua → generated.lua.cove-off"
fi

if command -v firefox >/dev/null && ask "Вернуть обычный вид Firefox (убрать userChrome/userContent Cove)?"; then
    sh "$REPO/config/quickshell/assets/firefox-theme.sh" off
    echo "  готово; расширение Pywalfox удалите в about:addons, если не нужно"
fi

if [ -f /etc/greetd/config.toml.tuigreet ] && ask "Вернуть прежний экран входа (tuigreet)? Нужен sudo" system; then
    sudo cp /etc/greetd/config.toml.tuigreet /etc/greetd/config.toml && echo "  экран входа — как был (со следующей загрузки)"
fi

if [ -d /usr/share/plymouth/themes/cove ] && ask "Убрать заставку загрузки Cove (Plymouth, Limine)? Нужен sudo" system; then
    bash "$REPO/system/boot/install.sh" revert
fi

if [ -f /etc/modprobe.d/cove-nvidia.conf ] && ask "Убрать настройки NVIDIA от Cove (драйвер останется)? Нужен sudo" system; then
    sudo rm -f /etc/modprobe.d/cove-nvidia.conf /etc/mkinitcpio.conf.d/cove-nvidia.conf /etc/greetd/gpu.lua
    rm -f "$HOME/.config/hypr/gpu.lua"
    if command -v limine-mkinitcpio >/dev/null; then sudo limine-mkinitcpio; else sudo mkinitcpio -P; fi
    echo "  убраны; драйвер и службы сна остались"
fi

shell_path=$(getent passwd "$USER" | cut -d: -f7)
if [ "$shell_path" = "$(command -v fish 2>/dev/null)" ] && ask "Вернуть bash оболочкой по умолчанию?"; then
    chsh -s /bin/bash && echo "  bash — со следующего входа"
fi

envs=("$HOME/.local/share/cove/code-venv" "$HOME/.local/share/cove/assistant-venv" "$HOME/.local/share/pywalfox-venv")
have=(); for e in "${envs[@]}"; do [ -d "$e" ] && have+=("$e"); done
if [ ${#have[@]} -gt 0 ] && ask "Удалить окружения Python Cove (${#have[@]} шт., Cove Code, ассистент, Pywalfox)?"; then
    rm -rf "${have[@]}" && echo "  удалены"
fi

echo "Готово. Шелл остановится при следующем входе; monitors.lua и settings.json остались. Вернуть всё: ./install.sh"
