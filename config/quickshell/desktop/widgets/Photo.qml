import QtQuick
import Quickshell.Widgets
import qs.config
import qs.components

ClippingRectangle {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    readonly property int size: opts.size ?? 260
    implicitWidth: size
    implicitHeight: opts.shape === "circle" ? size : Math.round(size * 1.25)
    radius: opts.shape === "circle" ? size / 2 : opts.shape === "square" ? 0 : Theme.radius + 6
    color: Theme.surface0
    border.width: 0

    Image {
        anchors.fill: parent
        source: root.opts.path ? "file://" + Settings.expand(String(root.opts.path)) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        asynchronous: true
    }
    StyledText {
        anchors.centerIn: parent
        visible: !root.opts.path
        horizontalAlignment: Text.AlignHCenter
        text: I18n.tr("Укажите путь\nв редакторе")
        color: Theme.overlay1
    }
}
