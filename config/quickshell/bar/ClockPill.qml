import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Pill {
    SystemClock { id: clock; precision: SystemClock.Minutes }
    icon: "󰥔"
    pinLabel: true
    label: Qt.formatDateTime(clock.date, "HH:mm")
    onClicked: Panels.toggle("dashboard")
}
