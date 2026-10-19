import QtQuick
import QtQuick.Layouts
import qs.kit
import qs.services

// Строка боковой панели: место, закладка, устройство или корзина
Item {
    id: r
    property var side: null
    property string icon: ""
    property string label: ""
    property string sub: ""
    property string path: ""
    property bool trash: false
    property bool bookmark: false
    property var device: null
    property int badge: 0
    readonly property bool current: !!r.side?.pane && (trash ? r.side.pane.mode === "trash" : r.side.pane.mode === "dir" && path !== "" && r.side.pane.path === path)
    readonly property bool hot: drop.containsDrag

    Layout.fillWidth: true
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: Cove.radiusSmall + 2
        color: r.hot ? Cove.alpha(Cove.accent, 0.3) : r.current ? Cove.alpha(Cove.accent, 0.18) : ma.containsMouse ? Cove.surface0 : "transparent"
        Behavior on color { ColorAnimation { duration: Cove.anim } }
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 14
        spacing: 11
        KIcon { icon: r.icon; size: 17; fill: r.current; color: r.current ? Cove.accent : Cove.subtext0 }
        KText {
            Layout.fillWidth: true
            text: r.label
            color: r.current ? Cove.text : Cove.subtext1
            font.bold: r.current
        }
        KText { visible: r.sub !== "" && !ma.containsMouse; text: r.sub; color: Cove.overlay0; font.pixelSize: Cove.fontSizeSmall }
        Rectangle {
            visible: r.badge > 0
            implicitWidth: Math.max(20, bt.implicitWidth + 10)
            implicitHeight: 18
            radius: 9
            color: Cove.surface1
            KText { id: bt; anchors.centerIn: parent; text: r.badge; font.pixelSize: Cove.fontSizeSmall - 1; color: Cove.subtext1 }
        }
        // извлечь / отключить устройство
        KIcon {
            visible: r.device !== null && r.path !== ""
            icon: "eject"
            size: 16
            color: ej.containsMouse ? Cove.accent : Cove.overlay1
            MouseArea {
                id: ej
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Places.unmount(r.device.path, r.device.removable, r.device.disk)
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton) {
                const p = r.mapToItem(r.side, e.x, e.y);
                r.side.menu({ path: r.path, label: r.label, trash: r.trash, bookmark: r.bookmark, device: r.device }, p.x, p.y);
                return;
            }
            if (r.trash) { r.side.openTrash(); return; }
            const go = p => e.button === Qt.MiddleButton ? r.side.newTab(p) : r.side.navigate(p);
            if (r.device && !r.path) Places.mount(r.device.path, () => {
                const d = Places.devices.find(x => x.path === r.device.path);
                if (d?.mount) go(d.mount);
            });
            else go(r.path);
        }
    }
    DropArea {
        id: drop
        anchors.fill: parent
        enabled: r.trash || r.path !== ""
        keys: ["text/uri-list"]
        onDropped: e => {
            r.side.dropped(e.urls, r.trash ? "trash:" : r.path, e.proposedAction);
            e.acceptProposedAction();
        }
    }
}
