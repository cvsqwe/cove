import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

RowLayout {
    id: root
    property bool shown: false
    property string kind: "volume"   // volume | mic | brightness
    readonly property bool mic: kind === "mic"
    readonly property bool bright: kind === "brightness"

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 12

    MIcon {
        icon: root.bright ? (Power.brightness > 0.5 ? "brightness_high" : "brightness_medium")
            : root.mic ? (Audio.micMuted ? "mic_off" : "mic") : Audio.icon(Audio.volume, Audio.muted)
        color: root.bright ? Theme.yellow : (root.mic ? Audio.micMuted : Audio.muted) ? Theme.overlay1 : root.mic ? Theme.accent2 : Theme.accent
        size: 18
        MouseArea { anchors.fill: parent; onClicked: root.bright ? null : root.mic ? Audio.toggleMic() : Audio.toggleMute() }
    }
    Slider {
        Layout.fillWidth: true
        value: root.bright ? Power.brightness : root.mic ? Audio.micVolume : Audio.volume
        dim: !root.bright && (root.mic ? Audio.micMuted : Audio.muted)
        color: root.bright ? Theme.yellow : root.mic ? Theme.accent2 : Theme.accent
        onMoved: v => root.bright ? Power.setBrightness(v) : root.mic ? Audio.setMic(v) : Audio.setVolume(v)
    }
    StyledText {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: root.bright ? Math.round(Power.brightness * 100)
            : (root.mic ? Audio.micMuted : Audio.muted) ? "—" : Math.round((root.mic ? Audio.micVolume : Audio.volume) * 100)
    }
}
