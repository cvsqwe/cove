pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Полка в острове: перетащил файл (или текст, ссылку) на капсулу — он лёг на полку,
// оттуда его можно утащить в любое окно. Файлы не копируются, полка хранит пути (Store.shelf).
Singleton {
    id: root

    readonly property var items: Store.shelf
    readonly property int count: items.length
    property bool dragging: false   // с полки сейчас что-то тащат: остров не закрывается
    property int serial: 0           // что-то положили на полку
    property bool shown: false       // полка раскрыта в острове (после броска, по клику на значок)
    property string where: ""        // на острове какого монитора
    function showOn(screen: string): void { where = screen; shown = true; }
    function focusedScreen(): string { return Hyprland.focusedMonitor?.name ?? ""; }

    function uri(p: string): string { return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F"); }
    function pathOf(u: string): string { return decodeURIComponent(u.replace(/^file:\/\/(localhost)?/, "")); }
    function baseName(p: string): string { return p.replace(/\/+$/, "").split("/").pop() || p; }
    function isImage(it): bool { return !!it.path && /^image\//.test(it.mime ?? ""); }

    // из DropEvent: файлы, ссылки, просто текст
    function drop(urls: var, text: string): void {
        const add = [];
        for (const raw of Array.from(urls ?? [])) {
            const u = raw.toString();
            if (u.startsWith("file:")) {
                const p = pathOf(u);
                add.push({ path: p, name: baseName(p), mime: "" });
            } else if (u) {
                add.push({ text: u, name: u.replace(/^\w+:\/\/(www\.)?/, "").slice(0, 60) });
            }
        }
        const t = (text ?? "").trim();
        if (!add.length && t)
            add.push({ text: t, name: t.replace(/\s+/g, " ").slice(0, 60) });
        if (!add.length) return;

        const keyOf = it => it.path ?? ("t:" + it.text);
        const have = new Set(items.map(keyOf));
        const fresh = add.filter(it => !have.has(keyOf(it)));
        if (fresh.length) {
            Store.shelf = items.concat(fresh).slice(-Settings.island.shelfMax);
            const paths = fresh.filter(it => it.path).map(it => it.path);
            if (paths.length) {
                mime.command = ["file", "-b", "-L", "--mime-type", "--", ...paths];
                mime.paths = paths;
                mime.running = true;
            }
        }
        serial++;
    }

    function remove(it): void {
        Store.shelf = items.filter(x => it.path ? x.path !== it.path : x.text !== it.text);
    }
    function clear(): void { Store.shelf = []; }

    function open(it): void {
        if (it.path) Qt.openUrlExternally(uri(it.path));
        else if (/^\w+:\/\//.test(it.text)) Qt.openUrlExternally(it.text);
        else Quickshell.execDetached(["wl-copy", "--", it.text]);
    }

    // данные для Drag.mimeData: файлы — uri-list (+ пути текстом для терминала), текст — как есть
    function mimeData(list: var): var {
        const files = list.filter(it => it.path);
        if (files.length)
            return { "text/uri-list": files.map(it => uri(it.path)).join("\r\n") + "\r\n",
                     "text/plain": files.map(it => it.path).join("\n") };
        const t = list.map(it => it.text).join("\n");
        return /^\w+:\/\/\S+$/.test(t) ? { "text/uri-list": t + "\r\n", "text/plain": t } : { "text/plain": t };
    }

    // После перетаскивания наружу. Qt на Wayland почти всегда сообщает IgnoreAction, даже если файл
    // приняли, поэтому смотрим, где отпустили: над островом — передумали, в другом месте — забрали.
    property bool overIsland: false
    function finished(list: var, action: int): void {
        dragging = false;
        const back = overIsland;
        overIsland = false;
        if (back || !Settings.island.shelfRemove) return;
        const gone = new Set(list.map(it => it.path ?? ("t:" + it.text)));
        Store.shelf = items.filter(x => !gone.has(x.path ?? ("t:" + x.text)));
    }

    IpcHandler {
        target: "shelf"
        function toggle(): void { if (root.shown) root.shown = false; else root.showOn(root.focusedScreen()); }
        function add(path: string): void { root.drop([root.uri(path)], ""); root.showOn(root.focusedScreen()); }
        function clear(): void { root.clear(); }
        function list(): string { return root.items.map(it => it.path ?? it.text).join("\n"); }
    }

    Process {
        id: mime
        property var paths: []
        stdout: StdioCollector {
            onStreamFinished: {
                const types = text.trim().split("\n");
                const by = {};
                mime.paths.forEach((p, i) => by[p] = types[i] ?? "");
                Store.shelf = root.items.map(it => it.path && by[it.path] !== undefined ? Object.assign({}, it, { mime: by[it.path] }) : it);
            }
        }
    }

    // при старте убираем с полки то, чего больше нет на диске
    Process {
        id: prune
        stdout: StdioCollector {
            onStreamFinished: {
                const alive = new Set(text.split("\n").filter(s => s));
                Store.shelf = root.items.filter(it => !it.path || alive.has(it.path));
            }
        }
    }
    function init(): void {
        const paths = items.filter(it => it.path).map(it => it.path);
        if (!paths.length) return;
        prune.command = ["sh", "-c", 'for p; do [ -e "$p" ] && printf "%s\\n" "$p"; done', "_", ...paths];
        prune.running = true;
    }
}
