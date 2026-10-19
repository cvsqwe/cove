import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Обзор воркспейсов 1–10 с живыми превью окон. Super+Tab.
// Клик по окну — фокус, клик по воркспейсу — переход, перетаскивание окна — перенос.
// Переключение окон: Super+Tab выделяет предыдущее окно, Tab при зажатом Super — дальше (Shift — назад),
// отпустить Super — перейти. Стрелки ←/→ и Enter тоже работают.
PanelWindow {
    id: win
    screen: Panels.screen   // монитор с фокусом в момент открытия

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
        buildOrder();
    } else {
        Panels.overviewSwitch = false;
    }

    // ---- переключение окон ----
    property var order: []    // адреса окон, от недавнего к давнему (обычные воркспейсы)
    property int sel: -1
    readonly property string selAddress: sel >= 0 && sel < order.length ? order[sel] : ""
    readonly property var selWindow: Hyprland.toplevels.values.find(t => t.address === selAddress) ?? null

    function buildOrder(): void {
        order = Hyprland.toplevels.values
            .filter(t => (t.workspace?.id ?? -1) > 0)
            .sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999))
            .map(t => t.address);
        // открыли переключателем — сразу на предыдущем окне, как Alt+Tab
        sel = order.length === 0 ? -1 : Panels.overviewSwitch && order.length > 1 ? 1 : 0;
    }
    function step(d: int): void {
        if (order.length === 0) return;
        sel = ((sel < 0 ? 0 : sel) + d + order.length) % order.length;
    }
    function activate(): void {
        if (selAddress !== "") Hypr.focusWindow(selAddress);
        Panels.overview = false;
    }
    Connections {
        target: Panels
        function onOverviewStep(d: int): void { win.step(d); }
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
            Keys.onReturnPressed: win.activate()
            Keys.onEnterPressed: win.activate()
            Keys.onRightPressed: win.step(1)
            Keys.onLeftPressed: win.step(-1)
            Keys.onTabPressed: win.step(1)
            Keys.onBacktabPressed: win.step(-1)
            Keys.onPressed: e => {
                const n = e.key - Qt.Key_0;
                if (n >= 0 && n <= 9) {
                    Hypr.focusWorkspace(n === 0 ? 10 : n);
                    Panels.overview = false;
                }
            }
            // отпустили Super, открыв обзор переключателем — переходим на выбранное окно
            Keys.onReleased: e => {
                if (Panels.overviewSwitch && [Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_Meta].includes(e.key)) win.activate();
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
                            z: hov.drag.active ? 10 : selected ? 5 : 1

                            Drag.active: hov.drag.active
                            Drag.source: winItem
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            readonly property bool selected: win.selAddress === address

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: Theme.surface0
                                border.width: winItem.selected ? 3 : hov.containsMouse ? 2 : 1
                                border.color: winItem.selected ? Theme.accent2 : hov.containsMouse ? Theme.accent : Theme.surface1
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

        // выбранное окно: значок, заголовок и воркспейс
        Rectangle {
            id: selCard
            anchors.bottom: grid.top
            anchors.bottomMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            visible: win.selWindow !== null
            implicitWidth: Math.min(selRow.implicitWidth + 32, win.width * 0.6)
            implicitHeight: 44
            radius: 22
            color: Theme.alpha(Theme.base, 0.95)
            border.width: 1
            border.color: Theme.accent2
            readonly property string app: win.selWindow?.wayland?.appId || win.selWindow?.lastIpcObject?.class || ""
            readonly property var entry: app ? DesktopEntries.heuristicLookup(app) : null
            RowLayout {
                id: selRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, selCard.width - 32)
                spacing: 10
                IconImage {
                    implicitSize: 22
                    source: Quickshell.iconPath(selCard.entry?.icon ?? selCard.app, "application-x-executable")
                }
                StyledText {
                    Layout.fillWidth: true
                    text: win.selWindow?.title || selCard.app
                    elide: Text.ElideRight
                    font.bold: true
                }
                StyledText {
                    text: I18n.tr("воркспейс ") + (win.selWindow?.workspace?.id ?? "")
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        StyledText {
            anchors.top: grid.bottom
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            text: I18n.tr("Tab / ←→ — выбрать окно · отпустить Super или Enter — перейти · перетаскивание — на другой воркспейс · 1–0 · Esc")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
