import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

SubPage {
    id: page
    title: I18n.tr("Звук")
    icon: "󰕾"

    // свои узлы эффектов (cove_fx_*, cove_mic*) — не устройства и не приложения
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio && !/^cove_(fx|mic)/.test(n.name ?? ""))
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream && !(n.name ?? "").endsWith(".monitor"))
    readonly property var streams: nodes.filter(n => n.isStream && !n.isSink)

    PwObjectTracker { objects: page.streams }

    function label(n): string { return n.description || n.nickname || n.name; }
    function sinkIcon(n): string {
        const s = (n.name + " " + n.description).toLowerCase();
        if (s.includes("hdmi") || s.includes("displayport")) return "󰡁";
        if (s.includes("bluez") || s.includes("headset") || s.includes("headphone")) return "󰋋";
        if (s.includes("usb")) return "󰕓";
        return "󰓃";
    }

    StyledText { text: I18n.tr("Вывод"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
    Repeater {
        model: page.sinks
        DeviceRow {
            required property var modelData
            icon: page.sinkIcon(modelData)
            title: page.label(modelData)
            active: Pipewire.defaultAudioSink === modelData
            sub: active ? I18n.tr("По умолчанию · ") + Math.round(Audio.volume * 100) + "%" : ""
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    Slider {
        Layout.fillWidth: true
        value: Audio.volume
        dim: Audio.muted
        onMoved: v => Audio.setVolume(v)
    }

    StyledText { Layout.topMargin: 6; text: I18n.tr("Ввод"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
    Repeater {
        model: page.sources
        DeviceRow {
            required property var modelData
            icon: "󰍬"
            title: page.label(modelData)
            active: Pipewire.defaultAudioSource === modelData
            sub: active ? I18n.tr("По умолчанию · ") + Math.round(Audio.micVolume * 100) + "%" : ""
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
    Slider {
        Layout.fillWidth: true
        value: Audio.micVolume
        dim: Audio.micMuted
        color: Theme.accent2
        onMoved: v => Audio.setMic(v)
    }

    StyledText { Layout.topMargin: 6; text: I18n.tr("Приложения"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
    StyledText { visible: page.streams.length === 0; text: I18n.tr("Сейчас ничего не играет."); color: Theme.overlay0; font.pixelSize: Theme.fontSizeSmall }
    Repeater {
        model: page.streams
        Rectangle {
            id: st
            required property var modelData
            readonly property string app: modelData.properties["application.name"] ?? modelData.name
            readonly property string iconName: modelData.properties["application.icon-name"] ?? modelData.properties["application.process.binary"] ?? ""
            Layout.fillWidth: true
            implicitHeight: 64
            radius: Theme.radius
            color: Theme.mantle

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                IconImage {
                    implicitSize: 28
                    source: Quickshell.iconPath(st.iconName, "audio-x-generic")
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    RowLayout {
                        StyledText { Layout.fillWidth: true; text: st.app; elide: Text.ElideRight; font.pixelSize: Theme.fontSizeSmall + 1 }
                        StyledText { text: Math.round((st.modelData.audio?.volume ?? 0) * 100) + "%"; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
                    }
                    Slider {
                        Layout.fillWidth: true
                        thickness: 6
                        value: st.modelData.audio?.volume ?? 0
                        dim: st.modelData.audio?.muted ?? false
                        onMoved: v => { if (st.modelData.audio) st.modelData.audio.volume = v; }
                    }
                }
                IconButton {
                    size: 30; iconSize: 14
                    icon: st.modelData.audio?.muted ? "󰝟" : "󰕾"
                    onClicked: if (st.modelData.audio) st.modelData.audio.muted = !st.modelData.audio.muted
                }
            }
        }
    }

    // эффекты Cove (services/SoundFx): наборы эквалайзера, график, микрофон
    StyledText { Layout.topMargin: 6; text: I18n.tr("Эффекты"); color: Theme.subtext1; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: fx.implicitHeight + 24
        radius: Theme.radius
        color: Theme.mantle

        ColumnLayout {
            id: fx
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MIcon { icon: "graphic_eq"; color: Settings.sound.enabled ? Theme.accent : Theme.overlay1; size: 20 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText { text: I18n.tr("Эквалайзер"); font.bold: true }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSizeSmall
                        text: !Settings.sound.enabled ? I18n.tr("Выключен")
                            : SoundFx.presetLabel(Settings.sound.preset) + (SoundFx.modified ? I18n.tr(" (изменён)") : "")
                    }
                }
                SSwitch { checked: Settings.sound.enabled; onToggled: v => Settings.sound.enabled = v }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                radius: Theme.radiusSmall
                color: Theme.crust
                opacity: Settings.sound.enabled ? 1 : 0.6
                EqCurve { anchors.fill: parent; anchors.margins: 4; labels: false }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [...SoundFx.builtin.map(p => ({ id: p.id, label: p.label })), ...SoundFx.customNames.map(n => ({ id: n, label: n }))]
                    Chip {
                        required property var modelData
                        implicitHeight: 28
                        text: modelData.label
                        active: Settings.sound.preset === modelData.id
                        dim: active && SoundFx.modified
                        onClicked: { SoundFx.load(modelData.id); Settings.sound.enabled = true; }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                MIcon { icon: "noise_control_off"; color: Settings.sound.mic ? Theme.accent2 : Theme.overlay1; size: 18 }
                StyledText { Layout.fillWidth: true; text: I18n.tr("Шумоподавление микрофона"); font.pixelSize: Theme.fontSizeSmall + 1 }
                SSwitch {
                    checked: Settings.sound.mic && Settings.sound.micNoise
                    onToggled: v => { Settings.sound.mic = v; if (v) Settings.sound.micNoise = true; }
                }
            }
        }
    }

    SButton {
        icon: "tune"
        text: I18n.tr("Все настройки звука")
        onClicked: Panels.openSettings("sound")
    }
}
