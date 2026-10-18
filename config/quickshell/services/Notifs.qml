pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Сервер уведомлений. Новые попадают в очередь острова, все — в историю центра управления.
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
    readonly property var list: [...server.trackedNotifications.values].reverse()
    readonly property int count: list.length

    function next(): void { queue = queue.slice(1); }
    function clearAll(): void {
        for (const n of [...server.trackedNotifications.values]) n.dismiss();
        queue = [];
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

        onNotification: n => {
            n.tracked = true;
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

    // «Не беспокоить» пропускает выбранных людей/приложения: совпадение без учёта регистра
    function allowed(n): bool {
        const hay = `${n.summary ?? ""}\n${n.appName ?? ""}`.toLowerCase();
        return (Settings.notifications.dndAllow ?? []).some(s => s && hay.includes(String(s).toLowerCase()));
    }

    function iconFor(n): string {
        if (!n) return "";
        // абсолютный путь без file:// Qt ищет в ресурсах программы (qrc:/usr/...) — значок пропадает
        const url = s => s.startsWith("/") ? "file://" + s : s;
        if (n.image) return url(n.image);
        const i = n.appIcon ?? "";
        if (i === "") return "";
        return i.startsWith("/") || i.includes("://") ? url(i) : Quickshell.iconPath(i, true);
    }
}
