import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Затемнение экрана вокруг лаунчера (Настройки → Лаунчер → «Затемнять экран»). Клик — закрыть.
PanelWindow {
    id: win
    screen: Panels.screen   // монитор с фокусом в момент открытия
    readonly property bool on: Panels.launcher && Settings.launcher.dim
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: on || shade.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-launcher-dim"

    Rectangle {
        id: shade
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.45)
        opacity: win.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    }
    MouseArea { anchors.fill: parent; onClicked: Panels.launcher = false }
}
