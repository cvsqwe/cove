pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Экранное время: сколько секунд за день у какого приложения был фокус.
// Не считаем, пока вы отошли (2 мин без ввода; видео с запретом сна — считается) и пока экран
// заблокирован. Дни — ~/.local/state/cove/screentime.json, хранятся 60 дней.
Singleton {
    id: root

    readonly property bool enabled: Settings.general.screenTime
    // { "2026-10-19": { "firefox": 3600, … }, … }
    property var days: ({})
    property bool loaded: false

    function dayKey(d): string { return Qt.formatDate(d ?? new Date(), "yyyy-MM-dd"); }
    readonly property string today: dayKey(clock.now)

    // appId из протокола Wayland: lastIpcObject у Hyprland без явного обновления бывает пустым
    readonly property string app: {
        const w = ToplevelManager.activeToplevel;
        return w && w.activated ? String(w.appId ?? "") : "";
    }

    IdleMonitor {
        id: idle
        enabled: root.enabled
        timeout: 120
        respectInhibitors: true
    }

    // тикаем раз в 5 с; Date — для смены дня
    QtObject { id: clock; property var now: new Date() }
    readonly property int step: 5
    Timer {
        running: root.enabled && root.loaded
        interval: root.step * 1000
        repeat: true
        onTriggered: {
            clock.now = new Date();
            if (idle.isIdle || Panels.locked || root.app === "") return;
            const d = Object.assign({}, root.days), t = Object.assign({}, d[root.today] ?? {});
            t[root.app] = (t[root.app] ?? 0) + root.step;
            d[root.today] = t;
            root.days = d;
        }
    }
    Timer {
        running: root.loaded
        interval: 60000
        repeat: true
        onTriggered: root.save()
    }

    function save(): void {
        const keep = Object.keys(days).sort().slice(-60);
        const d = {};
        for (const k of keep) d[k] = days[k];
        file.setText(JSON.stringify(d));
    }

    FileView {
        id: file
        path: Settings.home + "/.local/state/cove/screentime.json"
        printErrors: false
        onLoaded: { try { root.days = JSON.parse(text()); } catch (e) { root.days = {}; } root.loaded = true; }
        onLoadFailed: root.loaded = true
    }
    // перед выходом шелла
    Component.onDestruction: if (loaded) save()

    // ---- для страницы ----
    function total(day: string): int {
        const t = days[day] ?? {};
        return Object.keys(t).reduce((a, k) => a + t[k], 0);
    }
    // [{ app, secs }] по убыванию
    function apps(day: string): var {
        const t = days[day] ?? {};
        return Object.keys(t).map(k => ({ app: k, secs: t[k] })).sort((a, b) => b.secs - a.secs);
    }
    // последние 7 дней: [{ key, label, secs }]
    function week(): var {
        const out = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date(clock.now.getTime() - i * 86400000);
            const k = dayKey(d);
            out.push({ key: k, label: d.toLocaleDateString(I18n.locale, "ddd"), secs: total(k) });
        }
        return out;
    }
    function fmt(secs: int): string {
        const h = Math.floor(secs / 3600), m = Math.floor(secs % 3600 / 60);
        if (h > 0) return I18n.tr("{0} ч {1} мин", h, m);
        if (m > 0) return I18n.tr("{0} мин", m);
        return secs > 0 ? I18n.tr("< 1 мин") : I18n.tr("0 мин");
    }

    IpcHandler {
        target: "screentime"
        function today(): string { return JSON.stringify({ total: root.total(root.today), apps: root.apps(root.today).slice(0, 10), idle: idle.isIdle, app: root.app, loaded: root.loaded, locked: Panels.locked, day: root.today }); }
    }
}
