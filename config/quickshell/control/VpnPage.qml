import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// VPN в центре управления: подключение, где мы, скорость, маршрут, выбор сервера.
SubPage {
    id: page
    title: "VPN"
    icon: "vpn_lock"

    Component.onCompleted: { Vpn.probe(); if (Vpn.on) Vpn.refresh(); }

    function delayText(ms): string { return ms > 0 ? ms + I18n.tr(" мс") : I18n.tr("нет ответа"); }
    function delayColor(ms): color { return !(ms > 0) ? Theme.red : ms < 150 ? Theme.green : ms < 400 ? Theme.yellow : Theme.peach; }

    // ---- состояние и кнопка ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight + 28
        radius: Theme.radius
        color: Vpn.on ? Theme.alpha(Theme.accent, 0.14) : Theme.mantle
        border.width: Vpn.on ? 1 : 0
        border.color: Theme.alpha(Theme.accent, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.anim } }

        ColumnLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 44; implicitHeight: 44; radius: 22
                    color: Vpn.on ? Theme.accent : Theme.surface0
                    MIcon {
                        anchors.centerIn: parent
                        icon: Vpn.on ? "vpn_lock" : "vpn_key_off"
                        color: Vpn.on ? Theme.onAccent : Theme.overlay1
                        size: 22
                        RotationAnimation on rotation { running: Vpn.busy; from: 0; to: 360; duration: 1400; loops: Animation.Infinite }
                        onVisibleChanged: if (!Vpn.busy) rotation = 0
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        text: ({ on: I18n.tr("Подключено"), starting: I18n.tr("Подключаюсь…"), stopping: I18n.tr("Отключаюсь…"),
                                 error: I18n.tr("Не подключено"), off: I18n.tr("Отключено") })[Vpn.state] ?? ""
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: Vpn.on && Vpn.where ? `${Vpn.where.flag} ${Vpn.where.country} · ${Vpn.where.ip}`
                            : Vpn.on ? Vpn.current : ""
                        color: Theme.subtext0
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }
                SButton {
                    text: Vpn.on || Vpn.state === "starting" ? I18n.tr("Отключить") : I18n.tr("Подключить")
                    primary: !Vpn.on
                    enabled_: Vpn.ready && !Vpn.busy || Vpn.state === "starting"
                    onClicked: Vpn.toggle()
                }
            }

            // скорость
            RowLayout {
                visible: Vpn.on
                spacing: 16
                Row { spacing: 4; MIcon { icon: "arrow_downward"; size: 14; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                      StyledText { text: Vpn.fmtSpeed(Vpn.down); font.pixelSize: Theme.fontSizeSmall; font.features: { "tnum": 1 } } }
                Row { spacing: 4; MIcon { icon: "arrow_upward"; size: 14; color: Theme.accent2; anchors.verticalCenter: parent.verticalCenter }
                      StyledText { text: Vpn.fmtSpeed(Vpn.up); font.pixelSize: Theme.fontSizeSmall; font.features: { "tnum": 1 } } }
            }

            StyledText {
                Layout.fillWidth: true
                visible: Vpn.error !== "" && !Vpn.on
                text: Vpn.error
                color: Theme.red
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
            StyledText {
                Layout.fillWidth: true
                visible: Vpn.prizrak
                text: I18n.tr("Запущен Prizrak-Box. Если в нём включён VPN — выключите, два VPN мешают друг другу.")
                color: Theme.yellow
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    // не установлен — одна кнопка в настройки
    SButton {
        visible: Vpn.probed && (!Vpn.ready || !Vpn.hasSources)
        Layout.fillWidth: true
        icon: "settings"
        text: !Vpn.ready ? I18n.tr("Установить VPN") : I18n.tr("Добавить подписку")
        primary: true
        onClicked: Panels.openSettings("vpn")
    }

    // ---- маршрут ----
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: Vpn.ready
        StyledText { Layout.fillWidth: true; text: I18n.tr("Через VPN"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
        SSegment {
            options: [{ value: "ru", label: I18n.tr("Кроме РФ") }, { value: "all", label: I18n.tr("Всё") }]
            current: Settings.vpn.route
            onPicked: v => Settings.vpn.route = v
        }
    }

    // подписка не отдала ни одного сервера (просрочена, не тот адрес, панель требует устройство)
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: Vpn.noServers
        spacing: 6
        StyledText {
            Layout.fillWidth: true
            text: I18n.tr("Подписка не отдала ни одного сервера. Проверьте, что она не просрочена и адрес верный. Журнал: journalctl -u ") + Vpn.unit
            color: Theme.yellow
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
        }
        SButton {
            icon: "sync"
            text: Vpn.updating ? I18n.tr("Обновляю…") : I18n.tr("Обновить подписки")
            enabled_: !Vpn.updating
            onClicked: Vpn.updateSources()
        }
    }

    // ---- серверы ----
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: Vpn.on && !Vpn.noServers && Vpn.servers.length > 0
        StyledText { Layout.fillWidth: true; text: I18n.tr("Серверы"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
        SButton {
            icon: "sync"
            text: Vpn.updating ? I18n.tr("Обновляю…") : I18n.tr("Обновить")
            implicitHeight: 28
            enabled_: !Vpn.updating
            onClicked: Vpn.updateSources()
        }
        SButton {
            icon: "speed"
            text: Vpn.testing ? I18n.tr("Проверяю…") : I18n.tr("Проверить")
            implicitHeight: 28
            enabled_: !Vpn.testing
            onClicked: Vpn.test()
        }
    }
    Repeater {
        model: Vpn.on ? Vpn.servers : []
        DeviceRow {
            id: srv
            required property string modelData
            readonly property bool isAuto: modelData === Vpn.auto
            readonly property var ms: Vpn.delays[isAuto ? Vpn.autoNow : modelData]
            icon: isAuto ? "bolt" : "dns"
            title: isAuto ? I18n.tr("Авто — самый быстрый") : modelData
            sub: (isAuto && Vpn.autoNow ? Vpn.autoNow + " · " : "") + (ms !== undefined ? page.delayText(ms) : "")
            active: Vpn.now === modelData
            onClicked: Vpn.select(modelData)
            Rectangle {
                visible: srv.ms !== undefined
                width: 8; height: 8; radius: 4
                color: page.delayColor(srv.ms)
            }
        }
    }

    SButton {
        Layout.topMargin: 6
        icon: "tune"
        text: I18n.tr("Подписки и настройки VPN")
        onClicked: Panels.openSettings("vpn")
    }
}
