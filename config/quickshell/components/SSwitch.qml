import QtQuick
import qs.config

// Переключатель с анимированной «таблеткой».
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface1
    Behavior on color { ColorAnimation { duration: Theme.anim } }

    Rectangle {
        width: parent.height - 6
        height: width
        radius: width / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.onAccent : Theme.subtext0
        Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
