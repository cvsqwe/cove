import QtQuick
import qs.config

// Горизонтальный слайдер 0..1: клик, перетаскивание, колесо.
Item {
    id: root

    property real value: 0
    property color color: Theme.accent
    property bool dim: false
    property int thickness: 10

    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 200

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.thickness
        radius: height / 2
        color: Theme.surface0

        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: root.dim ? Theme.overlay0 : root.color
            Behavior on width { enabled: !area.pressed; NumberAnimation { duration: 90 } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(x: real): void { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
