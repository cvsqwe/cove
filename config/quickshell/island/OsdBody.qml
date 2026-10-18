import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

RowLayout {
    id: root
    property bool shown: false
    property string kind: "volume"   // volume | mic
    readonly property bool mic: kind === "mic"

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 12

    MIcon {
        icon: root.mic ? (Audio.micMuted ? "mic_off" : "mic") : Audio.icon(Audio.volume, Audio.muted)
        color: (root.mic ? Audio.micMuted : Audio.muted) ? Theme.overlay1 : root.mic ? Theme.accent2 : Theme.accent
        size: 18
        MouseArea { anchors.fill: parent; onClicked: root.mic ? Audio.toggleMic() : Audio.toggleMute() }
    }
    Slider {
        Layout.fillWidth: true
        value: root.mic ? Audio.micVolume : Audio.volume
        dim: root.mic ? Audio.micMuted : Audio.muted
        color: root.mic ? Theme.accent2 : Theme.accent
        onMoved: v => root.mic ? Audio.setMic(v) : Audio.setVolume(v)
    }
    StyledText {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: (root.mic ? Audio.micMuted : Audio.muted) ? "—" : Math.round((root.mic ? Audio.micVolume : Audio.volume) * 100)
    }
}
