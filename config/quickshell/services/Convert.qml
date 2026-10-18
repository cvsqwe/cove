pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Конвертер для калькулятора лаунчера: «=100 usd в руб», «=5 km in mi», «=30 c в f», «=2 гб в мб».
// Курсы валют — open.er-api.com (без ключа), кэш на 12 часов в ~/.cache/quickshell/rates.json.
Singleton {
    id: root

    property var rates: ({})      // код → сколько за 1 USD
    property real ratesTime: 0

    // единица → [величина, множитель к базовой]; температуру считаем отдельно
    readonly property var units: ({
        // длина, база — метр
        mm: ["len", 0.001], "мм": ["len", 0.001], cm: ["len", 0.01], "см": ["len", 0.01],
        m: ["len", 1], "м": ["len", 1], km: ["len", 1000], "км": ["len", 1000],
        in: ["len", 0.0254], inch: ["len", 0.0254], "дюйм": ["len", 0.0254], "дюйма": ["len", 0.0254], "дюймов": ["len", 0.0254],
        ft: ["len", 0.3048], "фут": ["len", 0.3048], "футов": ["len", 0.3048], yd: ["len", 0.9144], "ярд": ["len", 0.9144],
        mi: ["len", 1609.344], mile: ["len", 1609.344], miles: ["len", 1609.344], "миля": ["len", 1609.344], "мили": ["len", 1609.344], "миль": ["len", 1609.344],
        nmi: ["len", 1852],
        // масса, база — грамм
        mg: ["mass", 0.001], "мг": ["mass", 0.001], g: ["mass", 1], "г": ["mass", 1], kg: ["mass", 1000], "кг": ["mass", 1000],
        t: ["mass", 1e6], "т": ["mass", 1e6], lb: ["mass", 453.59237], lbs: ["mass", 453.59237], "фунт": ["mass", 453.59237], "фунтов": ["mass", 453.59237],
        oz: ["mass", 28.349523125], "унция": ["mass", 28.349523125], "унций": ["mass", 28.349523125],
        // объём, база — литр
        ml: ["vol", 0.001], "мл": ["vol", 0.001], l: ["vol", 1], "л": ["vol", 1], gal: ["vol", 3.785411784], "галлон": ["vol", 3.785411784],
        cup: ["vol", 0.2365882365], "чашка": ["vol", 0.25],
        // данные, база — байт
        b: ["data", 1], "б": ["data", 1], kb: ["data", 1e3], "кб": ["data", 1e3], mb: ["data", 1e6], "мб": ["data", 1e6],
        gb: ["data", 1e9], "гб": ["data", 1e9], tb: ["data", 1e12], "тб": ["data", 1e12],
        kib: ["data", 1024], mib: ["data", 1048576], gib: ["data", 1073741824], tib: ["data", 1099511627776],
        // время, база — секунда
        ms: ["time", 0.001], s: ["time", 1], sec: ["time", 1], "с": ["time", 1], "сек": ["time", 1],
        min: ["time", 60], "мин": ["time", 60], h: ["time", 3600], "ч": ["time", 3600], "час": ["time", 3600], "часа": ["time", 3600], "часов": ["time", 3600],
        d: ["time", 86400], day: ["time", 86400], days: ["time", 86400], "дн": ["time", 86400], "день": ["time", 86400], "дня": ["time", 86400], "дней": ["time", 86400],
        wk: ["time", 604800], "нед": ["time", 604800], "недель": ["time", 604800], y: ["time", 31557600], "год": ["time", 31557600], "лет": ["time", 31557600],
        // скорость, база — м/с
        "m/s": ["speed", 1], "м/с": ["speed", 1], kmh: ["speed", 1 / 3.6], "km/h": ["speed", 1 / 3.6], "км/ч": ["speed", 1 / 3.6], mph: ["speed", 0.44704], kn: ["speed", 0.514444], "узлов": ["speed", 0.514444],
        // площадь, база — м²
        "m2": ["area", 1], "м2": ["area", 1], "км2": ["area", 1e6], km2: ["area", 1e6], ha: ["area", 1e4], "га": ["area", 1e4], "сотка": ["area", 100], "соток": ["area", 100], acre: ["area", 4046.8564224], ft2: ["area", 0.09290304]
    })
    readonly property var temps: ({ c: "c", "°c": "c", "с°": "c", "цельсий": "c", "цельсия": "c", f: "f", "°f": "f", "фаренгейт": "f", k: "k", "кельвин": "k" })

    readonly property var currencyAliases: ({
        "$": "USD", "usd": "USD", "долл": "USD", "доллар": "USD", "доллара": "USD", "долларов": "USD", "баксов": "USD",
        "€": "EUR", "eur": "EUR", "евро": "EUR", "₽": "RUB", "rub": "RUB", "руб": "RUB", "рубль": "RUB", "рубля": "RUB", "рублей": "RUB", "р": "RUB",
        "£": "GBP", "gbp": "GBP", "¥": "JPY", "jpy": "JPY", "иен": "JPY", "cny": "CNY", "юань": "CNY", "юаней": "CNY",
        "uah": "UAH", "грн": "UAH", "гривна": "UAH", "гривен": "UAH", "byn": "BYN", "kzt": "KZT", "тенге": "KZT",
        "try": "TRY", "лира": "TRY", "лир": "TRY", "gel": "GEL", "лари": "GEL", "amd": "AMD", "драм": "AMD",
        "btc": "BTC", "usdt": "USDT"
    })

    function currency(s: string): string {
        const k = s.toLowerCase();
        if (currencyAliases[k]) return currencyAliases[k];
        return /^[a-z]{3}$/i.test(s) && rates[s.toUpperCase()] !== undefined ? s.toUpperCase() : "";
    }

    function fmt(v: real): string {
        const a = Math.abs(v);
        const r = a >= 1000 ? Math.round(v * 100) / 100 : a >= 1 ? Math.round(v * 10000) / 10000 : Number(v.toPrecision(6));
        return r.toLocaleString(I18n.locale, "f", a >= 1000 ? 2 : 4).replace(/[.,]?0+$/, "");
    }

    // «100 usd в руб» → { value, text } или null
    function convert(q: string): var {
        const m = String(q).trim().toLowerCase().replace(",", ".")
            .match(/^(-?\d+(?:\.\d+)?)\s*([^\d\s]+(?:\/[^\d\s]+)?)\s+(?:в|во|to|in|->|=)\s+([^\d\s]+(?:\/[^\d\s]+)?)$/);
        if (!m) return null;
        const n = Number(m[1]), from = m[2], to = m[3];
        // температура
        const tf = temps[from], tt = temps[to];
        if (tf && tt) {
            const c = tf === "c" ? n : tf === "f" ? (n - 32) * 5 / 9 : n - 273.15;
            const v = tt === "c" ? c : tt === "f" ? c * 9 / 5 + 32 : c + 273.15;
            return { value: v, text: `${fmt(v)} °${tt.toUpperCase()}` };
        }
        // единицы
        const uf = units[from], ut = units[to];
        if (uf && ut && uf[0] === ut[0]) {
            const v = n * uf[1] / ut[1];
            return { value: v, text: `${fmt(v)} ${to}` };
        }
        // валюты
        const cf = currency(from), ct = currency(to);
        if (cf && ct) {
            ensureRates();
            if (rates[cf] === undefined || rates[ct] === undefined)
                return { value: NaN, text: I18n.tr("Загружаю курсы…") };
            const v = n / rates[cf] * rates[ct];
            return { value: v, text: `${fmt(v)} ${ct}`, note: I18n.tr("курс на {0}", I18n.locale.toString(new Date(ratesTime), "d MMMM")) };
        }
        return null;
    }

    // ---- курсы ----
    readonly property string ratesFile: Quickshell.env("HOME") + "/.cache/quickshell/rates.json"
    function ensureRates(): void {
        if (Date.now() - ratesTime < 12 * 3600 * 1000 || ratesProc.running) return;
        ratesProc.running = true;
    }
    FileView {
        id: ratesView
        path: root.ratesFile
        printErrors: false
        onLoaded: root.load(text())
    }
    function load(t: string): void {
        try {
            const j = JSON.parse(t);
            if (j.rates) { rates = j.rates; ratesTime = (j.time_last_update_unix ?? 0) * 1000 || Date.now(); }
        } catch (e) {}
    }
    Process {
        id: ratesProc
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")"; curl -sf -m 10 https://open.er-api.com/v6/latest/USD -o "$1.tmp" && mv "$1.tmp" "$1" && cat "$1"', "_", root.ratesFile]
        stdout: StdioCollector { onStreamFinished: if (text) root.load(text) }
    }
}
