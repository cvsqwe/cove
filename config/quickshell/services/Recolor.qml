pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Разносит палитру шелла по kitty, Firefox и Cove Code (рамки окон Hyprland — в services/HyprConfig.qml).
// Firefox: цвета на лету через Pywalfox (~/.cache/wal/colors.json + `pywalfox update`),
// форма (скругления, шрифт) — userChrome.css из assets/firefox-theme.sh, применяется после перезапуска Firefox.
Singleton {
    id: root

    function hex(c: color): string { return String(c).slice(1, 7); }

    function apply(): void {
        kitty.setText([
            I18n.tr("# Сгенерировано Quickshell (services/Recolor.qml) — не редактировать"),
            `foreground ${Theme.text}`, `background ${Theme.base}`,
            `selection_foreground ${Theme.base}`, `selection_background ${Theme.accent}`,
            `cursor ${Theme.accent}`, `cursor_text_color ${Theme.base}`, `url_color ${Theme.accent2}`,
            `active_border_color ${Theme.accent}`, `inactive_border_color ${Theme.surface1}`,
            `active_tab_foreground ${Theme.crust}`, `active_tab_background ${Theme.accent}`,
            `inactive_tab_foreground ${Theme.subtext0}`, `inactive_tab_background ${Theme.mantle}`,
            `tab_bar_background ${Theme.crust}`,
            `color0 ${Theme.surface1}`, `color8 ${Theme.surface2}`,
            `color1 ${Theme.red}`, `color9 ${Theme.red}`,
            `color2 ${Theme.green}`, `color10 ${Theme.green}`,
            `color3 ${Theme.yellow}`, `color11 ${Theme.yellow}`,
            `color4 ${Theme.accent2}`, `color12 ${Theme.accent2}`,
            `color5 ${Theme.accent}`, `color13 ${Theme.accent}`,
            `color6 ${Theme.teal}`, `color14 ${Theme.teal}`,
            `color7 ${Theme.subtext1}`, `color15 ${Theme.subtext0}`,
            ""
        ].join("\n"));
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
        firefoxColors();
        coveColors();
    }

    // Cove Code (~/.config/cove/lua/cove/theme.lua) следит за этим файлом и перекрашивается на лету
    function coveColors(): void {
        const keys = ["crust", "mantle", "base", "surface0", "surface1", "surface2", "overlay0", "overlay1",
            "subtext0", "subtext1", "text", "accent", "accent2", "red", "peach", "yellow", "green", "teal", "lavender", "pink"];
        const p = { light: Theme.light };
        for (const k of keys) p[k] = "#" + hex(Theme[k]);
        cove.setText(JSON.stringify(p, null, 2));
        // значок Cove (Cove Code, меню приложений) — в цветах темы
        const c = k => "#" + hex(Theme[k]);
        coveIcon.setText(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${c("accent")}"/><stop offset="1" stop-color="${c("accent2")}"/></linearGradient></defs>
  <rect x="8" y="8" width="112" height="112" rx="30" fill="${c("mantle")}"/>
  <g transform="translate(24 24) scale(1.25)" fill="none" stroke-linecap="round">
    <path d="M48.06 14.17A24 24 0 1 0 48.06 49.83" stroke="url(#g)" stroke-width="7"/>
    <path d="M21 30Q26.5 24 32 30T43 30" stroke="${c("text")}" stroke-width="4.5"/>
    <path d="M26 41Q31.5 35.5 37 41" stroke="${c("text")}" stroke-opacity=".5" stroke-width="4"/>
  </g>
</svg>
`);
    }

    // Палитра в формате pywal. Pywalfox берёт фон из color0 (светлее оттенки считает сам),
    // акценты из color10 и color13, текст из color15.
    function firefoxColors(): void {
        const c = {
            color0: Theme.mantle, color1: Theme.red, color2: Theme.green, color3: Theme.yellow,
            color4: Theme.accent2, color5: Theme.accent, color6: Theme.teal, color7: Theme.subtext1,
            color8: Theme.surface1, color9: Theme.red, color10: Theme.accent, color11: Theme.yellow,
            color12: Theme.accent2, color13: Theme.accent2, color14: Theme.teal, color15: Theme.text
        };
        const colors = {};
        for (const k in c) colors[k] = "#" + hex(c[k]);
        wal.setText(JSON.stringify({
            wallpaper: Store.still, alpha: "100",
            special: { background: "#" + hex(Theme.mantle), foreground: "#" + hex(Theme.text), cursor: "#" + hex(Theme.accent) },
            colors
        }, null, 2));
        // update — перечитать палитру; light/dark — режим шаблона Pywalfox под тему шелла.
        // Связь с Firefox держит посредник, которого запускает сам Firefox; если соединение порвалось,
        // расширение не переподключается до перезапуска браузера — тогда один раз за сессию подсказываем.
        Quickshell.execDetached(["sh", "-c", 'command -v pywalfox >/dev/null || exit 0
            pywalfox "$1"; pywalfox update
            sock="/tmp/pywalfox_socket_$(id -u)"; flag="/tmp/cove-firefox-theme-warned-$(id -u)"
            # жив ли посредник: файл сокета мог остаться от упавшего процесса — пробуем подключиться
            alive=$(python3 -c "import socket,sys; socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM).connect(sys.argv[1])" "$sock" 2>/dev/null && echo 1)
            if pgrep -x firefox >/dev/null && [ -z "$alive" ] && [ ! -e "$flag" ]; then
                touch "$flag"
                notify-send -a "Cove" -i firefox "Firefox не получает цвета темы" "Связь с расширением Pywalfox потеряна — перезапусти Firefox, и тема снова будет меняться вместе с обоями."
            fi
            [ -n "$alive" ] && rm -f "$flag"', "_", Theme.light ? "light" : "dark"]);
    }

    // Firefox при запуске восстанавливает последнюю сохранённую тему, а палитру шелл шлёт только при смене
    // обоев — поэтому раз в несколько секунд смотрим, не появился ли новый Firefox, и сразу отдаём ему цвета
    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: Quickshell.execDetached(["sh", "-c", 'pid=$(pgrep -o -x firefox) || exit 0
            f="/tmp/cove-firefox-pid-$(id -u)"; [ "$(cat "$f" 2>/dev/null)" = "$pid" ] && exit 0
            sock="/tmp/pywalfox_socket_$(id -u)"
            python3 -c "import socket,sys; socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM).connect(sys.argv[1])" "$sock" 2>/dev/null || exit 0
            echo "$pid" > "$f"; command -v pywalfox >/dev/null && { pywalfox "$1"; pywalfox update; }', "_", Theme.light ? "light" : "dark"])
    }

    function firefoxShape(): void { FirefoxLook.shape(); }   // форма и стартовая страница — services/FirefoxLook.qml

    function init(): void { debounce.restart(); shapeDebounce.restart(); }

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.apply()
    }

    Timer {
        id: shapeDebounce
        interval: 800
        onTriggered: root.firefoxShape()
    }
    readonly property var shape: [Theme.font, Theme.radius]
    onShapeChanged: shapeDebounce.restart()

    Connections {
        target: Theme
        function onAccentChanged(): void { debounce.restart(); }
        function onBaseChanged(): void { debounce.restart(); }
    }

    FileView {
        id: cove
        path: Quickshell.env("HOME") + "/.cache/cove/palette.json"
        printErrors: false
    }

    FileView {
        id: coveIcon
        path: Quickshell.env("HOME") + "/.local/share/icons/hicolor/scalable/apps/cove.svg"
        printErrors: false
    }

    FileView {
        id: wal
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        printErrors: false   // до первой записи файла нет
    }

    FileView {
        id: kitty
        path: Quickshell.env("HOME") + "/.config/kitty/theme.conf"
    }
}
