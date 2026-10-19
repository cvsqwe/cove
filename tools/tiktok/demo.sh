#!/usr/bin/env bash
# Съёмка демо Cove для TikTok: сам шелл проходит по функциям через IPC, gpu-screen-recorder пишет экран.
# Каждая сцена отмечается в scenes.tsv: время_начала  кадрирование  подпись
# Результат — ~/Videos/cove-demo (raw.mp4 + scenes.tsv), сюда же бэкап настроек на время съёмки.
D="$HOME/Videos/cove-demo"; mkdir -p "$D"
exec </dev/null
export LC_NUMERIC=C
ipc() { qs ipc call "$@" >/dev/null 2>&1; }
W="$HOME/Wallpapers/Live"

# ---- подготовка: бэкап настроек, пустой воркспейс, «Не беспокоить» ----
cp ~/.config/quickshell/settings.json "$D/settings.backup.json"
cp ~/.local/state/quickshell/state.json "$D/state.backup.json"
PREV_WS=$(hyprctl activeworkspace -j | jq .id)
hyprctl dispatch 'hl.dsp.focus({ workspace = "9" })' >/dev/null
ipc wallpaper set "$W/purple-waves.mp4"
sleep 4

rm -f "$D/raw.mp4" "$D/scenes.tsv"
gpu-screen-recorder -w DP-1 -f 60 -encoder cpu -k h264 -cursor no -o "$D/raw.mp4" >"$D/gsr.log" 2>&1 &
REC=$!
sleep 1.2
T0=$EPOCHREALTIME
mark() { awk -v a="$T0" -v b="$EPOCHREALTIME" -v k="$1" -v s="$2" 'BEGIN { printf "%.3f\t%s\t%s\n", b - a, k, s }' >> "$D/scenes.tsv"; }

# 1. вступление
mark full "Это Cove — моя оболочка для Linux"
sleep 3.5

# 2. живые обои
mark full "Живые обои — и цвета всей системы подстраиваются под них"
ipc wallpaper toggle; sleep 1.6; ipc wallpaper toggle; sleep 0.4
ipc wallpaper set "$W/aurora-cabins.mp4"; sleep 2.6
ipc wallpaper set "$W/rain-on-glass.mp4"; sleep 2.6
ipc wallpaper set "$W/purple-tunnel.mp4"; sleep 2.6

# 3. остров
mark island "Динамический остров: таймеры, загрузки, микрофон и камера"
ipc timer start 3m "Чай"; sleep 1.5
( timeout 3 pw-record --media-category=Capture /dev/null >/dev/null 2>&1 & ); sleep 2.2
DL="$(xdg-user-dir DOWNLOAD)/cove-demo.iso"
( for i in $(seq 6); do head -c 4000000 /dev/urandom >> "$DL.part"; sleep 0.4; done; mv "$DL.part" "$DL" ) ; sleep 2.2
rm -f "$DL"
ipc timer cancel; sleep 0.6

# 4. лаунчер
mark center "Лаунчер: приложения, калькулятор, курсы валют, эмодзи, таймеры"
ipc launcher search ""; sleep 1.6
ipc launcher search "=2^10 * 3"; sleep 1.6
ipc launcher search "=100 usd в руб"; sleep 1.8
ipc launcher search ";кот"; sleep 1.4
ipc launcher search "+25m фокус"; sleep 1.6
ipc launcher toggle; sleep 0.5

# 5. центр управления
mark right "Центр управления: сеть, звук, Bluetooth, переключатели"
ipc control open ""; sleep 2.2
ipc control open bluetooth; sleep 1.6
ipc control open audio; sleep 1.6
ipc control toggle; sleep 0.5

# 6. дашборд
mark top "Дашборд: погода, музыка, календарь, система"
ipc dashboard toggle; sleep 3.4
ipc dashboard toggle; sleep 0.5

# 8. настройки
mark center "Всё настраивается кнопками, без конфигов"
for p in appearance bar island launcher time terminal; do ipc settings open "$p"; sleep 1.2; done
ipc settings toggle; sleep 0.5

# 9. окна и обзор
mark full "Окна и обзор всех рабочих столов"
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class cove-demo --hold fastfetch")' >/dev/null; sleep 1.2
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class cove-demo cava")' >/dev/null; sleep 1.2
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class cove-demo btop")' >/dev/null; sleep 2.2
ipc overview toggle; sleep 2.8
ipc overview toggle; sleep 0.8

# 9b. профили
mark full "Стиль всей системы — в один клик"
ipc profiles apply "Неон"; sleep 2.4
ipc profiles apply "Минимал"; sleep 2.4
ipc profiles apply "День"; sleep 2.6
ipc profiles apply "Уют"; sleep 2.4

# 10. polkit
mark center "Даже запрос пароля — в стиле системы"
( timeout 20 pkexec --disable-internal-agent /usr/bin/true >/dev/null 2>&1 & ); sleep 3.2
ipc polkit cancel; sleep 0.6
for pid in $(hyprctl clients -j | jq -r '.[] | select(.class=="cove-demo") | .pid'); do kill "$pid" 2>/dev/null; done
sleep 0.8

# 11. экран блокировки
mark full "Экран блокировки и меню питания"
ipc lock preview; sleep 3.2
ipc lock preview; sleep 0.4
ipc session toggle; sleep 1.8
ipc session toggle; sleep 0.5

# 12. финал
mark full "Cove · Hyprland + Quickshell"
sleep 4
mark end ""
sleep 0.3
kill -INT $REC; wait $REC 2>/dev/null

# ---- вернуть всё как было ----
cp "$D/settings.backup.json" ~/.config/quickshell/settings.json
cp "$D/state.backup.json" ~/.local/state/quickshell/state.json
pkill -f '^qs$'; sleep 0.5
hyprctl dispatch 'hl.dsp.exec_cmd("qs > ~/.config/qs.log 2>&1")' >/dev/null
hyprctl dispatch "hl.dsp.focus({ workspace = \"$PREV_WS\" })" >/dev/null
echo "запись: $D/raw.mp4"
