import QtQuick
import qs.config
import qs.components
import qs.services

// Нагрузка: CPU% и RAM%, цвет краснеет под нагрузкой. Клик — дашборд.
Pill {
    readonly property real hot: Math.max(Sysmon.cpu, Sysmon.ram)
    icon: "󰍛"
    iconColor: hot > 0.85 ? Theme.red : hot > 0.6 ? Theme.peach : Theme.barTint(Theme.accent2)
    label: `${Math.round(Sysmon.cpu * 100)}% · ${Math.round(Sysmon.ram * 100)}%`
    onClicked: Panels.toggle("dashboard")
}
