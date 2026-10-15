pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config

// Текущий плеер, спектр (cava) и акцентный цвет обложки.
Singleton {
    id: root

    readonly property var player: {
        const all = Mpris.players.values;
        return all.find(p => p.isPlaying) ?? all.find(p => (p.trackTitle ?? "") !== "") ?? null;
    }
    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string title: player?.trackTitle ?? ""
    // браузерные плееры (SoundCloud в Firefox) шлют в «исполнителе» служебный мусор вида 0:0:61525619
    readonly property string artist: cleanArtist(player?.trackArtist ?? "")
    function cleanArtist(a): string { const s = String(a ?? "").trim(); return /^[\d:.\s\-]*$/.test(s) ? "" : s; }
    readonly property string art: player?.trackArtUrl ?? ""

    readonly property int barCount: 48
    property var bars: new Array(barCount).fill(0)

    // позиция трека не обновляется сама — пинаем раз в секунду
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    Process {
        running: root.playing && Settings.island.visualizer
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(s => Math.min(1, parseInt(s) / 1000));
                if (v.length === root.barCount) root.bars = v;
            }
        }
        onRunningChanged: if (!running) root.bars = new Array(root.barCount).fill(0)
    }

    ColorQuantizer {
        id: artQuant
        source: root.art
        depth: 2
        rescaleSize: 32
    }

    readonly property color accent: {
        const cs = [...artQuant.colors].filter(c => c.hslHue >= 0)
            .sort((a, b) => b.hslSaturation - a.hslSaturation);
        if (!active || cs.length === 0) return Theme.accent;
        return Qt.hsla(cs[0].hslHue, Math.max(0.5, Math.min(0.85, cs[0].hslSaturation)), 0.75, 1);
    }

    function fmt(sec: real): string {
        if (!isFinite(sec) || sec < 0) return "0:00";
        const s = Math.floor(sec);
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }
}
