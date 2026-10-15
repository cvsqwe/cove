import QtQuick
import qs.config

// Круглая кнопка-иконка.
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property int size: 34
    property int iconSize: 17
    property bool active: false
    property color activeColor: Theme.accent

    signal clicked(var mouse)

    implicitWidth: size
    implicitHeight: size
    radius: size / 2
    color: active ? activeColor : mouse.containsMouse ? Theme.surface1 : Theme.surface0
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MIcon {
        anchors.centerIn: parent
        icon: root.icon
        fill: root.active
        color: root.active ? Theme.crust : root.iconColor
        size: root.iconSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => root.clicked(m)
    }
}
