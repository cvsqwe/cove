pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Перекраска сторонних приложений (GTK, Qt, Telegram, Vesktop, Obsidian, yazi, mpv, btop).
// Сама работа — в assets/theme/cove-theme.py, цели — assets/theme/targets/<id>/.
// Recolor зовёт apply() при смене палитры; выключенные цели — Settings.apps.off.
Singleton {
    id: root

    readonly property string engine: Quickshell.shellPath("assets/theme/cove-theme.py")
    property var targets: []          // [{id, name, icon, hint, action, installed}]
    property var results: ({})        // id → "ok" | "error: …" после последнего применения
    property bool busy: false
    property var pending: null        // палитра, ждущая применения

    function enabled(id: string): bool { return !(Settings.apps.off ?? []).includes(id); }
    function installed(id: string): bool { return targets.some(t => t.id === id && t.installed); }
    function active(id: string): bool { return installed(id) && enabled(id); }

    function setEnabled(id: string, on: bool): void {
        const off = (Settings.apps.off ?? []).filter(x => x !== id);
        if (!on) off.push(id);
        Settings.apps.off = off;
        if (on) apply();
        else Quickshell.execDetached(["python3", engine, "disable", id]);
    }

    function look(): var {
        const a = Settings.appearance;
        return { font: a.font, fontSize: a.fontSize, radius: a.radius, iconTheme: a.iconTheme,
                 mono: Settings.terminal.font, wallpaper: Store.still };
    }

    // палитра передаётся аргументом: файл palette.json Recolor пишет асинхронно
    function apply(): void {
        const keys = ["crust", "mantle", "base", "surface0", "surface1", "surface2", "overlay0", "overlay1",
            "subtext0", "subtext1", "text", "accent", "accent2", "red", "peach", "yellow", "green", "teal", "lavender", "pink"];
        const p = { light: Theme.light };
        for (const k of keys) p[k] = "#" + String(Theme[k]).slice(1, 7);
        pending = p;
        lookFile.setText(JSON.stringify(look(), null, 2));
        if (!busy) run();
    }

    function run(): void {
        if (!pending || targets.length === 0) return;   // список целей ещё не прочитан — дождёмся
        const ids = targets.filter(t => t.installed && enabled(t.id)).map(t => t.id);
        if (ids.length === 0) { pending = null; return; }
        busy = true;
        applyProc.command = ["python3", engine, "apply", ...ids, "--palette", JSON.stringify(pending), "--look", JSON.stringify(look())];
        pending = null;
        applyProc.running = true;
    }

    function action(id: string): void {
        Quickshell.execDetached(["python3", engine, "action", id]);
    }

    function refresh(): void { statusProc.running = true; }
    function init(): void { refresh(); }

    Process {
        id: statusProc
        command: ["python3", root.engine, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.targets = JSON.parse(text); } catch (e) { root.targets = []; }
                if (root.pending) root.run();
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.results = JSON.parse(text); } catch (e) {}
            }
        }
        onExited: {
            root.busy = false;
            if (root.pending) root.run();   // пока работали, палитра успела смениться
        }
    }

    // шрифт и форма тоже уходят в приложения
    property var shape: [Settings.appearance.font, Settings.appearance.fontSize, Settings.appearance.radius, Settings.appearance.iconTheme]
    onShapeChanged: if (Settings.ready) shapeDebounce.restart()
    Timer { id: shapeDebounce; interval: 1200; onTriggered: root.apply() }

    FileView {
        id: lookFile
        path: Quickshell.env("HOME") + "/.cache/cove/look.json"
        printErrors: false
    }
}
