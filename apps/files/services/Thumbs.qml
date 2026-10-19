pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Миниатюры: демон helpers/thumbs.py (кэш freedesktop). request(path) → сразу из памяти или позже сигналом ready.
Singleton {
    id: root
    property var cache: ({})      // путь → «file://…png» или "" (не вышло)
    property var asked: ({})
    signal ready(string path, string thumb)

    readonly property var exts: ["jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff", "avif", "heic", "jxl",
        "mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv", "flv", "mpg", "mpeg", "3gp", "mp3", "flac", "m4a", "ogg", "opus", "pdf"]
    function can(name: string): bool {
        const i = name.lastIndexOf(".");
        return i > 0 && exts.includes(name.slice(i + 1).toLowerCase());
    }

    // mtime в ключе: файл изменился — миниатюра заново
    function request(path: string, mtime: real): string {
        const key = path + "|" + mtime;
        if (key in cache) return cache[key];
        if (!asked[key]) {
            asked[key] = true;
            keys[path] = key;
            daemon.write(path + "\n");
        }
        return "";
    }
    property var keys: ({})

    Timer { id: restart; interval: 1000; onTriggered: { root.asked = ({}); daemon.running = true; } }

    Process {
        id: daemon
        command: ["python3", Quickshell.shellPath("helpers/thumbs.py")]
        stdinEnabled: true
        running: true
        onExited: restart.start()   // упал — поднимем снова
        stdout: SplitParser {
            onRead: ln => {
                const i = ln.indexOf("\t");
                const p = ln.slice(0, i), t = ln.slice(i + 1);
                const url = t ? "file://" + t : "";
                root.cache[root.keys[p] ?? p] = url;
                if (url) root.ready(p, url);
            }
        }
    }
}
