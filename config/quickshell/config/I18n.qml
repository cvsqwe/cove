pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Язык интерфейса. Исходные строки в коде — русские; для английского берётся перевод из
// assets/i18n/en.json (ключ — русская строка). tr("Привет, {0}", name) — с подстановками {0}, {1}…
// Строки без перевода показываются как есть. Язык меняется на лету: tr() читает lang, и привязки
// с ним пересчитываются.
Singleton {
    id: root

    // "ru" | "en" | "auto" (по $LANG)
    readonly property string setting: Settings.general.language ?? "ru"
    readonly property string lang: setting === "auto"
        ? ((Quickshell.env("LANG") ?? "").startsWith("ru") ? "ru" : "en")
        : setting
    readonly property bool en: lang === "en"
    readonly property var locale: Qt.locale(en ? "en_US" : "ru_RU")

    property var dict: ({})

    function tr(s: string, ...args): string {
        let r = en ? (dict[s] ?? s) : s;
        for (let i = 0; i < args.length; i++) r = r.split("{" + i + "}").join(args[i]);
        return r;
    }

    // русские формы множественного числа: plural(n, "файл", "файла", "файлов"); английские — из словаря
    function plural(n: int, one: string, few: string, many: string): string {
        if (en) return Math.abs(n) === 1 ? tr(one) : tr(many);
        const a = Math.abs(n) % 100, b = a % 10;
        if (a > 10 && a < 20) return many;
        if (b === 1) return one;
        if (b >= 2 && b <= 4) return few;
        return many;
    }

    // язык для остальной экосистемы (fastfetch, Cove Code): ~/.cache/cove/lang
    onLangChanged: langFile.setText(lang + "\n")
    Component.onCompleted: langFile.setText(lang + "\n")
    FileView { id: langFile; path: Quickshell.env("HOME") + "/.cache/cove/lang"; printErrors: false }

    FileView {
        path: Quickshell.shellPath("assets/i18n/en.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.dict = JSON.parse(text()); }
            catch (e) { console.warn("i18n: en.json не читается:", e); }
        }
    }
}
