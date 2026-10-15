import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Громкость: клик — mute, колесо — ±5%, ПКМ — EasyEffects.
Pill {
    icon: Audio.icon(Audio.volume, Audio.muted)
    iconColor: Audio.muted ? Theme.overlay0 : Theme.barTint(Theme.accent)
    label: Math.round(Audio.volume * 100) + "%"
    textColor: Audio.muted ? Theme.overlay0 : Theme.text

    onClicked: m => {
        if (m.button === Qt.RightButton) Quickshell.execDetached(["easyeffects"]);
        else Audio.toggleMute();
    }
    onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
}
