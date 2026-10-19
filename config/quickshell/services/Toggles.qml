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
    // выкл → слабо → сильно → выкл
    function antiFlash(): void { const n = Settings.nightLight; n.antiFlash = ({ off: "weak", weak: "strong" })[n.antiFlash] ?? "off"; }

    IpcHandler {
        target: "toggles"
        function dnd(): void { root.dnd(); }
        function nightLight(): void { root.nightLight(); }
        function caffeine(): void { root.caffeine(); }
        function gameMode(): void { root.gameMode(); }
        function light(): void { root.light(); }
        function antiFlash(): void { root.antiFlash(); }
    }
}
