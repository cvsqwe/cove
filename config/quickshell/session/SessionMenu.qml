import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Меню питания. Super+Escape или кнопка на панели. Клавиши: L E S R P, Esc — закрыть.
Scope {
    id: root

    readonly property bool open: Panels.session

    readonly property var actions: [
        { key: "L", icon: "󰌾", label: I18n.tr("Блокировка"), color: Theme.blue,     run: () => Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]) },
        { key: "E", icon: "󰍃", label: I18n.tr("Выход"),      color: Theme.yellow,   run: () => Hypr.exit() },
        { key: "S", icon: "󰤄", label: I18n.tr("Сон"),        color: Theme.lavender, run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { key: "R", icon: "󰜉", label: I18n.tr("Перезагрузка"), color: Theme.peach, run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { key: "P", icon: "󰐥", label: I18n.tr("Выключение"), color: Theme.red,      run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]

    function run(a): void {
        Panels.session = false;
        a.run();
    }

    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-session"
        color: Theme.alpha(Theme.crust, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.session = false
        }

        Item {
            anchors.fill: parent
            focus: root.open
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { Panels.session = false; return; }
                const a = root.actions.find(x => x.key.charCodeAt(0) === e.key);
                if (a) root.run(a);
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 18

            Repeater {
                model: root.actions

                Rectangle {
                    id: btn
                    required property var modelData
                    implicitWidth: 140
                    implicitHeight: 150
                    radius: Theme.radius + 6
                    color: hover.containsMouse ? Theme.surface0 : Theme.base
                    border.width: 2
                    border.color: hover.containsMouse ? modelData.color : Theme.surface0
                    scale: hover.containsMouse ? 1.05 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        MIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: btn.modelData.icon
                            color: btn.modelData.color
                            size: 44
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.label
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.modelData.key
                            color: Theme.overlay0
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(btn.modelData)
                    }
                }
            }
        }
    }
}
