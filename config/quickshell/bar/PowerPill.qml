import QtQuick
import qs.config
import qs.components
import qs.services

Pill {
    iconColor: Theme.barTint(Theme.red)
    icon: "󰐥"
    onClicked: Panels.toggle("session")
}
