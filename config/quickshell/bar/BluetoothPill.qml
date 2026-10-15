import QtQuick
import Quickshell.Bluetooth
import qs.config
import qs.components
import qs.services

// Bluetooth: имя подключённого устройства и заряд. Клик — центр управления.
Pill {
    readonly property var dev: BtAgent.connected[0] ?? null
    visible: Bluetooth.defaultAdapter !== null
    icon: !Bluetooth.defaultAdapter?.enabled ? "󰂲" : dev ? "󰂱" : "󰂯"
    iconColor: Bluetooth.defaultAdapter?.enabled ? Theme.barTint(Theme.accent2) : Theme.overlay0
    label: dev ? (dev.batteryAvailable ? `${dev.name} ${Math.round(dev.battery * 100)}%` : dev.name) : ""
    onClicked: Panels.openControl("bluetooth")
}
