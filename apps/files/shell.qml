import QtQuick
import Quickshell
import Quickshell.Io
import qs.kit
import qs.services
import qs.ui

// Cove Files — файловый менеджер Cove. Запуск: cove-files [папка] (local/bin/cove-files).
// Один процесс на все окна: повторный запуск передаёт папку сюда по IPC (qs ipc call files open <путь>).
ShellRoot {
    id: root
    property var windows: []

    function open(path: string): void {
        if (path.startsWith("file://")) path = decodeURIComponent(path.slice(7));
        const w = winC.createObject(root, { startPath: path || Cove.home });
        windows = windows.concat([w]);
    }
    function closed(w: var): void {
        windows = windows.filter(x => x !== w);
        w.destroy();
        if (!windows.length) Qt.quit();
    }

    Component {
        id: winC
        FilesWindow {
            id: w
            onVisibleChanged: if (!visible) root.closed(w)
            onNewWindow: p => root.open(p)
        }
    }

    IpcHandler {
        target: "files"
        function open(path: string): void { root.open(path); }
    }

    Component.onCompleted: open(Quickshell.env("COVE_FILES_OPEN") || Cove.home)
}
