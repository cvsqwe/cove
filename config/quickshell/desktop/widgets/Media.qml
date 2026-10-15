import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

RowLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: Media.active
    signal setOpt(string key, var value)
    spacing: 16
    implicitWidth: 390

    ClippingRectangle {
        implicitWidth: 104
        implicitHeight: 104
        radius: Theme.radius
        color: Theme.surface0
        Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(208, 208); asynchronous: true }
        MIcon { anchors.centerIn: parent; visible: !Media.art; icon: "󰎆"; size: 40; color: Theme.overlay1 }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        StyledText { Layout.fillWidth: true; text: Media.title || I18n.tr("Ничего не играет"); font.bold: true; font.pixelSize: Theme.fontSizeLarge; elide: Text.ElideRight }
        StyledText { Layout.fillWidth: true; text: Media.artist; color: Media.accent; elide: Text.ElideRight }
        Visualizer { visible: root.opts.visualizer !== false; Layout.topMargin: 4; step: 2; barWidth: 4; spacing: 2; maxHeight: 18; mirrored: true }
        Row {
            Layout.topMargin: 2
            spacing: 4
            IconButton { size: 32; iconSize: 16; icon: "󰒮"; onClicked: Media.player?.previous() }
            IconButton { size: 32; iconSize: 18; icon: Media.playing ? "󰏤" : "󰐊"; iconColor: Media.accent; onClicked: Media.player?.togglePlaying() }
            IconButton { size: 32; iconSize: 16; icon: "󰒭"; onClicked: Media.player?.next() }
        }
    }
}
