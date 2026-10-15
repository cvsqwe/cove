import QtQuick
import QtQuick.Layouts
import qs.config

// Карточка-группа настроек с заголовком. Строки внутри разделяются тонкими линиями.
ColumnLayout {
    id: root

    property string title: ""
    property string icon: ""
    default property alias rows: body.data

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        visible: root.title !== ""
        spacing: 8
        Layout.leftMargin: 4
        MIcon { visible: root.icon !== ""; icon: root.icon; color: Theme.accent }
        StyledText { text: root.title; font.bold: true; color: Theme.subtext1; font.pixelSize: Theme.fontSizeSmall + 1 }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 8
        radius: Theme.radius
        color: Theme.mantle
        border.width: 1
        border.color: Theme.surface0

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            spacing: 0
        }
    }
}
