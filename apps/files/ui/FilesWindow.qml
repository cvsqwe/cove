import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.kit
import qs.services

// Окно Cove Files: вкладки, боковая панель, строка пути, поиск, файлы, сведения, операции.
FloatingWindow {
    id: win
    property string startPath: Cove.home
    property var tabs: []
    property int cur: 0
    readonly property var pane: tabs[cur] ?? null
    signal newWindow(string path)

    title: (pane ? pane.title : "Файлы") + " — Файлы"
    implicitWidth: Prefs.winW
    implicitHeight: Prefs.winH
    color: Cove.base
    onWidthChanged: saveSize.restart()
    onHeightChanged: saveSize.restart()
    Timer { id: saveSize; interval: 800; onTriggered: { Prefs.winW = win.width; Prefs.winH = win.height; } }

    // ---------- вкладки ----------
    Component { id: paneC; Pane {} }
    function addTab(path: string, focus_: bool): void {
        const p = paneC.createObject(win.contentItem, { path: path });
        p.load();
        const t = tabs.slice();
        t.splice(cur + 1, 0, p);
        tabs = t;
        if (focus_) cur = Math.min(cur + 1, tabs.length - 1);
        if (tabs.length === 1) cur = 0;
    }
    function closeTab(i: int): void {
        if (tabs.length <= 1) { win.visible = false; return; }
        const t = tabs.slice();
        const [p] = t.splice(i, 1);
        tabs = t;
        if (cur >= tabs.length) cur = tabs.length - 1;
        else if (i < cur) cur--;
        p.destroy();
    }
    Component.onCompleted: { addTab(startPath, true); Qt.callLater(() => items.forceActiveFocus()); }

    // ---------- действия ----------
    function openEntry(e: var, newTab: bool): void {
        if (!e) return;
        if (pane.mode === "trash") { quick.show(); return; }
        if (e.dir) { if (newTab) addTab(e.path, false); else pane.go(e.path); items.forceActiveFocus(); }
        else Ops.open([e.path]);
    }
    function urlsToPaths(urls: var): var {
        return Array.from(urls).map(u => String(u)).filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7)));
    }
    function onDropped(urls: var, dest: string, action: int): void {
        const paths = urlsToPaths(urls);
        if (!paths.length) return;
        if (dest === "trash:") { Ops.trash(paths); return; }
        const move = action !== Qt.CopyAction && items.internalDrag;
        Ops.transfer(paths, dest, move);
    }
    function removeSel(forever: bool): void {
        const sel = pane.selectedPaths();
        if (!sel.length) return;
        if (pane.mode === "trash" || forever) {
            confirm.ask(forever && pane.mode !== "trash" ? "Удалить насовсем?" : "Удалить из корзины?",
                (sel.length === 1 ? "«" + sel[0].split("/").pop() + "»" : Fmt.items(sel.length)) + " — восстановить будет нельзя.",
                "delete_forever", [{ text: "Отмена" }, { text: "Удалить", danger: true, primary: true, run: () => Ops.remove(sel) }]);
        } else if (pane.mode !== "trash") Ops.trash(sel);
    }
    function compress(): void {
        const sel = pane.selected();
        if (!sel.length) return;
        const dir = pane.mode === "dir" ? pane.path : sel[0].path.slice(0, sel[0].path.lastIndexOf("/"));
        const base = sel.length === 1 ? sel[0].name.replace(/\.[^.]+$/, "") || sel[0].name : "Архив";
        Ops.compress(sel.map(e => e.path), dir + "/" + base + ".zip");
    }
    function askName(mode: string): void {
        const e = mode === "rename" ? pane.selected()[0] : null;
        if (mode === "rename" && (!e || pane.selCount !== 1 || pane.mode === "trash")) return;
        nameDlg.mode = mode;
        nameDlg.target = e;
        nameDlg.title = mode === "rename" ? "Переименовать" : mode === "mkdir" ? "Новая папка" : "Новый файл";
        nameDlg.icon = mode === "rename" ? "edit" : mode === "mkdir" ? "create_new_folder" : "note_add";
        nameDlg.err = "";
        nameField.text = e ? e.name : mode === "mkdir" ? "Новая папка" : "Новый файл.txt";
        nameDlg.open();
        Qt.callLater(() => {
            nameField.input.forceActiveFocus();
            const t = nameField.text, dot = t.lastIndexOf(".");
            // выделить имя без расширения
            nameField.input.select(0, (e && !e.dir || mode === "touch") && dot > 0 ? dot : t.length);
        });
    }
    function commitName(): void {
        const name = nameField.text.trim();
        if (!name || name.includes("/") || name === "." || name === "..") { nameDlg.err = "Недопустимое имя"; return; }
        const cb = err => { if (err) nameDlg.err = err; else { nameDlg.close(); items.forceActiveFocus(); } };
        if (nameDlg.mode === "rename") { if (name === nameDlg.target.name) { nameDlg.close(); return; } Ops.rename(nameDlg.target.path, name, cb); }
        else if (nameDlg.mode === "mkdir") Ops.mkdir(pane.path, name, cb);
        else Ops.touch(pane.path, name, cb);
    }
    function isDefaultFm(cb: var): void {
        Ops.sh("xdg-mime query default inode/directory", [], o => cb(o.trim() === "cove-files.desktop"));
    }

    // ---------- меню ----------
    function entryMenu(e: var, x: real, y: real): void {
        const sel = pane.selected(), paths = sel.map(s => s.path), one = sel.length === 1;
        const L = [];
        if (pane.mode === "trash") {
            L.push({ text: "Восстановить", icon: "restore_from_trash", run: () => Ops.restore(sel.map(s => s.trashName)) });
            L.push({ text: "Посмотреть", icon: "visibility", shortcut: "Пробел", enabled: one, run: () => quick.show() });
            L.push({ sep: true });
            L.push({ text: "Удалить навсегда", icon: "delete_forever", danger: true, shortcut: "Del", run: () => removeSel(true) });
            menu.open_(x, y, L);
            return;
        }
        L.push({ text: "Открыть", icon: "open_in_new", shortcut: "Enter", run: () => { for (const s of sel) if (!s.dir) Ops.open([s.path]); if (one && e.dir) openEntry(e, false); } });
        if (e.dir) {
            L.push({ text: "Открыть в новой вкладке", icon: "tab", run: () => { for (const s of sel) if (s.dir) addTab(s.path, false); } });
            L.push({ text: "Открыть в терминале", icon: "terminal", enabled: one, run: () => Ops.terminal(e.path) });
        } else {
            L.push({ text: "Открыть с помощью", icon: "apps", more: true, run: () => appsMenu(e, paths, x, y) });
        }
        L.push({ text: "Посмотреть", icon: "visibility", shortcut: "Пробел", enabled: one, run: () => quick.show() });
        if (pane.mode === "search") L.push({ text: "Показать в папке", icon: "folder_open", enabled: one, run: () => { const d = e.path.slice(0, e.path.lastIndexOf("/")) || "/"; pane.go(d); pane.focusAfter = e.path; } });
        L.push({ sep: true });
        L.push({ text: "Вырезать", icon: "content_cut", shortcut: "Ctrl+X", run: () => Ops.copy(paths, true) });
        L.push({ text: "Копировать", icon: "content_copy", shortcut: "Ctrl+C", run: () => Ops.copy(paths, false) });
        if (one && e.dir) L.push({ text: "Вставить внутрь", icon: "content_paste", run: () => Ops.paste(e.path) });
        L.push({ text: "Переименовать", icon: "edit", shortcut: "F2", enabled: one, run: () => askName("rename") });
        L.push({ text: "Копировать путь", icon: "link", run: () => Ops.copyText(paths.join("\n")) });
        L.push({ sep: true });
        L.push({ text: "Сжать в ZIP", icon: "archive", run: () => compress() });
        if (sel.every(s => !s.dir && Fmt.isArchive(s.name)))
            L.push({ text: "Распаковать сюда", icon: "unarchive", run: () => Ops.extract(paths, pane.mode === "dir" ? pane.path : paths[0].slice(0, paths[0].lastIndexOf("/"))) });
        if (one && !e.dir && (Fmt.isImage(e.name) || Fmt.isVideo(e.name)))
            L.push({ text: "Сделать обоями", icon: "wallpaper", run: () => Ops.setWallpaper(e.path) });
        if (one && e.dir)
            L.push(Places.isBookmarked(e.path) ? { text: "Убрать из закладок", icon: "bookmark_remove", run: () => Places.removeBookmark(e.path) }
                : { text: "В закладки", icon: "bookmark_add", run: () => Places.addBookmark(e.path) });
        L.push({ sep: true });
        L.push({ text: "В корзину", icon: "delete", danger: true, shortcut: "Del", run: () => removeSel(false) });
        L.push({ text: "Свойства", icon: "info", run: () => Prefs.info = true });
        menu.open_(x, y, L);
    }
    function appsMenu(e: var, paths: var, x: real, y: real): void {
        Ops.fm(["apps", e.mime], apps => {
            const L = (apps ?? []).map(a => ({ text: a.name + (a.default ? "  · основное" : ""), img: a.icon || "application-x-executable", run: () => Ops.openWith(a.id, paths) }));
            if (!L.length) L.push({ text: "Нет подходящих приложений", icon: "block", enabled: false });
            const defs = (apps ?? []).filter(a => !a.default);
            if (defs.length) {
                L.push({ sep: true });
                L.push({ text: "Сделать основным…", icon: "star", more: true, run: () => {
                    menu.open_(x, y, defs.map(a => ({ text: a.name, img: a.icon || "application-x-executable",
                        run: () => Ops.fm(["setdefault", a.id, e.mime], null) })));
                } });
            }
            menu.open_(x, y, L);
        });
    }
    function backgroundMenu(x: real, y: real): void {
        const L = [];
        if (pane.mode === "trash") {
            L.push({ text: "Очистить корзину", icon: "delete_sweep", danger: true, enabled: pane.entries.length > 0, run: () => emptyTrash() });
            menu.open_(x, y, L);
            return;
        }
        if (pane.mode === "dir") {
            L.push({ text: "Новая папка", icon: "create_new_folder", shortcut: "Ctrl+Shift+N", run: () => askName("mkdir") });
            L.push({ text: "Новый файл", icon: "note_add", run: () => askName("touch") });
            L.push({ text: "Вставить", icon: "content_paste", shortcut: "Ctrl+V", run: () => Ops.paste(pane.path) });
            L.push({ sep: true });
            L.push({ text: "Открыть в терминале", icon: "terminal", run: () => Ops.terminal(pane.path) });
        }
        L.push({ text: "Выделить всё", icon: "select_all", shortcut: "Ctrl+A", run: () => pane.selectAll() });
        L.push({ sep: true });
        L.push({ text: "Сетка", check: Prefs.view === "grid", shortcut: "Ctrl+1", run: () => Prefs.view = "grid" });
        L.push({ text: "Список", check: Prefs.view === "list", shortcut: "Ctrl+2", run: () => Prefs.view = "list" });
        L.push({ text: "Скрытые файлы", check: Prefs.showHidden, shortcut: "Ctrl+H", run: () => Prefs.showHidden = !Prefs.showHidden });
        L.push({ text: "Сортировка", icon: "sort", more: true, run: () => sortMenu(x, y) });
        if (pane.mode === "dir") {
            L.push({ sep: true });
            L.push(Places.isBookmarked(pane.path) ? { text: "Убрать из закладок", icon: "bookmark_remove", run: () => Places.removeBookmark(pane.path) }
                : { text: "В закладки", icon: "bookmark_add", run: () => Places.addBookmark(pane.path) });
        }
        menu.open_(x, y, L);
    }
    function sortMenu(x: real, y: real): void {
        const s = (k, t) => ({ text: t, check: Prefs.sortBy === k, run: () => Prefs.sortBy = k });
        menu.open_(x, y, [s("name", "По имени"), s("mtime", "По дате изменения"), s("size", "По размеру"), s("type", "По типу"), { sep: true },
            { text: "По убыванию", check: Prefs.sortDesc, run: () => Prefs.sortDesc = !Prefs.sortDesc },
            { text: "Папки сначала", check: Prefs.foldersFirst, run: () => Prefs.foldersFirst = !Prefs.foldersFirst }]);
    }
    function emptyTrash(): void {
        confirm.ask("Очистить корзину?", "Всё в корзине будет удалено насовсем.", "delete_sweep",
            [{ text: "Отмена" }, { text: "Очистить", danger: true, primary: true, run: () => { Ops.emptyTrash(); Qt.callLater(() => pane.load()); } }]);
    }
    function mainMenu(x: real, y: real): void {
        isDefaultFm(def => {
            const L = [
                { text: "Новое окно", icon: "open_in_new", shortcut: "Ctrl+N", run: () => win.newWindow(pane.mode === "dir" ? pane.path : Cove.home) },
                { text: "Новая вкладка", icon: "tab", shortcut: "Ctrl+T", run: () => addTab(pane.mode === "dir" ? pane.path : Cove.home, true) },
                { sep: true },
                { text: "Скрытые файлы", check: Prefs.showHidden, shortcut: "Ctrl+H", run: () => Prefs.showHidden = !Prefs.showHidden },
                { text: "Панель сведений", check: Prefs.info, shortcut: "Ctrl+I", run: () => Prefs.info = !Prefs.info },
                { text: "Папки сначала", check: Prefs.foldersFirst, run: () => Prefs.foldersFirst = !Prefs.foldersFirst }
            ];
            if (!def) {
                L.push({ sep: true });
                L.push({ text: "Сделать основным файловым менеджером", icon: "star", run: () => Ops.sh("xdg-mime default cove-files.desktop inode/directory", [], null) });
            }
            menu.open_(x, y, L);
        });
    }

    Connections {
        target: Ops
        function onConflict(names: var, answer: var): void {
            confirm.ask(names.length === 1 ? "«" + names[0] + "» уже есть" : "Уже есть " + Fmt.items(names.length),
                names.length > 1 ? names.slice(0, 6).join(", ") + (names.length > 6 ? "…" : "") : "В папке назначения уже есть файл с таким именем.",
                "file_copy", [{ text: "Отмена", run: () => answer("") }, { text: "Пропустить", run: () => answer("skip") },
                    { text: "Заменить", danger: true, run: () => answer("replace") }, { text: "Оставить оба", primary: true, run: () => answer("rename") }]);
        }
        function onNoTrash(paths: var): void {
            confirm.ask("Здесь нет корзины", (paths.length === 1 ? "«" + paths[0].split("/").pop() + "»" : Fmt.items(paths.length))
                + " лежит на диске без корзины. Удалить насовсем? Восстановить будет нельзя.", "delete_forever",
                [{ text: "Отмена" }, { text: "Удалить", danger: true, primary: true, run: () => Ops.remove(paths) }]);
        }
        function onFailed(title: string, errors: var): void {
            confirm.ask(title + ": не всё получилось", errors.slice(0, 8).join("\n"), "error", [{ text: "Понятно", primary: true }]);
        }
    }

    // ---------- сочетания клавиш ----------
    Shortcut { sequence: "Ctrl+L"; onActivated: pathBar.edit() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { search.input.forceActiveFocus(); search.input.selectAll(); } }
    Shortcut { sequence: "Ctrl+T"; onActivated: win.addTab(win.pane.mode === "dir" ? win.pane.path : Cove.home, true) }
    Shortcut { sequence: "Ctrl+W"; onActivated: win.closeTab(win.cur) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: win.cur = (win.cur + 1) % win.tabs.length }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: win.cur = (win.cur - 1 + win.tabs.length) % win.tabs.length }
    Shortcut { sequence: "Ctrl+N"; onActivated: win.newWindow(win.pane.mode === "dir" ? win.pane.path : Cove.home) }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: if (win.pane.mode === "dir") win.askName("mkdir") }
    Shortcut { sequence: "Ctrl+I"; onActivated: Prefs.info = !Prefs.info }
    Shortcut { sequence: "F5"; onActivated: win.pane.reload() }
    Shortcut { sequence: "Alt+Home"; onActivated: win.pane.go(Cove.home) }
    Shortcut { sequence: "Ctrl+Q"; onActivated: win.visible = false }

    // ---------- раскладка ----------
    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar {
            id: side
            Layout.fillHeight: true
            Layout.preferredWidth: Prefs.sidebarWidth
            pane: win.pane
            onNavigate: p => { win.pane.go(p); items.forceActiveFocus(); }
            onOpenTrash: { win.pane.showTrash(); items.forceActiveFocus(); }
            onNewTab: p => win.addTab(p, false)
            onDropped: (u, d, a) => win.onDropped(u, d, a)
            onMenu: (it, x, y) => {
                const pt = side.mapToItem(win.contentItem, x, y);
                const L = [];
                if (it.trash) L.push({ text: "Очистить корзину", icon: "delete_sweep", danger: true, enabled: Places.trashCount > 0, run: () => win.emptyTrash() });
                else if (it.path) {
                    L.push({ text: "Открыть в новой вкладке", icon: "tab", run: () => win.addTab(it.path, true) });
                    L.push({ text: "Открыть в терминале", icon: "terminal", run: () => Ops.terminal(it.path) });
                    if (it.bookmark) L.push({ text: "Убрать из закладок", icon: "bookmark_remove", run: () => Places.removeBookmark(it.path) });
                }
                if (it.device) {
                    if (it.path) L.push({ text: it.device.removable ? "Извлечь" : "Отключить", icon: "eject", run: () => Places.unmount(it.device.path, it.device.removable, it.device.disk) });
                    else L.push({ text: "Подключить", icon: "usb", run: () => Places.mount(it.device.path, null) });
                }
                if (L.length) menu.open_(pt.x, pt.y, L);
            }
            // граница-ручка: тянуть ширину
            Rectangle {
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Cove.surface0
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    cursorShape: Qt.SplitHCursor
                    property real sx
                    onPressed: m => sx = m.x
                    onPositionChanged: m => Prefs.sidebarWidth = Math.max(150, Math.min(360, Prefs.sidebarWidth + m.x - sx))
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---- панель инструментов ----
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 10
                Layout.bottomMargin: 6
                spacing: 6
                KButton { icon: "arrow_back"; flat: true; enabled: win.pane?.canBack ?? false; tip: "Назад (Alt+←)"; onClicked: win.pane.back() }
                KButton { icon: "arrow_forward"; flat: true; enabled: win.pane?.canForward ?? false; tip: "Вперёд (Alt+→)"; onClicked: win.pane.forward() }
                KButton { icon: "arrow_upward"; flat: true; enabled: win.pane?.mode !== "dir" || win.pane?.path !== "/"; tip: "Наверх (Alt+↑)"; onClicked: win.pane.up() }
                PathBar {
                    id: pathBar
                    Layout.fillWidth: true
                    pane: win.pane
                    onNavigate: p => { win.pane.go(p); items.forceActiveFocus(); }
                    onDropped: (u, d, a) => win.onDropped(u, d, a)
                }
                KField {
                    id: search
                    Layout.preferredWidth: 220
                    icon: "search"
                    placeholder: win.pane?.mode === "trash" ? "Фильтр" : "Поиск"
                    onTextChanged: if (win.pane && win.pane.mode !== "search") win.pane.filter = text
                    onAccepted: if (win.pane.mode !== "trash") { win.pane.search(text); text = ""; items.forceActiveFocus(); }
                    onEscaped: { text = ""; items.forceActiveFocus(); }
                    input.Keys.onDownPressed: items.forceActiveFocus()
                    KTip { text: "Набирайте — фильтр по этой папке, Enter — поиск во всех вложенных"; shown: search.input.activeFocus && search.text.length > 0 }
                }
                KButton { icon: Prefs.view === "grid" ? "grid_view" : "view_list"; flat: true; tip: Prefs.view === "grid" ? "Сетка (Ctrl+2 — список)" : "Список (Ctrl+1 — сетка)"; onClicked: Prefs.view = Prefs.view === "grid" ? "list" : "grid" }
                KButton { icon: "info"; flat: true; active: Prefs.info; tip: "Сведения (Ctrl+I)"; onClicked: Prefs.info = !Prefs.info }
                KButton {
                    id: moreBtn
                    icon: "more_vert"
                    flat: true
                    onClicked: { const p = moreBtn.mapToItem(win.contentItem, 0, moreBtn.height + 4); win.mainMenu(p.x - 220, p.y); }
                }
            }

            // ---- вкладки (если их больше одной) ----
            RowLayout {
                visible: win.tabs.length > 1
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 6
                spacing: 4
                Repeater {
                    model: win.tabs
                    Rectangle {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool on: index === win.cur
                        Layout.fillWidth: true
                        Layout.maximumWidth: 260
                        implicitHeight: 30
                        radius: Cove.radiusSmall + 2
                        color: on ? Cove.surface0 : tm.containsMouse ? Cove.alpha(Cove.surface0, 0.5) : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 4
                            spacing: 6
                            KIcon { icon: tab.modelData.mode === "trash" ? "delete" : tab.modelData.mode === "search" ? "search" : "folder"; size: 14; color: tab.on ? Cove.accent : Cove.overlay1; fill: tab.on }
                            KText { Layout.fillWidth: true; text: tab.modelData.title; font.pixelSize: Cove.fontSizeSmall + 1; color: tab.on ? Cove.text : Cove.subtext0 }
                            KButton { icon: "close"; flat: true; implicitWidth: 22; implicitHeight: 22; onClicked: win.closeTab(tab.index) }
                        }
                        MouseArea {
                            id: tm
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: m => m.button === Qt.MiddleButton ? win.closeTab(tab.index) : (win.cur = tab.index)
                        }
                    }
                }
                KButton { icon: "add"; flat: true; implicitWidth: 30; implicitHeight: 30; tip: "Новая вкладка (Ctrl+T)"; onClicked: win.addTab(win.pane.mode === "dir" ? win.pane.path : Cove.home, true) }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Cove.surface0 }

            // ---- файлы + сведения ----
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Items {
                    id: items
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    pane: win.pane
                    focus: true
                    onOpen: (e, t) => win.openEntry(e, t)
                    onMenu: (e, x, y) => { const p = items.mapToItem(win.contentItem, x, y); e ? win.entryMenu(e, p.x, p.y) : win.backgroundMenu(p.x, p.y); }
                    onQuickLook: if (win.pane.cursor >= 0) quick.show()
                    onDropped: (u, d, a) => win.onDropped(u, d, a)
                    onRename: win.askName("rename")
                    onRemove: f => win.removeSel(f)
                }
                Rectangle { visible: Prefs.info; Layout.fillHeight: true; width: 1; color: Cove.surface0 }
                InfoPanel {
                    visible: Prefs.info
                    Layout.fillHeight: true
                    Layout.preferredWidth: 270
                    pane: win.pane
                }
            }

            // ---- строка состояния ----
            Rectangle { Layout.fillWidth: true; height: 1; color: Cove.surface0 }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 10
                Layout.preferredHeight: 30
                spacing: 10
                KText {
                    readonly property var p: win.pane
                    readonly property var s: p ? p.selected() : []
                    text: !p ? "" : (Fmt.items(p.entries.length) + (s.length ? "  ·  выбрано " + s.length
                        + (s.every(x => !x.dir) ? " (" + Fmt.size(s.reduce((a, x) => a + x.size, 0)) + ")" : "") : ""))
                    color: Cove.overlay1
                    font.pixelSize: Cove.fontSizeSmall
                }
                Item { Layout.fillWidth: true }
                KText { id: free; color: Cove.overlay1; font.pixelSize: Cove.fontSizeSmall }
                KButton { visible: Prefs.view === "grid"; icon: "zoom_out"; flat: true; implicitWidth: 26; implicitHeight: 26; onClicked: items.zoom(-1) }
                KButton { visible: Prefs.view === "grid"; icon: "zoom_in"; flat: true; implicitWidth: 26; implicitHeight: 26; onClicked: items.zoom(1) }
            }
        }
    }

    // свободное место на диске текущей папки
    function refreshFree(): void {
        if (!pane || pane.mode !== "dir") { free.text = ""; return; }
        Ops.fm(["df", pane.path], v => free.text = v?.free !== undefined ? "свободно " + Fmt.size(v.free) + " из " + Fmt.size(v.total) : "");
    }
    Connections { target: win.pane; function onPathChanged(): void { win.refreshFree(); } }
    onPaneChanged: { refreshFree(); search.text = ""; }
    Connections { target: Ops; function onJobsChanged(): void { if (!Ops.jobs.length) win.refreshFree(); } }

    // ---------- поверх ----------
    JobsCard {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        anchors.bottomMargin: 44
        z: 50
    }
    QuickLook {
        id: quick
        anchors.fill: parent
        z: 60
        pane: win.pane
        onClosed: items.forceActiveFocus()
    }
    KMenu { id: menu; parent: win.contentItem; onClosed: if (!quick.visible) items.forceActiveFocus() }

    KDialog {
        id: confirm
        function ask(t: string, m: string, ic: string, b: var): void {
            title = t; message = m; icon = ic; buttons = b; open();
        }
    }
    KDialog {
        id: nameDlg
        property string mode: "rename"
        property var target: null
        property string err: ""
        buttons: [{ text: "Отмена" }, { text: mode === "rename" ? "Переименовать" : "Создать", primary: true, keep: true, run: () => win.commitName() }]
        onClosed: items.forceActiveFocus()
        KField {
            id: nameField
            Layout.fillWidth: true
            onAccepted: win.commitName()
            onEscaped: nameDlg.close()
            onTextChanged: nameDlg.err = ""
        }
        KText { visible: nameDlg.err !== ""; text: nameDlg.err; color: Cove.red; font.pixelSize: Cove.fontSizeSmall }
    }
}
