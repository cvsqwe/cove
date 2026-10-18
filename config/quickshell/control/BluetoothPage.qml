import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.config
import qs.components
import qs.services

SubPage {
    id: page
    title: "Bluetooth"
    icon: "󰂯"

    readonly property var ad: Bluetooth.defaultAdapter

    // пока страница открыта — ищем устройства
    Component.onCompleted: if (ad?.enabled) BtAgent.scan(true)
    Component.onDestruction: BtAgent.scan(false)
    onVisibleChanged: BtAgent.scan(visible && !!ad?.enabled)

    function devIcon(d): string {
        const i = d.icon ?? "";
        if (i.includes("headset") || i.includes("headphone")) return "󰋋";
        if (i.includes("audio") || i.includes("speaker")) return "󰓃";
        if (i.includes("keyboard")) return "󰌌";
        if (i.includes("mouse")) return "󰍽";
        if (i.includes("phone")) return "󰄜";
        if (i.includes("gaming") || i.includes("joystick")) return "󰊴";
        if (i.includes("computer")) return "󰟀";
        if (i.includes("watch")) return "󰖉";
        return "󰂯";
    }

    headerExtra: [
        SSwitch {
            checked: page.ad?.enabled ?? false
            onToggled: v => { if (page.ad) { page.ad.enabled = v; BtAgent.scan(v); } }
        }
    ]

    StyledText {
        visible: !page.ad
        Layout.fillWidth: true
        text: I18n.tr("Bluetooth-адаптер не найден.")
        color: Theme.overlay0
    }

    // код сопряжения
    Rectangle {
        visible: BtAgent.passkey !== ""
        Layout.fillWidth: true
        implicitHeight: 78
        radius: Theme.radius
        color: Theme.alpha(Theme.accent, 0.15)
        border.width: 1
        border.color: Theme.accent
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            StyledText { Layout.alignment: Qt.AlignHCenter; text: I18n.tr("Проверьте код на ") + (BtAgent.pendingName || I18n.tr("устройстве")); color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall }
            StyledText { Layout.alignment: Qt.AlignHCenter; text: BtAgent.passkey.replace(/(\d{3})(\d{3})/, "$1 $2"); font.pixelSize: 28; font.bold: true; color: Theme.accent }
        }
    }

    StyledText { visible: BtAgent.paired.length > 0; text: I18n.tr("Мои устройства"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }

    Repeater {
        model: BtAgent.paired
        DeviceRow {
            id: dr
            required property var modelData
            icon: page.devIcon(modelData)
            title: modelData.name
            active: modelData.connected
            busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
            sub: modelData.connected ? I18n.tr("Подключено")
                : busy ? I18n.tr("Подключение…") : I18n.tr("Не подключено")
            battery: modelData.connected && modelData.batteryAvailable ? modelData.battery : -1
            onClicked: BtAgent.toggle(modelData)
            IconButton { size: 30; iconSize: 14; icon: "󰆴"; iconColor: Theme.red; onClicked: BtAgent.forget(dr.modelData) }
        }
    }

    RowLayout {
        visible: !!page.ad?.enabled
        Layout.topMargin: 6
        StyledText { text: I18n.tr("Доступные"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
        MIcon {
            visible: page.ad?.discovering ?? false
            icon: "󰑓"
            color: Theme.accent
            RotationAnimation on rotation { running: page.ad?.discovering ?? false; from: 0; to: 360; duration: 1400; loops: Animation.Infinite }
        }
        Item { Layout.fillWidth: true }
        StyledText {
            text: page.ad?.discovering ? I18n.tr("идёт поиск…") : I18n.tr("искать")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: BtAgent.scan(!page.ad.discovering) }
        }
    }

    Repeater {
        model: page.ad?.enabled ? BtAgent.found : []
        DeviceRow {
            required property var modelData
            icon: page.devIcon(modelData)
            title: modelData.name
            busy: modelData.pairing
            sub: modelData.pairing ? I18n.tr("Сопряжение…") : I18n.tr("Нажмите, чтобы подключить")
            onClicked: BtAgent.pair(modelData)
        }
    }

    StyledText {
        visible: !!page.ad?.enabled && BtAgent.found.length === 0
        Layout.fillWidth: true
        text: I18n.tr("Переведите устройство в режим сопряжения — оно появится здесь.")
        color: Theme.overlay0
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.Wrap
    }
}
