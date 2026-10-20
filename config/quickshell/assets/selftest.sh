#!/usr/bin/env bash
# Самопроверка шелла: по очереди открывает окна, страницы настроек и режимы лаунчера через IPC
# и собирает из лога новые ошибки QML. Итог — в stdout и уведомлением.
#   bash ~/.config/quickshell/assets/selftest.sh        # или: Настройки → О системе → Самопроверка
exec </dev/null
dir=$(cd "$(dirname "$0")/.." && pwd)
log() { qs log 2>/dev/null; }
call() { qs ipc call "$@" >/dev/null 2>&1; sleep 0.6; }

before=$(log | wc -l)

# бюджет производительности: CPU в простое и память шелла — до того, как самопроверка откроет окна
pid=$(pgrep -x qs | head -1)
if [ -n "$pid" ]; then
    hz=$(getconf CLK_TCK)
    t1=$(awk '{print $14+$15}' "/proc/$pid/stat"); sleep 10; t2=$(awk '{print $14+$15}' "/proc/$pid/stat")
    cpu=$(( (t2 - t1) * 1000 / hz / 10 ))          # десятые доли процента
    rss=$(awk '/VmRSS/ {print int($2/1024)}' "/proc/$pid/status")
    # пока играет музыка, спектр законно рисует кадры — порог выше
    budget=30; playerctl -a status 2>/dev/null | grep -q Playing && budget=60
    echo "Нагрузка в простое: $((cpu / 10)).$((cpu % 10))% CPU, ${rss} МБ памяти"
    [ "$cpu" -gt "$budget" ] && perf+="${perf:+$'\n'}      1 Нагрузка в простое $((cpu / 10)).$((cpu % 10))% CPU — больше $((budget / 10))%"
    [ "$rss" -gt 700 ] && perf+="${perf:+$'\n'}      1 Память шелла ${rss} МБ — больше 700"
fi


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

# окна игр (создаются при открытии)
for t in games gamesLegacy; do call "$t" toggle; sleep 0.8; call "$t" toggle; done

sleep 0.5
noise='Cannot open: file:///tmp/|textinput|qt\.svg|sni\.watcher|host portal|Metadata|handler_name|Stream #|Duration:|encoder|qt\.multimedia'
errors=$(log | tail -n +"$((before + 1))" | grep -E 'WARN|ERROR' | grep -vE "$noise" | sed 's/\x1b\[[0-9;]*m//g' | sort | uniq -c | sort -rn)

[ -n "$perf" ] && errors+="${errors:+$'\n'}$perf"
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
