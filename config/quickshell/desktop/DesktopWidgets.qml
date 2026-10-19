import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Виджеты рабочего стола (слой под окнами) и их редактор.
// Редактор: `qs ipc call desktop edit`, Настройки → Рабочий стол или действие «Редактор виджетов».
// В редакторе: тащить — двигать, уголок — масштаб, Del — удалить, стрелки (+Shift) — сдвиг,
// Ctrl+D — копия, Esc — снять выделение / выйти. Типы виджетов — desktop/Catalog.qml.
PanelWindow {
    id: win
    screen: Displays.primaryScreen   // Настройки → Мониторы → «Основной»

    property bool editing: false
    property string selected: ""
    property bool adding: false
    readonly property var list: Settings.desktop.widgets ?? []
    readonly property int grid: 20
    readonly property bool snap: Settings.desktop.snap

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Settings.desktop.enabled && !GameMode.active
    WlrLayershell.layer: editing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "qs-desktop"
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // вне редактора клики проходят сквозь всё, кроме интерактивных виджетов (плеер, задачи, таймер…)
    mask: Region { item: win.editing ? fullArea : null; regions: win.editing ? [] : win.hot }
    property list<Region> hot: {
        void rep.count;
        const out = [];
        for (let i = 0; i < rep.count; i++) { const it = rep.itemAt(i); if (it) out.push(it.region); }
        return out;
    }

    onEditingChanged: {
        if (editing) keys.forceActiveFocus();
        else { selected = ""; adding = false; }
    }

    Item { id: fullArea; anchors.fill: parent }

    IpcHandler {
        target: "desktop"
        function edit(): void { win.editing = !win.editing; }
        function add(type: string): void { if (Catalog.types[type]) { win.editing = true; win.add(type); } }
        function select(id: string): void { win.editing = true; win.selected = id; }
        function gallery(): void { win.editing = true; win.adding = true; }
    }

    // ---------- данные ----------
    function wid(e, i: int): string { return e?.id ?? ("legacy-" + i); }
    function commit(fn): void {
        const l = Settings.copy(list);
        l.forEach((e, i) => { if (!e.id) e.id = wid(e, i); });
        fn(l);
        Settings.desktop.widgets = l;
    }
    function find(l, id: string): var { return l.find(e => e.id === id); }
    function newId(): string { return "w" + Date.now().toString(36) + Math.floor(Math.random() * 1000); }
    function update(id: string, p): void { commit(l => { const e = find(l, id); if (e) Object.assign(e, p); }); }
    function setOpt(id: string, k: string, v): void {
        commit(l => { const e = find(l, id); if (e) { const o = Object.assign({}, e.opts ?? {}); o[k] = v; e.opts = o; } });
    }
    function add(type: string): void {
        const c = Catalog.types[type], id = newId();
        commit(l => l.push({ id, type, x: snapV(width / 2 - 160), y: snapV(height / 2 - 120), scale: 1, enabled: true, style: c.style, opts: Settings.copy(c.opts) }));
        selected = id;
        adding = false;
    }
    function remove(id: string): void {
        commit(l => { const i = l.findIndex(e => e.id === id); if (i >= 0) l.splice(i, 1); });
        if (selected === id) selected = "";
    }
    function duplicate(id: string): void {
        const nid = newId();
        commit(l => { const e = find(l, id); if (e) { const c = JSON.parse(JSON.stringify(e)); c.id = nid; c.x += 40; c.y += 40; l.push(c); } });
        selected = nid;
    }
    function raise(id: string): void { commit(l => { const i = l.findIndex(e => e.id === id); if (i >= 0) l.push(l.splice(i, 1)[0]); }); }
    function nudge(dx: int, dy: int): void {
        const e = list.find((x, i) => wid(x, i) === selected);
        if (e) update(selected, { x: Math.max(0, e.x + dx), y: Math.max(0, e.y + dy) });
    }
    function snapV(v: real): int { return snap ? Math.round(v / grid) * grid : Math.round(v); }

    readonly property var selEntry: list.find((e, i) => wid(e, i) === selected) ?? null

    // ---------- фон редактора ----------
    Rectangle {
        anchors.fill: parent
        visible: win.editing
        color: Theme.alpha(Theme.crust, 0.3)

        Canvas {
            id: gridCanvas
            anchors.fill: parent
            visible: win.snap
            onWidthChanged: requestPaint()
            onVisibleChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                for (let x = 0; x < width; x += win.grid) {
                    g.fillStyle = x % (win.grid * 5) === 0 ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.025);
                    g.fillRect(x, 0, 1, height);
                }
                for (let y = 0; y < height; y += win.grid) {
                    g.fillStyle = y % (win.grid * 5) === 0 ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.025);
                    g.fillRect(0, y, width, 1);
                }
            }
        }
        // клик по пустому месту — снять выделение
        MouseArea { anchors.fill: parent; onClicked: { win.selected = ""; win.adding = false; keys.forceActiveFocus(); } }
    }

    Item {
        id: keys
        focus: win.editing
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier, step = e.modifiers & Qt.ShiftModifier ? 10 : 1;
            if (e.key === Qt.Key_Escape) {
                if (win.adding) win.adding = false;
                else if (win.selected) win.selected = "";
                else win.editing = false;
            } else if (!win.selected) {
                return;
            } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) win.remove(win.selected);
            else if (ctrl && e.key === Qt.Key_D) win.duplicate(win.selected);
            else if (e.key === Qt.Key_Left) win.nudge(-step, 0);
            else if (e.key === Qt.Key_Right) win.nudge(step, 0);
            else if (e.key === Qt.Key_Up) win.nudge(0, -step);
            else if (e.key === Qt.Key_Down) win.nudge(0, step);
            else return;
            e.accepted = true;
        }
    }

    // ---------- виджеты ----------
    // Модель — число: при правке значений делегаты не пересоздаются (нет мерцания, состояние живо).
    Repeater {
        id: rep
        model: win.list.length

        Item {
            id: w
            required property int index
            readonly property var e: win.list[index] ?? ({})
            readonly property string wid: win.wid(e, index)
            readonly property var cat: Catalog.types[e.type] ?? null
            readonly property bool sel: win.editing && win.selected === wid
            readonly property string style: e.style ?? cat?.style ?? "glass"
            readonly property int pad: style === "none" ? 0 : 20
            property real liveScale: 0
            readonly property real s: liveScale > 0 ? liveScale : (e.scale ?? 1)
            readonly property bool shownW: loader.item?.shown ?? true
            readonly property alias region: reg

            // зона кликов вне редактора — только у видимых интерактивных
            Region { id: reg; item: !win.editing && w.visible && !!w.cat?.interactive ? w : null }

            visible: !!cat && e.enabled !== false && (shownW || win.editing)
            opacity: shownW ? 1 : 0.45
            x: e.x ?? 100
            y: e.y ?? 100
            z: sel ? 1000 : index
            width: body.width * s
            height: body.height * s

            Item {
                id: body
                readonly property bool scalableText: true   // StyledText внутри рисует буквы кривыми — без мыла при scale
                width: (loader.item?.implicitWidth ?? 120) + 2 * w.pad
                height: (loader.item?.implicitHeight ?? 80) + 2 * w.pad
                scale: w.s
                transformOrigin: Item.TopLeft

                RectangularShadow {
                    anchors.fill: bg
                    visible: w.style !== "none"
                    radius: bg.radius
                    offset.y: 6
                    blur: 28
                    color: Qt.rgba(0, 0, 0, 0.28)
                }
                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: Theme.radius + 8
                    color: w.style === "glass" ? Theme.alpha(Theme.base, 0.55) : w.style === "solid" ? Theme.base : "transparent"
                    border.width: w.style === "none" ? 0 : 1
                    border.color: w.style === "glass" ? Theme.alpha(Theme.text, 0.12) : Theme.surface0
                }
                Loader {
                    id: loader
                    x: w.pad
                    y: w.pad
                    // выключенные виджеты не держим в памяти: невидимые, они всё равно считали бы графики и спектр
                    active: w.e.enabled !== false || win.editing
                    source: w.cat ? Qt.resolvedUrl("widgets/" + w.cat.file + ".qml") : ""
                }
                Binding { target: loader.item; property: "opts"; value: Object.assign({}, w.cat?.opts ?? {}, w.e.opts ?? {}); when: loader.status === Loader.Ready }
                Binding { target: loader.item; property: "editing"; value: win.editing; when: loader.status === Loader.Ready }
                Connections {
                    target: loader.item
                    ignoreUnknownSignals: true
                    function onSetOpt(k, v) { win.setOpt(w.wid, k, v); }
                }
            }

            // ---- рамка и ручки редактора ----
            Rectangle {
                anchors.fill: parent
                anchors.margins: -6
                visible: win.editing
                radius: Theme.radius + 12
                color: w.sel ? Theme.alpha(Theme.accent, 0.06) : "transparent"
                border.width: w.sel ? 2 : 1
                border.color: w.sel ? Theme.accent : Theme.alpha(Theme.text, 0.3)
            }
            Rectangle {
                visible: win.editing
                x: -6
                y: -32
                height: 24
                width: tag.implicitWidth + 18
                radius: 12
                color: w.sel ? Theme.accent : Theme.alpha(Theme.crust, 0.85)
                Row {
                    id: tag
                    anchors.centerIn: parent
                    spacing: 6
                    MIcon { anchors.verticalCenter: parent.verticalCenter; icon: w.cat?.icon ?? "widgets"; size: Theme.fontSizeSmall; color: w.sel ? Theme.onAccent : Theme.text }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (w.cat?.label ?? w.e.type) + (w.shownW ? "" : I18n.tr(" · сейчас скрыт"))
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: w.sel
                        color: w.sel ? Theme.onAccent : Theme.text
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: win.editing
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: w
                drag.threshold: 2
                drag.minimumX: 0
                drag.minimumY: 0
                drag.maximumX: win.width - w.width
                drag.maximumY: win.height - w.height
                onPressed: { win.selected = w.wid; win.adding = false; keys.forceActiveFocus(); }
                onReleased: {
                    if (w.x !== w.e.x || w.y !== w.e.y) win.update(w.wid, { x: win.snapV(w.x), y: win.snapV(w.y) });
                    // перетаскивание рвёт привязку x/y к настройкам — восстанавливаем
                    w.x = Qt.binding(() => w.e.x ?? 100);
                    w.y = Qt.binding(() => w.e.y ?? 100);
                }
            }
            Rectangle {
                visible: w.sel
                width: 18
                height: 18
                radius: 9
                x: parent.width - 9
                y: parent.height - 9
                color: Theme.accent
                border.width: 3
                border.color: Theme.crust
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.SizeFDiagCursor
                    onPositionChanged: m => {
                        const p = mapToItem(w, m.x, m.y);
                        w.liveScale = Math.max(0.4, Math.min(3, p.x / body.width));
                    }
                    onReleased: {
                        if (w.liveScale > 0) win.update(w.wid, { scale: Math.round(w.liveScale * 100) / 100 });
                        w.liveScale = 0;
                    }
                }
            }
        }
    }

    // ---------- панели редактора ----------
    Inspector {
        visible: win.editing && !!win.selEntry && !win.adding
        entry: win.selEntry ?? ({})
        cat: Catalog.types[win.selEntry?.type] ?? ({})
        z: 2000
        // напротив выделенного виджета
        x: (win.selEntry?.x ?? 0) > win.width / 2 ? 24 : win.width - width - 24
        y: Theme.barBottom + 24
        onPatch: p => win.update(win.selected, p)
        onOpt: (k, v) => win.setOpt(win.selected, k, v)
        onDuplicate: win.duplicate(win.selected)
        onRemove: win.remove(win.selected)
        onRaise: win.raise(win.selected)
        onClose: win.selected = ""
    }

    AddGallery {
        visible: win.editing && win.adding
        z: 2000
        anchors.centerIn: parent
        onPicked: t => win.add(t)
        onClose: win.adding = false
    }

    Rectangle {
        visible: win.editing
        z: 2000
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: bar.implicitWidth + 24
        height: bar.implicitHeight + 20
        radius: height / 2
        color: Theme.panel
        border.width: 1
        border.color: Theme.surface0

        RowLayout {
            id: bar
            anchors.centerIn: parent
            spacing: 8
            SButton { icon: "󰐕"; text: I18n.tr("Добавить"); primary: win.adding; onClicked: win.adding = !win.adding }
            SButton { icon: win.snap ? "󰕰" : "󰝤"; text: win.snap ? I18n.tr("Сетка: вкл") : I18n.tr("Сетка: выкл"); onClicked: Settings.desktop.snap = !Settings.desktop.snap }
            StyledText {
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                text: I18n.tr("Del — удалить · стрелки — сдвиг · Ctrl+D — копия · Esc — выход")
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
            }
            SButton { icon: "󰄬"; text: I18n.tr("Готово"); primary: true; onClicked: win.editing = false }
        }
    }
}
