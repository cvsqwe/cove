import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Монитор системы для дашборда: CPU / RAM / GPU с графиками и температурами.
Card {
    id: card
    implicitWidth: 230

    component Meter: ColumnLayout {
        property string icon
        property string label
        property real value
        property var history
        property color color
        property string extra: ""
        Layout.fillWidth: true
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            MIcon { icon: parent.parent.icon; color: parent.parent.color }
            StyledText { text: parent.parent.label; font.pixelSize: Theme.fontSizeSmall; color: Theme.subtext1 }
            Item { Layout.fillWidth: true }
            StyledText { text: parent.parent.extra; font.pixelSize: Theme.fontSizeSmall; color: Theme.overlay1 }
            StyledText { text: Math.round(parent.parent.value * 100) + "%"; font.bold: true; font.pixelSize: Theme.fontSizeSmall + 1 }
        }
        Sparkline {
            Layout.fillWidth: true
            implicitHeight: 30
            values: parent.history
            color: parent.color
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Meter {
            icon: "󰻠"; label: "CPU"; color: Theme.accent
            value: Sysmon.cpu; history: Sysmon.cpuHistory
            extra: Sysmon.cpuTemp > 0 ? Math.round(Sysmon.cpuTemp) + "°" : ""
        }
        Meter {
            icon: "󰍛"; label: "RAM"; color: Theme.accent2
            value: Sysmon.ram; history: Sysmon.ramHistory
            extra: Sysmon.ramUsedGb.toFixed(1) + I18n.tr(" ГБ")
        }
        Meter {
            icon: "󰢮"; label: "GPU"; color: Theme.peach
            value: Sysmon.gpu; history: Sysmon.gpuHistory
            extra: Sysmon.gpuTemp > 0 ? Math.round(Sysmon.gpuTemp) + "°" : ""
        }
    }
}
