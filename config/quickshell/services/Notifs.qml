pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config

// Сервер уведомлений. Новые попадают в очередь острова, все — в историю центра управления.
// История — свои записи (~/.local/state/quickshell/notifications.json): переживает перезапуск
// шелла и перезагрузку. Пока приложение не закрыло уведомление, у записи есть живой объект n
// (кнопки, ответ); после перезагрузки остаётся только текст.
Singleton {
    id: root

    property var queue: []

    // «Не беспокоить»: вручную или по расписанию из настроек
    property bool scheduled: false
    readonly property bool quiet: Store.dnd || scheduled
    function inWindow(from: string, to: string): bool {
        const m = s => { const [h, mm] = String(s).split(":").map(Number); return (h || 0) * 60 + (mm || 0); };
        const d = new Date(), cur = d.getHours() * 60 + d.getMinutes(), a = m(from), b = m(to);
        return a < b ? cur >= a && cur < b : cur >= a || cur < b;
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.scheduled = Settings.notifications.dndSchedule && root.inWindow(Settings.notifications.dndFrom, Settings.notifications.dndTo)
    }
    readonly property var current: queue.length > 0 ? queue[0] : null

    // ---------- история ----------
    // записи: { key, nid, appName, appIcon, summary, body, icon, urgency, time }, новые первыми
    property var records: []
    property var live: ({})            // key → Notification, пока она жива (не сохраняется)
    property int liveRev: 0            // меняется вместе с live — для привязок
    readonly property int maxRecords: 150

    // для списков: записи + живой объект
    readonly property var list: { liveRev; return records.map(r => Object.assign({}, r, { n: live[r.key] ?? null })); }
    readonly property int count: records.length
    // по приложениям: [{ app, icon, items: [...] }], группа с самым свежим — первой
    readonly property var groups: {
        const out = [], at = {};
        for (const r of list) {
            const k = r.appName || r.appIcon || "?";
            if (at[k] === undefined) { at[k] = out.length; out.push({ app: k, icon: r.icon, items: [] }); }
            out[at[k]].items.push(r);
        }
        return out;
    }

    function next(): void { queue = queue.slice(1); }

    function keyOf(n): string {
        for (const k in live) if (live[k] === n) return k;
        return "";
    }
    function forget(key: string): void {
        if (!key) return;
        records = records.filter(r => r.key !== key);
        if (live[key]) { const l = live; delete l[key]; live = l; liveRev++; }
        saveLater.restart();
    }
    // закрыть: живую — у приложения, запись — из истории (приходит и Notification, и запись из list)
    function dismiss(x): void {
        if (!x) return;
        const n = x.key !== undefined ? x.n : x;
        const key = x.key !== undefined ? x.key : keyOf(x);
        if (n) n.dismiss();   // closed → forget
        forget(key);
    }
    function dismissApp(app: string): void {
        for (const r of list.filter(r => (r.appName || r.appIcon || "?") === app)) dismiss(r);
    }
    function clearAll(): void {
        for (const n of [...server.trackedNotifications.values]) n.dismiss();
        records = [];
        live = ({});
        liveRev++;
        queue = [];
        saveLater.restart();
    }

    function track(n): void {
        // пережило горячую перезагрузку шелла — запись уже есть, только привязываем. Новые — всегда новой
        // записью: после полного перезапуска номера уведомлений начинаются заново и совпали бы со старыми
        let rec = n.lastGeneration ? records.find(r => r.nid === n.id && r.summary === (n.summary ?? "") && !live[r.key]) : null;
        if (!rec) {
            if (n.transient) return;   // «временные» (громкость в чужих OSD и т.п.) в историю не пишем
            rec = {
                key: `${Date.now()}-${n.id}`, nid: n.id, appName: n.appName ?? "", appIcon: n.appIcon ?? "",
                summary: n.summary ?? "", body: n.body ?? "", icon: iconFor(n), urgency: n.urgency, time: Date.now(),
                // картинка из памяти (image://…) живёт до перезапуска — для истории запасной значок приложения
                appIconPath: appIconPath(n)
            };
            records = [rec, ...records].slice(0, maxRecords);
            saveLater.restart();
        }
        const l = live;
        l[rec.key] = n;
        live = l;
        liveRev++;
        const key = rec.key;
        // приложение само убрало (прочитали в телефоне) или пользователь закрыл — из истории тоже
        n.closed.connect(reason => {
            if (reason === NotificationCloseReason.Expired) { const m = root.live; delete m[key]; root.live = m; root.liveRev++; }
            else root.forget(key);
        });
    }

    FileView {
        id: historyFile
        path: Settings.home + "/.local/state/quickshell/notifications.json"
        printErrors: false
        onLoaded: {
            try { root.records = JSON.parse(text()).filter(r => r && r.key); } catch (e) { root.records = []; }
            root.loaded = true;
            for (const n of [...server.trackedNotifications.values]) root.track(n);
        }
        onLoadFailed: { root.loaded = true; for (const n of [...server.trackedNotifications.values]) root.track(n); }
    }
    property bool loaded: false
    Timer {
        id: saveLater
        interval: 400
        onTriggered: if (root.loaded) historyFile.setText(JSON.stringify(root.records.slice(0, root.maxRecords)))
    }

    // при закрытии уведомления (приложением или нами) убираем его из очереди
    Connections {
        target: root.current
        function onClosed(): void { root.next(); }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: n => {
            n.tracked = true;
            if (root.loaded) root.track(n);   // до загрузки истории — подхватит onLoaded
            // перенесённое через перезагрузку шелла — только в историю, без всплывашки и звука
            if (n.lastGeneration) return;
            const app = n.appName || "";
            if (app && !(Store.seenApps ?? []).includes(app)) Store.seenApps = [...(Store.seenApps ?? []), app].slice(-60);
            if ((Settings.notifications.muted ?? []).includes(app)) return; // только в историю
            if (!root.quiet || n.urgency === NotificationUrgency.Critical || root.allowed(n)) {
                root.queue = [...root.queue, n];
                Sounds.play("notify");
            }
        }
    }

    IpcHandler {
        target: "notifs"
        function count(): int { return root.count; }
        // убрать из истории всё от одного приложения (по appName)
        function clearApp(app: string): void { root.dismissApp(app); }
        function clear(): void { root.clearAll(); }
    }

    // «Не беспокоить» пропускает выбранных людей/приложения: совпадение без учёта регистра
    function allowed(n): bool {
        const hay = `${n.summary ?? ""}\n${n.appName ?? ""}`.toLowerCase();
        return (Settings.notifications.dndAllow ?? []).some(s => s && hay.includes(String(s).toLowerCase()));
    }

    // «5 мин», «14:20», «вчера 09:10», «12 окт»
    function ago(t: real): string {
        if (!t) return "";
        const d = new Date(t), now = new Date(), s = (now - d) / 1000;
        if (s < 60) return I18n.tr("сейчас");
        if (s < 3600) return I18n.tr("{0} мин", Math.floor(s / 60));
        const day = x => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
        const diff = Math.round((day(now) - day(d)) / 86400000);
        const hm = Qt.formatTime(d, "HH:mm");
        if (diff === 0) return hm;
        if (diff === 1) return I18n.tr("вчера {0}", hm);
        return d.toLocaleDateString(I18n.locale, "d MMM");
    }

    function appIconPath(n): string {
        const i = n.appIcon ?? "";
        return i === "" ? "" : i.startsWith("/") ? "file://" + i : i.includes("://") ? i : Quickshell.iconPath(i, true);
    }
    function iconFor(n): string {
        if (!n) return "";
        if (n.key !== undefined) {   // запись истории
            const i = n.icon ?? "";
            return i.startsWith("image://") && !n.n ? (n.appIconPath ?? "") : i;
        }
        // абсолютный путь без file:// Qt ищет в ресурсах программы (qrc:/usr/...) — значок пропадает
        const url = s => s.startsWith("/") ? "file://" + s : s;
        if (n.image) return url(n.image);
        const i = n.appIcon ?? "";
        if (i === "") return "";
        return i.startsWith("/") || i.includes("://") ? url(i) : Quickshell.iconPath(i, true);
    }
}
