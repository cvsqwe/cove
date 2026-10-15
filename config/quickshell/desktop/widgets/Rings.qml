import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

RowLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    spacing: 18

    component Ring: ColumnLayout {
        id: ring
        property real value
        property color color
        property string label
        property string text
        spacing: 6
        Item {
            implicitWidth: 86
            implicitHeight: 86
            RingArc {
                anchors.fill: parent
                value: ring.value
                color: ring.color
            }
            StyledText { anchors.centerIn: parent; text: ring.text; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
        }
        StyledText { Layout.alignment: Qt.AlignHCenter; text: ring.label; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall }
    }

    Ring { value: Sysmon.cpu; color: Theme.accent; label: "CPU"; text: Math.round(Sysmon.cpu * 100) + "%" }
    Ring { value: Sysmon.ram; color: Theme.accent2; label: "RAM"; text: Math.round(Sysmon.ram * 100) + "%" }
    Ring { visible: root.opts.gpu !== false; value: Sysmon.gpu; color: Theme.teal; label: "GPU"; text: Math.round(Sysmon.gpu * 100) + "%" }
    Ring {
        visible: root.opts.temp !== false
        value: Sysmon.cpuTemp / 100
        color: Sysmon.cpuTemp > 80 ? Theme.red : Sysmon.cpuTemp > 65 ? Theme.peach : Theme.green
        label: I18n.tr("Темп.")
        text: Math.round(Sysmon.cpuTemp) + "°"
    }
}
