import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

RowLayout {
    property bool shown: false

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 12

    MIcon {
        icon: Audio.icon(Audio.volume, Audio.muted)
        color: Audio.muted ? Theme.overlay1 : Theme.accent
        size: 18
        MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
    }
    Slider {
        Layout.fillWidth: true
        value: Audio.volume
        dim: Audio.muted
        onMoved: v => Audio.setVolume(v)
    }
    StyledText {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(Audio.volume * 100)
    }
}
