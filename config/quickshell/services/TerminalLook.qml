pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Вид kitty из настроек (раздел «Терминал»): ~/.config/kitty/cove.conf, который подключает kitty.conf.
// Цвета — отдельно, services/Recolor.qml → theme.conf. Применяется сразу (SIGUSR1 перечитывает конфиг).
Singleton {
    id: root

    readonly property var t: Settings.terminal
    property var fonts: []

    function apply(): void {
        const L = [
            I18n.tr("# Сгенерировано Quickshell (services/TerminalLook.qml) — меняйте в Настройках → Терминал"),
            `font_family      ${t.font}`,
            `font_size        ${t.fontSize}`,
            `window_padding_width ${t.padding}`,
            `background_opacity ${t.opacity}`,
            `cursor_shape ${t.cursor}`,
            `cursor_blink_interval ${t.cursorBlink ? -1 : 0}`,
            t.tabs === "hidden" ? "tab_bar_style hidden" : `tab_bar_style ${t.tabs}`,
            ""
        ];
        const text = L.join("\n");
        if (text === conf.text()) return;
        conf.setText(text);
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }

    // приветствие fish — универсальная переменная, видна всем окнам сразу
    function applyGreeting(): void {
        Quickshell.execDetached(["fish", "-c", `set -U fish_fastfetch ${t.greeting ? 1 : 0}`]);
    }

    property var watch: [t.font, t.fontSize, t.padding, t.opacity, t.cursor, t.cursorBlink, t.tabs]
    onWatchChanged: debounce.restart()
    readonly property bool greeting: t.greeting
    onGreetingChanged: if (Settings.ready) applyGreeting()

    Timer { id: debounce; interval: 300; onTriggered: if (Settings.ready) root.apply() }

    FileView {
        id: conf
        path: Quickshell.env("HOME") + "/.config/kitty/cove.conf"
        blockLoading: true
        printErrors: false
    }

    // моноширинные шрифты для выбора
    Process {
        running: true
        command: ["sh", "-c", "fc-list :spacing=mono family | cut -d, -f1 | sort -u"]
        stdout: StdioCollector { onStreamFinished: root.fonts = text.split("\n").filter(s => s && !/^\./.test(s)) }
    }
}
