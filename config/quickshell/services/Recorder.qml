pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Запись экрана через gpu-screen-recorder: весь монитор или выделенная область, со звуком системы.
// Кодирует процессором (x264): аппаратный VCE на RX 580 зависает под gsr (ring vce0 timeout)
// и роняет GPU со сбросом VRAM — артефакты и падение сессии.
// Файлы — ~/Videos/Recordings. Остров показывает красную точку и таймер.
Singleton {
    id: root

    readonly property bool recording: proc.running
    property int seconds: 0
    property string file: ""
    readonly property string dir: Settings.home + "/Videos/Recordings"
    readonly property string timeText: `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`

    function start(region: bool): void {
        if (recording) return;
        file = `${dir}/${Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss")}.mp4`;
        const mon = Hyprland.focusedMonitor?.name ?? "screen";
        const base = `mkdir -p "${dir}"; `;
        proc.command = region
            ? ["sh", "-c", base + `g=$(slurp -f "%wx%h+%x+%y") || exit 1; exec gpu-screen-recorder -w region -region "$g" -f 60 -encoder cpu -k h264 -a default_output -o "$1"`, "_", file]
            : ["sh", "-c", base + `exec gpu-screen-recorder -w "$2" -f 60 -encoder cpu -k h264 -a default_output -o "$1"`, "_", file, mon];
        seconds = 0;
        proc.running = true;
    }

    function stop(): void {
        if (recording) proc.signal(2); // SIGINT — gsr корректно дописывает файл
    }

    function toggle(): void { recording ? stop() : start(false); }

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.seconds++
    }

    Process {
        id: proc
        onExited: code => {
            if (root.seconds > 0)
                Quickshell.execDetached(["notify-send", "-a", I18n.tr("Запись экрана"), I18n.tr("Видео сохранено"), root.file.replace(Settings.home, "~")]);
        }
    }

    IpcHandler {
        target: "record"
        function toggle(): void { root.toggle(); }
        function region(): void { root.recording ? root.stop() : root.start(true); }
    }
}
