pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    function clamp(v: real): real { return Math.max(0, Math.min(1, v)); }

    function setVolume(v: real): void {
        if (!sink?.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = clamp(v);
    }
    function step(d: real): void { setVolume(volume + d); }
    function toggleMute(): void { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }

    function setMic(v: real): void {
        if (!source?.audio) return;
        source.audio.muted = false;
        source.audio.volume = clamp(v);
    }
    function toggleMic(): void { if (source?.audio) source.audio.muted = !source.audio.muted; }

    function icon(v: real, m: bool): string {
        return m ? "󰝟" : v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : "󰕿";
    }
}
