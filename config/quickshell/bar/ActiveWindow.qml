import QtQuick
import Quickshell.Hyprland
import qs.config
import qs.components

StyledText {
    property real maxWidth: 400
    readonly property var win: Hyprland.activeToplevel
    readonly property bool onCurrent: !!win && !!win.workspace && win.workspace.id === Hyprland.focusedWorkspace?.id

    width: Math.min(implicitWidth, maxWidth)
    visible: text !== ""
    leftPadding: 12
    rightPadding: 12
    text: onCurrent ? win.title : ""
    color: Theme.subtext1
    elide: Text.ElideRight
}
