import QtQuick
import qs.config
import qs.components
import qs.services

// VPN подключён: щит и страна. Клик — VPN в центре управления.
Pill {
    visible: Vpn.on || Vpn.busy
    icon: Vpn.busy ? "vpn_key" : "vpn_lock"
    iconColor: Vpn.busy ? Theme.overlay1 : Theme.barTint(Theme.green)
    label: Vpn.where?.code ?? "VPN"
    onClicked: Panels.openControl("vpn")
}
