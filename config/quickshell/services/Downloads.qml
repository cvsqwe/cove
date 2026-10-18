pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Идущие загрузки браузера: недокачанные файлы в папке загрузок (Firefox — *.part,
// Chromium — *.crdownload). Сколько всего и с какой скоростью; конец загрузки — тост в острове.
Singleton {
    id: root

    property string dir: ""
    property var files: []          // [{ name, size }]
    property real speed: 0          // байт/с
    property real lastTotal: -1
    property real lastTime: 0

    readonly property int count: files.length
    readonly property bool active: count > 0
    readonly property string name: count === 1 ? files[0].name : ""

    signal completed(string name)

    // XDG_DOWNLOAD_DIR (обычно ~/Downloads или ~/Загрузки)
    Process {
        running: true
        command: ["sh", "-c", 'xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads"']
        stdout: StdioCollector { onStreamFinished: root.dir = text.trim() }
    }

    Process {
        id: scan
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "(", "-name", "*.part", "-o", "-name", "*.crdownload", ")", "-printf", "%s\t%f\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now();
                const list = text.split("\n").filter(s => s).map(l => {
                    const [size, ...rest] = l.split("\t");
                    return { size: Number(size), name: rest.join("\t").replace(/\.(part|crdownload)$/, "") };
                });
                const total = list.reduce((s, f) => s + f.size, 0);
                if (root.lastTotal >= 0 && list.length && now > root.lastTime)
                    root.speed = 0.6 * root.speed + 0.4 * Math.max(0, (total - root.lastTotal) / ((now - root.lastTime) / 1000));
                else if (!list.length) root.speed = 0;
                // что пропало из списка — докачалось (или отменено: тогда и обычного файла нет)
                for (const f of root.files)
                    if (!list.some(g => g.name === f.name)) done.check(f.name);
                root.lastTotal = list.length ? total : -1;
                root.lastTime = now;
                root.files = list;
            }
        }
    }
    Timer {
        interval: root.active ? 1000 : 2500
        running: root.dir !== ""
        repeat: true
        onTriggered: scan.running = true
    }

    // докачанный файл существует и не пустой → сообщаем
    Process {
        id: done
        property var queue: []
        function check(name: string): void {
            queue = [...queue, name];
            if (!running) next();
        }
        function next(): void {
            if (!queue.length) return;
            current = queue[0];
            queue = queue.slice(1);
            running = true;
        }
        property string current: ""
        command: ["test", "-s", root.dir + "/" + current]
        onExited: code => {
            if (code === 0) root.completed(current);
            next();
        }
    }

    function human(bytes: real): string {
        const u = [I18n.tr("Б"), I18n.tr("КБ"), I18n.tr("МБ"), I18n.tr("ГБ")];
        let i = 0;
        while (bytes >= 1024 && i < u.length - 1) { bytes /= 1024; i++; }
        return (i > 1 ? bytes.toFixed(1) : Math.round(bytes)) + " " + u[i];
    }
}
