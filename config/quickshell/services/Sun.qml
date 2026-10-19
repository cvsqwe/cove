pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Восход и закат по координатам из Settings.general (считаются локально, без сети: формулы SunCalc/NOAA)
// и автоматическая тема: светлая днём — по солнцу или по своему расписанию (Settings.appearance.themeMode).
// Тема меняется только на границе дня и ночи: ручное переключение держится до следующей границы.
Singleton {
    id: root

    property var sunrise: null     // Date; null — полярный день или ночь
    property var sunset: null
    property string polar: ""      // "" | "day" | "night"
    property bool isDay: true
    readonly property string sunriseText: sunrise ? Qt.formatTime(sunrise, "HH:mm") : "—"
    readonly property string sunsetText: sunset ? Qt.formatTime(sunset, "HH:mm") : "—"

    function times(date, lat: real, lon: real): var {
        const rad = Math.PI / 180, day = 86400000, J1970 = 2440588, J2000 = 2451545;
        const noonLocal = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
        const d = noonLocal.valueOf() / day - 0.5 + J1970 - J2000;
        const lw = -lon * rad, phi = lat * rad;
        const n = Math.round(d - 0.0009 - lw / (2 * Math.PI));
        const ds = 0.0009 + lw / (2 * Math.PI) + n;
        const M = rad * (357.5291 + 0.98560028 * ds);
        const C = rad * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
        const L = M + C + rad * 102.9372 + Math.PI;
        const dec = Math.asin(Math.sin(rad * 23.4397) * Math.sin(L));
        const transit = j => J2000 + j + 0.0053 * Math.sin(M) - 0.0069 * Math.sin(2 * L);
        const noon = transit(ds);
        // -0.833° — верхний край диска с учётом рефракции
        const cosW = (Math.sin(-0.833 * rad) - Math.sin(phi) * Math.sin(dec)) / (Math.cos(phi) * Math.cos(dec));
        if (cosW < -1) return { polar: "day" };
        if (cosW > 1) return { polar: "night" };
        const toDate = j => new Date((j + 0.5 - J1970) * day);
        const set = transit(0.0009 + (Math.acos(cosW) + lw) / (2 * Math.PI) + n);
        return { sunrise: toDate(noon - (set - noon)), sunset: toDate(set), polar: "" };
    }

    function update(): void {
        const now = new Date(), t = times(now, Settings.general.latitude, Settings.general.longitude);
        sunrise = t.sunrise ?? null;
        sunset = t.sunset ?? null;
        polar = t.polar;
        isDay = polar ? polar === "day" : now >= sunrise && now < sunset;
    }

    // ---- автотема ----
    readonly property var a: Settings.appearance
    property var lastWanted: null      // null — применить при первом тике (старт или смена режима)
    function wantLight(): bool {
        return a.themeMode === "sun" ? isDay : Notifs.inWindow(a.lightFrom, a.lightTo);
    }
    function tick(): void {
        update();
        if (!Settings.ready || a.themeMode === "manual") return;
        const w = wantLight();
        if (w !== lastWanted && a.light !== w) a.light = w;
        lastWanted = w;
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
    Connections {
        target: Settings.appearance
        function onThemeModeChanged(): void { root.lastWanted = null; root.tick(); }
        function onLightFromChanged(): void { root.lastWanted = null; root.tick(); }
        function onLightToChanged(): void { root.lastWanted = null; root.tick(); }
    }
    Connections {
        target: Settings.general
        function onLatitudeChanged(): void { root.lastWanted = null; root.tick(); }
        function onLongitudeChanged(): void { root.lastWanted = null; root.tick(); }
    }

    IpcHandler {
        target: "sun"
        function status(): string {
            root.update();
            return root.polar ? I18n.tr("полярный ") + root.polar : `${root.sunriseText}–${root.sunsetText} ${root.isDay ? "day" : "night"}`;
        }
    }
}
