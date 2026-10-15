import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Обзор воркспейсов 1–10 с живыми превью окон. Super+Tab.
// Клик по окну — фокус, клик по воркспейсу — переход, перетаскивание окна — перенос.
PanelWindow {
    id: win

    readonly property bool open: Panels.overview
    readonly property real scale: 0.16
    readonly property var mon: Hyprland.focusedMonitor
    readonly property real monW: mon?.width ?? 1920
    readonly property real monH: mon?.height ?? 1080

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || bg.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        keys.forceActiveFocus();
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.55)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.overview = false
        }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: Panels.overview = false
            Keys.onPressed: e => {
                const n = e.key - Qt.Key_0;
                if (n >= 0 && n <= 9) {
                    Hypr.focusWorkspace(n === 0 ? 10 : n);
                    Panels.overview = false;
                }
            }
        }

        GridLayout {
            id: grid
            anchors.centerIn: parent
            columns: 5
            rowSpacing: 22
            columnSpacing: 22
            scale: win.open ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

            Repeater {
                model: 10

                Rectangle {
                    id: tile
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                    readonly property bool isActive: Hyprland.focusedWorkspace?.id === wsId

                    implicitWidth: win.monW * win.scale
                    implicitHeight: win.monH * win.scale
                    radius: Theme.radius
                    color: Theme.alpha(Theme.base, 0.92)
                    border.width: isActive || drop.containsDrag ? 2 : 1
                    border.color: drop.containsDrag ? Theme.accent2 : isActive ? Theme.accent : Theme.surface0
                    clip: true

                    StyledText {
                        anchors.centerIn: parent
                        text: tile.wsId
                        color: Theme.surface2
                        font.pixelSize: 34
                        font.bold: true
                        visible: (tile.ws?.toplevels.values.length ?? 0) === 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            Hypr.focusWorkspace(tile.wsId);
                            Panels.overview = false;
                        }
                    }

                    DropArea {
                        id: drop
                        anchors.fill: parent
                        onDropped: d => {
                            if (d.source?.address) Hypr.moveWindow(d.source.address, tile.wsId);
                        }
                    }

                    Repeater {
                        model: tile.ws?.toplevels ?? null

                        Item {
                            id: winItem
                            required property var modelData
                            readonly property var ipc: modelData.lastIpcObject
                            readonly property string address: modelData.address
                            readonly property real ox: (win.mon?.x ?? 0)
                            readonly property real oy: (win.mon?.y ?? 0)

                            x: ((ipc?.at?.[0] ?? 0) - ox) * win.scale
                            y: ((ipc?.at?.[1] ?? 0) - oy) * win.scale
                            width: (ipc?.size?.[0] ?? 100) * win.scale
                            height: (ipc?.size?.[1] ?? 100) * win.scale
                            z: hov.drag.active ? 10 : 1

                            Drag.active: hov.drag.active
                            Drag.source: winItem
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: Theme.surface0
                                border.width: hov.containsMouse ? 2 : 1
                                border.color: hov.containsMouse ? Theme.accent : Theme.surface1
                                clip: true

                                ScreencopyView {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.open ? winItem.modelData.wayland : null
                                    live: win.open
                                }
                            }

                            MouseArea {
                                id: hov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                drag.target: winItem
                                property point start
                                onPressed: start = Qt.point(winItem.x, winItem.y)
                                onReleased: {
                                    if (drag.active) {
                                        winItem.Drag.drop();
                                        winItem.x = Qt.binding(() => ((winItem.ipc?.at?.[0] ?? 0) - winItem.ox) * win.scale);
                                        winItem.y = Qt.binding(() => ((winItem.ipc?.at?.[1] ?? 0) - winItem.oy) * win.scale);
                                        Qt.callLater(Hyprland.refreshToplevels);
                                    }
                                }
                                onClicked: {
                                    Hypr.focusWindow(winItem.address);
                                    Panels.overview = false;
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 8
                        width: 22
                        height: 22
                        radius: 11
                        color: tile.isActive ? Theme.accent : Theme.surface0
                        StyledText {
                            anchors.centerIn: parent
                            text: tile.wsId
                            font.pixelSize: Theme.fontSizeSmall
                            color: tile.isActive ? Theme.crust : Theme.subtext0
                        }
                    }
                }
            }
        }

        StyledText {
            anchors.top: grid.bottom
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("Перетащите окно на другой воркспейс · 1–0 — переход · Esc — закрыть")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
