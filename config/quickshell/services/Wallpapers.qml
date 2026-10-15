pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Обои: список из папки, установка через awww и режимы смены —
// fixed (один), time (день/ночь), workspace (свои на каждом воркспейсе), slideshow.
Singleton {
    id: root

    property var files: []
    readonly property var w: Settings.wallpaper

    function refresh(): void { scan.running = true; }

    function transition(): var {
        const t = w.transition === "random"
            ? ["grow", "outer", "wipe", "wave", "fade", "center"][Math.floor(Math.random() * 6)]
            : w.transition;
        return ["--transition-type", t, "--transition-pos", "0.5,0.5", "--transition-duration", "1.2", "--transition-fps", "60"];
    }

    function apply(path: string): void {
        if (!path) return;
        Store.wallpaper = path;
        Quickshell.execDetached(["awww", "img", ...transition(), path]);
    }

    function set(path: string): void { apply(path); }

    function restore(): void {
        Quickshell.execDetached(["sh", "-c",
            'for i in $(seq 40); do awww query >/dev/null 2>&1 && break; sleep 0.25; done; awww img --transition-type fade --transition-duration 0.6 "$1"',
            "_", Store.wallpaper]);
        Qt.callLater(evaluate);
    }

    function minutes(s: string): int {
        const [h, m] = String(s ?? "0:0").split(":").map(Number);
        return (h || 0) * 60 + (m || 0);
    }

    // что должно стоять сейчас по текущему режиму
    function evaluate(): void {
        if (w.mode === "time") {
            const now = new Date(), cur = now.getHours() * 60 + now.getMinutes();
            const d = minutes(w.dayStart), n = minutes(w.nightStart);
            const isDay = d < n ? cur >= d && cur < n : cur >= d || cur < n;
            const target = isDay ? w.day : w.night;
            if (target && target !== Store.wallpaper) apply(target);
        } else if (w.mode === "workspace") {
            const id = String(Hyprland.focusedWorkspace?.id ?? 1);
            const target = (w.perWorkspace ?? {})[id];
            if (target && target !== Store.wallpaper) apply(target);
        }
    }

    function next(): void {
        if (files.length < 2) return;
        let p;
        do { p = files[Math.floor(Math.random() * files.length)]; } while (p === Store.wallpaper);
        apply(p);
    }

    Timer {
        interval: 60 * 1000
        running: root.w.mode === "time"
        repeat: true
        onTriggered: root.evaluate()
    }
    Timer {
        interval: Math.max(1, root.w.slideshowMinutes) * 60 * 1000
        running: root.w.mode === "slideshow"
        repeat: true
        onTriggered: root.next()
    }
    Connections {
        target: Hyprland
        enabled: root.w.mode === "workspace"
        function onFocusedWorkspaceChanged(): void { root.evaluate(); }
    }
    Connections {
        target: root.w
        function onModeChanged(): void { root.evaluate(); }
    }

    Process {
        id: scan
        command: ["fd", "-t", "f", "-e", "jpg", "-e", "jpeg", "-e", "png", "-e", "webp", ".", Settings.expand(Settings.wallpaper.dir)]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(s => s !== "").sort()
        }
    }

    Component.onCompleted: refresh()
}
