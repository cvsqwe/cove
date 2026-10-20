import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Галерея «Добавить виджет».
Rectangle {
    id: root
    signal picked(string type)
    signal close()

    width: 4 * 210 + 3 * 10 + 40
    height: grid.implicitHeight + 90
    radius: Theme.radius + 6
    // почти непрозрачно: панель лежит в одном слое с виджетами, размытия под ней нет — они бы просвечивали
    color: Theme.alpha(Theme.base, 0.97)
    border.width: 1
    border.color: Theme.surface0

    MouseArea { anchors.fill: parent }

    RowLayout {
        x: 20; y: 16
        width: parent.width - 40
        StyledText { Layout.fillWidth: true; text: I18n.tr("Добавить виджет"); font.bold: true; font.pixelSize: Theme.fontSizeLarge }
        IconButton { size: 28; iconSize: 14; icon: "󰅖"; onClicked: root.close() }
    }

    Grid {
        id: grid
        x: 20; y: 64
        columns: 4
        spacing: 10
        Repeater {
            model: Catalog.order
            Rectangle {
                id: tile
                required property string modelData
                readonly property var c: Catalog.types[modelData]
                width: 210
                height: 74
                radius: Theme.radius
                color: m.containsMouse ? Theme.surface0 : Theme.mantle
                border.width: 1
                border.color: m.containsMouse ? Theme.accent : Theme.surface0
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    MIcon { icon: tile.c.icon; size: 26; color: Theme.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText { text: tile.c.label; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                        StyledText { text: tile.c.desc; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(tile.modelData) }
            }
        }
    }
}
