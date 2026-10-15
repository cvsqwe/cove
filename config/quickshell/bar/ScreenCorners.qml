import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// Скруглённые нижние углы экрана — продолжают «рамку» панели.
PanelWindow {
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Theme.frameRadius
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-corners"
    color: "transparent"
    mask: Region {}

    InvertedCorner {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        corner: "bottomLeft"
        radius: Theme.frameRadius
        color: Theme.panel
    }
    InvertedCorner {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        corner: "bottomRight"
        radius: Theme.frameRadius
        color: Theme.panel
    }
}
