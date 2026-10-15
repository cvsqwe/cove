import QtQuick
import qs.config
import qs.components
import qs.services

Pill {
    icon: Audio.micMuted ? "󰍭" : "󰍬"
    iconColor: Audio.micMuted ? Theme.red : Theme.barTint(Theme.accent2)
    onClicked: Audio.toggleMic()
    onWheel: w => Audio.setMic(Audio.micVolume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
}
