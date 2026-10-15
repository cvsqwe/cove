import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Превью только что сделанного скриншота с действиями.
RowLayout {
    id: root

    property bool shown: false
    signal done()

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 14

    Rectangle {
        implicitWidth: 224
        implicitHeight: 126
        radius: Theme.radiusSmall
        color: Theme.surface0
        clip: true
        Image {
            anchors.fill: parent
            source: Screenshot.last ? "file://" + Screenshot.last + "?" + Screenshot.serial : ""
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(448, 252)
            cache: false
        }
    }

    ColumnLayout {
        spacing: 6
        StyledText { text: I18n.tr("Скриншот в буфере"); font.bold: true; color: Theme.accent }
        StyledText {
            Layout.maximumWidth: 200
            text: Screenshot.last.replace(Settings.home, "~")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideMiddle
        }
        RowLayout {
            spacing: 6
            Layout.topMargin: 4
            IconButton { icon: "󰈈"; onClicked: { Qt.openUrlExternally("file://" + Screenshot.last); root.done(); } }
            IconButton { icon: "󰏫"; onClicked: { Screenshot.edit(Screenshot.last); root.done(); } }
            IconButton { icon: "󰉋"; onClicked: { Qt.openUrlExternally("file://" + Screenshot.dir); root.done(); } }
            IconButton { icon: "󰆴"; iconColor: Theme.red; onClicked: { Quickshell.execDetached(["rm", "-f", Screenshot.last]); root.done(); } }
        }
    }
}
