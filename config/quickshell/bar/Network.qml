import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components

// Значок сети. Клик — nmtui в терминале.
Pill {
    readonly property var device: Networking.devices.values.find(d => d.connected) ?? null
    readonly property var wifi: device && device.type === DeviceType.Wifi
        ? device.networks.values.find(n => n.connected) ?? null
        : null

    icon: {
        if (!device) return "󰤮";
        if (device.type === DeviceType.Wired) return "󰌘";
        const s = wifi?.signalStrength ?? 0;
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟";
    }
    iconColor: device ? Theme.barTint(Theme.accent2) : Theme.red
    label: wifi ? wifi.name : ""

    onClicked: Quickshell.execDetached([Settings.general.terminal, "--class", "floating", "-e", "nmtui"])
}
