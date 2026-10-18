import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var lock

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // фон: размытые обои
    Image {
        id: wall
        anchors.fill: parent
        source: "file://" + Store.still
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(1280, 720)
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        brightness: -0.28
        saturation: 0.1
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        scale: 1.04
        Component.onCompleted: { opacity = 1; scale = 1; }
        states: State {
            when: root.lock.unlocking
            PropertyChanges { content.opacity: 0; content.scale: 0.96 }
        }
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -60
            spacing: 4

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 120
                font.bold: true
                color: Theme.text
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const s = I18n.locale.toString(clock.date, "dddd, d MMMM");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                font.pixelSize: 20
                color: Theme.subtext1
            }

            // уведомления: только сколько и от каких приложений — текст на экране блокировки не показываем
            Rectangle {
                readonly property var apps: {
                    const seen = [], out = [];
                    for (const n of Notifs.list) {
                        const k = n.appName || n.appIcon;
                        if (seen.includes(k)) continue;
                        seen.push(k);
                        out.push(Notifs.iconFor(n));
                    }
                    return out.slice(0, 5);
                }
                visible: Notifs.count > 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                implicitWidth: notifRow.implicitWidth + 24
                implicitHeight: 34
                radius: 17
                color: Theme.alpha(Theme.base, 0.6)
                Row {
                    id: notifRow
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: parent.parent.apps
                        Image {
                            required property string modelData
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            source: modelData
                            sourceSize: Qt.size(36, 36)
                            visible: status === Image.Ready
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 4
                        text: Notifs.count + " " + I18n.plural(Notifs.count, "уведомление", "уведомления", "уведомлений")
                        color: Theme.subtext1
                        font.pixelSize: Theme.fontSizeSmall + 1
                    }
                }
            }

            Item { implicitHeight: 24 }

            // аватар (Настройки → Система)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 12
                implicitWidth: 72
                implicitHeight: 72
                radius: 36
                color: Theme.accent
                clip: true
                border.width: 3
                border.color: Theme.alpha(Theme.text, 0.6)
                MIcon { anchors.centerIn: parent; visible: !ava.visible; icon: "cove"; color: Theme.onAccent; size: 40 }
                Image {
                    id: ava
                    anchors.fill: parent
                    visible: status === Image.Ready
                    source: Settings.general.avatar ? "file://" + Settings.expand(Settings.general.avatar) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(144, 144)
                }
            }

            // поле пароля
            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 340
                implicitHeight: 54
                radius: height / 2
                color: Theme.alpha(Theme.base, 0.8)
                border.width: 2
                border.color: root.lock.failed ? Theme.red : root.lock.busy ? Theme.yellow : input.activeFocus ? Theme.accent : Theme.surface1
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                // встряхивание при ошибке
                transform: Translate { id: shake }
                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: shake; property: "x"; to: -14; duration: 50 }
                    NumberAnimation { target: shake; property: "x"; to: 12; duration: 60 }
                    NumberAnimation { target: shake; property: "x"; to: -8; duration: 60 }
                    NumberAnimation { target: shake; property: "x"; to: 0; duration: 60 }
                }
                Connections {
                    target: root.lock
                    function onFailedChanged(): void { if (root.lock.failed) shakeAnim.restart(); }
                }

                TextInput {
                    id: input
                    anchors.fill: parent
                    focus: true
                    opacity: 0
                    echoMode: TextInput.Password
                    text: root.lock.password
                    onTextChanged: {
                        root.lock.password = text;
                        if (text !== "") root.lock.failed = false;
                    }
                    Keys.onReturnPressed: root.lock.tryUnlock()
                    Keys.onEnterPressed: root.lock.tryUnlock()
                    Keys.onEscapePressed: root.lock.password = ""
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.lock.password.length > 0

                    Repeater {
                        model: Math.min(root.lock.password.length, 24)
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: Theme.accent
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.lock.password.length === 0
                    text: root.lock.busy ? I18n.tr("Проверка…") : root.lock.failed ? I18n.tr("Неверный пароль") : I18n.tr("Введите пароль")
                    color: root.lock.failed ? Theme.red : Theme.overlay1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: input.forceActiveFocus()
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                spacing: 6
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "keyboard"; color: Theme.overlay1; size: Theme.fontSizeSmall }
                StyledText { anchors.verticalCenter: parent.verticalCenter; text: Hypr.layout; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
            }
        }

        // плеер внизу
        Rectangle {
            visible: Media.active
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 60
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: mediaRow.implicitWidth + 28
            implicitHeight: 64
            radius: 32
            color: Theme.alpha(Theme.base, 0.75)

            RowLayout {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: 21
                    color: Theme.surface0
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: Media.art
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(84, 84)
                    }
                }
                ColumnLayout {
                    spacing: 0
                    StyledText { Layout.maximumWidth: 260; text: Media.title; font.bold: true; elide: Text.ElideRight }
                    StyledText { Layout.maximumWidth: 260; text: Media.artist; color: Media.accent; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                }
                IconButton { icon: "󰒮"; onClicked: Media.player?.previous() }
                IconButton { icon: Media.playing ? "󰏤" : "󰐊"; active: true; activeColor: Media.accent; onClicked: Media.player?.togglePlaying() }
                IconButton { icon: "󰒭"; onClicked: Media.player?.next() }
            }
        }

        // питание
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 30
            spacing: 10
            IconButton { icon: "󰤄"; onClicked: if (!(root.lock.preview ?? false)) Quickshell.execDetached(["systemctl", "suspend"]) }
            IconButton { icon: "󰜉"; iconColor: Theme.peach; onClicked: if (!(root.lock.preview ?? false)) Quickshell.execDetached(["systemctl", "reboot"]) }
            IconButton { icon: "󰐥"; iconColor: Theme.red; onClicked: if (!(root.lock.preview ?? false)) Quickshell.execDetached(["systemctl", "poweroff"]) }
        }
    }
}
