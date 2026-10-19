import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.kit
import qs.services

// Содержимое папки: сетка или список. Вся мышь — в одном слое поверх вида (клик, Ctrl/Shift, рамка,
// двойной клик, перетаскивание наружу), клавиатура — здесь же. Делегаты только рисуют.
FocusScope {
    id: root
    property var pane: null
    readonly property bool grid: Prefs.view === "grid"
    readonly property var view: loader.item
    readonly property bool activeFocus_: activeFocus
    property int hovered: -1
    property var dragPaths: []          // что сейчас тащим (на себя не бросаем)
    property bool internalDrag: false
    readonly property int rowH: 36
    readonly property int headerH: 32
    readonly property int colDate: 150
    readonly property int colSize: 80
    readonly property int colType: 150

    signal open(var entry, bool newTab)
    signal menu(var entry, real x, real y)    // entry = null — меню фона
    signal quickLook()
    signal dropped(var urls, string dest, int action)
    signal rename()
    signal remove(bool forever)

    function positionAt(i: int): void { if (view && i >= 0) view.positionViewAtIndex(i, ListView.Contain); }
    function cols(): int { return grid && view ? Math.max(1, Math.floor(view.width / view.cellWidth)) : 1; }

    // ---------- фон: бросить файлы в текущую папку ----------
    DropArea {
        anchors.fill: parent
        enabled: root.pane && root.pane.mode === "dir"
        keys: ["text/uri-list"]
        onDropped: e => { root.dropped(e.urls, root.pane.path, e.proposedAction); e.acceptProposedAction(); }
    }

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: root.grid ? gridC : listC
        onLoaded: if (root.pane) root.positionAt(root.pane.cursor)
    }

    // пусто / ошибка / загрузка
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.pane && root.pane.entries.length === 0 && !root.pane.loading
        spacing: 10
        KIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: root.pane?.error ? "block" : root.pane?.mode === "trash" ? "delete" : root.pane?.mode === "search" ? "search_off" : root.pane?.filter ? "filter_alt_off" : "folder_open"
            size: 54
            color: Cove.surface2
        }
        KText {
            Layout.alignment: Qt.AlignHCenter
            text: root.pane?.error || (root.pane?.mode === "trash" ? "Корзина пуста" : root.pane?.mode === "search" ? "Ничего не нашлось"
                : root.pane?.filter ? "Нет совпадений" : "Папка пуста")
            color: Cove.overlay1
            font.pixelSize: Cove.fontSizeLarge
        }
    }
    KBusy {
        anchors.centerIn: parent
        visible: root.pane?.loading ?? false
    }

    Component {
        id: gridC
        GridView {
            id: g
            clip: true
            focus: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.pane?.entries ?? []
            topMargin: 8
            bottomMargin: 40
            leftMargin: 8
            rightMargin: 8
            readonly property int minCell: Prefs.iconSize + 40
            cellWidth: Math.floor((width - 16) / Math.max(1, Math.floor((width - 16) / minCell)))
            cellHeight: Prefs.iconSize + 62
            cacheBuffer: 600
            ScrollBar.vertical: KScrollBar {}
            delegate: GridCell { items: root }
            ItemsMouse { view: g; items: root }
            ItemsBand { view: g; items: root }
        }
    }
    Component {
        id: listC
        ListView {
            id: l
            clip: true
            focus: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.pane?.entries ?? []
            bottomMargin: 40
            cacheBuffer: 600
            ScrollBar.vertical: KScrollBar {}
            headerPositioning: ListView.OverlayHeader
            header: ListHeader { items: root; z: 3 }
            delegate: ListRow { items: root }
            ItemsMouse { view: l; items: root; anchors.topMargin: root.headerH }
            ItemsBand { view: l; items: root }
        }
    }

    // ---------- рамка выделения (в координатах содержимого) ----------
    property point bandA: Qt.point(0, 0)
    property point bandB: Qt.point(0, 0)
    property bool banding: false
    property var bandBase: ({})

    function bandSelect(): void {
        const x1 = Math.min(bandA.x, bandB.x), x2 = Math.max(bandA.x, bandB.x);
        const y1 = Math.min(bandA.y, bandB.y), y2 = Math.max(bandA.y, bandB.y);
        const s = Object.assign({}, bandBase);
        const list = pane.entries;
        if (grid) {
            const cw = view.cellWidth, ch = view.cellHeight, c = cols();
            const r1 = Math.max(0, Math.floor(y1 / ch)), r2 = Math.floor(y2 / ch);
            for (let r = r1; r <= r2; r++)
                for (let k = 0; k < c; k++) {
                    const i = r * c + k;
                    if (i >= list.length) break;
                    const cx = k * cw, cy = r * ch;
                    // попадание в «тело» ячейки, без пустых полей
                    if (cx + cw - 8 > x1 && cx + 8 < x2 && cy + ch - 8 > y1 && cy + 8 < y2) s[list[i].path] = true;
                }
        } else {
            const a = Math.max(0, Math.floor(y1 / rowH)), b = Math.min(list.length - 1, Math.floor(y2 / rowH));
            for (let i = a; i <= b; i++) s[list[i].path] = true;
        }
        pane.sel = s;
    }

    function zoom(d: int): void {
        if (grid) Prefs.iconSize = Math.max(48, Math.min(256, Prefs.iconSize + d * 16));
    }

    // ---------- перетаскивание наружу (в другие приложения и на свои папки) ----------
    Item {
        id: dragProxy
        width: 1
        height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.onDragFinished: { root.dragPaths = []; root.internalDrag = false; }
    }
    function startDrag(): void {
        const paths = pane.selectedPaths();
        if (!paths.length) return;
        dragPaths = paths;
        internalDrag = true;
        dragProxy.Drag.mimeData = { "text/uri-list": paths.map(Ops.uri).join("\r\n") + "\r\n" };
        const first = pane.selected()[0];
        dragProxy.Drag.imageSource = Mime.iconPath(first.mime, first.path);
        dragProxy.Drag.active = true;
    }

    // ---------- клавиатура ----------
    property string typed: ""
    Timer { id: typedReset; interval: 900; onTriggered: root.typed = "" }

    function moveTo(i: int, shift: bool): void {
        const n = pane.entries.length;
        if (!n) return;
        i = Math.max(0, Math.min(n - 1, i));
        if (shift) pane.selectRange(i, false);
        else pane.selectOnly(i);
        positionAt(i);
    }

    Keys.onPressed: e => {
        const p = pane, c = cols(), cur = p.cursor;
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier, alt = e.modifiers & Qt.AltModifier;
        const page = view ? Math.max(1, Math.floor(view.height / (grid ? view.cellHeight : rowH))) * c : 10;
        let done = true;
        switch (e.key) {
        case Qt.Key_Right: if (alt) p.forward(); else moveTo(grid ? cur + 1 : cur, shift); break;
        case Qt.Key_Left: if (alt) p.back(); else moveTo(grid ? cur - 1 : cur, shift); break;
        case Qt.Key_Down: moveTo(cur < 0 ? 0 : cur + c, shift); break;
        case Qt.Key_Up: if (alt) p.up(); else moveTo(cur < 0 ? 0 : cur - c, shift); break;
        case Qt.Key_Home: moveTo(0, shift); break;
        case Qt.Key_End: moveTo(p.entries.length - 1, shift); break;
        case Qt.Key_PageDown: moveTo(cur + page, shift); break;
        case Qt.Key_PageUp: moveTo(cur - page, shift); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (cur >= 0) root.open(p.entries[cur], ctrl);
            break;
        case Qt.Key_Space: if (typed) done = false; else root.quickLook(); break;
        case Qt.Key_Backspace: if (typed) { typed = typed.slice(0, -1); } else p.up(); break;
        case Qt.Key_Escape: if (p.filter) p.filter = ""; else p.clearSel(); break;
        case Qt.Key_Delete: root.remove(shift); break;
        case Qt.Key_F2: root.rename(); break;
        case Qt.Key_Menu: {
            const i = cur >= 0 ? cur : -1;
            root.menu(i >= 0 ? p.entries[i] : null, width / 2, height / 3);
            break;
        }
        default: done = false;
        }
        if (!done && ctrl) {
            done = true;
            switch (e.key) {
            case Qt.Key_A: p.selectAll(); break;
            case Qt.Key_C: Ops.copy(p.selectedPaths(), false); break;
            case Qt.Key_X: if (p.mode === "dir") Ops.copy(p.selectedPaths(), true); break;
            case Qt.Key_V: if (p.mode === "dir") Ops.paste(p.path); break;
            case Qt.Key_H: Prefs.showHidden = !Prefs.showHidden; break;
            case Qt.Key_1: Prefs.view = "grid"; break;
            case Qt.Key_2: Prefs.view = "list"; break;
            case Qt.Key_Plus:
            case Qt.Key_Equal: zoom(1); break;
            case Qt.Key_Minus: zoom(-1); break;
            default: done = false;
            }
        }
        // набор букв — прыжок к первому подходящему имени
        if (!done && !ctrl && !alt && e.text && e.text.length === 1 && e.text >= " ") {
            typed += e.text.toLowerCase();
            typedReset.restart();
            const i = p.entries.findIndex(x => x.name.toLowerCase().startsWith(typed));
            if (i >= 0) moveTo(i, false);
            done = true;
        }
        e.accepted = done;
    }

    // подсказка набранного
    Rectangle {
        visible: root.typed !== ""
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 18
        width: tt.implicitWidth + 28
        height: 32
        radius: 16
        color: Cove.surface0
        border.color: Cove.surface1
        z: 20
        KText { id: tt; anchors.centerIn: parent; text: root.typed; font.bold: true }
    }
}
