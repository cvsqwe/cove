import QtQuick
import qs.config

// Кликабельный блок панели: иконка + необязательный текст, подсветка при наведении.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.barTint(Theme.accent)
    property color textColor: Theme.text
    property alias hovered: mouse.containsMouse
    property bool badge: false        // точка-метка на значке (например, есть уведомления)
    property bool pinLabel: false     // подпись видна всегда, даже в режиме «при наведении»
    readonly property bool labelShown: label !== "" && (pinLabel || !Theme.barHoverLabels || mouse.containsMouse)

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: Math.max(implicitHeight, row.implicitWidth + 16)
    Behavior on implicitWidth { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    implicitHeight: Theme.capsuleHeight - 2
    radius: Theme.barRound ? height / 2 : Math.max(2, Theme.capsuleRadius - 2)
    color: mouse.containsMouse ? Theme.capsuleHover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        MIcon {
            visible: root.icon !== ""
            icon: root.icon
            color: root.iconColor
            size: Theme.iconSize

            Rectangle {
                visible: root.badge
                width: 7
                height: 7
                radius: 3.5
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -1
                anchors.topMargin: 1
                color: Theme.accent
                border.width: 1.5
                border.color: Theme.crust
            }
        }
        // подпись выезжает справа от значка
        Item {
            visible: root.label !== ""
            clip: true
            width: root.labelShown ? lbl.implicitWidth + (root.icon !== "" ? 7 : 0) : 0
            height: lbl.implicitHeight
            anchors.verticalCenter: parent.verticalCenter
            Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            StyledText {
                id: lbl
                x: root.icon !== "" ? 7 : 0
                text: root.label
                color: root.textColor
                opacity: root.labelShown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
}
