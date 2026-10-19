pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config

// Мониторы: что подключено (hyprctl monitors all), применение на лету с откатом
// и сохранение в Settings.displays.monitors (оттуда их пишет в generated.lua services/HyprConfig.qml).
// Новые настройки сначала пробуются: если за 15 с не нажать «Оставить», вернутся прежние.
Singleton {
    id: root

    property var monitors: []          // как отдаёт hyprctl
    property var backup: []            // настройки до пробы
    property var trial: []             // что пробуем
    property bool pending: false       // ждём «Оставить» или отката
    property int countdown: 0

    readonly property var d: Settings.displays

    function key(m): string { return m.description ? "desc:" + m.description : m.name; }
    function rate(r: real): string { return Number(r).toFixed(2); }
    function modeOf(m): string { return `${m.width}x${m.height}@${rate(m.refreshRate)}`; }
    function title(m): string {
        const desc = (m.description ?? "").replace(/\s+[0-9A-Fx]{6,}$/, "");   // без серийного номера
        return desc ? `${desc} (${m.name})` : m.name;
    }

    // текущие настройки монитора в нашем формате
    function current(m): var {
        return {
            key: key(m), name: m.name, enabled: !m.disabled, mode: modeOf(m),
            x: m.x, y: m.y, scale: Number(m.scale), transform: m.transform,
            vrr: m.vrr ? 1 : 0, mirror: m.mirrorOf && m.mirrorOf !== "none" ? m.mirrorOf : ""
        };
    }
    function currentAll(): var { return monitors.map(m => current(m)); }

    // логический размер на рабочем столе: с учётом масштаба и поворота
    function logical(c): var {
        const p = /^(\d+)x(\d+)/.exec(c.mode ?? "") ?? [0, 1920, 1080];
        let w = Number(p[1]) / (c.scale || 1), h = Number(p[2]) / (c.scale || 1);
        if (c.transform % 2 === 1) [w, h] = [h, w];
        return { w: Math.round(w), h: Math.round(h) };
    }

    // режимы монитора: разрешения и частоты для каждого
    function modes(m): var {
        const out = {};
        for (const s of m?.availableModes ?? []) {
            const r = /^(\d+x\d+)@([\d.]+)Hz$/.exec(s);
            if (!r) continue;
            (out[r[1]] = out[r[1]] ?? []);
            if (!out[r[1]].includes(r[2])) out[r[1]].push(r[2]);
        }
        for (const k in out) out[k].sort((a, b) => Number(b) - Number(a));
        return out;
    }
    function byName(name: string): var { return monitors.find(m => m.name === name) ?? null; }

    function lua(c): string {
        const q = s => JSON.stringify(String(s));
        if (!c.enabled) return `hl.monitor({ output = ${q(c.key)}, disabled = true })`;
        const f = [`output = ${q(c.key)}`, `mode = ${q(c.mode)}`, `position = ${q(Math.round(c.x) + "x" + Math.round(c.y))}`,
                   `scale = ${c.scale}`, `transform = ${c.transform ?? 0}`, `vrr = ${c.vrr ?? 0}`, "disabled = false"];
        if (c.mirror) f.push(`mirror = ${q(c.mirror)}`);
        return `hl.monitor({ ${f.join(", ")} })`;
    }

    // ---- проба и откат ----
    function tryApply(cfgs: var): void {
        if (!pending) backup = currentAll();
        trial = Settings.copy(cfgs);
        run(cfgs);
        pending = true;
        countdown = 15;
        tick.restart();
    }
    // сохраняем пробу; настройки мониторов, которые сейчас не подключены, не трогаем
    function keep(): void {
        tick.stop();
        pending = false;
        const keys = new Set(trial.map(c => c.key));
        Settings.displays.monitors = (d.monitors ?? []).filter(c => !keys.has(c.key)).concat(Settings.copy(trial));
    }
    function revert(): void {
        tick.stop();
        pending = false;
        run(backup);
    }
    // забыть свои настройки: дальше решают Hyprland и monitors.lua
    function reset(): void {
        Settings.displays.monitors = [];
        Quickshell.execDetached(["hyprctl", "reload"]);
        refreshSoon.restart();
    }
    function run(cfgs: var): void {
        // сначала включённые (чтобы не остаться без экрана), выключение — последним
        const ordered = cfgs.filter(c => c.enabled).concat(cfgs.filter(c => !c.enabled));
        apply.command = ["sh", "-c", 'for l; do hyprctl eval "$l" >/dev/null; done', "_", ...ordered.map(c => lua(c))];
        apply.running = true;
    }
    Process {
        id: apply
        onExited: refreshSoon.restart()
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: if (--root.countdown <= 0) root.revert()
    }

    // ---- список мониторов ----
    function refresh(): void { list.running = true; }
    Process {
        id: list
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitors = JSON.parse(text).sort((a, b) => a.x - b.x || a.y - b.y); } catch (e) {}
            }
        }
    }
    Timer { id: refreshSoon; interval: 600; onTriggered: root.refresh() }
    Connections {
        target: Hyprland
        function onRawEvent(e: HyprlandEvent): void {
            if (/^monitor(added|removed)/.test(e.name)) refreshSoon.restart();
        }
    }
    Component.onCompleted: refresh()

    // экран для виджетов рабочего стола и прочего «одного на систему»
    readonly property var primaryScreen: Quickshell.screens.find(s => s.name === d.primary) ?? Quickshell.screens[0] ?? null
    function hasBar(screen): bool { return d.bars !== "primary" || screen === primaryScreen; }

    IpcHandler {
        target: "displays"
        function list(): string { return root.monitors.map(m => `${m.name} ${root.modeOf(m)} ${m.x}x${m.y} ${m.scale}${m.disabled ? " off" : ""}`).join("\n"); }
        function keep(): void { if (root.pending) root.keep(); }
        function revert(): void { if (root.pending) root.revert(); }
        function reset(): void { root.reset(); }
    }
}
