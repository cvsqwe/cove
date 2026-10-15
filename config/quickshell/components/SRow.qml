import QtQuick
import QtQuick.Layouts
import qs.config

// Строка настройки: иконка, название, пояснение и элемент управления справа.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string desc: ""
    property bool separator: true
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(54, text.implicitHeight + 22)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: Theme.radiusSmall
        color: hover.hovered ? Theme.alpha(Theme.surface0, 0.5) : "transparent"
    }
    HoverHandler { id: hover }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 14

        MIcon {
            visible: root.icon !== ""
            Layout.preferredWidth: 22
            horizontalAlignment: Text.AlignHCenter
            icon: root.icon
            color: Theme.accent
            size: 18
        }
        ColumnLayout {
            id: text
            Layout.fillWidth: true
            spacing: 2
            StyledText { Layout.fillWidth: true; text: root.title; elide: Text.ElideRight }
            StyledText {
                Layout.fillWidth: true
                visible: root.desc !== ""
                text: root.desc
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
        Row {
            id: slot
            spacing: 8
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        }
    }

    Rectangle {
        visible: root.separator
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        height: 1
        color: Theme.surface0
        opacity: 0.6
    }
}
