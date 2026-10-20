import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Центр управления — ящик справа (Super+N, колокольчик).
// Главный экран + подстраницы Bluetooth / Сеть / Звук (Panels.controlPage).
Drawer {
    id: root
    screen: Panels.screen   // монитор с фокусом в момент открытия

    side: "right"
    drawerWidth: 430
    drawerHeight: Math.min(920, (screen?.height ?? 1080) - 140)   // под переключателями — место для уведомлений
    open: Panels.control
    keyboardOnDemand: true   // поле пароля Wi-Fi, ответ на уведомление
    onCloseRequested: Panels.control = false
    onOpenChanged: if (!open) resetPage.restart()

    Timer { id: resetPage; interval: 600; onTriggered: if (!Panels.control) Panels.controlPage = "" }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifiDev?.networks.values.find(n => n.connected) ?? null
    readonly property var wiredUp: Networking.devices.values.some(d => d.type === DeviceType.Wired && d.connected)

    Item {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 12
        clip: true

        // ---------- главный экран ----------
        ColumnLayout {
            id: main
            width: parent.width
            height: parent.height
            x: Panels.controlPage === "" ? 0 : -parent.width - 20
            opacity: Panels.controlPage === "" ? 1 : 0
            Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            spacing: 14

            // шапка
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: 23
                    color: Theme.accent
                    clip: true
                    MIcon { anchors.centerIn: parent; visible: !ava.visible; icon: "cove"; color: Theme.onAccent; size: 26 }
                    Image {
                        id: ava
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: Settings.general.avatar ? "file://" + Settings.expand(Settings.general.avatar) : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(92, 92)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText { text: Settings.displayName; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                    RowLayout {
                        spacing: 4
                        MIcon { visible: Power.hasBattery; icon: Power.icon(); color: Power.tint(); size: Theme.fontSizeSmall + 1 }
                        StyledText {
                            text: Power.hasBattery ? `${Power.percent}% · ${Power.statusText}` : I18n.tr("в работе ") + System.uptime
                            color: Power.low ? Theme.red : Theme.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
                IconButton { icon: "󰒓"; onClicked: Panels.openSettings("") }
                IconButton { icon: "󰐥"; iconColor: Theme.red; onClicked: Panels.toggle("session") }
            }

            // переключатели
            GridLayout {
                readonly property string look: Settings.appearance.tileStyle ?? "tiles"
                Layout.fillWidth: true
                columns: look === "round" ? 4 : look === "list" ? 1 : 2
                rowSpacing: look === "round" ? 12 : look === "list" ? 4 : 8
                columnSpacing: 8

                Toggle {
                    Layout.fillWidth: true
                    icon: root.wiredUp ? "󰈀" : Networking.wifiEnabled ? "󰤨" : "󰤭"
                    label: I18n.tr("Сеть")
                    sub: root.wifiNet?.name ?? (root.wiredUp ? I18n.tr("Проводная") : Networking.wifiEnabled ? I18n.tr("Не подключено") : I18n.tr("Wi-Fi выключен"))
                    on: root.wiredUp || !!root.wifiNet
                    hasMore: true
                    onClicked: root.wifiDev ? (Networking.wifiEnabled = !Networking.wifiEnabled) : (Panels.controlPage = "wifi")
                    onMore: Panels.controlPage = "wifi"
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: root.adapter?.enabled ? (BtAgent.connected.length ? "󰂱" : "󰂯") : "󰂲"
                    label: "Bluetooth"
                    sub: !root.adapter ? I18n.tr("Нет адаптера")
                        : BtAgent.connected.length > 0 ? BtAgent.connected.map(d => d.name).join(", ")
                        : root.adapter.enabled ? I18n.tr("Включён") : I18n.tr("Выключен")
                    on: root.adapter?.enabled ?? false
                    hasMore: true
                    onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                    onMore: Panels.controlPage = "bluetooth"
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "󰂛"
                    label: I18n.tr("Не беспокоить")
                    sub: Notifs.scheduled ? I18n.tr("По расписанию") : Store.dnd ? I18n.tr("Только важные") : I18n.tr("Выключено")
                    on: Notifs.quiet
                    onClicked: Store.dnd = !Store.dnd
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "󰖔"
                    label: I18n.tr("Ночной свет")
                    sub: Store.nightLight ? Settings.nightLight.temperature + " K" : I18n.tr("Выключен")
                    on: Store.nightLight
                    onClicked: Store.nightLight = !Store.nightLight
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "󰅶"
                    label: I18n.tr("Не засыпать")
                    sub: Store.caffeine ? I18n.tr("Экран не гаснет") : I18n.tr("Выключено")
                    on: Store.caffeine
                    onClicked: Store.caffeine = !Store.caffeine
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "󰊴"
                    label: I18n.tr("Игровой режим")
                    sub: GameMode.auto ? I18n.tr("Включён автоматически") : Store.gameMode ? I18n.tr("Без эффектов") : I18n.tr("Выключен")
                    on: GameMode.active
                    onClicked: Store.gameMode = !Store.gameMode
                }
                // VPN — во всю ширину: включение одним нажатием, стрелка — серверы
                Toggle {
                    Layout.fillWidth: true
                    Layout.columnSpan: (Settings.appearance.tileStyle ?? "tiles") === "tiles" ? 2 : 1
                    icon: Vpn.on ? "vpn_lock" : "vpn_key_off"
                    label: "VPN"
                    sub: Vpn.on ? ((Vpn.where ? Vpn.where.flag + " " + Vpn.where.country + " · " : "") + Vpn.current)
                        : Vpn.state === "starting" ? I18n.tr("Подключаюсь…")
                        : Vpn.state === "error" ? Vpn.error.split("\n")[0]
                        : !Vpn.ready || !Vpn.hasSources ? I18n.tr("Настроить") : I18n.tr("Отключено")
                    on: Vpn.on
                    hasMore: true
                    onClicked: Vpn.ready && Vpn.hasSources ? Vpn.toggle() : (Panels.controlPage = "vpn")
                    onMore: Panels.controlPage = "vpn"
                }
                Toggle {
                    Layout.fillWidth: true
                    visible: Power.hasProfiles
                    icon: Power.profileInfo(Power.profile).icon
                    label: I18n.tr("Режим питания")
                    sub: Power.profileInfo(Power.profile).label
                    on: Power.profile !== PowerProfile.Balanced
                    onClicked: Power.cycleProfile()
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "graphic_eq"
                    label: I18n.tr("Эффекты звука")
                    sub: Settings.sound.enabled ? SoundFx.presetLabel(Settings.sound.preset) : I18n.tr("Выключены")
                    on: Settings.sound.enabled
                    hasMore: true
                    onClicked: Settings.sound.enabled = !Settings.sound.enabled
                    onMore: Panels.controlPage = "audio"
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: Settings.appearance.light ? "󰖙" : "󰖔"
                    label: Settings.appearance.light ? I18n.tr("Светлая тема") : I18n.tr("Тёмная тема")
                    sub: I18n.tr("Нажмите, чтобы сменить")
                    on: false
                    onClicked: Settings.appearance.light = !Settings.appearance.light
                }
                Toggle {
                    Layout.fillWidth: true
                    icon: "󰏘"
                    label: I18n.tr("Цвета из обоев")
                    sub: Settings.appearance.palette === "wallpaper" ? I18n.tr("Включено") : I18n.tr("Выключено")
                    on: Settings.appearance.palette === "wallpaper"
                    onClicked: Settings.appearance.palette = Settings.appearance.palette === "wallpaper" ? "catppuccin" : "wallpaper"
                }
            }

            // быстрые действия
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [
                        { icon: "󰩭", run: () => { Panels.control = false; shotDelay.restart(); } },
                        { icon: Recorder.recording ? "󰙧" : "󰑋", hot: Recorder.recording, run: () => { Panels.control = false; Recorder.toggle(); } },
                        { icon: "󰈊", run: () => { Panels.control = false; pickDelay.restart(); } },
                        { icon: "󰔟", hot: Focus.active, run: () => Focus.toggle() },
                        { icon: "󰎞", run: () => Panels.toggle("notes") },
                        { icon: "music_note", hot: SongId.busy, run: () => { Panels.control = false; SongId.recognize(); } },
                        { icon: "󰸉", run: () => Panels.toggle("wallpaper") }
                    ]
                    IconButton {
                        required property var modelData
                        Layout.fillWidth: true
                        size: 44
                        icon: modelData.icon
                        active: !!modelData.hot
                        activeColor: Theme.red
                        onClicked: modelData.run()
                    }
                }
            }
            Timer { id: shotDelay; interval: 450; onTriggered: Screenshot.area() }
            Timer { id: pickDelay; interval: 450; onTriggered: Picker.pick() }

            // звук
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sliders.implicitHeight + 24
                radius: Theme.radius
                color: Theme.mantle

                ColumnLayout {
                    id: sliders
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        visible: Power.hasBrightness
                        spacing: 10
                        MIcon { Layout.preferredWidth: 22; icon: Power.brightness > 0.5 ? "brightness_high" : "brightness_medium"; color: Theme.yellow; size: 18 }
                        Slider { Layout.fillWidth: true; value: Power.brightness; color: Theme.yellow; onMoved: v => Power.setBrightness(v) }
                        StyledText { Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; text: Math.round(Power.brightness * 100) }
                        Item { implicitWidth: 28 }
                    }
                    RowLayout {
                        spacing: 10
                        MIcon {
                            Layout.preferredWidth: 22
                            icon: Audio.icon(Audio.volume, Audio.muted)
                            color: Audio.muted ? Theme.overlay1 : Theme.accent
                            size: 18
                            MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
                        }
                        Slider { Layout.fillWidth: true; value: Audio.volume; dim: Audio.muted; onMoved: v => Audio.setVolume(v) }
                        StyledText { Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; text: Math.round(Audio.volume * 100) }
                        IconButton { size: 28; iconSize: 13; icon: "󰅂"; onClicked: Panels.controlPage = "audio" }
                    }
                    RowLayout {
                        spacing: 10
                        MIcon {
                            Layout.preferredWidth: 22
                            icon: Audio.micMuted ? "mic_off" : "mic"
                            color: Audio.micMuted ? Theme.overlay1 : Theme.accent2
                            size: 18
                            MouseArea { anchors.fill: parent; onClicked: Audio.toggleMic() }
                        }
                        Slider { Layout.fillWidth: true; value: Audio.micVolume; dim: Audio.micMuted; color: Theme.accent2; onMoved: v => Audio.setMic(v) }
                        StyledText { Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; text: Math.round(Audio.micVolume * 100) }
                        Item { implicitWidth: 28 }
                    }
                }
            }

            // уведомления
            RowLayout {
                Layout.fillWidth: true
                StyledText { text: I18n.tr("Уведомления"); font.bold: true }
                StyledText { text: Notifs.count > 0 ? String(Notifs.count) : ""; color: Theme.accent }
                Item { Layout.fillWidth: true }
                StyledText {
                    visible: Notifs.count > 0
                    text: I18n.tr("Очистить")
                    color: clear.containsMouse ? Theme.red : Theme.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                    MouseArea { id: clear; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Notifs.clearAll() }
                }
            }

            // по приложениям. Flickable с колонкой, а не ListView: у ListView при росте первой группы
            // съезжает начало списка. ScriptModel сохраняет делегаты (раскрытие, начатый ответ).
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: groupsCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: groupsCol
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: ScriptModel { values: Notifs.groups.map(g => g.app) }
                        NotifGroup { Layout.fillWidth: true }
                    }
                }

                ColumnLayout {
                    x: (groupsCol.width - width) / 2
                    y: 70
                    visible: Notifs.count === 0
                    spacing: 6
                    MIcon { Layout.alignment: Qt.AlignHCenter; icon: "󰂚"; color: Theme.surface2; size: 40 }
                    StyledText { Layout.alignment: Qt.AlignHCenter; text: I18n.tr("Всё прочитано"); color: Theme.overlay0 }
                }
            }
        }

        // ---------- подстраницы ----------
        Loader {
            width: parent.width
            height: parent.height
            x: Panels.controlPage !== "" ? 0 : parent.width + 20
            opacity: Panels.controlPage !== "" ? 1 : 0
            Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            active: Panels.controlPage !== "" && root.open
            source: ({ bluetooth: "BluetoothPage.qml", wifi: "WifiPage.qml", audio: "AudioPage.qml", vpn: "VpnPage.qml" })[Panels.controlPage] ?? ""
        }
    }
}
