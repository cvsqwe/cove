#!/usr/bin/env bash
# Загрузка в стиле Cove: заставка Plymouth (как экран входа) и меню Limine в цветах шелла.
#
#   bash install.sh install   — поставить тему Plymouth, бесшовный переход в гритер, оформление Limine
#   bash install.sh preview   — посмотреть заставку и поле пароля (запускать из консоли: Ctrl+Alt+F3)
#   bash install.sh apply     — пересобрать initramfs, чтобы заставка появилась при загрузке
#   bash install.sh revert    — вернуть как было (тема Plymouth, Limine, переход)
#   bash install.sh limine    — обновить только меню Limine (после смены обоев или цветов)
#   bash install.sh render D  — только нарисовать картинки темы в папку D (без sudo)
#
# Цвета — из ~/.cache/cove/palette.json (их пишет шелл), фон — обои экрана входа (/etc/greetd/qs-greeter/wallpaper).
# Если заставка сломалась: в меню Limine нажать E и убрать из строки ядра слово «splash» — пароль спросят текстом.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
THEME_DIR=/usr/share/plymouth/themes/cove
DROPIN=/etc/systemd/system/plymouth-quit.service.d/cove.conf
LIMINE=${COVE_LIMINE:-/boot/limine.conf}
BOOTDIR=${COVE_BOOTDIR:-/boot/cove}
STATE="$HOME/.local/state/quickshell/state.json"
PALETTE="$HOME/.cache/cove/palette.json"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }

color() {   # color <имя> <запасной> — цвет из палитры шелла
    python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1]))[sys.argv[2]])
except Exception: print(sys.argv[3])' "$PALETTE" "$1" "$2"
}
rgb01() {   # #rrggbb → "r, g, b" (0..1) для скрипта Plymouth
    python3 -c 'import sys; h=sys.argv[1].lstrip("#"); print(", ".join("%.3f" % (int(h[i:i+2],16)/255) for i in (0,2,4)))' "$1"
}

ACCENT=$(color accent "#cba6f7")
BASE=$(color base "#1e1e2e")
TEXT=$(color text "#cdd6f4")
DIM=$(color subtext0 "#a6adc8")
GREEN=$(color green "#a6e3a1"); RED=$(color red "#f38ba8"); YELLOW=$(color yellow "#f9e2af")
PINK=$(color pink "#f5c2e7"); TEAL=$(color teal "#94e2d5"); OVERLAY=$(color overlay0 "#6c7086")

wallpaper() {
    if [ -r /etc/greetd/qs-greeter/wallpaper ]; then echo /etc/greetd/qs-greeter/wallpaper; return; fi
    local w; w=$(python3 -c "import json;print(json.load(open('$STATE'))['wallpaper'])" 2>/dev/null || true)
    case "$w" in *.mp4|*.webm|*.mkv|*.mov|"") echo "$SRC/../../config/quickshell/assets/wallpapers/cove-dark.png" ;; *) echo "$w" ;; esac
}

screen_size() {
    hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys
try: m=max(json.load(sys.stdin), key=lambda m: m["width"]*m["height"]); print("%dx%d" % (m["width"], m["height"]))
except Exception: print("1920x1080")' 2>/dev/null || echo 1920x1080
}

# ---- картинки темы: всё как у гритера (greeter/shell.qml) ----
render() {
    local out=$1 size; size=$(screen_size)
    mkdir -p "$out"
    # обои: размытие и затемнение как MultiEffect гритера (blur 64 на 1280×720, brightness −0.3)
    magick "$(wallpaper)" -resize 1280x720^ -gravity center -extent 1280x720 \
        -blur 0x18 -evaluate subtract 30% -resize "$size"^ -gravity center -extent "$size" "$out/background.png"
    # знак Cove в круге акцента (components/CoveLogo.qml)
    cat > "$out/logo.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="76" height="76" viewBox="0 0 76 76">
  <circle cx="38" cy="38" r="38" fill="$ACCENT"/>
  <g transform="translate(16 16) scale(0.6875)" fill="none" stroke-linecap="round" stroke="$BASE">
    <path d="M48.06 14.17A24 24 0 1 0 48.06 49.83" stroke-width="7"/>
    <path d="M21 30Q26.5 24 32 30T43 30" stroke-width="4.5"/>
    <path d="M26 41Q31.5 35.5 37 41" stroke-width="4" stroke-opacity="0.5"/>
  </g>
</svg>
SVG
    # поле пароля: пилюля 340×54, полупрозрачный фон и рамка акцента
    cat > "$out/entry.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="340" height="54">
  <rect x="1" y="1" width="338" height="52" rx="26" fill="$BASE" fill-opacity="0.8" stroke="$ACCENT" stroke-width="2"/>
</svg>
SVG
    cat > "$out/bullet.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="5" fill="$ACCENT"/></svg>
SVG
    for f in logo entry bullet; do rsvg-convert "$out/$f.svg" -o "$out/$f.png"; rm "$out/$f.svg"; done

    sed -e "s/@BASE_RGB@/$(rgb01 "$BASE")/g" -e "s/@DIM_RGB@/$(rgb01 "$DIM")/g" "$SRC/plymouth/cove.script" > "$out/cove.script"
    cat > "$out/cove.plymouth" <<EOF
[Plymouth Theme]
Name=Cove
Description=Cove: заставка в стиле экрана входа
ModuleName=script

[script]
ImageDir=$THEME_DIR
ScriptFile=$THEME_DIR/cove.script
Font=Adwaita Sans 14
ConsoleLogBackgroundColor=0x${BASE#\#}
EOF
}

limine_block() {
    h() { echo "${1#\#}"; }
    cat <<EOF
# --- Cove (system/boot/install.sh), откат: bash install.sh revert ---
wallpaper: boot():/cove/background.png
wallpaper_style: stretched
interface_branding: Cove
interface_branding_colour: $(h "$ACCENT")
interface_help_hidden: yes
term_foreground: $(h "$TEXT")
term_foreground_bright: $(h "$TEXT")
term_background: 30$(h "$BASE")
term_background_bright: $(h "$OVERLAY")
term_palette: $(h "$BASE");$(h "$RED");$(h "$GREEN");$(h "$YELLOW");$(h "$ACCENT");$(h "$PINK");$(h "$TEAL");$(h "$DIM")
term_palette_bright: $(h "$OVERLAY");$(h "$RED");$(h "$GREEN");$(h "$YELLOW");$(h "$ACCENT");$(h "$PINK");$(h "$TEAL");$(h "$TEXT")
# --- /Cove ---
EOF
}
LIMINE_KEYS='wallpaper|wallpaper_style|interface_branding|interface_branding_colou?r|interface_help_hidden|term_foreground|term_foreground_bright|term_background|term_background_bright|term_palette|term_palette_bright'

limine_enrolled() {   # хэш конфига вшит в загрузчик — тогда правка limine.conf сломает загрузку
    grep -hsE '^\s*ENABLE_ENROLL_LIMINE_CONFIG\s*=\s*"?yes' /etc/limine-entry-tool.conf /etc/limine-entry-tool.d/*.conf /etc/default/limine >/dev/null
}

install_limine() {
    if ! sudo test -f "$LIMINE"; then say "Limine: $LIMINE не найден — пропускаю"; return; fi
    if limine_enrolled; then say "Limine: конфиг защищён хэшем (ENABLE_ENROLL_LIMINE_CONFIG) — не трогаю"; return; fi
    say "Limine: фон и цвета (копия — $LIMINE.cove-bak)"
    sudo test -f "$LIMINE.cove-bak" || sudo cp "$LIMINE" "$LIMINE.cove-bak"
    sudo mkdir -p "$BOOTDIR"
    sudo install -m644 "$1/background.png" "$BOOTDIR/background.png"
    # убираем прошлый блок Cove, свои глобальные строки с теми же ключами комментируем, блок — в начало файла
    local tmp; tmp=$(mktemp)
    sudo cat "$LIMINE" | sed '/^# --- Cove (system\/boot\/install.sh)/,/^# --- \/Cove ---/d' \
        | sed -E "s/^(($LIMINE_KEYS):)/#cove# \1/" > "$tmp.body"
    { limine_block; cat "$tmp.body"; } > "$tmp"
    sudo install -m644 "$tmp" "$LIMINE"
    rm -f "$tmp" "$tmp.body"
}

revert_limine() {
    sudo test -f "$LIMINE" || return 0
    local tmp; tmp=$(mktemp)
    sudo cat "$LIMINE" | sed '/^# --- Cove (system\/boot\/install.sh)/,/^# --- \/Cove ---/d' | sed 's/^#cove# //' > "$tmp"
    sudo install -m644 "$tmp" "$LIMINE"; rm -f "$tmp"
    sudo rm -rf "$BOOTDIR"
    say "Limine: оформление убрано"
}

case "${1:-}" in
limine)   # только меню Limine — например, после смены обоев или цветов
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    render "$tmp"; install_limine "$tmp"
    ;;
render)
    render "${2:?папка}"
    say "Картинки темы — в $2"
    ;;
install)
    for c in magick rsvg-convert plymouth-set-default-theme; do command -v $c >/dev/null || { echo "нет $c"; exit 1; }; done
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    say "Рисую тему (акцент $ACCENT, фон — $(wallpaper))"
    render "$tmp"
    say "Plymouth: тема в $THEME_DIR"
    cur=$(plymouth-set-default-theme 2>/dev/null || echo bgrt)
    [ "$cur" = cove ] || echo "$cur" | sudo tee /etc/plymouth/.cove-previous-theme >/dev/null
    sudo rm -rf "$THEME_DIR"; sudo mkdir -p "$THEME_DIR"
    sudo install -m644 "$tmp"/* "$THEME_DIR/"
    sudo plymouth-set-default-theme cove
    say "Переход в экран входа без чёрного кадра (plymouth quit --retain-splash)"
    sudo mkdir -p "$(dirname "$DROPIN")"
    printf '[Service]\nExecStart=\nExecStart=-/usr/bin/plymouth quit --retain-splash\n' | sudo tee "$DROPIN" >/dev/null
    sudo systemctl daemon-reload
    install_limine "$tmp"
    # сами не правим: только подсказываем, чего не хватает для заставки
    grep -hsE '^\s*HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/*.conf >/dev/null \
        || say "ВНИМАНИЕ: в HOOKS mkinitcpio нет plymouth — без него заставки не будет (добавьте после udev/systemd)"
    grep -qw splash /proc/cmdline || say "ВНИМАНИЕ: в строке ядра нет «splash» — добавьте его в KERNEL_CMDLINE (/etc/default/limine)"
    say "Готово. Дальше:"
    echo "    1) проверить заставку: Ctrl+Alt+F3, войти, bash $SRC/install.sh preview  (Ctrl+Alt+F1 — назад)"
    echo "    2) включить при загрузке: bash $SRC/install.sh apply"
    ;;
preview)
    [ -t 0 ] && ! [ -n "${WAYLAND_DISPLAY:-}" ] || { echo "Запускайте из консоли (Ctrl+Alt+F3), не из окна: заставке нужен весь экран."; exit 1; }
    sudo plymouthd --mode=boot
    sudo plymouth show-splash
    sleep 4
    sudo plymouth ask-for-password --prompt="Пароль от диска" >/dev/null || true
    sudo plymouth display-message --text="Проверка диска…"; sleep 2
    sudo plymouth quit
    ;;
apply)
    say "Пересобираю initramfs (limine-mkinitcpio)"
    if command -v limine-mkinitcpio >/dev/null; then sudo limine-mkinitcpio; else sudo mkinitcpio -P; fi
    say "Готово: заставка появится при следующей загрузке"
    ;;
revert)
    prev=$(cat /etc/plymouth/.cove-previous-theme 2>/dev/null || echo bgrt)
    say "Plymouth: возвращаю тему $prev"
    sudo plymouth-set-default-theme "$prev"
    sudo rm -f "$DROPIN" /etc/plymouth/.cove-previous-theme; sudo systemctl daemon-reload
    revert_limine
    say "Осталось пересобрать initramfs: bash $SRC/install.sh apply"
    ;;
*)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    ;;
esac
