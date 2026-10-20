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
        source: Store.still !== "" ? "file://" + Store.still : ""
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

    // wallpaper / custom / cover — палитра считается из одного цвета (dynamic);
    // preset — готовая палитра из Palettes (Catppuccin, Gruvbox, Nord…)
    readonly property string mode: useCover ? "cover"
        : a.palette === "wallpaper" && wallRanked.length > 0 ? "wallpaper"
        : a.palette === "custom" ? "custom"
        : "preset"
    readonly property bool dynamic: mode !== "preset"
    readonly property var preset: (Palettes.sets[a.palette] ?? Palettes.sets.catppuccin)[light ? "light" : "dark"]
    // смысловые цвета (красный, зелёный…) у dynamic — из Catppuccin
    readonly property var basePreset: Palettes.sets.catppuccin[light ? "light" : "dark"]

    // ---- схема (только для dynamic): как из одного цвета получаются остальные ----
    //   tonal — поверхности слегка в цвет акцента (как было), vibrant — насыщенно, muted — приглушённо,
    //   neutral — серые поверхности, contrast — глубже фон и ярче текст, expressive — второй акцент на треть круга
    readonly property string scheme: a.scheme ?? "tonal"
    readonly property var sp: ({
        tonal:      { surf: 1.0, acc: 1.0,  hue2: 0,    contrast: 0 },
        vibrant:    { surf: 1.9, acc: 1.15, hue2: 0,    contrast: 0 },
        muted:      { surf: 0.5, acc: 0.6,  hue2: 0,    contrast: 0 },
        neutral:    { surf: 0.0, acc: 1.0,  hue2: 0,    contrast: 0 },
        contrast:   { surf: 0.8, acc: 1.05, hue2: 0,    contrast: 1 },
        expressive: { surf: 1.2, acc: 1.1,  hue2: 0.33, contrast: 0 }
    })[scheme] ?? ({ surf: 1, acc: 1, hue2: 0, contrast: 0 })

    readonly property var src: mode === "cover" ? coverRanked : wallRanked
    readonly property real hue: mode === "custom" ? Math.max(0, custom.hslHue) : (src[0]?.hslHue ?? 0.75)
    readonly property real hue2: {
        if (sp.hue2 > 0) return (hue + sp.hue2) % 1;
        if (mode === "custom") return (hue + 0.09) % 1;
        for (const c of src.slice(1)) {
            const d = Math.min(Math.abs(c.hslHue - hue), 1 - Math.abs(c.hslHue - hue));
            if (d > 0.06) return c.hslHue;
        }
        return (hue + 0.1) % 1;
    }
    readonly property real sat: {
        const base = mode === "custom" ? custom.hslSaturation : (src[0]?.hslSaturation ?? 0.7);
        return Math.max(0.15, Math.min(0.95, Math.max(0.55, Math.min(0.85, base)) * a.saturation * sp.acc));
    }

    // l — «тёмная» яркость; в светлой теме зеркалим. Контрастная схема раздвигает фон и текст.
    function tone(s: real, l: real): color {
        let ll = l;
        if (sp.contrast) ll = l < 0.4 ? l * 0.6 : l + (1 - l) * 0.55;
        ll = light ? 1 - ll * 0.92 : ll;
        return Qt.hsla(hue, Math.min(1, s * a.tint * sp.surf), ll, 1);
    }
    function pick(dark: string, latte: string): color { return light ? latte : dark; }

    // свои цвета поверх палитры: Settings.appearance.overrides = { accent: "#…", base: "#…" }
    readonly property var ov: a.overrides ?? ({})
    function o(key: string, c: color): color { return ov[key] ? ov[key] : c; }
    function pr(key: string): color { return preset[key]; }

    // смысловой цвет; «гармонизация» чуть поворачивает его оттенок к акценту
    function sem(key: string): color {
        const c = Qt.color(dynamic ? basePreset[key] : preset[key]);
        if (!dynamic || !a.harmonize) return c;
        let d = hue - c.hslHue;
        if (d > 0.5) d -= 1;
        if (d < -0.5) d += 1;
        const shift = Math.max(-0.045, Math.min(0.045, d * 0.35));
        return Qt.hsla((c.hslHue + shift + 1) % 1, c.hslSaturation, c.hslLightness, 1);
    }

    // поверхности
    readonly property color crust: o("crust", dynamic ? tone(0.25, 0.06) : pr("crust"))
    readonly property color mantle: o("mantle", dynamic ? tone(0.22, 0.08) : pr("mantle"))
    readonly property color base: o("base", dynamic ? tone(0.20, 0.105) : pr("base"))
    readonly property color surface0: o("surface0", dynamic ? tone(0.17, 0.18) : pr("surface0"))
    readonly property color surface1: o("surface1", dynamic ? tone(0.15, 0.25) : pr("surface1"))
    readonly property color surface2: o("surface2", dynamic ? tone(0.13, 0.32) : pr("surface2"))
    readonly property color overlay0: o("overlay0", dynamic ? tone(0.12, 0.44) : pr("overlay0"))
    readonly property color overlay1: o("overlay1", dynamic ? tone(0.12, 0.52) : pr("overlay1"))
    readonly property color subtext0: o("subtext0", dynamic ? tone(0.20, 0.72) : pr("subtext0"))
    readonly property color subtext1: o("subtext1", dynamic ? tone(0.25, 0.80) : pr("subtext1"))
    readonly property color text: o("text", dynamic ? tone(0.35, 0.90) : pr("text"))

    // контраст по WCAG: светлота в HSL у жёлтого и синего даёт очень разную видимую яркость
    function lum(c: color): real {
        const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }
    function contrast(a: color, b: color): real {
        const x = lum(a), y = lum(b);
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
    }
    // светлота акцента: в светлой теме тёплые и зелёные оттенки темнеют, пока контраст с фоном не станет 4:1
    // (иначе на жёлтых и зелёных обоях акцентный текст почти сливался с фоном — до 1.3:1)
    function accentTone(h: real, l0: real): color {
        let l = l0;
        if (light) while (l > 0.12 && contrast(Qt.hsla(h, sat, l, 1), base) < 4) l -= 0.02;
        return Qt.hsla(h, sat, l, 1);
    }

    // акценты
    readonly property real accentL: light ? 0.46 : 0.78
    readonly property color accent: o("accent", dynamic ? accentTone(hue, accentL) : pr("accent"))
    readonly property color accent2: o("accent2", dynamic ? accentTone(hue2, accentL - 0.02) : pr("accent2"))
    readonly property color lavender: dynamic ? Qt.hsla(hue, sat * 0.6, light ? 0.5 : 0.84, 1) : pr("lavender")
    readonly property color blue: accent2

    // смысловые цвета
    readonly property color sapphire: sem("sapphire")
    readonly property color teal: sem("teal")
    readonly property color green: o("green", sem("green"))
    readonly property color yellow: o("yellow", sem("yellow"))
    readonly property color peach: sem("peach")
    readonly property color red: o("red", sem("red"))
    readonly property color pink: sem("pink")
    readonly property color mauve: accent

    // ---- материал поверхностей (Settings.appearance.material) ----
    //   solid — сплошной, glass — прозрачное стекло с размытием обоев, frosted — матовое (почти непрозрачное,
    //   светлее, с бликом), acrylic — стекло с зерном и бликом. Размытие под слоями — правила в HyprConfig.
    readonly property string material: a.material ?? "solid"
    readonly property bool glassy: material !== "solid"
    readonly property real panelAlpha: a.panelOpacity * (({ solid: 1, glass: 0.6, frosted: 0.86, acrylic: 0.72 })[material] ?? 1)
    readonly property bool noise: material === "acrylic"
    readonly property bool sheen: material === "acrylic" || material === "frosted"
    readonly property color panel: material === "frosted"
        ? alpha(Qt.tint(base, alpha(light ? "#ffffff" : text, light ? 0.35 : 0.06)), panelAlpha)
        : alpha(base, panelAlpha)
    // обводка поверхностей: у стекла — светлая кромка, иначе — как раньше
    readonly property int borderWidth: a.borderWidth ?? 1
    readonly property color edge: glassy ? alpha(light ? "#ffffff" : text, light ? 0.55 : 0.13) : surface0
    // сила теней (0 — без теней); множитель к альфе RectangularShadow
    readonly property real shadow: a.shadow ?? 1
    readonly property color island: crust
    // текст на акцентной заливке: белый или тёмный — что контрастнее
    readonly property color onAccent: contrast(accent, "#ffffff") >= contrast(accent, light ? text : crust) ? "#ffffff" : (light ? text : crust)

    function alpha(c: color, v: real): color { return Qt.rgba(c.r, c.g, c.b, v); }

    // шрифт
    readonly property string font: a.font
    readonly property string fontHeading: a.fontHeading || a.font
    // плотность: множитель высоты строк настроек, плиток ЦУ и отступов капсул
    readonly property real density: ({ compact: 0.84, normal: 1, comfy: 1.16 })[a.density ?? "normal"] ?? 1
    // значки
    readonly property bool iconFill: !!a.iconFill
    readonly property int iconWeight: a.iconWeight ?? 400
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
    // плавающие стили: полоса с отступом от краёв; остров вырастает из капсулы.
    //   islands — у каждой стороны своя таблетка, полосы нет; compact — полоса по ширине содержимого;
    //   line — без фона, только светящаяся линия по низу
    readonly property bool barIslands: Settings.bar.style === "islands"
    readonly property bool barCompact: Settings.bar.style === "compact"
    readonly property bool barLine: Settings.bar.style === "line"
    readonly property bool barFloating: Settings.bar.style === "floating" || barIslands || barCompact || barLine
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
    readonly property bool barless: (barFloating && bs.bodyOpacity < 0.02) || barIslands || barLine   // без полосы — одни капсулы
    readonly property color barBody: barDrops || barNotch || barIslands || barLine ? "transparent" : alpha(panel, panelAlpha * bs.bodyOpacity)
    // таблетка стороны в «Островах»
    readonly property color barPill: alpha(panel, Math.max(0.35, panelAlpha * bs.bodyOpacity))
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
