pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Обновления системы: репозитории (checkupdates — без root, во временной копии базы) и AUR (yay -Qua).
// Проверка раз в два часа и после обновления; модуль панели «updates» виден, когда есть что ставить.
Singleton {
    id: root

    property var repo: []          // ["пакет старая -> новая"]
    property var aur: []
    property bool checking: false
    property real checkedAt: 0
    readonly property int count: repo.length + aur.length

    function check(): void {
        if (checking) return;
        checking = true;
        proc.running = true;
    }

    // обновить в терминале; когда окно закроют — проверить заново
    function upgrade(): void {
        upgrader.running = true;
    }

    Process {
        id: proc
        command: ["sh", "-c", 'exec </dev/null
            command -v checkupdates >/dev/null && checkupdates 2>/dev/null | sed "s/^/R /"
            if command -v yay >/dev/null; then yay -Qua 2>/dev/null | sed "s/^/A /"
            elif command -v paru >/dev/null; then paru -Qua 2>/dev/null | sed "s/^/A /"; fi
            true']
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(s => s);
                root.repo = lines.filter(l => l.startsWith("R ")).map(l => l.slice(2));
                root.aur = lines.filter(l => l.startsWith("A ")).map(l => l.slice(2));
                root.checking = false;
                root.checkedAt = Date.now();
            }
        }
    }

    Process {
        id: upgrader
        command: [Settings.general.terminal, "--title", I18n.tr("Обновление системы"), "sh", "-c",
            'if command -v yay >/dev/null; then yay -Syu; elif command -v paru >/dev/null; then paru -Syu; else sudo pacman -Syu; fi
             echo; printf "%s" "$1"; read -r _', "_", I18n.tr("Готово — Enter, чтобы закрыть")]
        onExited: root.check()
    }

    Timer {
        interval: 2 * 3600 * 1000
        running: true
        repeat: true
        onTriggered: root.check()
    }
    // первая проверка — не сразу после входа, чтобы не мешать запуску
    Timer { interval: 90 * 1000; running: true; onTriggered: root.check() }

    IpcHandler {
        target: "updates"
        function check(): void { root.check(); }
        function count(): int { return root.count; }
    }
}
