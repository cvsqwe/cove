pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Текст текущей песни (assets/lyrics.py → LRCLIB) и строка, которая звучит сейчас.
// Плеер сообщает позицию раз в секунду — между отсчётами досчитываем по часам, чтобы строки
// менялись вовремя.
Singleton {
    id: root

    readonly property bool enabled: Settings.island.lyrics
    property var lines: []           // [[секунда, строка], …]
    property string plain: ""
    property bool loading: false
    readonly property bool has: lines.length > 0

    readonly property var player: Media.player
    readonly property string key: enabled && Media.active ? `${Media.artist}\n${Media.title}` : ""
    onKeyChanged: {
        lines = [];
        plain = "";
        if (key) fetchLater.restart();
    }
    // пока плеер «перелистывает» метаданные, приходят промежуточные значения — ждём, пока устоится
    Timer { id: fetchLater; interval: 700; onTriggered: root.fetch() }

    function fetch(): void {
        if (!key) return;
        loading = true;
        const len = Number(player?.length ?? 0);
        proc.command = ["python3", Quickshell.shellPath("assets/lyrics.py"), Media.artist, Media.title, len > 0 ? String(len) : ""];
        proc.wanted = key;
        proc.running = true;
    }
    Process {
        id: proc
        property string wanted: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (proc.wanted !== root.key) return;   // трек уже сменился
                try {
                    const d = JSON.parse(text);
                    root.lines = d.synced ?? [];
                    root.plain = d.plain ?? "";
                } catch (e) { root.lines = []; root.plain = ""; }
            }
        }
    }

    // ---- позиция ----
    property real basePos: 0
    property real baseAt: 0
    property real pos: 0
    Connections {
        target: root.player
        function onPositionChanged(): void { root.basePos = root.player.position; root.baseAt = Date.now(); root.tick(); }
    }
    function tick(): void {
        if (!player) return;
        pos = basePos + (Media.playing ? (Date.now() - baseAt) / 1000 : 0);
    }
    Timer {
        running: root.has && Media.playing
        interval: 150
        repeat: true
        onTriggered: root.tick()
    }

    // строку показываем чуть раньше отметки: глазу нужно мгновение, чтобы прочитать
    readonly property int index: {
        const t = pos + 0.25;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k][0] <= t; k++) i = k;
        return i;
    }
    readonly property string line: index >= 0 ? lines[index][1] : ""
    readonly property string nextLine: index + 1 < lines.length ? lines[index + 1][1] : ""
    // сколько звучит строка (для длинных строк, которые остров показывает частями);
    // перед проигрышем следующая строка далеко — берём время, за которое строку успевают спеть
    readonly property real lineStart: index >= 0 ? lines[index][0] : 0
    readonly property real lineEnd: index < 0 ? 0
        : Math.min(index + 1 < lines.length ? lines[index + 1][0] : lineStart + 8, lineStart + 1.5 + line.length * 0.09)

    IpcHandler {
        target: "lyrics"
        function status(): string {
            return JSON.stringify({ key: root.key, lines: root.lines.length, loading: root.loading, pos: Math.round(root.pos * 10) / 10, index: root.index, line: root.line });
        }
        function refetch(): void { root.fetch(); }
    }
}
