#!/usr/bin/env bash
# Самопроверка шелла: по очереди открывает окна, страницы настроек и режимы лаунчера через IPC
# и собирает из лога новые ошибки QML. Итог — в stdout и уведомлением.
#   bash ~/.config/quickshell/assets/selftest.sh        # или: Настройки → О системе → Самопроверка
exec </dev/null
dir=$(cd "$(dirname "$0")/.." && pwd)
log() { qs log 2>/dev/null; }
call() { qs ipc call "$@" >/dev/null 2>&1; sleep 0.6; }

before=$(log | wc -l)

# страницы настроек (id из списка в SettingsWindow.qml)
for id in $(grep -oP '\{ id: "\K[a-z]+' "$dir/settings/SettingsWindow.qml"); do call settings open "$id"; done
call settings toggle

# лаунчер во всех режимах
for q in "" "=2+2" "=100 usd в руб" "/qml" ">ls" "?test" ":" "#" "!" "@" ";кот" "+5m" "<git"; do
    qs ipc call launcher search "$q" >/dev/null 2>&1; sleep 0.5
done
call launcher toggle

# центр управления и его страницы
for p in "" wifi bluetooth audio; do call control open "$p"; done
call control toggle

# остальные окна: открыть и закрыть
for t in dashboard overview wallpaper session cheatsheet notes; do call "$t" toggle; call "$t" toggle; done

sleep 0.5
noise='textinput|qt\.svg|sni\.watcher|host portal|Metadata|handler_name|Stream #|Duration:|encoder|qt\.multimedia'
errors=$(log | tail -n +"$((before + 1))" | grep -E 'WARN|ERROR' | grep -vE "$noise" | sed 's/\x1b\[[0-9;]*m//g' | sort | uniq -c | sort -rn)

if [ -z "$errors" ]; then
    echo "Самопроверка: ошибок нет"
    notify-send -a Cove -i cove "Самопроверка пройдена" "Все окна и страницы открылись без ошибок"
else
    n=$(printf '%s\n' "$errors" | wc -l)
    printf '%s\n' "$errors"
    printf '%s\n' "$errors" > "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/selftest.log"
    notify-send -a Cove -i dialog-warning "Самопроверка: проблем — $n" "$(printf '%s\n' "$errors" | head -5)"
    exit 1
fi
