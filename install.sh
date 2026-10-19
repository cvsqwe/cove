#!/usr/bin/env bash
# Cove — установка на Arch Linux.
#
#   ./install.sh              всё по шагам, необязательное спрашивает
#   ./install.sh -y           всё, ответы по умолчанию
#   ./install.sh <шаг>…       только эти шаги: packages fonts link editor shell
#                             wallpapers cursors firefox greeter
#
# Конфиги ставятся симлинками на этот репозиторий: `git pull` — и система обновлена.
# Всё, что лежало на их месте, переносится в ~/.local/state/cove/backup-<дата>/ (откат — ./uninstall.sh).
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
YES=0
STEPS=()
for a in "$@"; do
    case "$a" in
        -y|--yes) YES=1 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) STEPS+=("$a") ;;
    esac
done

# ---- оформление вывода ----
if [ -t 1 ]; then B=$'\e[1m'; D=$'\e[2m'; M=$'\e[35m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B= D= M= G= Y= R= N=; fi
step() { printf '\n%s==>%s %s%s%s\n' "$M" "$N" "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
# ask "вопрос" y|n — вернёт 0 на «да»
ask() {
    local def=$2 hint ans
    [ "$def" = y ] && hint="[Y/n]" || hint="[y/N]"
    if [ $YES = 1 ] || [ ! -t 0 ]; then [ "$def" = y ]; return; fi
    read -r -p "  $1 $hint " ans || true
    ans=${ans:-$def}
    [[ "$ans" =~ ^[YyДд] ]]
}
want() { # шаг выбран явно или идёт полная установка
    [ ${#STEPS[@]} = 0 ] && return 0
    local s; for s in "${STEPS[@]}"; do [ "$s" = "$1" ] && return 0; done; return 1
}
explicit() { [ ${#STEPS[@]} -gt 0 ]; }

[ "$(id -u)" = 0 ] && die "Запускайте от своего пользователя, не от root — sudo спросится, когда понадобится."

cat <<EOF

   ${M}▄▄████▄▄${N}
 ${M}▟█▀▀    ▀▀█▙${N}     ${B}cove${N}
${M}▟█▘${N}                своя экосистема на Hyprland
${M}██${N}   ${B}▄▀▀▄▄▀▀▄${N}     ${D}$REPO${N}
${M}▜█▖${N}
 ${M}▜█▄▄    ▄▄█▛${N}
   ${M}▀▀████▀▀${N}
EOF

# ---------------------------------------------------------------- пакеты
PACKAGES=(
    # Hyprland и окружение
    hyprland quickshell awww hypridle hyprlock hyprsunset hyprpicker hyprpolkitagent
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt6-svg qt6-imageformats qt6-multimedia qt6-wayland qt6ct
    # звук, сеть, железо
    pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils
    brightnessctl playerctl power-profiles-daemon upower lm_sensors udisks2
    # скриншоты, запись, буфер
    grim slurp satty gpu-screen-recorder cliphist wl-clipboard libnotify
    # текст и QR с экрана (Super+Shift+T / Super+Shift+Q)
    tesseract tesseract-data-rus tesseract-data-eng zbar
    # терминал и Cove Code
    kitty fish starship fastfetch zoxide eza bat git-delta fzf fd ripgrep yazi neovim
    # миниатюры и просмотр (Cove Files)
    python-pillow ffmpegthumbnailer poppler
    # прочее
    cava git curl unzip python librsvg
    # шрифты и темы
    adwaita-fonts ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk adw-gtk-theme breeze-icons
)
OPTIONAL=(easyeffects)

if want packages; then
    step "Пакеты"
    if ! command -v pacman >/dev/null; then
        warn "pacman не найден — Cove рассчитан на Arch Linux. Поставьте вручную: ${PACKAGES[*]}"
    else
        missing=()
        for p in "${PACKAGES[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
        if [ ${#missing[@]} = 0 ]; then ok "всё уже установлено"
        else
            echo "  Нужно поставить ${#missing[@]}: ${D}${missing[*]}${N}"
            sudo pacman -S --needed "${missing[@]}"
            ok "установлено"
        fi
        for p in "${OPTIONAL[@]}"; do
            pacman -Qq "$p" >/dev/null 2>&1 && continue
            ask "Поставить $p (эквалайзер — кнопка в центре управления)?" n && sudo pacman -S --needed --noconfirm "$p"
        done
        if command -v systemctl >/dev/null; then
            for svc in NetworkManager bluetooth; do
                systemctl is-enabled "$svc" >/dev/null 2>&1 && continue
                ask "Включить службу $svc?" y && sudo systemctl enable --now "$svc" && ok "$svc включён"
            done
        fi
    fi
fi

# ---------------------------------------------------------------- шрифт значков
if want fonts; then
    step "Шрифт значков (Material Symbols Rounded)"
    f="$HOME/.local/share/fonts/MaterialSymbolsRounded.ttf"
    if fc-list 2>/dev/null | grep -q "Material Symbols Rounded"; then ok "уже есть"
    else
        mkdir -p "$(dirname "$f")"
        curl -fL --progress-bar -o "$f" \
            "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
        fc-cache -f >/dev/null 2>&1 || true
        ok "установлен (Apache-2.0, Google)"
    fi
fi

# ---------------------------------------------------------------- конфиги
BACKUP="$HOME/.local/state/cove/backup-$(date +%Y%m%d-%H%M%S)"
if want link; then
    step "Конфиги (симлинки на репозиторий)"
    while read -r src dst; do
        [[ -z "$src" || "$src" == \#* ]] && continue
        target="$HOME/$dst"
        if [ -L "$target" ] && [ "$(readlink -f "$target")" = "$(readlink -f "$REPO/$src")" ]; then continue; fi
        if [ -e "$target" ] || [ -L "$target" ]; then
            mkdir -p "$BACKUP/$(dirname "$dst")"
            mv "$target" "$BACKUP/$dst"
            echo "  ${D}сохранён старый $dst${N}"
        fi
        mkdir -p "$(dirname "$target")"
        ln -s "$REPO/$src" "$target"
        ok "$dst"
    done < "$REPO/links.txt"
    [ -d "$BACKUP" ] && echo "$BACKUP" > "$HOME/.local/state/cove/last-backup" && warn "старые файлы — в $BACKUP"

    # мониторы — локальный файл, не в репозитории
    mon="$HOME/.config/hypr/monitors.lua"
    if [ ! -e "$mon" ]; then
        cat > "$mon" <<'LUA'
-- Мониторы этой машины (локальный файл, в репозиторий Cove не входит).
-- Пример: 144 Гц на DP-1. Имена выходов: hyprctl monitors
-- hl.monitor({ output = "DP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })
LUA
        ok "создан ~/.config/hypr/monitors.lua — частоту и расположение экранов задайте там"
    fi
    chmod +x "$REPO"/local/bin/* 2>/dev/null || true
    # значок Cove до первого запуска шелла (дальше его перекрашивает сам шелл)
    icon="$HOME/.local/share/icons/hicolor/scalable/apps/cove.svg"
    [ -e "$icon" ] || { mkdir -p "$(dirname "$icon")"; cp "$REPO/data/cove.svg" "$icon"; }
    command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# ---------------------------------------------------------------- Cove Code
if want editor && command -v nvim >/dev/null; then
    step "Cove Code — плагины редактора"
    NVIM_APPNAME=cove nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 && ok "готово — запуск: cove [файл|папка]" \
        || warn "не вышло, плагины поставятся при первом запуске cove"
fi

# ---------------------------------------------------------------- оболочка
if want shell && command -v fish >/dev/null; then
    fish_path=$(command -v fish)
    if [ "${SHELL:-}" != "$fish_path" ]; then
        step "Оболочка"
        if ask "Сделать fish оболочкой по умолчанию?" y; then
            grep -qx "$fish_path" /etc/shells || echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
            chsh -s "$fish_path" && ok "fish — оболочка по умолчанию (со следующего входа)"
        fi
    fi
fi

# ---------------------------------------------------------------- обои
if want wallpapers; then
    step "Обои"
    n=$(grep -vc '^#' "$REPO/data/wallpapers.tsv")
    if explicit || ask "Скачать пак обоев ($n шт., ~700 МБ) в ~/Wallpapers?" y; then
        mkdir -p "$HOME/Wallpapers/Cove"
        cp -n "$REPO"/config/quickshell/assets/wallpapers/*.png "$HOME/Wallpapers/Cove/"
        i=0; fail=0
        while IFS=$'\t' read -r dir file url; do
            [[ -z "$dir" || "$dir" == \#* ]] && continue
            i=$((i + 1)); out="$HOME/Wallpapers/$dir/$file"
            [ -s "$out" ] && continue
            mkdir -p "$HOME/Wallpapers/$dir"
            printf '\r  %s[%d/%d]%s %-60.60s' "$D" "$i" "$n" "$N" "$dir/$file"
            curl -fsL --retry 2 -o "$out.part" "$url" && mv "$out.part" "$out" || { rm -f "$out.part"; fail=$((fail + 1)); }
        done < "$REPO/data/wallpapers.tsv"
        printf '\r%80s\r' ''
        [ $fail = 0 ] && ok "обои в ~/Wallpapers" || warn "обои в ~/Wallpapers, не скачалось: $fail (повторить: ./install.sh wallpapers)"
    fi
fi

# ---------------------------------------------------------------- курсоры
if want cursors; then
    step "Курсоры"
    if explicit || ask "Скачать темы курсоров (Bibata, Catppuccin, Google, macOS, phinger)?" y; then
        dest="$HOME/.local/share/icons"; mkdir -p "$dest"
        tmp=$(mktemp -d)
        while IFS=$'\t' read -r name url lic; do
            [[ -z "$name" || "$name" == \#* ]] && continue
            [ -d "$dest/$name" ] && continue
            a="$tmp/$(basename "$url")"
            if curl -fsL -o "$a" "$url"; then
                x="$tmp/x"; rm -rf "${x:?}"; mkdir -p "$x"
                case "$a" in
                    *.zip) unzip -qo "$a" -d "$x" ;;
                    *) tar -xf "$a" -C "$x" ;;
                esac
                # из архива — только папки тем (с cursors/ внутри), без README/LICENSE
                for t in "$x"/*/ "$x"/*/*/; do
                    [ -d "$t/cursors" ] && [ ! -e "$dest/$(basename "$t")" ] && mv "$t" "$dest/"
                done
                ok "$name ${D}($lic)${N}"
            else warn "$name не скачался"; fi
        done < "$REPO/data/cursors.tsv"
        rm -rf "${tmp:?}"
    fi
fi

# ---------------------------------------------------------------- Firefox
if want firefox && command -v firefox >/dev/null; then
    step "Firefox в стиле Cove"
    if explicit || ask "Настроить Firefox (цвета из темы через Pywalfox, вид и стартовая страница)?" y; then
        profiles=()
        for base in "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox" "$HOME/.mozilla/firefox"; do
            [ -f "$base/profiles.ini" ] || continue
            while read -r p; do [ -n "$p" ] && [ -d "$base/$p" ] && profiles+=("$base/$p"); done < <(
                { grep -h '^Default=' "$base/installs.ini" 2>/dev/null | cut -d= -f2
                  awk -F= '/^\[Profile/{p=""} /^Path=/{p=$2} /^Default=1/{print p}' "$base/profiles.ini"; } | sort -u)
        done
        if [ ${#profiles[@]} = 0 ]; then
            warn "профиль Firefox не найден — запустите Firefox один раз и повторите: ./install.sh firefox"
        else
            # посредник Pywalfox (python) в своём окружении
            venv="$HOME/.local/share/pywalfox-venv"
            [ -x "$venv/bin/pywalfox" ] || { python -m venv "$venv" && "$venv/bin/pip" install -q pywalfox; }
            mkdir -p "$HOME/.local/bin"; ln -sf "$venv/bin/pywalfox" "$HOME/.local/bin/pywalfox"
            "$venv/bin/pywalfox" install >/dev/null
            # Firefox с XDG-путями ищет манифест в ~/.config/mozilla
            for d in "$HOME/.mozilla/native-messaging-hosts" "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/native-messaging-hosts"; do
                mkdir -p "$d"
                [ -f "$d/pywalfox.json" ] || cp "$HOME/.mozilla/native-messaging-hosts/pywalfox.json" "$d/" 2>/dev/null || true
            done
            xpi=$(mktemp --suffix=.xpi)
            curl -fsL -o "$xpi" "$(curl -fsL https://addons.mozilla.org/api/v5/addons/addon/pywalfox/ | python -c 'import json,sys;print(json.load(sys.stdin)["current_version"]["file"]["url"])')"
            for p in "${profiles[@]}"; do
                mkdir -p "$p/extensions"; cp "$xpi" "$p/extensions/pywalfox@frewacom.org.xpi"
                ok "профиль $(basename "$p")"
            done
            rm -f "$xpi"
            # форма — тем же скриптом, что вызывает шелл (дальше шелл обновляет её сам)
            sh "$REPO/config/quickshell/assets/firefox-theme.sh" "Adwaita Sans" 14 8 floating 1 1 "$HOME/.local/share/cove/startpage.html"
            ok "готово — перезапустите Firefox; вид меняется в Настройках → Firefox"
        fi
    fi
fi

# ---------------------------------------------------------------- экран входа
if want greeter; then
    if explicit || ask "Поставить экран входа Cove (greetd, заменит текущий; меняет /etc/greetd)?" n; then
        step "Экран входа"
        command -v greetd >/dev/null || sudo pacman -S --needed --noconfirm greetd
        bash "$REPO/config/quickshell/greeter/install.sh"
    fi
fi

# ---------------------------------------------------------------- готово
step "Готово"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
    pkill -x qs 2>/dev/null || true
    hyprctl dispatch 'hl.dsp.exec_cmd("qs")' >/dev/null 2>&1 || (setsid qs >/dev/null 2>&1 &)
    ok "Hyprland перечитан, шелл перезапущен"
else
    echo "  Выйдите из сеанса и войдите в ${B}Hyprland${N}."
fi
cat <<EOF

  ${B}Super + Пробел${N}  лаунчер         ${B}Super + ,${N}  настройки
  ${B}Super + /${N}       все хоткеи      ${B}cove${N}       редактор Cove Code
  Обновление: ${D}cd $REPO && git pull${N}    Откат: ${D}./uninstall.sh${N}

EOF
