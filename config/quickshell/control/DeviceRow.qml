import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Строка устройства/сети: иконка, имя, подпись, кнопки справа.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string sub: ""
    property bool active: false
    property bool busy: false
    default property alias buttons: btns.data
    signal clicked()

    Layout.fillWidth: true
    implicitHeight: 58
    radius: Theme.radius
    color: active ? Theme.alpha(Theme.accent, 0.16) : mouse.containsMouse ? Theme.surface0 : Theme.mantle
    border.width: active ? 1 : 0
    border.color: Theme.alpha(Theme.accent, 0.5)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 12

        MIcon {
            icon: root.icon
            color: root.active ? Theme.accent : Theme.subtext0
            size: 20
            RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
            onVisibleChanged: if (!root.busy) rotation = 0
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText { Layout.fillWidth: true; text: root.title; elide: Text.ElideRight; font.bold: root.active }
            StyledText { Layout.fillWidth: true; visible: text !== ""; text: root.sub; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
        }
        Row { id: btns; spacing: 6 }
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
