import QtQuick
import Quickshell.Io

// Одноразовый процесс: запускается сразу, отдаёт весь вывод в done(text, code) и удаляет себя.
Process {
    id: root
    property var done: null
    running: true
    stdout: StdioCollector { id: col }
    onExited: code => {
        const f = root.done;
        Qt.callLater(() => { if (f) f(col.text, code); root.destroy(); });
    }
}
