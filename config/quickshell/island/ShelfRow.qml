import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Плитки полки. Потянуть плитку — перетащить файл в другое окно, клик — открыть,
// ПКМ — убрать с полки. Плитка «Все» тащит всё сразу.
ListView {
    id: root

    readonly property int tileW: 78
    implicitWidth: Math.min(contentWidth, 6 * (tileW + spacing))
    implicitHeight: 92
    orientation: ListView.Horizontal
    spacing: 6
    clip: true
    interactive: contentWidth > width
    boundsBehavior: Flickable.StopAtBounds
    model: Shelf.count > 1 ? [{ all: true }, ...Shelf.items] : Shelf.items

    function iconOf(it): string {
        if (it.all) return Quickshell.iconPath("folder-documents", true) || Quickshell.iconPath("folder");
        if (!it.path) return Quickshell.iconPath(/^\w+:\/\//.test(it.text) ? "text-html" : "text-x-generic", true) || Quickshell.iconPath("text-x-generic");
        const m = it.mime || "";
        if (m === "inode/directory") return Quickshell.iconPath("folder");
        return Quickshell.iconPath(m.replace("/", "-"), true) || Quickshell.iconPath(m.split("/")[0] + "-x-generic", true)
            || Quickshell.iconPath("text-x-generic", true) || Quickshell.iconPath("unknown");
    }

    // источник перетаскивания один на всю полку: плитка может исчезнуть, пока её тащат
    Item {
        id: proxy
        property var list: []
        width: 1; height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.CopyAction
        Drag.onDragFinished: action => { Shelf.finished(proxy.list, action); proxy.list = []; }
    }
    function startDrag(list: var, icon: string): void {
        proxy.list = list;
        Shelf.dragging = true;
        proxy.Drag.mimeData = Shelf.mimeData(list);
        proxy.Drag.imageSource = icon;
        proxy.Drag.active = true;
    }

    delegate: Rectangle {
        id: tile
        required property var modelData
        readonly property bool all: !!modelData.all
        readonly property bool image: !all && Shelf.isImage(modelData)
        width: root.tileW
        height: root.implicitHeight
        radius: Theme.radiusSmall
        color: area.containsMouse ? Theme.surface1 : Theme.surface0
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Item {
            id: art
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 50; height: 50

            Image {
                anchors.fill: parent
                visible: !tile.image
                source: tile.image ? "" : root.iconOf(tile.modelData)
                sourceSize: Qt.size(100, 100)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                visible: tile.image
                radius: 8
                color: Theme.surface2
                clip: true
                Image {
                    anchors.fill: parent
                    source: tile.image ? Shelf.uri(tile.modelData.path) : ""
                    sourceSize: Qt.size(100, 100)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            // число на плитке «Все»
            Rectangle {
                visible: tile.all
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -4
                width: Math.max(20, cnt.implicitWidth + 10); height: 20; radius: 10
                color: Theme.accent
                StyledText { id: cnt; anchors.centerIn: parent; text: Shelf.count; color: Theme.onAccent; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
            }
        }

        StyledText {
            anchors.top: art.bottom
            anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 10
            horizontalAlignment: Text.AlignHCenter
            text: tile.all ? I18n.tr("Все") : tile.modelData.name
            color: tile.all ? Theme.accent : Theme.subtext0
            font.pixelSize: Theme.fontSizeSmall
            font.bold: tile.all
            elide: Text.ElideMiddle
        }

        MouseArea {
            id: area
            property point from
            property bool moved: false
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: e => { from = Qt.point(e.x, e.y); moved = false; }
            onPositionChanged: e => {
                if (!pressed || moved || !(e.buttons & Qt.LeftButton) || Math.hypot(e.x - from.x, e.y - from.y) < 8) return;
                moved = true;
                root.startDrag(tile.all ? Shelf.items.slice() : [tile.modelData], root.iconOf(tile.modelData));
            }
            onClicked: e => {
                if (moved) return;
                if (tile.all) { if (e.button !== Qt.LeftButton) Shelf.clear(); return; }
                if (e.button === Qt.LeftButton) Shelf.open(tile.modelData);
                else Shelf.remove(tile.modelData);
            }
        }

        // крестик при наведении
        Rectangle {
            visible: (area.containsMouse || closeArea.containsMouse) && !tile.all
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 3
            width: 18; height: 18; radius: 9
            color: closeArea.containsMouse ? Theme.red : Theme.surface2
            MIcon { anchors.centerIn: parent; icon: "close"; size: 12; color: closeArea.containsMouse ? Theme.crust : Theme.text }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Shelf.remove(tile.modelData) }
        }
    }
}
