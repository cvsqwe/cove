import QtQuick
import QtQuick.Layouts
import qs.config

// Плашка выбора (наборы эквалайзера и т.п.): активная — в акценте; removable — крестик справа.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool active: false
    property bool dim: false            // выбрана, но изменена
    property bool removable: false
    signal clicked()
    signal removed()

    implicitWidth: row.implicitWidth + (removable ? 22 : 28)
    implicitHeight: 32
    radius: height / 2
    color: active ? (dim ? Theme.alpha(Theme.accent, 0.35) : Theme.accent) : mouse.containsMouse ? Theme.surface1 : Theme.surface0
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        spacing: 6
        MIcon { visible: root.icon !== ""; icon: root.icon; size: 14; color: root.active && !root.dim ? Theme.onAccent : Theme.accent }
        StyledText {
            text: root.text
            color: root.active && !root.dim ? Theme.onAccent : Theme.text
            font.pixelSize: Theme.fontSizeSmall + 1
            font.bold: root.active
        }
        MIcon {
            visible: root.removable
            icon: "close"
            size: 13
            color: closeArea.containsMouse ? Theme.red : root.active && !root.dim ? Theme.onAccent : Theme.overlay1
            MouseArea {
                id: closeArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removed()
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
