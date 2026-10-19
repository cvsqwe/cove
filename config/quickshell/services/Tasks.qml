pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Диспетчер задач: процессы (assets/procs.py), сгруппированные по приложениям.
// Помощник работает, только пока открыта панель (tasks/TasksPanel.qml).
Singleton {
    id: root

    property var procs: []
    property int me: -1
    property real memTotal: 0
    property bool running: Panels.tasks

    // «electron», «Isolated Web Co» и т. п. уже сведены к приложению помощником (поле exe)
    readonly property var entries: {
        const m = {};
        for (const e of DesktopEntries.applications.values) {
            const keys = [e.id, e.startupClass, (e.command ?? [])[0] ? String(e.command[0]).split("/").pop() : ""];
            // и как есть, и без «.desktop» на конце: id org.telegram.desktop — это и есть appId Telegram
            for (const k of keys) if (k) for (const l of [String(k).toLowerCase(), String(k).toLowerCase().replace(/\.desktop$/, "")]) if (!m[l]) m[l] = e;
        }
        return m;
    }
    function entryFor(exe: string): var {
        const l = exe.toLowerCase();
        return entries[l] ?? entries[l.replace(/[-_]?bin$/, "")] ?? entries["org." + l + ".desktop"] ?? null;
    }

    // [{ key, name, icon, cpu, mem, pids: [...], procs: [...], system }]
    readonly property var groups: {
        const at = {}, out = [];
        for (const p of procs) {
            const k = p.exe || p.name;
            if (at[k] === undefined) {
                const e = entryFor(k);
                at[k] = out.length;
                out.push({ key: k, name: e?.name ?? k, icon: e?.icon ?? "", cpu: 0, mem: 0, procs: [], system: true });
            }
            const g = out[at[k]];
            g.cpu += p.cpu;
            g.mem += p.mem;
            g.procs.push(p);
            if (p.uid === me) g.system = false;
        }
        for (const g of out) g.procs.sort((a, b) => b.cpu - a.cpu || b.mem - a.mem);
        return out;
    }

    Process {
        id: helper
        running: root.running
        command: ["python3", Quickshell.shellPath("assets/procs.py"), "2"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const d = JSON.parse(line);
                    root.me = d.me;
                    root.memTotal = d.memTotal;
                    root.procs = d.procs.filter(p => p.pid !== d.self);
                } catch (e) {}
            }
        }
        onRunningChanged: if (!running) root.procs = []
    }

    // чужие (root, другие пользователи) — через pkexec, то есть через окно polkit Cove
    function sendSignal(pids, sig: string, system: bool): void {
        const list = pids.map(String);
        if (!list.length) return;
        Quickshell.execDetached(system ? ["pkexec", "kill", "-" + sig, ...list] : ["kill", "-" + sig, ...list]);
        refresh.restart();
    }
    function end(g): void { sendSignal(g.procs.map(p => p.pid), "TERM", g.system); }
    function kill(g): void { sendSignal(g.procs.map(p => p.pid), "KILL", g.system); }
    // после сигнала — свежий снимок через полсекунды, а не через 2 с
    Timer { id: refresh; interval: 600; onTriggered: if (helper.running) { helper.running = false; helper.running = true; } }

    function fmtMem(b: real): string {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + I18n.tr(" ГБ");
        return Math.round(b / 1048576) + I18n.tr(" МБ");
    }
}
