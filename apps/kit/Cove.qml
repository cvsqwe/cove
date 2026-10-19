pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Тема приложений Cove: палитра и вид из файлов, которые пишет шелл
// (~/.cache/cove/palette.json — services/Recolor.qml, ~/.cache/cove/look.json — services/AppThemes.qml).
// Файлы отслеживаются: сменились обои — приложение перекрасилось. Без шелла — тёмная палитра по умолчанию.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/cove"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/cove"

    property var p: ({})
    property var l: ({})
    function c(k: string, d: string): color { return p[k] ?? d; }

    readonly property bool light: p.light ?? false
    readonly property color crust: c("crust", "#0d0916")
    readonly property color mantle: c("mantle", "#110d1c")
    readonly property color base: c("base", "#171224")
    readonly property color surface0: c("surface0", "#29213b")
    readonly property color surface1: c("surface1", "#392f50")
    readonly property color surface2: c("surface2", "#4a4064")
    readonly property color overlay0: c("overlay0", "#675987")
    readonly property color overlay1: c("overlay1", "#7b6c9e")
    readonly property color subtext0: c("subtext0", "#ae9fd0")
    readonly property color subtext1: c("subtext1", "#c3b6e2")
    readonly property color text: c("text", "#dfd6f5")
    readonly property color accent: c("accent", "#b292fc")
    readonly property color accent2: c("accent2", "#f088fc")
    readonly property color red: c("red", "#f38ba8")
    readonly property color peach: c("peach", "#fab387")
    readonly property color yellow: c("yellow", "#f9e2af")
    readonly property color green: c("green", "#a6e3a1")
    readonly property color teal: c("teal", "#94e2d5")
    readonly property color pink: c("pink", "#f5c2e7")
    readonly property color onAccent: crust

    readonly property string font: l.font ?? "Adwaita Sans"
    readonly property string mono: l.mono ?? "JetBrainsMono Nerd Font"
    readonly property int fontSize: l.fontSize ?? 13
    readonly property int fontSizeSmall: Math.round(fontSize * 0.85)
    readonly property int fontSizeLarge: Math.round(fontSize * 1.23)
    readonly property int radius: l.radius ?? 14
    readonly property int radiusSmall: Math.max(2, Math.round(radius * 0.57))
    readonly property string iconTheme: l.iconTheme ?? "Adwaita"
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property int anim: 160

    function alpha(c: color, v: real): color { return Qt.rgba(c.r, c.g, c.b, v); }
    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    FileView {
        path: root.cacheDir + "/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.p = JSON.parse(text()); } catch (e) {} }
    }
    FileView {
        path: root.cacheDir + "/look.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.l = JSON.parse(text()); } catch (e) {} }
    }
}
