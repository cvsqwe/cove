pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Погода (open-meteo, без ключа) и курс валют (open.er-api.com). Обновление раз в 30 минут.
Singleton {
    id: root

    property bool ready: false
    property real temp: 0
    property real feels: 0
    property real wind: 0
    property int code: -1
    property bool isDay: true
    property var daily: [] // [{ day, code, max, min }]

    property real usd: 0
    property real eur: 0

    readonly property string icon: iconFor(code, isDay)
    readonly property string description: describe(code)

    function iconFor(c: int, day: bool): string {
        if (c === 0) return day ? "󰖙" : "󰖔";
        if (c <= 2) return day ? "󰖕" : "󰼱";
        if (c === 3) return "󰖐";
        if (c === 45 || c === 48) return "󰖑";
        if (c >= 51 && c <= 57) return "󰖗";
        if ((c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "󰖖";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "󰖘";
        if (c >= 95) return "󰖓";
        return "󰖐";
    }

    function describe(c: int): string {
        if (c === 0) return I18n.tr("Ясно");
        if (c === 1) return I18n.tr("Преимущественно ясно");
        if (c === 2) return I18n.tr("Переменная облачность");
        if (c === 3) return I18n.tr("Пасмурно");
        if (c === 45 || c === 48) return I18n.tr("Туман");
        if (c >= 51 && c <= 57) return I18n.tr("Морось");
        if (c >= 61 && c <= 67) return I18n.tr("Дождь");
        if (c >= 71 && c <= 77) return I18n.tr("Снег");
        if (c >= 80 && c <= 82) return I18n.tr("Ливень");
        if (c === 85 || c === 86) return I18n.tr("Снегопад");
        if (c >= 95) return I18n.tr("Гроза");
        return "";
    }

    function refresh(): void {
        if (!Settings.general.weather) return;
        weatherProc.running = true;
        ratesProc.running = true;
    }

    Timer {
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: weatherProc
        command: ["curl", "-sf", "-m", "15",
            `https://api.open-meteo.com/v1/forecast?latitude=${Settings.general.latitude}&longitude=${Settings.general.longitude}` +
            "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=4"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.temp = d.current.temperature_2m;
                    root.feels = d.current.apparent_temperature;
                    root.wind = d.current.wind_speed_10m;
                    root.code = d.current.weather_code;
                    root.isDay = d.current.is_day === 1;
                    root.daily = d.daily.time.map((t, i) => ({
                        day: new Date(t + "T12:00:00"),
                        code: d.daily.weather_code[i],
                        max: d.daily.temperature_2m_max[i],
                        min: d.daily.temperature_2m_min[i]
                    }));
                    root.ready = true;
                } catch (e) {}
            }
        }
    }

    Process {
        id: ratesProc
        command: ["curl", "-sf", "-m", "15", "https://open.er-api.com/v6/latest/USD"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text).rates;
                    root.usd = r.RUB;
                    root.eur = r.RUB / r.EUR;
                } catch (e) {}
            }
        }
    }
}
