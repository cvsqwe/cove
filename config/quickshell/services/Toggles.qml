pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Переключатели для хоткеев и палитры: `qs ipc call toggles <имя>`.
Singleton {
    id: root

    function dnd(): void { Store.dnd = !Store.dnd; }
    function nightLight(): void { Store.nightLight = !Store.nightLight; }
    function caffeine(): void { Store.caffeine = !Store.caffeine; }
    function gameMode(): void { Store.gameMode = !Store.gameMode; }
    function light(): void { Settings.appearance.light = !Settings.appearance.light; }

    IpcHandler {
        target: "toggles"
        function dnd(): void { root.dnd(); }
        function nightLight(): void { root.nightLight(); }
        function caffeine(): void { root.caffeine(); }
        function gameMode(): void { root.gameMode(); }
        function light(): void { root.light(); }
    }
}
