import QtQuick
import qs.config
import qs.components
import qs.services

Pill {
    // в режиме «только значки» раскладка — коротким текстом без значка
    icon: Theme.barHoverLabels ? "" : "󰌌"
    pinLabel: true
    iconColor: Theme.barTint(Theme.lavender)
    label: Hypr.layout
    onClicked: Hypr.nextLayout()
}
