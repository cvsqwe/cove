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

    // Картинку под окнами awww показывает размытой (Settings.wallpaper.blurWindows), видео рисует
    // wallpaper/LiveWallpaper.qml поверх постера. Постер и размытая копия готовятся один раз в кэш.
    function blurredOf(still: string): string { return `${Store.cacheDir}/blur-${Store.hash(still)}.jpg`; }
    readonly property bool busy: {
        const ws = Hyprland.focusedWorkspace;
        return !!ws && (ws.toplevels?.values?.length ?? 0) > 0;
    }
    readonly property bool blurNow: w.blurWindows && busy
    onBlurNowChanged: blurDebounce.restart()
    Timer { id: blurDebounce; interval: 120; onTriggered: root.show(["--transition-type", "fade", "--transition-duration", "0.5", "--transition-fps", "60"]) }

    // показать текущие обои в awww (обычные или размытые)
    function show(trans: var): void {
        const still = Store.still;
        if (!still) return;
        Quickshell.execDetached(["sh", "-c",
            'f="$1" blur="$2" b="$3"; shift 3
            if [ "$blur" = 1 ]; then [ -s "$b" ] || magick "$f" -resize 1920x1080^ -blur 0x28 -quality 88 "$b"; f="$b"; fi
            exec awww img "$@" "$f"',
            "_", still, root.blurNow ? "1" : "0", blurredOf(still), ...trans]);
    }

    // awww ставит картинку только на подключённые сейчас мониторы — новому показываем заново
    Connections {
        target: Quickshell
        function onScreensChanged(): void { screensDebounce.restart(); }
    }
    Timer { id: screensDebounce; interval: 800; onTriggered: root.show(["--transition-type", "none"]) }

    function apply(path: string): void {
        if (!path) return;
        if (!Store.isVideo(path)) {
            Store.wallpaper = path;
            show(transition());
            return;
        }
        // видео: сначала кадр-постер (по нему палитра и всё, что показывает обои картинкой)
        poster.target = path;
        poster.running = true;
    }
    Process {
        id: poster
        property string target: ""
        command: ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] || ffmpeg -loglevel error -y -ss 1 -i "$1" -frames:v 1 -q:v 3 "$2" || ffmpeg -loglevel error -y -i "$1" -frames:v 1 -q:v 3 "$2"',
            "_", target, Store.posterOf(target)]
        onExited: code => {
            if (code !== 0) { console.warn("wallpaper: не удалось взять кадр из", target); return; }
            Store.wallpaper = target;
            root.show(root.transition());
        }
    }

    function set(path: string): void { apply(path); }

    function restore(): void {
        Quickshell.execDetached(["sh", "-c", 'for i in $(seq 40); do awww query >/dev/null 2>&1 && break; sleep 0.25; done']);
        restoreDelay.start();
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

    // ждём, пока поднимется awww-daemon (при входе он стартует вместе с шеллом)
    Timer {
        id: restoreDelay
        interval: 600
        onTriggered: {
            if (Store.isVideo(Store.wallpaper)) root.apply(Store.wallpaper);
            else root.show(["--transition-type", "fade", "--transition-duration", "0.6"]);
            root.evaluate();
        }
    }

    // Обои для экранов вне шелла: lock.jpg в кэше — фон запасного hyprlock, копия в гритер —
    // фон экрана входа (файл в /etc/greetd/qs-greeter принадлежит пользователю, см. greeter/install.sh).
    // Пересобираем, только если обои правда сменились (в режиме workspace они меняются часто).
    readonly property string lockWall: Store.cacheDir + "/lock.jpg"
    readonly property string greeterWall: "/etc/greetd/qs-greeter/wallpaper"
    readonly property string syncKey: Store.ready ? Store.still : ""
    onSyncKeyChanged: if (syncKey) syncDelay.restart()
    Timer { id: syncDelay; interval: 3000; onTriggered: syncOutside.running = true }
    Process {
        id: syncOutside
        command: ["sh", "-c",
            'f="$1" out="$2" greeter="$3" stamp="$2.src"
            [ -s "$f" ] || exit 0
            mkdir -p "$(dirname "$out")"
            if [ "$(cat "$stamp" 2>/dev/null)" != "$f" ] || [ ! -s "$out" ]; then
                magick "$f[0]" -resize 1920x1080^ -quality 90 "$out.tmp" && mv -f "$out.tmp" "$out" || cp -f "$f" "$out"
                printf %s "$f" > "$stamp"
            fi
            if [ -w "$greeter" ] && ! cmp -s "$out" "$greeter"; then cat "$out" > "$greeter"; fi',
            "_", Store.still, root.lockWall, root.greeterWall]
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
        command: ["fd", "-t", "f", "-e", "jpg", "-e", "jpeg", "-e", "png", "-e", "webp", "-e", "gif", "-e", "mp4", "-e", "webm", "-e", "mkv", "-e", "mov", ".", Settings.expand(Settings.wallpaper.dir)]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(s => s !== "").sort();
                const vids = root.files.filter(f => Store.isVideo(f));
                if (vids.length) { posters.files = vids; posters.running = true; }
            }
        }
    }

    // миниатюры видео для выбора обоев: кадр-постер, тот же, что и для палитры
    property int posterSerial: 0
    function thumbOf(p: string): string { return Store.isVideo(p) ? Store.posterOf(p) + "?" + posterSerial : p; }
    Process {
        id: posters
        property var files: []
        command: ["sh", "-c", 'mkdir -p "$1"; shift
            while [ $# -gt 0 ]; do [ -s "$2" ] || ffmpeg -loglevel error -y -ss 1 -i "$1" -frames:v 1 -q:v 3 "$2" </dev/null; shift 2; done',
            "_", Store.cacheDir, ...Array.from(files).reduce((a, f) => a.concat([f, Store.posterOf(f)]), [])]
        onExited: root.posterSerial++
    }

    Component.onCompleted: refresh()
}
