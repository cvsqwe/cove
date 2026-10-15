import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Шпаргалка хоткеев (Super+/). Строится из настроек — всегда актуальна.
PanelWindow {
    id: win

    readonly property bool open: Panels.cheatsheet
    readonly property var groups: Actions.groups.map(g => ({
        g, list: (Settings.binds ?? []).filter(b => b.enabled !== false && (Actions.get(b.action)?.group ?? "") === g)
            // повторяющиеся по смыслу (воркспейсы 1–10) сворачиваем
            .filter((b, i, arr) => !(["ws.focus", "ws.move", "ws.moveSilent", "win.focus", "win.move", "win.resize"].includes(b.action)
                && arr.findIndex(x => x.action === b.action) !== i))
    })).filter(x => x.list.length > 0)

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || bg.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-cheatsheet"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function summary(b): string {
        const a = Actions.get(b.action);
        if (["ws.focus", "ws.move", "ws.moveSilent"].includes(b.action)) return a.label + " 1–10";
        if (["win.focus", "win.move", "win.resize"].includes(b.action)) return a.label + I18n.tr(" (стрелки)");
        return Actions.describe(b);
    }
    function caps(b): var {
        const k = Binds.keycaps(b);
        if (["ws.focus", "ws.move", "ws.moveSilent"].includes(b.action)) k[k.length - 1] = "1…0";
        if (["win.focus", "win.move", "win.resize"].includes(b.action)) k[k.length - 1] = "←↑→↓";
        return k;
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.alpha(Theme.crust, 0.94)
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        MouseArea { anchors.fill: parent; onClicked: Panels.cheatsheet = false }
        Item { focus: win.open; Keys.onPressed: Panels.cheatsheet = false }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 1500)
            spacing: 20
            scale: win.open ? 1 : 0.96
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

            RowLayout {
                StyledText { text: I18n.tr("Хоткеи"); font.pixelSize: 28; font.bold: true }
                Item { Layout.fillWidth: true }
                StyledText { text: I18n.tr("Изменить — Настройки → Хоткеи (Super + ,) · любая клавиша — закрыть"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(flow.implicitHeight, win.height - 170)
                contentHeight: flow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
            Flow {
                id: flow
                width: parent.width
                spacing: 18

                Repeater {
                    model: win.groups
                    Rectangle {
                        required property var modelData
                        width: 470
                        height: col.implicitHeight + 28
                        radius: Theme.radius
                        color: Theme.base
                        border.width: 1
                        border.color: Theme.surface0

                        ColumnLayout {
                            id: col
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6
                            StyledText { text: parent.parent.modelData.g; color: Theme.accent; font.bold: true }
                            Repeater {
                                model: parent.parent.modelData.list
                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: win.summary(modelData)
                                        elide: Text.ElideRight
                                        font.pixelSize: Theme.fontSizeSmall + 1
                                    }
                                    KeyCaps { keys: win.caps(parent.modelData) }
                                }
                            }
                        }
                    }
                }
            }
            }
        }
    }
}
