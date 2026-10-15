pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Вид Firefox в стиле шелла: стили (assets/firefox-theme.sh из шаблонов assets/firefox/) и своя стартовая
// страница (~/.local/share/cove/startpage.html). Форма применяется после перезапуска Firefox,
// цвета — на лету через Pywalfox (services/Recolor.qml).
Singleton {
    id: root

    readonly property var f: Settings.firefox
    readonly property string startpagePath: Quickshell.env("HOME") + "/.local/share/cove/startpage.html"

    function shape(): void {
        Quickshell.execDetached([Quickshell.shellPath("assets/firefox-theme.sh"), Theme.font, String(Theme.radius), String(Theme.radiusSmall),
            f.layout, f.menus ? "1" : "0", f.cleanNewtab ? "1" : "0", f.startpage ? startpagePath : ""]);
        startpage();
    }

    function hex(c: color): string { return "#" + String(c).slice(1, 7); }

    function startpage(): void {
        if (!f.startpage || !tpl.loaded) return;
        const vars = {
            CRUST: hex(Theme.crust), MANTLE: hex(Theme.mantle), BASE: hex(Theme.base), SURFACE0: hex(Theme.surface0),
            SURFACE1: hex(Theme.surface1), TEXT: hex(Theme.text), SUBTEXT: hex(Theme.subtext1), OVERLAY: hex(Theme.overlay1),
            LANG: I18n.lang, ACCENT_URL: "%23" + hex(Theme.accent).slice(1), ACCENT: hex(Theme.accent), ACCENT2: hex(Theme.accent2), RADIUS: String(Theme.radius + 4), FONT: Theme.font,
            WALLPAPER: Store.wallpaper ? "file://" + encodeURI(Store.wallpaper) : "",
            NAME_JSON: JSON.stringify(Settings.displayName),
            LINKS_JSON: JSON.stringify(f.links ?? []),
            BANGS_JSON: JSON.stringify(Settings.launcher.bangs ?? []),
            ENGINE_JSON: JSON.stringify(f.engine)
        };
        let html = tpl.text();
        for (const k in vars) html = html.split("@" + k + "@").join(vars[k]);
        out.setText(html);
    }

    // форма — при смене вида, шрифта, скруглений
    readonly property var shapeWatch: [f.layout, f.menus, f.cleanNewtab, f.startpage, Theme.font, Theme.radius]
    onShapeWatchChanged: shapeTimer.restart()
    Timer { id: shapeTimer; interval: 700; onTriggered: root.shape() }

    // стартовая страница — при смене палитры, обоев, ссылок, имени
    readonly property var pageWatch: [Theme.accent, Theme.base, Theme.text, Store.wallpaper, JSON.stringify(f.links), f.engine,
        Settings.displayName, JSON.stringify(Settings.launcher.bangs), I18n.lang]
    onPageWatchChanged: pageTimer.restart()
    Timer { id: pageTimer; interval: 900; onTriggered: root.startpage() }

    FileView { id: tpl; path: Quickshell.shellPath("assets/firefox/startpage.html"); onLoaded: root.startpage() }
    FileView { id: out; path: root.startpagePath; printErrors: false }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Quickshell.env("HOME") + "/.local/share/cove"])
}
