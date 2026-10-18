pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Cove Code (Neovim с NVIM_APPNAME=cove) пишет своё состояние в ~/.cache/cove/status.json
// (lua/cove/shell.lua): проект, файл, ветка, несохранённое, ошибки. Панель показывает его
// вместо голого заголовка, когда активно окно Cove Code.
Singleton {
    id: root

    property var status: null
    readonly property var win: Hyprland.activeToplevel
    // отдельное окно (cove-gui, класс cove) или терминал, где заголовок «… — Cove Code»
    readonly property bool focused: !!win && (String(win.lastIpcObject?.class ?? "") === "cove" || /— Cove Code$/.test(win.title ?? ""))
    readonly property bool active: focused && status !== null

    FileView {
        path: Quickshell.env("HOME") + "/.cache/cove/status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.status = JSON.parse(text()); } catch (e) { root.status = null; } }
        onLoadFailed: root.status = null
    }
}
