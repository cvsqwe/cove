import QtQuick
import qs.config
import qs.components
import qs.services

// Колокольчик: число уведомлений, режим «не беспокоить». Клик — центр управления.
Pill {
    icon: Notifs.quiet ? "󰂛" : Notifs.count > 0 ? "󰂞" : "󰂚"
    iconColor: Notifs.quiet ? Theme.overlay0 : Notifs.count > 0 ? Theme.accent : Theme.barTint(Theme.subtext0)
    label: Notifs.count > 0 ? String(Notifs.count) : ""
    badge: Theme.barHoverLabels && Notifs.count > 0 && !Notifs.quiet
    onClicked: m => {
        if (m.button === Qt.RightButton) Store.dnd = !Store.dnd;
        else Panels.toggle("control");
    }
}
