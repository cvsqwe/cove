import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.config
import qs.components
import qs.services

SubPage {
    id: page
    title: I18n.tr("Сеть")
    icon: "󰤨"

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var nets: (wifi?.networks.values ?? [])
        .filter(n => (n.name ?? "") !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    property string askPsk: "" // сеть, для которой вводим пароль

    onVisibleChanged: if (wifi) wifi.scannerEnabled = visible
    Component.onCompleted: if (wifi) wifi.scannerEnabled = true
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false

    function signalIcon(s: real): string { return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟"; }

    headerExtra: [
        SSwitch {
            visible: page.wifi !== null
            checked: Networking.wifiEnabled
            onToggled: v => Networking.wifiEnabled = v
        }
    ]

    StyledText { visible: page.wired.length > 0; text: I18n.tr("Проводная"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
    Repeater {
        model: page.wired
        DeviceRow {
            required property var modelData
            icon: "󰈀"
            title: modelData.name
            active: modelData.connected
            sub: modelData.connected ? I18n.tr("Подключено") + (modelData.address ? " · " + modelData.address : "") : I18n.tr("Кабель не подключён")
        }
    }

    StyledText { visible: page.wifi !== null; Layout.topMargin: 6; text: "Wi-Fi"; color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
    StyledText {
        visible: page.wifi === null
        text: I18n.tr("Wi-Fi-адаптера нет — только проводная сеть.")
        color: Theme.overlay0
    }

    Repeater {
        model: Networking.wifiEnabled ? page.nets : []
        ColumnLayout {
            id: netItem
            required property var modelData
            Layout.fillWidth: true
            spacing: 6

            DeviceRow {
                icon: page.signalIcon(netItem.modelData.signalStrength)
                title: netItem.modelData.name
                active: netItem.modelData.connected
                busy: netItem.modelData.stateChanging
                subIcon: !netItem.modelData.connected && !netItem.modelData.stateChanging && netItem.modelData.security !== WifiSecurityType.None ? "lock" : ""
                sub: netItem.modelData.connected ? I18n.tr("Подключено")
                    : netItem.modelData.stateChanging ? I18n.tr("Подключение…")
                    : (netItem.modelData.known ? I18n.tr("Сохранена") : Math.round(netItem.modelData.signalStrength * 100) + "%")
                onClicked: {
                    const n = netItem.modelData;
                    if (n.connected) n.disconnect();
                    else if (n.known || n.security === WifiSecurityType.None) n.connect();
                    else page.askPsk = page.askPsk === n.name ? "" : n.name;
                }
                IconButton {
                    visible: netItem.modelData.known
                    size: 30; iconSize: 14; icon: "󰆴"; iconColor: Theme.red
                    onClicked: netItem.modelData.forget()
                }
            }

            RowLayout {
                visible: page.askPsk === netItem.modelData.name
                Layout.fillWidth: true
                spacing: 8
                SField {
                    id: psk
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: I18n.tr("Пароль от ") + netItem.modelData.name
                    onVisibleChanged: if (visible) forceActiveFocus()
                    onAccepted: { netItem.modelData.connectWithPsk(text); page.askPsk = ""; text = ""; }
                }
                SButton { text: I18n.tr("Войти"); primary: true; onClicked: { netItem.modelData.connectWithPsk(psk.text); page.askPsk = ""; psk.text = ""; } }
            }
        }
    }

    SButton {
        Layout.topMargin: 6
        icon: ""
        text: I18n.tr("Расширенные настройки (nmtui)")
        onClicked: { Quickshell.execDetached([Settings.general.terminal, "--class", "floating", "-e", "nmtui"]); Panels.control = false; }
    }
}
