pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Цвета и размеры — всё из Settings.appearance.
// Палитра: из обоев (ColorQuantizer), Catppuccin (Mocha/Latte) или свой акцент.
// coverAccent — пока играет музыка, система перекрашивается в цвет обложки.
Singleton {
    id: root

    readonly property var a: Settings.appearance
    readonly property bool light: a.light

    ColorQuantizer {
        id: quant
        source: Store.wallpaper !== "" ? "file://" + Store.wallpaper : ""
        depth: 3
        rescaleSize: 96
    }

    // обложка текущего трека (свой экземпляр, чтобы не зависеть от services)
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null
    ColorQuantizer {
        id: coverQuant
        source: root.a.coverAccent && root.player ? (root.player.trackArtUrl ?? "") : ""
        depth: 2
        rescaleSize: 32
    }

    function score(c: color): real {
        return c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.6);
    }
    function ranked(list): var { return [...list].filter(c => c.hslHue >= 0).sort((x, y) => score(y) - score(x)); }

    readonly property var wallRanked: ranked(quant.colors)
    readonly property var coverRanked: ranked(coverQuant.colors)
    readonly property bool useCover: a.coverAccent && coverRanked.length > 0
    readonly property color custom: a.customAccent

    readonly property string mode: useCover ? "cover"
        : a.palette === "wallpaper" && wallRanked.length > 0 ? "wallpaper"
        : a.palette === "custom" ? "custom"
        : "catppuccin"
    readonly property bool dynamic: mode !== "catppuccin"

    readonly property var src: mode === "cover" ? coverRanked : wallRanked
    readonly property real hue: mode === "custom" ? Math.max(0, custom.hslHue) : (src[0]?.hslHue ?? 0.75)
    readonly property real hue2: {
        if (mode === "custom") return (hue + 0.09) % 1;
        for (const c of src.slice(1)) {
            const d = Math.min(Math.abs(c.hslHue - hue), 1 - Math.abs(c.hslHue - hue));
            if (d > 0.06) return c.hslHue;
        }
        return (hue + 0.1) % 1;
    }
    readonly property real sat: {
        const base = mode === "custom" ? custom.hslSaturation : (src[0]?.hslSaturation ?? 0.7);
        return Math.max(0.15, Math.min(0.95, Math.max(0.55, Math.min(0.85, base)) * a.saturation));
    }

    // l — «тёмная» яркость; в светлой теме зеркалим
    function tone(s: real, l: real): color {
        const ll = light ? 1 - l * 0.92 : l;
        return Qt.hsla(hue, Math.min(1, s * a.tint), ll, 1);
    }
    function pick(dark: string, latte: string): color { return light ? latte : dark; }

    // поверхности
    readonly property color crust: dynamic ? tone(0.25, 0.06) : pick("#11111b", "#dce0e8")
    readonly property color mantle: dynamic ? tone(0.22, 0.08) : pick("#181825", "#e6e9ef")
    readonly property color base: dynamic ? tone(0.20, 0.105) : pick("#1e1e2e", "#eff1f5")
    readonly property color surface0: dynamic ? tone(0.17, 0.18) : pick("#313244", "#ccd0da")
    readonly property color surface1: dynamic ? tone(0.15, 0.25) : pick("#45475a", "#bcc0cc")
    readonly property color surface2: dynamic ? tone(0.13, 0.32) : pick("#585b70", "#acb0be")
    readonly property color overlay0: dynamic ? tone(0.12, 0.44) : pick("#6c7086", "#9ca0b0")
    readonly property color overlay1: dynamic ? tone(0.12, 0.52) : pick("#7f849c", "#8c8fa1")
    readonly property color subtext0: dynamic ? tone(0.20, 0.72) : pick("#a6adc8", "#6c6f85")
    readonly property color subtext1: dynamic ? tone(0.25, 0.80) : pick("#bac2de", "#5c5f77")
    readonly property color text: dynamic ? tone(0.35, 0.90) : pick("#cdd6f4", "#4c4f69")

    // акценты
    readonly property real accentL: light ? 0.46 : 0.78
    readonly property color accent: dynamic ? Qt.hsla(hue, sat, accentL, 1) : pick("#cba6f7", "#8839ef")
    readonly property color accent2: dynamic ? Qt.hsla(hue2, sat, accentL - 0.02, 1) : pick("#89b4fa", "#1e66f5")
    readonly property color lavender: dynamic ? Qt.hsla(hue, sat * 0.6, light ? 0.5 : 0.84, 1) : pick("#b4befe", "#7287fd")
    readonly property color blue: accent2

    // смысловые цвета
    readonly property color sapphire: pick("#74c7ec", "#209fb5")
    readonly property color teal: pick("#94e2d5", "#179299")
    readonly property color green: pick("#a6e3a1", "#40a02b")
    readonly property color yellow: pick("#f9e2af", "#df8e1d")
    readonly property color peach: pick("#fab387", "#fe640b")
    readonly property color red: pick("#f38ba8", "#d20f39")
    readonly property color pink: pick("#f5c2e7", "#ea76cb")
    readonly property color mauve: accent

    readonly property color panel: alpha(base, a.panelOpacity)
    readonly property color island: crust
    readonly property color onAccent: light ? "#ffffff" : crust

    function alpha(c: color, v: real): color { return Qt.rgba(c.r, c.g, c.b, v); }

    // шрифт
    readonly property string font: a.font
    readonly property int fontSize: a.fontSize
    readonly property int fontSizeSmall: Math.round(a.fontSize * 0.85)
    readonly property int fontSizeLarge: Math.round(a.fontSize * 1.23)
    readonly property int iconSize: Math.round(a.fontSize * 1.23)

    // геометрия
    readonly property int gap: Settings.windows.gapsOut
    readonly property int barHeight: a.barHeight
    readonly property int radius: a.radius
    readonly property int radiusSmall: Math.max(2, Math.round(a.radius * 0.57))
    // плавающая панель: отступ от краёв = внешний зазор окон; рамки экрана в этом стиле нет
    readonly property bool barFloating: Settings.bar.style === "floating"
    readonly property int barMargin: barFloating ? Math.max(6, gap) : 0
    readonly property int barTop: barMargin                     // верх тела панели
    readonly property int barBottom: barTop + barHeight         // отсюда выпадают остров и ящики
    readonly property int barRadius: Settings.bar.shape !== "soft" ? Math.min(radius + 4, Math.floor(barHeight / 2)) : radius
    readonly property int frameRadius: a.frame && Settings.bar.style === "docked" ? a.frameRadius : 0
    // «Капли»: полосы нет, группы модулей свисают с верхнего края, как остров
    readonly property bool barDrops: Settings.bar.style === "drops"
    readonly property int dropRadius: 10                        // вогнутые наплывы у края экрана
    readonly property int dropHeight: barHeight - 4
    // «Чёлка»: остров — чёрный вырез у края экрана, остальное — два стеклянных крыла по бокам
    readonly property bool barNotch: Settings.bar.style === "notch"
    readonly property bool islandHanging: barDrops || barNotch    // остров свисает с края даже свёрнутым
    // чёлка — самый глубокий тон палитры (а не чистый чёрный: тот выбивался), крылья — он же, стеклом
    readonly property color islandColor: barNotch ? crust : panel
    readonly property color wing: alpha(crust, 0.78)
    readonly property int notchRadius: 13           // наплывы чёлки у края экрана
    // ящики отдельными карточками (а не «из панели»), с отступом от края
    readonly property bool barCards: barFloating || barDrops || barNotch
    readonly property int cardMargin: barCards ? Math.max(6, gap) : 0

    // ---- стиль панели: параметры из Settings.bar, превращённые в токены ----
    // Всё, что рисует панель и остров, берёт цвета и формы только отсюда.
    readonly property var bs: Settings.bar
    readonly property bool barRound: bs.shape !== "soft"
    readonly property bool barless: barFloating && bs.bodyOpacity < 0.02   // без полосы — одни капсулы
    readonly property color barBody: barDrops || barNotch ? "transparent" : alpha(base, a.panelOpacity * bs.bodyOpacity)
    readonly property int capsuleHeight: barHeight - 8
    readonly property int capsuleRadius: barRound ? capsuleHeight / 2 : radiusSmall
    readonly property color capsule: bs.capsuleFill === "light" ? surface0 : bs.capsuleFill === "outline" ? "transparent" : mantle
    readonly property color capsuleBorder: bs.capsuleFill === "light" ? surface1 : bs.capsuleFill === "outline" ? surface2 : surface0
    readonly property color capsuleHover: bs.capsuleFill === "light" ? surface1 : surface0
    readonly property color barIcon: subtext1
    readonly property bool barHoverLabels: bs.labels === "hover"   // только значки, подпись — при наведении
    // цвет иконки модуля: моно — нейтральный, акцент — акцент, цветные — свой цвет модуля
    function barTint(c: color): color { return bs.iconColors === "colorful" ? c : bs.iconColors === "accent" ? accent : barIcon; }

    // анимации
    function dur(ms: int): int { return a.animations ? Math.round(ms / Math.max(0.1, a.animSpeed)) : 1; }
    readonly property int animFast: dur(150)
    readonly property int anim: dur(280)
    readonly property int animSlow: dur(450)
    readonly property real springDamping: a.springiness
    readonly property real springSpring: a.animations ? 3.2 * a.animSpeed : 50
}
