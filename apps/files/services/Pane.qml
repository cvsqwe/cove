import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.kit

// Одна вкладка: где мы, история, список файлов (отсортированный и отфильтрованный), выделение.
// mode: dir — папка (следим за изменениями сами через FolderListModel), search — результаты fd, trash — корзина.
Item {
    id: root

    property string path: Cove.home
    property string mode: "dir"
    property string query: ""
    property string filter: ""            // быстрый фильтр по имени в текущей папке
    property var history: []
    property var fwd: []
    property var raw: []
    property var entries: []
    property var sel: ({})                // путь → true
    readonly property int selCount: Object.keys(sel).length
    property int cursor: -1               // индекс «фокуса» клавиатуры
    property int anchor: -1               // начало выделения с Shift
    property bool loading: false
    property string error: ""
    property string focusAfter: ""        // выделить этот путь, когда список загрузится

    readonly property string title: mode === "trash" ? "Корзина" : mode === "search" ? "Поиск: " + query
        : path === Cove.home ? "Домашняя папка" : path === "/" ? "Компьютер" : path.split("/").pop()
    readonly property bool canBack: history.length > 0
    readonly property bool canForward: fwd.length > 0

    function url(p: string): string { return "file://" + encodeURI(p).replace(/#/g, "%23").replace(/\?/g, "%3F"); }

    // ---------- переходы ----------

    function norm(p: string): string {
        if (p.startsWith("file://")) p = decodeURIComponent(p.slice(7));
        if (p.startsWith("~")) p = Cove.home + p.slice(1);
        p = p.replace(/\/+/g, "/");
        if (p.length > 1 && p.endsWith("/")) p = p.slice(0, -1);
        return p || "/";
    }
    function state(): var { return { path, mode, query }; }
    function restoreState(s: var): void {
        mode = s.mode; query = s.query; path = s.path;
        load();
    }
    function go(p: string): void {
        p = norm(p);
        if (p === path && mode === "dir") return;
        history = history.concat([state()]);
        fwd = [];
        mode = "dir";
        path = p;
        load();
    }
    // «/a» и «/a/b/c» → «/a/b»: какую папку подсветить, вернувшись наверх
    function childOf(parent: string, p: string): string {
        const pre = parent === "/" ? "/" : parent + "/";
        if (!p.startsWith(pre) || p === parent) return "";
        return pre + p.slice(pre.length).split("/")[0];
    }
    function back(): void {
        if (!history.length) return;
        fwd = fwd.concat([state()]);
        const s = history[history.length - 1];
        history = history.slice(0, -1);
        focusAfter = mode === "dir" && s.mode === "dir" ? childOf(s.path, path) : "";
        restoreState(s);
    }
    function forward(): void {
        if (!fwd.length) return;
        history = history.concat([state()]);
        const s = fwd[fwd.length - 1];
        fwd = fwd.slice(0, -1);
        restoreState(s);
    }
    function up(): void {
        if (mode !== "dir") { go(path); return; }
        if (path === "/") return;
        const from = path;
        go(path.slice(0, path.lastIndexOf("/")) || "/");
        focusAfter = from;   // подсветить папку, из которой вышли
    }
    function search(q: string): void {
        q = q.trim();
        if (!q) { if (mode === "search") back(); return; }
        if (mode !== "search") history = history.concat([state()]);
        fwd = [];
        mode = "search";
        query = q;
        load();
    }
    function showTrash(): void {
        if (mode === "trash") return;
        history = history.concat([state()]);
        fwd = [];
        mode = "trash";
        load();
    }

    function load(): void {
        sel = ({});
        cursor = -1;
        anchor = -1;
        filter = "";
        error = "";
        if (mode === "dir") {
            loading = true;
            raw = [];
            entries = [];
            access.running = false;
            access.command = ["sh", "-c", '[ -d "$1" ] || { echo missing; exit; }; [ -r "$1" ] && [ -x "$1" ] || echo denied', "_", path];
            access.running = true;
        } else if (mode === "search") {
            loading = true;
            entries = [];
            const q = query;
            Ops.fm(["search", path, q, Prefs.showHidden ? "1" : ""], v => {
                if (mode !== "search" || query !== q) return;
                raw = (v ?? []).map(e => Object.assign(e, { mime: Mime.of(e.name, e.dir) }));
                loading = false;
                apply();
            });
        } else if (mode === "trash") {
            loading = true;
            entries = [];
            Ops.fm(["trash"], v => {
                if (mode !== "trash") return;
                raw = (v ?? []).map(e => Object.assign(e, { mime: Mime.of(e.name, e.dir) }));
                loading = false;
                apply();
            });
        }
    }
    function reload(): void {
        if (mode === "dir") rebuild();
        else { const keep = sel; load(); sel = keep; }
    }

    Process {
        id: access
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.error = t === "missing" ? "Такой папки нет" : t === "denied" ? "Нет доступа к этой папке" : "";
                if (root.error) root.loading = false;
            }
        }
    }

    // ---------- список ----------

    FolderListModel {
        id: model
        folder: root.mode === "dir" && root.error === "" ? root.url(root.path) : ""
        showDirsFirst: false
        showHidden: true
        showDotAndDotDot: false
        showOnlyReadable: false
        sortField: FolderListModel.Unsorted
        onStatusChanged: if (status === FolderListModel.Ready) rebuildTimer.restart()
        onCountChanged: if (status === FolderListModel.Ready) rebuildTimer.restart()
    }
    Timer { id: rebuildTimer; interval: 30; onTriggered: root.rebuild() }

    function rebuild(): void {
        if (mode !== "dir") return;
        const out = [];
        for (let i = 0; i < model.count; i++) {
            const name = model.get(i, "fileName");
            const dir = model.get(i, "fileIsDir");
            const m = model.get(i, "fileModified");
            out.push({ name, path: model.get(i, "filePath"), dir, size: dir ? -1 : model.get(i, "fileSize"),
                       mtime: m ? m.getTime() : 0, mime: Mime.of(name, dir) });
        }
        raw = out;
        loading = false;
        apply();
    }

    // естественное сравнение: «2» < «10», без учёта регистра
    function natural(a: string, b: string): int {
        const ax = a.toLowerCase().match(/(\d+|\D+)/g) ?? [], bx = b.toLowerCase().match(/(\d+|\D+)/g) ?? [];
        for (let i = 0; i < Math.min(ax.length, bx.length); i++) {
            const x = ax[i], y = bx[i];
            if (x === y) continue;
            const nx = /^\d/.test(x), ny = /^\d/.test(y);
            if (nx && ny) { const d = parseInt(x, 10) - parseInt(y, 10); if (d) return d; continue; }
            return x.localeCompare(y);
        }
        return ax.length - bx.length;
    }

    function apply(): void {
        const f = filter.toLowerCase();
        let list = raw.filter(e => (Prefs.showHidden || mode === "trash" || !e.name.startsWith(".")) && (!f || e.name.toLowerCase().includes(f)));
        const by = mode === "trash" && Prefs.sortBy === "name" ? "name" : Prefs.sortBy, desc = Prefs.sortDesc;
        const ext = n => { const i = n.lastIndexOf("."); return i > 0 ? n.slice(i + 1).toLowerCase() : ""; };
        list.sort((a, b) => {
            if (Prefs.foldersFirst && a.dir !== b.dir) return a.dir ? -1 : 1;
            let d = 0;
            if (by === "mtime") d = a.mtime - b.mtime;
            else if (by === "size") d = a.size - b.size;
            else if (by === "type") d = ext(a.name).localeCompare(ext(b.name));
            if (d === 0) d = natural(a.name, b.name);
            return desc ? -d : d;
        });
        // выделение и фокус переживают пересортировку и изменения на диске
        const curPath = cursor >= 0 ? entries[cursor]?.path : "";
        entries = list;
        const s = {};
        for (const e of list) if (sel[e.path]) s[e.path] = true;
        if (Object.keys(s).length !== selCount) sel = s;
        if (focusAfter) {
            const i = list.findIndex(e => e.path === focusAfter);
            if (i >= 0) { selectOnly(i); focusAfter = ""; }
        } else if (curPath) cursor = list.findIndex(e => e.path === curPath);
    }

    Connections {
        target: Prefs
        function onShowHiddenChanged(): void { if (root.mode === "search") root.load(); else root.apply(); }
        function onSortByChanged(): void { root.apply(); }
        function onSortDescChanged(): void { root.apply(); }
        function onFoldersFirstChanged(): void { root.apply(); }
    }
    onFilterChanged: apply()
    Connections {
        target: Mime
        function onExtChanged(): void { root.raw = root.raw.map(e => Object.assign(e, { mime: Mime.of(e.name, e.dir) })); root.apply(); }
    }
    Connections {
        target: Ops
        function onCreated(paths: var): void {
            // новая папка, вставка: выделить, когда появится в списке
            const mine = paths.filter(p => p.slice(0, p.lastIndexOf("/")) === root.path);
            if (!mine.length) return;
            root.focusAfter = mine[0];
            root.selectPaths(mine);
        }
    }

    // ---------- выделение ----------

    function selected(): var { return entries.filter(e => sel[e.path]); }
    function selectedPaths(): var { return selected().map(e => e.path); }
    function selectOnly(i: int): void {
        if (i < 0 || i >= entries.length) return;
        const s = {};
        s[entries[i].path] = true;
        sel = s;
        cursor = i;
        anchor = i;
    }
    function selectPaths(paths: var): void {
        const s = {};
        for (const p of paths) s[p] = true;
        sel = s;
    }
    function toggle(i: int): void {
        const s = Object.assign({}, sel);
        const p = entries[i].path;
        if (s[p]) delete s[p]; else s[p] = true;
        sel = s;
        cursor = i;
        anchor = i;
    }
    function selectRange(i: int, add: bool): void {
        if (anchor < 0) anchor = Math.max(0, cursor);
        const s = add ? Object.assign({}, sel) : {};
        const a = Math.min(anchor, i), b = Math.max(anchor, i);
        for (let k = a; k <= b; k++) s[entries[k].path] = true;
        sel = s;
        cursor = i;
    }
    function selectAll(): void {
        const s = {};
        for (const e of entries) s[e.path] = true;
        sel = s;
    }
    function clearSel(): void { sel = ({}); anchor = -1; }
}
