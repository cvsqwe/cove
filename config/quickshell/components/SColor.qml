import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.config

// Выбор цвета: готовые образцы + свой (оттенок/насыщенность/яркость + HEX) + пипетка с экрана.
Row {
    id: root

    property color value: "#cba6f7"
    signal picked(color value)

    readonly property var presets: ["#cba6f7", "#f5c2e7", "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1",
        "#94e2d5", "#89dceb", "#89b4fa", "#b4befe", "#ff4fd8", "#00e5ff"]

    spacing: 6

    Repeater {
        model: root.presets
        Rectangle {
            required property string modelData
            width: 26
            height: 26
            radius: 13
            color: modelData
            border.width: Qt.colorEqual(root.value, modelData) ? 3 : 0
            border.color: Theme.text
            scale: sw.containsMouse ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            MouseArea { id: sw; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(parent.modelData) }
        }
    }

    // свой цвет
    Rectangle {
        width: 26
        height: 26
        radius: 13
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#ff5555" }
            GradientStop { position: 0.33; color: "#55ff55" }
            GradientStop { position: 0.66; color: "#5555ff" }
            GradientStop { position: 1; color: "#ff55ff" }
        }
        StyledText { anchors.centerIn: parent; text: "+"; color: "white"; font.bold: true }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pop.open() }

        Popup {
            id: pop
            y: 34
            x: -220
            width: 300
            padding: 14
            property real h: Math.max(0, root.value.hslHue)
            property real s: root.value.hslSaturation
            property real l: root.value.hslLightness
            onOpened: { h = Math.max(0, root.value.hslHue); s = root.value.hslSaturation; l = root.value.hslLightness; hex.text = String(root.value); }
            function emit(): void { const c = Qt.hsla(h, s, l, 1); hex.text = String(c); root.picked(c); }

            background: Rectangle { radius: Theme.radius; color: Theme.mantle; border.width: 1; border.color: Theme.surface1 }

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Theme.radiusSmall
                    color: Qt.hsla(pop.h, pop.s, pop.l, 1)
                }

                Repeater {
                    model: [
                        { k: "h", label: I18n.tr("Оттенок") },
                        { k: "s", label: I18n.tr("Насыщенность") },
                        { k: "l", label: I18n.tr("Яркость") }
                    ]
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 4
                        StyledText { text: modelData.label; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 14
                            radius: 7
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: modelData.k === "h" ? Qt.hsla(0, 0.8, 0.6, 1) : modelData.k === "s" ? Qt.hsla(pop.h, 0, pop.l, 1) : "black" }
                                GradientStop { position: 0.5; color: modelData.k === "h" ? Qt.hsla(0.5, 0.8, 0.6, 1) : Qt.hsla(pop.h, modelData.k === "s" ? 0.5 : pop.s, 0.5, 1) }
                                GradientStop { position: 1; color: modelData.k === "h" ? Qt.hsla(0.99, 0.8, 0.6, 1) : modelData.k === "s" ? Qt.hsla(pop.h, 1, pop.l, 1) : "white" }
                            }
                            Rectangle {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: (parent.width - width) * pop[modelData.k]
                                color: "transparent"
                                border.width: 3
                                border.color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                function upd(x: real): void { pop[parent.parent.modelData.k] = Math.max(0, Math.min(1, x / width)); pop.emit(); }
                                onPressed: m => upd(m.x)
                                onPositionChanged: m => { if (pressed) upd(m.x); }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    SField {
                        id: hex
                        Layout.fillWidth: true
                        onEdited: t => { if (/^#[0-9a-fA-F]{6}$/.test(t.trim())) root.picked(t.trim()); }
                    }
                    SButton {
                        icon: "󰈊"
                        onClicked: { pop.close(); picker.running = true; }
                    }
                }
            }
        }
    }

    // пипетка с экрана
    property var picker: Process {
        command: ["hyprpicker", "-f", "hex", "-n"]
        stdout: StdioCollector { onStreamFinished: { const v = text.trim(); if (/^#[0-9a-fA-F]{6}$/.test(v)) root.picked(v); } }
    }
}
