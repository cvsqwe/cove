import QtQuick
import QtQuick.Layouts
import qs.config

// Кнопка: обычная, primary (акцент) или danger.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property bool enabled_: true
    signal clicked()

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: Theme.radiusSmall + 2
    opacity: enabled_ ? 1 : 0.5
    color: primary ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
        : danger ? (mouse.containsMouse ? Theme.alpha(Theme.red, 0.3) : Theme.alpha(Theme.red, 0.15))
        : mouse.containsMouse ? Theme.surface1 : Theme.surface0
    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        MIcon {
            visible: root.icon !== ""
            icon: root.icon
            color: root.primary ? Theme.onAccent : root.danger ? Theme.red : Theme.accent
        }
        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.primary ? Theme.onAccent : root.danger ? Theme.red : Theme.text
            font.pixelSize: Theme.fontSizeSmall + 1
            font.bold: root.primary
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.enabled_) root.clicked()
    }
}
