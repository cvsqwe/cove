pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Кто сейчас пишет микрофон, снимает камеру или транслирует экран — для точек-индикаторов в острове.
// Микрофон и экран — потоки PipeWire; камера — процессы, открывшие /dev/video*.
Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes.values

    // захват звука, кроме «слушателей выхода» (визуализатор cava, запись системного звука)
    readonly property var micStreams: nodes.filter(n => n.type === PwNodeType.AudioInStream
        && n.properties["stream.capture.sink"] !== "true"
        && !/^cove_(fx|mic)/.test(n.name ?? "")   // обработка микрофона Cove — не «кто-то слушает»
        && !/^(cava|quickshell|qs)$/i.test(n.properties["application.name"] ?? ""))
    // демонстрация экрана через xdg-desktop-portal-hyprland
    readonly property var screenStreams: nodes.filter(n => n.type === PwNodeType.VideoSource && /^xdph/i.test(n.name ?? ""))

    PwObjectTracker { objects: root.nodes.filter(n => n.type === PwNodeType.AudioInStream) }

    function appName(n): string {
        const p = n.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || n.description || n.name || "";
    }

    readonly property var micApps: [...new Set(micStreams.map(n => appName(n)).filter(s => s))]
    readonly property bool mic: micStreams.length > 0
    readonly property bool screen: screenStreams.length > 0
    property var cameraApps: []
    readonly property bool camera: cameraApps.length > 0
    readonly property bool any: mic || camera || screen

    // процессы с открытой камерой; pipewire/wireplumber держат её за приложения, которые идут через портал
    Process {
        id: cam
        command: ["sh", "-c", 'ls /dev/video* >/dev/null 2>&1 || exit 0
            for p in $(fuser /dev/video* 2>/dev/null); do cat /proc/$p/comm 2>/dev/null; done | sort -u']
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").map(s => s.trim()).filter(s => s);
                const apps = names.map(s => /^(pipewire|wireplumber)$/.test(s) ? "PipeWire" : s);
                if (JSON.stringify(apps) !== JSON.stringify(root.cameraApps)) root.cameraApps = apps;
            }
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cam.running = true
    }
}
