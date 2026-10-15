import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    spacing: 10
    readonly property color col: Focus.phase === "work" ? Theme.red : Focus.phase === "break" ? Theme.green : Theme.overlay1

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 150
        implicitHeight: 150
        RingArc {
            anchors.fill: parent
            thickness: 10
            value: Focus.active ? Focus.progress : 0
            color: root.col
        }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 0
            StyledText { Layout.alignment: Qt.AlignHCenter; text: Focus.active ? Focus.timeText : "󰐊"; font.pixelSize: Focus.active ? 34 : 40; font.bold: true; color: Focus.active ? Theme.text : Theme.accent }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Focus.phase === "work" ? I18n.tr("фокус") : Focus.phase === "break" ? I18n.tr("перерыв") : I18n.tr("старт")
                color: root.col
                font.pixelSize: Theme.fontSizeSmall
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !root.editing
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: m => m.button === Qt.RightButton ? Focus.skip() : Focus.toggle()
        }
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: I18n.tr("раундов: ") + Focus.rounds + I18n.tr("  ·  ПКМ — пропустить")
        color: Theme.overlay0
        font.pixelSize: Theme.fontSizeSmall
    }
}
