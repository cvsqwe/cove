import QtQuick
import QtQuick.Layouts
import qs.kit
import qs.services

// Строка списка: значок, имя, дата, размер, тип (в корзине — откуда удалено)
Item {
    id: root
    required property var modelData
    required property int index
    property var items: null
    readonly property var e: modelData
    readonly property bool selected: !!items.pane.sel[e.path]
    readonly property bool hovered: items.hovered === index
    readonly property bool focused: items.pane.cursor === index && items.activeFocus_
    readonly property bool cut: Ops.clip.cut && Ops.clip.paths.includes(e.path)
    readonly property bool trash: items.pane.mode === "trash"
    readonly property bool search: items.pane.mode === "search"

    width: ListView.view.width
    height: items.rowH

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: Cove.radiusSmall + 2
        color: drop.containsDrag ? Cove.alpha(Cove.accent, 0.3)
            : root.selected ? Cove.alpha(Cove.accent, root.hovered ? 0.26 : 0.2)
            : root.hovered ? Cove.alpha(Cove.surface0, 0.8)
            : root.index % 2 ? Cove.alpha(Cove.surface0, 0.18) : "transparent"
        border.width: root.focused ? 1 : 0
        border.color: Cove.alpha(Cove.accent, 0.6)
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12
        opacity: root.cut ? 0.45 : root.e.name.startsWith(".") ? 0.7 : 1
        EntryIcon { implicitWidth: 22; implicitHeight: 22; size: 22; entry: root.e }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            KText { Layout.fillWidth: true; text: root.e.name; elide: Text.ElideMiddle; color: root.selected ? Cove.text : Cove.subtext1 }
            KText {
                Layout.fillWidth: true
                visible: root.search || root.trash
                text: root.trash ? "из " + root.e.orig.slice(0, root.e.orig.lastIndexOf("/")).replace(Cove.home, "~")
                    : root.e.path.slice(0, root.e.path.lastIndexOf("/")).replace(Cove.home, "~")
                color: Cove.overlay1
                font.pixelSize: Cove.fontSizeSmall - 1
                elide: Text.ElideMiddle
            }
        }
        KText { Layout.preferredWidth: root.items.colDate; text: Fmt.date(root.e.mtime); color: Cove.overlay1; font.pixelSize: Cove.fontSizeSmall }
        KText { Layout.preferredWidth: root.items.colSize; horizontalAlignment: Text.AlignRight; text: root.e.dir ? "" : Fmt.size(root.e.size); color: Cove.overlay1; font.pixelSize: Cove.fontSizeSmall }
        KText { Layout.preferredWidth: root.items.colType; text: root.e.dir ? "Папка" : Mime.describe(root.e.mime, root.e.name); color: Cove.overlay1; font.pixelSize: Cove.fontSizeSmall }
    }
    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.e.dir && !root.trash && !root.items.dragPaths.includes(root.e.path)
        keys: ["text/uri-list"]
        onDropped: ev => { root.items.dropped(ev.urls, root.e.path, ev.proposedAction); ev.acceptProposedAction(); }
    }
}
