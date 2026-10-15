pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Быстрые заметки: обычные .md-файлы в ~/Notes. Список, создание, удаление.
// Само редактирование — в notes/NotesDrawer.qml (FileView на выбранный файл).
Singleton {
    id: root

    readonly property string dir: Settings.home + "/Notes"
    property var files: [] // [{ path, name, mtime }]

    function refresh(): void { scan.running = true; }

    function create(): string {
        const name = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm") + ".md";
        const path = `${dir}/${name}`;
        Quickshell.execDetached(["sh", "-c", I18n.tr("mkdir -p \"$1\" && [ -e \"$2\" ] || printf '# Новая заметка\n\n' > \"$2\""), "_", dir, path]);
        refreshLater.restart();
        return path;
    }

    function remove(path: string): void {
        Quickshell.execDetached(["rm", "-f", path]);
        refreshLater.restart();
    }

    Timer { id: refreshLater; interval: 300; onTriggered: root.refresh() }

    Process {
        id: scan
        command: ["sh", "-c", `mkdir -p "$1"; cd "$1" && find . -maxdepth 1 -name '*.md' -printf '%T@\t%f\n' | sort -rn`, "_", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(Boolean).map(l => {
                const [t, f] = l.split("\t");
                return { path: `${root.dir}/${f}`, name: f.replace(/\.md$/, ""), mtime: new Date(Number(t) * 1000) };
            })
        }
    }

    Component.onCompleted: refresh()
}
