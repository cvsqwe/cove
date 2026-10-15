#!/usr/bin/env bash
# Убирает симлинки Cove и возвращает файлы из последнего бэкапа установщика.
# Пакеты, обои, курсоры и сам репозиторий не трогает.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
last="$HOME/.local/state/cove/last-backup"
BACKUP=$( [ -f "$last" ] && cat "$last" || true )

read -r -p "Убрать конфиги Cove из ~/.config? [y/N] " a
[[ "$a" =~ ^[YyДд] ]] || exit 0

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
echo "Готово. Шелл Quickshell остановится при следующем входе; monitors.lua и ваши настройки (config/quickshell/settings.json) остались."
