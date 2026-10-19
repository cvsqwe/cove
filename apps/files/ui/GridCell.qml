import QtQuick
import qs.kit
import qs.services

// Ячейка сетки: значок/миниатюра и имя в две строки
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

    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Cove.radius
        color: drop.containsDrag ? Cove.alpha(Cove.accent, 0.3)
            : root.selected ? Cove.alpha(Cove.accent, root.hovered ? 0.26 : 0.2)
            : root.hovered ? Cove.alpha(Cove.surface0, 0.8) : "transparent"
        border.width: root.focused ? 1 : 0
        border.color: Cove.alpha(Cove.accent, 0.6)
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    EntryIcon {
        id: icon
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        width: Prefs.iconSize
        height: Prefs.iconSize
        size: Prefs.iconSize
        entry: root.e
        opacity: root.cut ? 0.45 : root.e.name.startsWith(".") ? 0.7 : 1
    }
    KText {
        anchors.top: icon.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 14
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        text: root.e.name
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        maximumLineCount: root.hovered || root.selected ? 3 : 2
        elide: Text.ElideMiddle
        font.pixelSize: Cove.fontSizeSmall + 1
        color: root.selected ? Cove.text : Cove.subtext1
        opacity: root.cut ? 0.6 : 1
    }
    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.e.dir && !root.items.dragPaths.includes(root.e.path)
        keys: ["text/uri-list"]
        onDropped: ev => { root.items.dropped(ev.urls, root.e.path, ev.proposedAction); ev.acceptProposedAction(); }
    }
}
