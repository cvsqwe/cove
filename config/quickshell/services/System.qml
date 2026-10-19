pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Ночной свет (hyprsunset) и аптайм.
Singleton {
    id: root

    property string uptime: ""

    // ночной свет: вручную или по расписанию; смена температуры перезапускает hyprsunset
    Process {
        id: sunset
        running: Store.nightLight
        command: ["hyprsunset", "-t", String(Settings.nightLight.temperature)]
    }
    Timer {
        id: sunsetRestart
        interval: 400
        onTriggered: if (Store.nightLight) { sunset.running = false; sunset.running = true; }
    }
    Connections {
        target: Settings.nightLight
        function onTemperatureChanged(): void { sunsetRestart.restart(); }
    }
    property bool lastScheduled: false
    Timer {
        interval: 30000
        running: Settings.nightLight.schedule
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const n = Settings.nightLight;
            const now = n.bySun ? !Sun.isDay : Notifs.inWindow(n.from, n.to);
            if (now !== root.lastScheduled) Store.nightLight = now; // не мешаем ручному переключению внутри окна
            root.lastScheduled = now;
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const s = parseFloat(text());
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = (d > 0 ? I18n.tr("{0} д ", d) : "") + (h > 0 ? I18n.tr("{0} ч ", h) : "") + I18n.tr("{0} мин", m);
        }
    }
}
