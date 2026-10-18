import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Результат пипетки: образец, HEX/RGB/HSL (клик — копировать), история.
RowLayout {
    id: root

    property bool shown: false
    property string copied: ""

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 14

    Rectangle {
        implicitWidth: 86
        implicitHeight: 86
        radius: Theme.radius
        color: Picker.color
        border.width: 2
        border.color: Theme.surface1
    }

    ColumnLayout {
        spacing: 4
        Repeater {
            model: [Picker.hex, Picker.rgb, Picker.hsl]
            Rectangle {
                required property string modelData
                implicitWidth: 230
                implicitHeight: 24
                radius: 6
                color: m.containsMouse ? Theme.surface0 : "transparent"
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    text: parent.modelData
                    font.bold: parent.modelData === Picker.hex
                }
                MIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.copied === parent.modelData ? "check" : "content_copy"
                    color: root.copied === parent.modelData ? Theme.green : Theme.overlay1
                }
                MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Picker.copy(parent.modelData); root.copied = parent.modelData; } }
            }
        }
        Row {
            spacing: 4
            Repeater {
                model: Picker.history.slice(1)
                Rectangle {
                    required property string modelData
                    width: 18; height: 18; radius: 9
                    color: modelData
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Picker.copy(parent.modelData) }
                }
            }
        }
    }

    Connections {
        target: Picker
        function onSerialChanged(): void { root.copied = Picker.hex; }
    }
}
