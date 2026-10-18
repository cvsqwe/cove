pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Таймеры (в памяти) и будильники (Store.alarms, переживают перезапуск).
// Остров показывает ближайший таймер в капсуле; по окончании — звук, тост и уведомление,
// которое проходит даже сквозь «Не беспокоить» (critical).
// Лаунчер: «+5m чай», IPC: qs ipc call timer start 25m "Фокус" | cancel | list.
Singleton {
    id: root

    property var timers: []          // [{ id, label, end, total, left (на паузе) }]
    property real now: Date.now()
    property var fired: ({})         // будильник → последняя минута срабатывания ("2026-10-18 07:30")
    property int nextId: 1

    readonly property var running: timers.filter(t => t.left === undefined)
    readonly property var nearest: timers.length
        ? timers.slice().sort((a, b) => root.remaining(a) - root.remaining(b))[0] : null
    readonly property bool active: timers.length > 0

    signal finished(string label)

    Timer {
        interval: 250
        running: root.timers.length > 0
        repeat: true
        onTriggered: {
            root.now = Date.now();
            const done = root.timers.filter(t => t.left === undefined && t.end <= root.now);
            if (done.length) {
                root.timers = root.timers.filter(t => !done.includes(t));
                for (const t of done) root.ring(t.label || I18n.tr("Таймер"), I18n.tr("Время вышло"));
            }
        }
    }

    // ---- таймеры ----
    function remaining(t): real { return t.left !== undefined ? t.left : Math.max(0, t.end - now); }
    function progress(t): real { return t.total > 0 ? 1 - remaining(t) / t.total : 0; }

    function start(seconds: real, label: string): void {
        if (!(seconds > 0)) return;
        now = Date.now();
        timers = [...timers, { id: nextId++, label: label ?? "", end: now + seconds * 1000, total: seconds * 1000 }];
    }
    function cancel(id: int): void { timers = timers.filter(t => t.id !== id); }
    function cancelAll(): void { timers = []; }
    function togglePause(id: int): void {
        now = Date.now();
        timers = timers.map(t => t.id !== id ? t
            : t.left !== undefined ? { id: t.id, label: t.label, total: t.total, end: now + t.left }
            : { id: t.id, label: t.label, total: t.total, end: t.end, left: Math.max(0, t.end - now) });
    }

    // «5m», «1h30m», «90s», «1:30», «25:00», «10» (минуты) → секунды; 0 — не понял
    function parse(s: string): real {
        s = String(s ?? "").trim().toLowerCase().replace(",", ".");
        if (/^\d+(\.\d+)?$/.test(s)) return Number(s) * 60;
        let m = s.match(/^(\d+):(\d{1,2})(?::(\d{1,2}))?$/);
        if (m) return m[3] !== undefined ? +m[1] * 3600 + +m[2] * 60 + +m[3] : +m[1] * 60 + +m[2];
        let total = 0, any = false;
        const re = /(\d+(?:\.\d+)?)\s*(ч|h|час[а-я]*|м|m|мин[а-я]*|min|с|s|сек[а-я]*|sec)/g;
        // вся строка должна состоять из «число+единица», иначе «5mчай» сошло бы за 5 минут
        if (s.replace(re, "").trim() !== "") return 0;
        re.lastIndex = 0;
        while ((m = re.exec(s)) !== null) {
            any = true;
            const n = Number(m[1]), u = m[2][0];
            total += u === "ч" || u === "h" ? n * 3600 : u === "м" || u === "m" ? n * 60 : n;
        }
        return any ? total : 0;
    }

    // разбирает «5m чай» → { seconds, label }
    function parseCommand(s: string): var {
        const parts = String(s ?? "").trim().split(/\s+/);
        for (let n = parts.length; n > 0; n--) {
            const sec = parse(parts.slice(0, n).join(""));
            if (sec > 0) return { seconds: sec, label: parts.slice(n).join(" ") };
        }
        return { seconds: 0, label: "" };
    }

    function format(ms: real): string {
        const s = Math.ceil(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const p = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${p(m)}:${p(sec)}` : `${m}:${p(sec)}`;
    }
    function human(seconds: real): string {
        const h = Math.floor(seconds / 3600), m = Math.floor(seconds % 3600 / 60), s = Math.round(seconds % 60);
        const out = [];
        if (h) out.push(h + I18n.tr(" ч"));
        if (m) out.push(m + I18n.tr(" мин"));
        if (s && !h) out.push(s + I18n.tr(" с"));
        return out.join(" ") || "0" + I18n.tr(" с");
    }

    // ---- будильники ----
    function addAlarm(time: string, label: string, days: var): void {
        if (!/^\d{1,2}:\d{2}$/.test(time)) return;
        const [h, m] = time.split(":").map(Number);
        const t = String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0");
        Store.alarms = [...(Store.alarms ?? []), { id: Date.now(), time: t, label: label ?? "", days: days ?? [], on: true }];
    }
    function updateAlarm(id: real, patch: var): void {
        Store.alarms = (Store.alarms ?? []).map(a => a.id === id ? Object.assign({}, a, patch) : a);
    }
    function removeAlarm(id: real): void { Store.alarms = (Store.alarms ?? []).filter(a => a.id !== id); }

    // ближайший включённый будильник: { alarm, at: Date }
    readonly property var nextAlarm: {
        void now;
        let best = null;
        const base = new Date();
        for (const a of Store.alarms ?? []) {
            if (!a.on) continue;
            const [h, m] = a.time.split(":").map(Number);
            for (let d = 0; d < 8; d++) {
                const at = new Date(base.getFullYear(), base.getMonth(), base.getDate() + d, h, m);
                if (at <= base) continue;
                const dow = at.getDay() === 0 ? 7 : at.getDay();
                if ((a.days ?? []).length && !a.days.includes(dow)) continue;
                if (!best || at < best.at) best = { alarm: a, at };
                break;
            }
        }
        return best;
    }

    Timer {
        interval: 10000
        running: (Store.alarms ?? []).length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const d = new Date();
            const hm = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
            const key = d.toDateString() + " " + hm;
            const dow = d.getDay() === 0 ? 7 : d.getDay();
            root.now = Date.now();
            for (const a of Store.alarms ?? []) {
                if (!a.on || a.time !== hm || root.fired[a.id] === key) continue;
                if ((a.days ?? []).length && !a.days.includes(dow)) continue;
                root.fired = Object.assign({}, root.fired, { [a.id]: key });
                // разовый будильник (без дней) после срабатывания выключается
                if (!(a.days ?? []).length) root.updateAlarm(a.id, { on: false });
                root.ring(a.label || I18n.tr("Будильник"), a.time);
            }
        }
    }

    // ---- сигнал ----
    function ring(title: string, body: string): void {
        root.finished(title);
        ringer.count = 0;
        ringer.restart();
        Quickshell.execDetached(["notify-send", "-a", "Cove", "-u", "critical", "-i", "cove", title, body]);
    }
    // звон три раза с паузой, громкость — общая громкость звуков интерфейса (но даже при выключенных звуках)
    Timer {
        id: ringer
        property int count: 0
        interval: 1400
        triggeredOnStart: true
        repeat: count < 3
        onTriggered: {
            count++;
            Quickshell.execDetached(["pw-play", "--volume", String(Math.max(0.5, Settings.general.soundVolume)), Sounds.path("alarm")]);
        }
    }

    IpcHandler {
        target: "timer"
        function start(duration: string, label: string): string {
            const s = root.parse(duration);
            if (!s) return "не понял длительность: " + duration;
            root.start(s, label);
            return "ok";
        }
        function cancel(): void { root.cancelAll(); }
        function list(): string { return root.timers.map(t => `${t.label || "таймер"} ${root.format(root.remaining(t))}`).join("\n"); }
        function alarm(time: string, label: string): void { root.addAlarm(time, label, []); }
    }
}
