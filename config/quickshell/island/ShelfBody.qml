import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Полка: что лежит + место, куда бросать. Пока над островом что-то тащат, рамка подсвечена.
ColumnLayout {
    id: root

    property bool shown: false
    property bool dropping: false   // над островом держат файл

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        MIcon { icon: "inventory_2"; size: 18; color: Theme.accent }
        StyledText {
            text: Shelf.count ? I18n.tr("Полка · {0}", Shelf.count) : I18n.tr("Полка")
            font.bold: true
            color: Theme.text
        }
        Item { Layout.fillWidth: true }
        IconButton {
            visible: Shelf.count > 0 && !root.dropping
            size: 28; iconSize: 15
            icon: "delete_sweep"
            onClicked: Shelf.clear()
        }
    }

    ShelfRow {
        visible: Shelf.count > 0
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: implicitWidth
    }

    // место для броска
    Rectangle {
        visible: root.dropping || Shelf.count === 0
        Layout.fillWidth: true
        Layout.preferredWidth: 360
        Layout.preferredHeight: 64
        radius: Theme.radiusSmall
        color: root.dropping ? Theme.alpha(Theme.accent, 0.14) : "transparent"
        border.width: 2
        border.color: root.dropping ? Theme.accent : Theme.surface2
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            MIcon { icon: root.dropping ? "download" : "drag_pan"; size: 20; color: root.dropping ? Theme.accent : Theme.overlay1 }
            StyledText {
                text: root.dropping ? I18n.tr("Отпустите, чтобы положить на полку") : I18n.tr("Перетащите сюда файл, текст или ссылку")
                color: root.dropping ? Theme.accent : Theme.overlay1
            }
        }
    }

    StyledText {
        visible: Shelf.count > 0 && !root.dropping
        Layout.alignment: Qt.AlignHCenter
        text: I18n.tr("Потяните плитку в нужное окно · клик — открыть · ПКМ — убрать")
        color: Theme.overlay1
        font.pixelSize: Theme.fontSizeSmall
    }
}
