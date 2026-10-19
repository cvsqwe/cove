import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.kit
import qs.services

// Панель сведений справа: превью и свойства выделенного (или текущей папки, если ничего не выделено)
Rectangle {
    id: root
    property var pane: null
    readonly property var sel: pane ? pane.selected() : []
    readonly property var one: sel.length === 1 ? sel[0] : null
    property var du: null          // {size, count} для папок и множественного выделения
    property var st: null          // права, владелец (helpers/fm.py stat)
    property size dims: Qt.size(0, 0)
    signal openEntry(var e)

    color: Cove.mantle

    function refresh(): void {
        du = null; st = null; dims = Qt.size(0, 0);
        if (!pane) return;
        const paths = sel.length ? sel.map(e => e.path) : (pane.mode === "dir" ? [pane.path] : []);
        if (!paths.length) return;
        const key = paths.join("\n");
        if (sel.some(e => e.dir) || !sel.length || sel.length > 1)
            Ops.fm(["du", ...paths], v => { if (key === cur()) root.du = v; });
        if (one) Ops.fm(["stat", one.path], v => { if (key === cur()) root.st = v; });
    }
    function cur(): string { return (sel.length ? sel.map(e => e.path) : [pane?.path ?? ""]).join("\n"); }
    Timer { id: deb; interval: 250; onTriggered: root.refresh() }
    onSelChanged: deb.restart()
    Component.onCompleted: deb.restart()

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 30
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: KScrollBar {}

        ColumnLayout {
            id: col
            x: 18
            y: 18
            width: parent.width - 36
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.75
                radius: Cove.radius
                color: Cove.base
                EntryIcon {
                    anchors.centerIn: parent
                    visible: root.one !== null
                    width: Math.min(parent.width, parent.height) - 24
                    height: width
                    size: width
                    entry: root.one
                }
                Image {
                    // размеры картинки: читаем заголовок, не декодируя всё
                    visible: false
                    source: root.one && Fmt.isImage(root.one.name) ? "file://" + root.one.path : ""
                    sourceSize: Qt.size(1, 1)
                    asynchronous: true
                    onStatusChanged: if (status === Image.Ready) root.dims = Qt.size(implicitWidth, implicitHeight)
                }
                KIcon {
                    visible: root.one === null
                    anchors.centerIn: parent
                    icon: root.sel.length > 1 ? "library_add_check" : root.pane?.mode === "trash" ? "delete" : "folder"
                    fill: true
                    size: 64
                    color: Cove.alpha(Cove.accent, 0.8)
                }
            }
            KText {
                Layout.fillWidth: true
                text: root.one ? root.one.name : root.sel.length > 1 ? "Выбрано: " + Fmt.items(root.sel.length) : root.pane?.title ?? ""
                font.pixelSize: Cove.fontSizeLarge
                font.bold: true
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
            }
            KText {
                Layout.fillWidth: true
                text: root.one ? (root.one.dir ? "Папка" : Mime.describe(root.one.mime, root.one.name)) : ""
                visible: text !== ""
                color: Cove.overlay1
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Cove.surface0; Layout.topMargin: 4; Layout.bottomMargin: 4 }

            Prop { k: "Размер"; v: root.one && !root.one.dir ? Fmt.size(root.one.size) : root.du ? Fmt.size(root.du.size) : "считаю…" }
            Prop { k: "Внутри"; v: root.du && (root.one?.dir || !root.sel.length) ? Fmt.items(root.du.count) : ""; visible: v !== "" }
            Prop { k: "Разрешение"; v: root.dims.width > 0 ? root.dims.width + " × " + root.dims.height : ""; visible: v !== "" }
            Prop { k: "Изменён"; v: root.one ? Fmt.full(root.one.mtime) : ""; visible: v !== "" }
            Prop { k: "Удалён"; v: root.one && root.pane.mode === "trash" ? Fmt.full(root.one.mtime) : ""; visible: v !== "" }
            Prop { k: "Откуда"; v: root.one?.orig ? root.one.orig.replace(Cove.home, "~") : ""; visible: v !== "" }
            Prop { k: "Где"; v: root.one && root.pane.mode !== "trash" ? root.one.path.slice(0, root.one.path.lastIndexOf("/")).replace(Cove.home, "~") || "/" : ""; visible: v !== "" }
            Prop { k: "Права"; v: root.st?.mode ? root.st.mode + "  " + root.st.owner : ""; visible: v !== "" }
            Prop { k: "Ссылка на"; v: root.st?.link ?? ""; visible: v !== "" }
        }
    }

    component Prop: ColumnLayout {
        property string k
        property string v
        Layout.fillWidth: true
        spacing: 1
        KText { text: parent.k; color: Cove.overlay1; font.pixelSize: Cove.fontSizeSmall }
        KText { Layout.fillWidth: true; text: parent.v; wrapMode: Text.WrapAnywhere; elide: Text.ElideNone }
    }
}
