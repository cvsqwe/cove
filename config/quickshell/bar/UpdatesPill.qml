import QtQuick
import qs.config
import qs.components
import qs.services

// Доступные обновления: клик — обновить в терминале, ПКМ — проверить заново.
Pill {
    visible: Updates.count > 0
    icon: "system_update_alt"
    iconColor: Theme.barTint(Theme.green)
    label: String(Updates.count)
    pinLabel: true   // число видно всегда, даже при «подписях по наведению»
    onClicked: m => m.button === Qt.RightButton ? Updates.check() : Updates.upgrade()
}
