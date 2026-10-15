import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Подстраница центра управления: шапка «← Назад» + прокручиваемое содержимое.
ColumnLayout {
    id: root

    property string title: ""
    property string icon: ""
    default property alias content: col.data
    property alias headerExtra: extra.data

    spacing: 12

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        IconButton { icon: "󰁍"; onClicked: Panels.controlPage = "" }
        MIcon { icon: root.icon; color: Theme.accent; size: 20 }
        StyledText { Layout.fillWidth: true; text: root.title; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
        Row { id: extra; spacing: 8 }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 8
        }
    }
}
