pragma Singleton

import QtQuick
import Quickshell

// Размеры, даты, слова с числами — по-русски
Singleton {
    function size(b: real): string {
        if (b < 0) return "—";
        if (b < 1024) return b + " Б";
        const u = ["КБ", "МБ", "ГБ", "ТБ"];
        let v = b / 1024, i = 0;
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
        return (v < 10 ? v.toFixed(1) : Math.round(v).toString()).replace(".", ",") + " " + u[i];
    }
    readonly property var months: ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
    function two(n: int): string { return n < 10 ? "0" + n : "" + n; }
    function date(ms: real): string {
        if (!ms) return "—";
        const d = new Date(ms), now = new Date();
        const t = two(d.getHours()) + ":" + two(d.getMinutes());
        const day = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (ms >= day) return "Сегодня, " + t;
        if (ms >= day - 86400000) return "Вчера, " + t;
        const s = d.getDate() + " " + months[d.getMonth()];
        return d.getFullYear() === now.getFullYear() ? s + ", " + t : s + " " + d.getFullYear();
    }
    function full(ms: real): string {
        if (!ms) return "—";
        const d = new Date(ms);
        return d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear() + ", " + two(d.getHours()) + ":" + two(d.getMinutes());
    }
    // 1 файл, 2 файла, 5 файлов
    function plural(n: int, one: string, few: string, many: string): string {
        const m10 = n % 10, m100 = n % 100;
        const w = m10 === 1 && m100 !== 11 ? one : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? few : many;
        return n + " " + w;
    }
    function items(n: int): string { return plural(n, "объект", "объекта", "объектов"); }
    function isArchive(name: string): bool { return /\.(zip|7z|rar|tar|tgz|tar\.(gz|xz|zst|bz2)|gz|xz|zst|bz2|iso|cpio|deb|rpm)$/i.test(name); }
    function isImage(name: string): bool { return /\.(jpe?g|png|webp|gif|bmp|tiff?|avif|svg|ico)$/i.test(name); }
    function isVideo(name: string): bool { return /\.(mp4|mkv|webm|mov|avi|m4v|wmv|flv|mpe?g|3gp)$/i.test(name); }
    function isAudio(name: string): bool { return /\.(mp3|flac|m4a|ogg|opus|wav|aac)$/i.test(name); }
    function isText(mime: string, name: string): bool {
        return mime.startsWith("text/") || /\.(json|ya?ml|toml|ini|conf|cfg|lua|qml|js|ts|py|rs|go|c|cpp|h|hpp|sh|fish|md|log|desktop|xml|csv)$/i.test(name);
    }
}
