pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.kit

// Боковая панель: стандартные папки, закладки (общие с GTK: ~/.config/gtk-3.0/bookmarks), диски, корзина.
Singleton {
    id: root
    readonly property string home: Cove.home
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/Trash"

    // стандартные папки, которые реально есть; имена — из user-dirs.dirs, иначе привычные английские
    property var userDirs: []
    property var bookmarks: []    // [{ path, name }]
    property var devices: []      // [{ path, label, size, mount, fs, removable, disk }]
    readonly property int trashCount: trashModel.count

    function std(): var {
        return [
            { key: "DESKTOP", def: "Desktop", name: "Рабочий стол", icon: "desktop_windows" },
            { key: "DOCUMENTS", def: "Documents", name: "Документы", icon: "description" },
            { key: "DOWNLOAD", def: "Downloads", name: "Загрузки", icon: "download" },
            { key: "PICTURES", def: "Pictures", name: "Изображения", icon: "image" },
            { key: "MUSIC", def: "Music", name: "Музыка", icon: "music_note" },
            { key: "VIDEOS", def: "Videos", name: "Видео", icon: "movie" }
        ];
    }

    function addBookmark(path: string): void {
        if (bookmarks.some(b => b.path === path)) return;
        bookmarks = bookmarks.concat([{ path, name: path.split("/").pop() }]);
        saveBookmarks();
    }
    function removeBookmark(path: string): void {
        bookmarks = bookmarks.filter(b => b.path !== path);
        saveBookmarks();
    }
    function moveBookmark(from: int, to: int): void {
        const b = bookmarks.slice();
        const [x] = b.splice(from, 1);
        b.splice(to, 0, x);
        bookmarks = b;
        saveBookmarks();
    }
    function isBookmarked(path: string): bool { return bookmarks.some(b => b.path === path); }
    function saveBookmarks(): void {
        bmFile.setText(bookmarks.map(b => "file://" + encodeURI(b.path) + (b.name !== b.path.split("/").pop() ? " " + b.name : "")).join("\n") + "\n");
    }

    function refreshDevices(): void { devProc.running = true; }
    function mount(dev: string, then_: var): void {
        const p = proc.createObject(root, { command: ["udisksctl", "mount", "--no-user-interaction", "-b", dev] });
        p.done = (out, code) => {
            // без прав — повторить с запросом пароля (polkit)
            if (code !== 0) {
                const q = proc.createObject(root, { command: ["udisksctl", "mount", "-b", dev] });
                q.done = () => { refreshDevices(); if (then_) then_(); };
            } else { refreshDevices(); if (then_) then_(); }
        };
    }
    function unmount(dev: string, eject: bool, disk: string): void {
        const p = proc.createObject(root, { command: ["sh", "-c", 'udisksctl unmount -b "$1" && { [ "$2" = 1 ] && udisksctl power-off -b "$3" || true; }', "_", dev, eject ? "1" : "0", disk] });
        p.done = (out, code) => {
            refreshDevices();
            if (code !== 0) Quickshell.execDetached(["notify-send", "-a", "Cove Files", "-i", "drive-removable-media", "Не удалось извлечь", "Устройство занято: закройте открытые на нём файлы."]);
        };
    }

    Component { id: proc; Proc {} }

    // user-dirs.dirs: XDG_DOCUMENTS_DIR="$HOME/Документы"
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/user-dirs.dirs"
        printErrors: false
        onLoaded: root.buildDirs(text())
        onLoadFailed: root.buildDirs("")
    }
    function buildDirs(txt: string): void {
        const map = {};
        for (const ln of txt.split("\n")) {
            const m = ln.match(/^XDG_(\w+)_DIR="(.*)"/);
            if (m) map[m[1]] = m[2].replace("$HOME", home);
        }
        dirCheck.command = ["sh", "-c", 'for d; do [ -d "$d" ] && echo "$d"; done', "_",
            ...std().map(s => map[s.key] ?? home + "/" + s.def)];
        dirCheck.map = map;
        dirCheck.running = true;
    }
    Process {
        id: dirCheck
        property var map: ({})
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = text.split("\n").filter(Boolean);
                root.userDirs = root.std().map(s => Object.assign({ path: dirCheck.map[s.key] ?? root.home + "/" + s.def }, s))
                    .filter(s => ok.includes(s.path) && s.path !== root.home);
            }
        }
    }

    FileView {
        id: bmFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/gtk-3.0/bookmarks"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.bookmarks = text().split("\n").filter(l => l.startsWith("file://")).map(l => {
                const sp = l.indexOf(" ");
                const path = decodeURIComponent((sp > 0 ? l.slice(0, sp) : l).slice(7));
                return { path, name: sp > 0 ? l.slice(sp + 1) : path.split("/").pop() };
            });
        }
    }

    Process {
        id: devProc
        command: ["python3", Quickshell.shellPath("helpers/fm.py"), "devices"]
        stdout: StdioCollector { onStreamFinished: { try { root.devices = JSON.parse(text); } catch (e) {} } }
    }
    // события udisks: вставили флешку, подключили, извлекли
    Process {
        running: true
        command: ["udisksctl", "monitor"]
        stdout: SplitParser { onRead: devDebounce.restart() }
    }
    Timer { id: devDebounce; interval: 700; onTriggered: root.refreshDevices() }

    FolderListModel {
        id: trashModel
        folder: "file://" + root.trashDir + "/info"
        showHidden: true
        nameFilters: ["*.trashinfo"]
    }

    Component.onCompleted: refreshDevices()
}
