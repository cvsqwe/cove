import QtQuick
import qs.config
import qs.components
import qs.services

Pill {
    visible: Settings.general.weather && Weather.ready
    icon: Weather.icon
    iconColor: Theme.barTint(Theme.yellow)
    label: Math.round(Weather.temp) + "°"
    onClicked: Panels.toggle("dashboard")
}
