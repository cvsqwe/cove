pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// События календаря из ICS-подписок (Settings.general.calendars: ссылки «секретный адрес iCal»
// Google/Яндекс/Nextcloud или пути к .ics). Раз в 15 минут скачиваем, разбираем на ближайшие 14 дней.
// Повторы: FREQ=DAILY/WEEKLY/MONTHLY/YEARLY с INTERVAL, COUNT, UNTIL, BYDAY и EXDATE.
// За Settings.general.calendarRemind минут до начала — тост в острове и уведомление.
Singleton {
    id: root

    property var events: []         // [{ title, start: Date, end: Date, allDay, location, cal }]
    property bool loading: false
    property string error: ""
    property real now: Date.now()
    property var reminded: ({})

    readonly property var sources: Settings.general.calendars ?? []
    readonly property string cache: Quickshell.env("HOME") + "/.cache/quickshell/calendar"

    // ближайшее ещё не закончившееся событие со временем (весь день — не «следующее»)
    readonly property var next: events.find(e => !e.allDay && e.end.getTime() > now) ?? null
    readonly property var today: events.filter(e => sameDay(e.start, new Date(now)) || (e.allDay && e.start.getTime() <= now && e.end.getTime() > now))
    function minutesTo(e): int { return Math.round((e.start.getTime() - now) / 60000); }
    function upcoming(days: int): var {
        const lim = now + days * 86400000;
        return events.filter(e => e.end.getTime() > now && e.start.getTime() < lim);
    }

    signal remind(var event)

    function sameDay(a, b): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function refresh(): void {
        if (!sources.length) { events = []; error = ""; return; }
        loading = true;
        fetch.running = true;
    }
    onSourcesChanged: refresh()
    Component.onCompleted: refresh()

    Timer { interval: 15 * 60 * 1000; running: root.sources.length > 0; repeat: true; onTriggered: root.refresh() }
    Timer {
        interval: 30000
        running: root.events.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            const before = Settings.general.calendarRemind ?? 10;
            if (before <= 0) return;
            for (const e of root.events) {
                if (e.allDay) continue;
                const m = (e.start.getTime() - root.now) / 60000;
                const key = e.title + e.start.getTime();
                if (m > 0 && m <= before && !root.reminded[key]) {
                    root.reminded = Object.assign({}, root.reminded, { [key]: true });
                    root.remind(e);
                    Quickshell.execDetached(["notify-send", "-a", I18n.tr("Календарь"), "-i", "x-office-calendar", e.title,
                        I18n.tr("Через {0} мин", Math.round(m)) + (e.location ? " · " + e.location : "")]);
                }
            }
        }
    }

    // качаем все источники одним процессом: каждый файл — между маркерами
    Process {
        id: fetch
        command: ["sh", "-c", 'mkdir -p "$1"; dir="$1"; shift; i=0
            for src in "$@"; do
                i=$((i+1)); f="$dir/$i.ics"
                case "$src" in
                    http*|webcal*) url=$(printf %s "$src" | sed "s|^webcal://|https://|")
                        curl -sfL -m 20 "$url" -o "$f.tmp" && mv "$f.tmp" "$f" ;;
                    *) src=$(printf %s "$src" | sed "s|^~|$HOME|"); cp "$src" "$f" 2>/dev/null ;;
                esac
                echo "@@CAL $i"; cat "$f" 2>/dev/null
            done', "_", root.cache, ...root.sources]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const parts = text.split(/^@@CAL \d+$/m).slice(1);
                    let all = [];
                    parts.forEach((p, i) => { all = all.concat(root.parse(p, i)); });
                    all.sort((a, b) => a.start - b.start);
                    root.events = all;
                    root.error = parts.some(p => !p.includes("BEGIN:VCALENDAR")) ? I18n.tr("Не все календари загрузились") : "";
                } catch (e) {
                    console.warn("calendar:", e);
                    root.error = String(e);
                }
                root.now = Date.now();
            }
        }
    }

    // ---- разбор ICS ----
    function unfold(text: string): var {
        return text.replace(/\r/g, "").replace(/\n[ \t]/g, "").split("\n");
    }
    function unesc(s: string): string {
        return s.replace(/\\n/gi, " ").replace(/\\([,;\\])/g, "$1").trim();
    }
    // «20261018T093000Z», «20261018T093000» (+TZID), «20261018» (весь день)
    function parseDate(value: string, params: string): var {
        const m = value.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/);
        if (!m) return null;
        const [, y, mo, d, h, mi, s, z] = m;
        if (h === undefined) return { date: new Date(+y, +mo - 1, +d), allDay: true };
        if (z) return { date: new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +(s ?? 0))), allDay: false };
        const tz = (params.match(/TZID=([^;:]+)/) ?? [])[1];
        const local = new Date(+y, +mo - 1, +d, +h, +mi, +(s ?? 0));
        return { date: tz ? fromZone(local, tz) : local, allDay: false };
    }
    // время «по часам зоны tz» → настоящий момент (через Intl, который знает зоны)
    function fromZone(local, tz: string): var {
        try {
            const fmt = new Intl.DateTimeFormat("en-US", { timeZone: tz.replace(/^"|"$/g, ""), hour12: false,
                year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" });
            const asUtc = Date.UTC(local.getFullYear(), local.getMonth(), local.getDate(), local.getHours(), local.getMinutes(), local.getSeconds());
            const p = Object.fromEntries(fmt.formatToParts(new Date(asUtc)).map(x => [x.type, x.value]));
            const shown = Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour % 24, +p.minute, +p.second);
            return new Date(asUtc - (shown - asUtc));
        } catch (e) {
            return local;
        }
    }

    function parse(text: string, cal: int): var {
        const lines = unfold(text);
        const from = new Date(); from.setHours(0, 0, 0, 0);
        const to = new Date(from.getTime() + 14 * 86400000);
        const out = [];
        let ev = null;
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") { ev = { exdates: [] }; continue; }
            if (line === "END:VEVENT") { if (ev) expand(ev, from, to, cal, out); ev = null; continue; }
            if (!ev) continue;
            const i = line.indexOf(":");
            if (i < 0) continue;
            const head = line.slice(0, i), value = line.slice(i + 1);
            const [key, ...ps] = head.split(";");
            const params = ps.join(";");
            if (key === "SUMMARY") ev.title = unesc(value);
            else if (key === "LOCATION") ev.location = unesc(value);
            else if (key === "DTSTART") ev.start = parseDate(value, params);
            else if (key === "DTEND") ev.end = parseDate(value, params);
            else if (key === "DURATION") ev.duration = value;
            else if (key === "RRULE") ev.rrule = value;
            else if (key === "STATUS") ev.status = value;
            else if (key === "EXDATE") for (const v of value.split(",")) { const d = parseDate(v, params); if (d) ev.exdates.push(d.date.getTime()); }
            else if (key === "RECURRENCE-ID") ev.recurrence = true;
        }
        return out;
    }

    function durationMs(s: string): real {
        const m = String(s ?? "").match(/P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?/);
        if (!m) return 0;
        return ((+(m[1] ?? 0) * 7 + +(m[2] ?? 0)) * 86400 + +(m[3] ?? 0) * 3600 + +(m[4] ?? 0) * 60 + +(m[5] ?? 0)) * 1000;
    }

    function expand(ev, from, to, cal: int, out): void {
        if (!ev.start || ev.status === "CANCELLED") return;
        const start = ev.start.date, allDay = ev.start.allDay;
        const len = ev.end ? ev.end.date - start : ev.duration ? durationMs(ev.duration) : allDay ? 86400000 : 3600000;
        const push = s => {
            if (ev.exdates.includes(s.getTime())) return;
            const e = new Date(s.getTime() + len);
            if (e > from && s < to)
                out.push({ title: ev.title || I18n.tr("Без названия"), start: s, end: e, allDay, location: ev.location ?? "", cal });
        };
        if (!ev.rrule) { push(start); return; }

        const r = Object.fromEntries(ev.rrule.split(";").map(kv => kv.split("=")));
        const freq = r.FREQ, interval = Math.max(1, +(r.INTERVAL ?? 1));
        const count = r.COUNT ? +r.COUNT : Infinity;
        const until = r.UNTIL ? parseDate(r.UNTIL, "")?.date : null;
        const days = r.BYDAY ? r.BYDAY.split(",").map(d => ["SU", "MO", "TU", "WE", "TH", "FR", "SA"].indexOf(d.slice(-2))) : null;
        let n = 0;
        const add = s => {
            if (n >= count || (until && s > until) || s >= to) return false;
            n++;
            push(s);
            return true;
        };
        const at = (base, dd) => new Date(base.getFullYear(), base.getMonth(), base.getDate() + dd, start.getHours(), start.getMinutes(), start.getSeconds());
        for (let i = 0; i < 2000; i++) {
            if (freq === "DAILY") {
                if (!add(at(start, i * interval))) break;
            } else if (freq === "WEEKLY") {
                const weekStart = at(start, i * 7 * interval - ((start.getDay() + 6) % 7));
                if (weekStart >= to || (until && weekStart > until) || n >= count) break;
                const ds = days ?? [start.getDay()];
                for (const wd of ds.slice().sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7))) {
                    const s = at(weekStart, (wd + 6) % 7);
                    if (s < start) continue;
                    if (!add(s)) break;
                }
            } else if (freq === "MONTHLY") {
                const s = new Date(start.getFullYear(), start.getMonth() + i * interval, start.getDate(), start.getHours(), start.getMinutes());
                if (s.getDate() !== start.getDate()) continue;
                if (!add(s)) break;
            } else if (freq === "YEARLY") {
                if (!add(new Date(start.getFullYear() + i * interval, start.getMonth(), start.getDate(), start.getHours(), start.getMinutes()))) break;
            } else break;
        }
    }

    IpcHandler {
        target: "calendar"
        function refresh(): void { root.refresh(); }
        function next(): string { return root.next ? `${root.next.title} ${root.next.start}` : ""; }
    }
}
