#!/usr/bin/env bash
# Cove — установка на Arch Linux.
#
#   ./install.sh              всё по шагам, необязательное спрашивает
#   ./install.sh -y           всё, ответы по умолчанию
#   ./install.sh check        только проверить систему, ничего не менять
#   ./install.sh <шаг>…       только эти шаги: packages fonts link editor shell
#                             nvidia wallpapers cursors firefox greeter boot vpn
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
        -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
# Ядро ставится всегда, группы — по выбору (с -y — все).
CORE=(
    # Hyprland и окружение
    hyprland quickshell awww hypridle hyprlock hyprsunset hyprpicker hyprpolkitagent
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt6-svg qt6-imageformats qt6-multimedia qt6-wayland qt6ct
    # звук, сеть, железо
    pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils
    brightnessctl playerctl power-profiles-daemon upower lm_sensors udisks2
    # скриншоты, буфер, уведомления
    grim slurp satty cliphist wl-clipboard libnotify
    # терминал
    kitty fish starship fastfetch zoxide eza bat git-delta fzf fd ripgrep
    # прочее
    git curl unzip python librsvg
    # шрифты и темы
    adwaita-fonts ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk adw-gtk-theme breeze-icons
)
# группа|что даёт|пакеты
PKG_GROUPS=(
    "record|запись экрана (Super+Alt+R)|gpu-screen-recorder"
    "ocr|текст и QR с экрана (Super+Shift+T / Super+Shift+Q)|tesseract tesseract-data-rus tesseract-data-eng zbar"
    "files|миниатюры и просмотр в Cove Files|python-pillow ffmpegthumbnailer poppler"
    "tools|файловый менеджер yazi, спектр музыки в острове|yazi cava"
    "nvim|старый Cove Code на Neovim (cove-nvim)|neovim"
    "eq|выравнивание громкости и защита от перегруза в Настройки → Звук|lsp-plugins-lv2"
    "songid|«что за песня играет» (Shazam) в центре управления|songrec"
)
PKG_DEFAULT=(y y y y n y y)

missing_of() { local p; for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 || printf '%s ' "$p"; done; }

# ---------------------------------------------------------------- проверка системы
# Ничего не меняет: что за система, что помешает шеллу, каких пакетов не хватает.
preflight() {
    step "Проверка системы"
    local bad=0
    if command -v pacman >/dev/null; then ok "Arch Linux (pacman)"
    else warn "pacman не найден: Cove рассчитан на Arch Linux, пакеты придётся ставить вручную"; bad=1; fi

    if command -v Hyprland >/dev/null; then
        local v; v=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ -n "$v" ] && [ "$(printf '%s\n0.56.0\n' "$v" | sort -V | head -1)" != 0.56.0 ]; then
            warn "Hyprland $v: нужен 0.56 или новее (конфиг на Lua) — обновите систему: sudo pacman -Syu"; bad=1
        else ok "Hyprland ${v:-есть}"; fi
    else echo "  ${D}Hyprland поставится вместе с пакетами${N}"; fi

    # видеокарта: NVIDIA требует своего драйвера и переменных окружения
    local gpu; gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | sed 's/.*: //' | head -2 | paste -sd ';' -)
    if grep -qi nvidia <<<"$gpu"; then
        warn "видеокарта NVIDIA ($gpu): установщик поставит драйвер и настроит её (шаг nvidia)"
    elif [ -n "$gpu" ]; then ok "видеокарта: $gpu"; fi
    # NVIDIA уже настроена? драйвер загружен и KMS включён
    if grep -qi nvidia <<<"$gpu"; then
        if lsmod 2>/dev/null | grep -q '^nvidia_drm'; then
            [ "$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)" = Y ] && ok "драйвер NVIDIA загружен, KMS включён" \
                || warn "драйвер NVIDIA загружен, но KMS выключен: ./install.sh nvidia и перезагрузка"
        else
            warn "драйвер NVIDIA не загружен (nouveau или не поставлен): ./install.sh nvidia"
        fi
    fi

    local free; free=$(df -Pm "$HOME" | awk 'NR==2{print $4}')
    if [ "${free:-0}" -lt 3000 ]; then warn "мало места в домашней папке: $((free / 1024)) ГБ (обоям нужно ~1 ГБ)"; else ok "место: $((free / 1024)) ГБ свободно"; fi

    if curl -fsI --max-time 6 https://github.com >/dev/null 2>&1; then ok "интернет есть"
    else warn "нет доступа к github.com: шрифт значков, обои и курсоры не скачаются"; bad=1; fi

    # что подерётся с шеллом: свой бар, уведомления, обои, polkit
    local p rivals=()
    for p in waybar ags eww hyprpanel mako dunst swaync fnott hyprpaper swaybg swww-daemon; do
        pgrep -x "$p" >/dev/null 2>&1 && rivals+=("$p")
    done
    if [ ${#rivals[@]} -gt 0 ]; then
        warn "сейчас запущены: ${rivals[*]} — Cove заменяет их (бар, уведомления, обои); уберите их из автозапуска Hyprland"
    else ok "конфликтующих бара, уведомлений и обоев не запущено"; fi

    local dm; dm=$(systemctl --no-legend list-unit-files 2>/dev/null | awk '$1 ~ /^(sddm|gdm|lightdm|ly|greetd)\.service$/ && $2=="enabled"{print $1}' | head -1)
    [ -n "$dm" ] && echo "  ${D}экран входа сейчас: ${dm%.service} (свой экран входа Cove — шаг greeter, по желанию)${N}"

    if command -v pacman >/dev/null; then
        local m; m=$(missing_of "${CORE[@]}")
        [ -n "$m" ] && echo "  Не хватает обязательных пакетов: ${D}$m${N}" || ok "обязательные пакеты на месте"
        local g name desc pk
        for g in "${PKG_GROUPS[@]}"; do
            IFS='|' read -r name desc pk <<<"$g"
            m=$(missing_of $pk)
            [ -n "$m" ] && echo "  ${D}по желанию — $desc: $m${N}"
        done
    fi
    return $bad
}

if want check || [ ${#STEPS[@]} = 0 ]; then
    if ! preflight && [ ${#STEPS[@]} = 0 ]; then
        ask "Есть предупреждения. Продолжить установку?" y || exit 1
    fi
    [ "${STEPS[*]}" = check ] && exit 0
fi

if want packages; then
    step "Пакеты"
    if ! command -v pacman >/dev/null; then
        warn "pacman не найден — поставьте вручную: ${CORE[*]}"
    else
        todo=($(missing_of "${CORE[@]}"))
        for i in "${!PKG_GROUPS[@]}"; do
            IFS='|' read -r name desc pk <<<"${PKG_GROUPS[$i]}"
            m=($(missing_of $pk))
            [ ${#m[@]} = 0 ] && continue
            ask "Поставить: $desc?" "${PKG_DEFAULT[$i]}" && todo+=("${m[@]}")
        done
        if [ ${#todo[@]} = 0 ]; then ok "всё уже установлено"
        else
            echo "  Нужно поставить ${#todo[@]}: ${D}${todo[*]}${N}"
            sudo pacman -S --needed "${todo[@]}"
            ok "установлено"
        fi
        if command -v systemctl >/dev/null; then
            for svc in NetworkManager bluetooth; do
                systemctl is-enabled "$svc" >/dev/null 2>&1 && continue
                ask "Включить службу $svc?" y && sudo systemctl enable --now "$svc" && ok "$svc включён"
            done
        fi
    fi
fi

# ---------------------------------------------------------------- NVIDIA
# Драйвер по поколению карты, ранний KMS, сон, переменные окружения для Hyprland.
# Всё системное — отдельными файлами Cove (откат: ./uninstall.sh), загрузчик не трогаем.
ETC="${COVE_ETC:-/etc}"   # для проверки в песочнице
nvidia_gen() { # turing | legacy | old | "" (нет NVIDIA)
    local l; l=$(lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' | grep -i nvidia | head -1)
    [ -z "$l" ] && return
    if grep -qE '\b(TU|GA|GH|AD|GB)[0-9]{3}' <<<"$l"; then echo turing
    elif grep -qE '\b(GM|GP|GV)[0-9]{3}' <<<"$l"; then echo legacy
    else echo old; fi
}
# вторая видеокарта (не NVIDIA): в «NVIDIA Corporation» тоже есть «ati», поэтому строки NVIDIA отбрасываем
hybrid_gpu() { lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -vi nvidia | grep -qiE 'intel|amd|\bati\b'; }

if want nvidia; then
    gen=$(nvidia_gen)
    if [ -z "$gen" ]; then
        explicit && { step "NVIDIA"; ok "видеокарты NVIDIA нет, делать нечего"; }
    elif explicit || ask "Найдена видеокарта NVIDIA. Поставить драйвер и настроить её для Hyprland?" y; then
        step "NVIDIA"
        echo "  ${D}$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -i nvidia | head -1 | sed 's/.*: //')${N}"
        hybrid=0; hybrid_gpu && hybrid=1
        multilib=0; grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null && multilib=1
        # заголовки ядер для dkms
        heads=(); for k in linux linux-lts linux-zen linux-hardened; do pacman -Qq "$k" >/dev/null 2>&1 && heads+=("$k-headers"); done
        drv_ok=0
        case "$gen" in
        turing)
            pk=(nvidia-open-dkms nvidia-utils egl-wayland libva-nvidia-driver "${heads[@]}")
            [ $multilib = 1 ] && pk+=(lib32-nvidia-utils)
            [ $hybrid = 1 ] && pk+=(nvidia-prime)
            # драйвер уже стоит (nvidia-open без dkms тоже годится) — не меняем
            pacman -Qq nvidia-open >/dev/null 2>&1 && pk=("${pk[@]/nvidia-open-dkms}")
            m=($(missing_of ${pk[@]}))
            if [ ${#m[@]} -gt 0 ]; then sudo pacman -S --needed "${m[@]}" && drv_ok=1; else drv_ok=1; fi
            [ $drv_ok = 1 ] && ok "драйвер nvidia-open"
            ;;
        legacy)
            warn "GTX 9xx/10xx: основной драйвер их больше не поддерживает, нужен nvidia-580xx из AUR (последняя ветка для этих карт)"
            aur=$(command -v yay || command -v paru || true)
            pk=(nvidia-580xx-dkms nvidia-580xx-utils)
            [ $multilib = 1 ] && pk+=(lib32-nvidia-580xx-utils)
            m=($(missing_of ${pk[@]}))
            if [ ${#m[@]} = 0 ]; then drv_ok=1; ok "драйвер nvidia-580xx уже стоит"
            elif [ -n "$aur" ]; then
                [ ${#heads[@]} -gt 0 ] && sudo pacman -S --needed "${heads[@]}"
                "$aur" -S --needed egl-wayland libva-nvidia-driver "${m[@]}" && drv_ok=1 && ok "драйвер nvidia-580xx"
            else
                warn "нет помощника AUR (yay или paru): поставьте один из них и повторите ./install.sh nvidia"
            fi
            ;;
        old)
            warn "карта старше GTX 900: драйверов NVIDIA для неё больше нет, остаётся nouveau — Hyprland и шелл будут тормозить. Cove такие карты не поддерживает"
            ;;
        esac

        if [ $drv_ok = 1 ]; then
            # параметры модуля: KMS, консоль, память видеокарты сохраняется во сне
            sudo mkdir -p "$ETC/modprobe.d" "$ETC/mkinitcpio.conf.d"
            printf '%s\n' "# Cove (install.sh nvidia): KMS для Wayland и сон без потери картинки" \
                "options nvidia_drm modeset=1 fbdev=1" \
                "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee "$ETC/modprobe.d/cove-nvidia.conf" >/dev/null
            # ранний KMS: модули в initramfs (нужно для заставки и чтобы не было чёрного экрана при входе)
            printf '%s\n' "# Cove (install.sh nvidia): ранний KMS" \
                "MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)" | sudo tee "$ETC/mkinitcpio.conf.d/cove-nvidia.conf" >/dev/null
            ok "KMS и модули: $ETC/modprobe.d/cove-nvidia.conf, $ETC/mkinitcpio.conf.d/cove-nvidia.conf"
            if command -v limine-mkinitcpio >/dev/null; then sudo limine-mkinitcpio; else sudo mkinitcpio -P; fi && ok "initramfs пересобран"
            for svc in nvidia-suspend nvidia-hibernate nvidia-resume; do
                sudo systemctl enable "$svc.service" >/dev/null 2>&1 || true
            done
            ok "сон и гибернация (nvidia-suspend/hibernate/resume)"

            # окружение Hyprland: свой локальный файл, его подхватывают hyprland.lua и экран входа
            gpu="$HOME/.config/hypr/gpu.lua"; mkdir -p "$(dirname "$gpu")"
            if [ $hybrid = 1 ]; then
                # ноутбук с двумя видеокартами: рисует встроенная, NVIDIA — по запросу (prime-run)
                printf '%s\n' "-- Cove (install.sh nvidia): ноутбук с двумя видеокартами." \
                    "-- Рисует встроенная, игры на NVIDIA: prime-run <команда> (в Steam: prime-run %command%)." > "$gpu"
                ok "две видеокарты: рабочий стол на встроенной, игры — prime-run"
            else
                printf '%s\n' "-- Cove (install.sh nvidia): окружение для NVIDIA" \
                    'hl.env("LIBVA_DRIVER_NAME", "nvidia")' \
                    'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")' \
                    'hl.env("NVD_BACKEND", "direct")' > "$gpu"
                ok "переменные окружения: ~/.config/hypr/gpu.lua"
            fi
            [ -d "$ETC/greetd" ] && sudo install -m644 "$gpu" "$ETC/greetd/gpu.lua" && ok "то же для экрана входа"
            warn "перезагрузитесь, чтобы заработал новый драйвер"
        fi
    fi
fi

# ---------------------------------------------------------------- шрифт значков
if want fonts; then
    step "Шрифты значков (Material Symbols: Rounded, Outlined, Sharp)"
    mkdir -p "$HOME/.local/share/fonts"
    for v in Rounded Outlined Sharp; do
        f="$HOME/.local/share/fonts/MaterialSymbols$v.ttf"
        if fc-list 2>/dev/null | grep -q "Material Symbols $v"; then ok "$v — уже есть"; continue; fi
        curl -fL --progress-bar -o "$f" \
            "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbols$v%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
        ok "$v установлен (Apache-2.0, Google)"
    done
    fc-cache -f >/dev/null 2>&1 || true
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
        ok "создан ~/.config/hypr/monitors.lua; удобнее — Настройки → Мониторы"
    fi
    chmod +x "$REPO"/local/bin/* 2>/dev/null || true
    # значок Cove до первого запуска шелла (дальше его перекрашивает сам шелл)
    icon="$HOME/.local/share/icons/hicolor/scalable/apps/cove.svg"
    [ -e "$icon" ] || { mkdir -p "$(dirname "$icon")"; cp "$REPO/data/cove.svg" "$icon"; }
    command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# ---------------------------------------------------------------- Cove Code
if want editor; then
    step "Cove Code — редактор"
    venv="$HOME/.local/share/cove/code-venv"
    # Textual с подсветкой (tree-sitter) — в своём окружении, системный Python не трогаем
    if { [ -x "$venv/bin/python" ] || python3 -m venv "$venv"; } && "$venv/bin/pip" install -q --upgrade 'textual[syntax]' \
            tree-sitter-c tree-sitter-cpp tree-sitter-lua tree-sitter-typescript tree-sitter-qmljs tree-sitter-c-sharp \
            tree-sitter-php tree-sitter-ruby tree-sitter-make tree-sitter-cmake tree-sitter-glsl tree-sitter-nix \
            tree-sitter-zig tree-sitter-swift tree-sitter-dockerfile; then
        ok "готово — запуск: cove [файл|папка], окном: cove-gui"
    else
        warn "не вышло поставить Textual в $venv — проверьте интернет и запустите ./install.sh editor ещё раз"
    fi
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

# ---------------------------------------------------------------- загрузка
if want boot; then
    if explicit || ask "Поставить заставку загрузки Cove (Plymouth в стиле экрана входа, меню Limine)?" n; then
        step "Заставка загрузки"
        command -v plymouthd >/dev/null || sudo pacman -S --needed --noconfirm plymouth
        bash "$REPO/system/boot/install.sh" install
        warn "Заставка включится после: bash $REPO/system/boot/install.sh apply (пересборка initramfs)"
    fi
fi

# ---------------------------------------------------------------- VPN
if want vpn; then
    if explicit || ask "Поставить свой VPN Cove (ядро Mihomo из AUR + служба; подписки — в Настройки → VPN)?" n; then
        step "VPN"
        if ! command -v mihomo >/dev/null; then
            aur=$(command -v yay || command -v paru || true)
            if [ -n "$aur" ]; then "$aur" -S --needed mihomo-bin && ok "ядро mihomo"
            else warn "нет помощника AUR (yay или paru): поставьте mihomo-bin и повторите ./install.sh vpn"; fi
        fi
        command -v mihomo >/dev/null && sudo bash "$REPO/system/vpn/install.sh" install "$USER" >/dev/null && ok "служба cove-vpn@$USER (включается без пароля)"
    fi
fi

# ---------------------------------------------------------------- готово
step "Готово"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -z "${COVE_NO_RESTART:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || true
    pkill -f '^qs$' 2>/dev/null || true   # только шелл: окна Cove Files — тоже qs, их не трогаем
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
