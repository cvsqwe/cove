import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Плитка-переключатель центра управления. hasMore — стрелка для перехода на подстраницу.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    property bool hasMore: false

    signal clicked()
    signal more()

    implicitHeight: 62
    radius: Theme.radius
    color: on ? Theme.accent : mouse.containsMouse ? Theme.surface1 : Theme.surface0
    Behavior on color { ColorAnimation { duration: Theme.anim } }
    scale: mouse.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: root.hasMore ? 4 : 10
        spacing: 10

        MIcon {
            icon: root.icon
            fill: root.on
            color: root.on ? Theme.onAccent : Theme.accent
            size: 20
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: root.on ? Theme.onAccent : Theme.text
                font.bold: true
                font.pixelSize: Theme.fontSizeSmall + 1
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sub
                color: root.on ? Theme.alpha(Theme.onAccent, 0.75) : Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall - 1
                elide: Text.ElideRight
            }
        }
        Rectangle {
            visible: root.hasMore
            implicitWidth: 30
            implicitHeight: 46
            radius: Theme.radiusSmall
            color: moreMouse.containsMouse ? Theme.alpha(root.on ? Theme.onAccent : Theme.text, 0.12) : "transparent"
            MIcon { anchors.centerIn: parent; icon: "󰅂"; color: root.on ? Theme.onAccent : Theme.overlay1 }
            MouseArea { id: moreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.more() }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.rightMargin: root.hasMore ? 38 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
