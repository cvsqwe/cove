import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Оформление")
    subtitle: I18n.tr("Цвета, шрифты, формы и анимации. Всё применяется сразу.")

    readonly property var a: Settings.appearance
    property var iconThemes: []
    property var cursorThemes: []
    property string cursorFilter: "all"   // all | classic | anime
    readonly property string previewDir: Quickshell.env("HOME") + "/.cache/quickshell/cursors/"
    function isAnime(n: string): bool { return /^(Anime-|Sekai-|BlueArchive)/.test(n); }
    // «Sekai-HoshinoIchika» → «Hoshino Ichika», «catppuccin-mocha-pink-cursors» → «Catppuccin Mocha Pink»
    function prettyCursor(n: string): string {
        const s = n.replace(/^(Anime|Sekai)-/, "").replace(/-?(cursors|Xcursor|Linux)$/i, "").replace(/[-_]+/g, " ")
            .replace(/([a-z])([A-Z])/g, "$1 $2").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    // ---- палитра ----
    readonly property bool dynamicPalette: a.palette === "wallpaper" || a.palette === "custom"
    property string lastPreset: "catppuccin"
    readonly property var schemes: [
        { value: "tonal", label: I18n.tr("Тональная"), desc: I18n.tr("Поверхности слегка окрашены в цвет акцента") },
        { value: "vibrant", label: I18n.tr("Яркая"), desc: I18n.tr("Насыщенные поверхности и сочный акцент") },
        { value: "muted", label: I18n.tr("Приглушённая"), desc: I18n.tr("Спокойные, пыльные тона") },
        { value: "neutral", label: I18n.tr("Нейтральная"), desc: I18n.tr("Серые поверхности, цвет — только в акценте") },
        { value: "contrast", label: I18n.tr("Контрастная"), desc: I18n.tr("Глубже фон, ярче текст — легче читать") },
        { value: "expressive", label: I18n.tr("Выразительная"), desc: I18n.tr("Второй акцент на треть круга от первого") }
    ]
    // приблизительное превью схемы: [фон, поверхность, акцент, второй акцент, текст]
    function schemePreview(k: string): var {
        const f = ({ tonal: [1, 1, 0], vibrant: [1.9, 1.15, 0], muted: [0.5, 0.6, 0], neutral: [0, 1, 0], contrast: [0.8, 1.05, 0], expressive: [1.2, 1.1, 0.33] })[k];
        const h = Theme.hue, L = a.light, s = Math.min(0.95, Theme.sat / (Theme.sp.acc || 1) * f[1]);
        const t = (sat, l) => {
            let ll = l;
            if (k === "contrast") ll = l < 0.4 ? l * 0.6 : l + (1 - l) * 0.55;
            return Qt.hsla(h, Math.min(1, sat * a.tint * f[0]), L ? 1 - ll * 0.92 : ll, 1);
        };
        const al = L ? 0.46 : 0.78;
        return [t(0.20, 0.105), t(0.15, 0.25), Qt.hsla(h, s, al, 1), Qt.hsla(f[2] > 0 ? (h + f[2]) % 1 : (Theme.hue2), s, al - 0.02, 1), t(0.35, 0.9)];
    }
    readonly property var overrideKeys: [
        { key: "accent", label: I18n.tr("Акцент") }, { key: "accent2", label: I18n.tr("Второй акцент") },
        { key: "base", label: I18n.tr("Фон") }, { key: "mantle", label: I18n.tr("Фон темнее") },
        { key: "crust", label: I18n.tr("Самый тёмный") }, { key: "surface0", label: I18n.tr("Поверхность") },
        { key: "surface1", label: I18n.tr("Поверхность 2") }, { key: "text", label: I18n.tr("Текст") },
        { key: "subtext0", label: I18n.tr("Второстепенный текст") }, { key: "red", label: I18n.tr("Красный") },
        { key: "yellow", label: I18n.tr("Жёлтый") }, { key: "green", label: I18n.tr("Зелёный") }
    ]
    function setOverride(k: string, v: string): void {
        const o = Object.assign({}, a.overrides ?? {});
        if (v) o[k] = v; else delete o[k];
        a.overrides = o;
    }

    readonly property var fontOptions: Qt.fontFamilies().filter(f => (!/Noto (Sans|Serif) (?!Mono)[A-Z]/.test(f) || f === "Noto Sans") && !/^Material Symbols/.test(f))
        .map(f => ({ value: f, label: f, font: f }))

    readonly property var shownCursors: cursorThemes.filter(n => cursorFilter === "all" || (cursorFilter === "anime") === isAnime(n))

    Process {
        running: true
        // превью курсоров (assets/cursor-previews.py) создаются только для новых тем
        command: ["sh", "-c", "python3 " + Quickshell.shellPath("assets/cursor-previews.py") + " >/dev/null 2>&1; for d in /usr/share/icons/* ~/.local/share/icons/*; do [ -d \"$d\" ] || continue; n=$(basename \"$d\"); [ -d \"$d/cursors\" ] && echo \"c:$n\"; [ -f \"$d/index.theme\" ] && [ ! -d \"$d/cursors\" ] && echo \"i:$n\"; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").filter(Boolean);
                page.iconThemes = l.filter(x => x.startsWith("i:")).map(x => x.slice(2));
                page.cursorThemes = l.filter(x => x.startsWith("c:")).map(x => x.slice(2));
            }
        }
    }

    // ---- живое превью ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 190
        radius: Theme.radius + 4
        color: Theme.crust
        clip: true

        Image {
            anchors.fill: parent
            source: "file://" + Store.still
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(800, 300)
            opacity: 0.55
        }

        // мини-панель с островом
        Rectangle {
            id: miniBar
            width: parent.width
            height: 30
            color: Theme.panel
            Row {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                MIcon { icon: Settings.bar.launcherIcon; color: Theme.accent; size: 14 }
                Repeater { model: 5; Rectangle { width: index === 1 ? 18 : 7; height: 7; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: index === 1 ? Theme.accent : Theme.surface2 } }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: 150
                height: 22
                radius: 11
                color: Theme.mantle
                StyledText { anchors.centerIn: parent; text: I18n.tr("12:34 • чт, 15 окт"); font.pixelSize: 10; color: Theme.text }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                StyledText { text: "8°"; color: Theme.yellow; font.pixelSize: 11 }
                StyledText { text: "35%"; color: Theme.accent; font.pixelSize: 11 }
                MIcon { icon: "󰂚"; color: Theme.subtext0; size: 11 }
            }
        }
        InvertedCorner { y: 30; corner: "topLeft"; radius: Theme.frameRadius * 0.6; color: Theme.panel }
        InvertedCorner { y: 30; anchors.right: parent.right; corner: "topRight"; radius: Theme.frameRadius * 0.6; color: Theme.panel }

        // окна
        Rectangle {
            x: 30; y: 48; width: parent.width * 0.42; height: 120
            radius: Settings.windows.rounding * 0.6
            color: Theme.alpha(Theme.base, 0.95)
            border.width: Math.max(1, Settings.windows.borderSize)
            border.color: Theme.accent
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                StyledText { text: "~ $ fastfetch"; color: Theme.accent; font.pixelSize: 11 }
                Row { spacing: 4; Repeater { model: [Theme.red, Theme.peach, Theme.yellow, Theme.green, Theme.teal, Theme.accent2, Theme.accent]; Rectangle { width: 16; height: 16; radius: 4; color: modelData } } }
                StyledText { text: I18n.tr("Привет, ") + Settings.displayName; color: Theme.text; font.pixelSize: 11 }
            }
        }
        Rectangle {
            x: parent.width * 0.42 + 40; y: 48; width: parent.width * 0.58 - 70; height: 120
            radius: Settings.windows.rounding * 0.6
            color: Theme.alpha(Theme.base, 0.95)
            border.width: Math.max(1, Settings.windows.borderSize)
            border.color: Theme.surface0
            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                Repeater {
                    model: [[I18n.tr("Акцент"), Theme.accent], [I18n.tr("Второй"), Theme.accent2], [I18n.tr("Фон"), Theme.base], [I18n.tr("Поверхность"), Theme.surface1], [I18n.tr("Текст"), Theme.text]]
                    Row {
                        spacing: 8
                        Rectangle { width: 14; height: 14; radius: 7; color: modelData[1]; border.width: 1; border.color: Theme.surface2 }
                        StyledText { text: modelData[0] + "  " + String(modelData[1]).toUpperCase(); font.pixelSize: 10; color: Theme.subtext1 }
                    }
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Палитра")
        icon: "󰏘"

        SRow {
            icon: "󰔎"
            title: I18n.tr("Тема")
            SSegment {
                options: [{ value: false, label: I18n.tr("Тёмная"), icon: "󰖔" }, { value: true, label: I18n.tr("Светлая"), icon: "󰖙" }]
                current: page.a.light
                onPicked: v => page.a.light = v
            }
        }
        SRow {
            icon: "brightness_auto"
            title: I18n.tr("Менять сама")
            desc: page.a.themeMode === "sun" ? I18n.tr("Светлая от восхода ({0}) до заката ({1}); ручное переключение держится до следующей смены", Sun.sunriseText, Sun.sunsetText)
                : page.a.themeMode === "schedule" ? I18n.tr("Светлая в заданные часы, остальное время — тёмная")
                : I18n.tr("Тема меняется только вручную")
            SSegment {
                options: [{ value: "manual", label: I18n.tr("Нет") }, { value: "sun", label: I18n.tr("По солнцу") }, { value: "schedule", label: I18n.tr("По часам") }]
                current: page.a.themeMode
                onPicked: v => page.a.themeMode = v
            }
        }
        SRow {
            visible: page.a.themeMode === "schedule"
            icon: "schedule"
            title: I18n.tr("Светлая с и до")
            SField { implicitWidth: 80; text: page.a.lightFrom; inputMask: "99:99"; onEdited: t => page.a.lightFrom = t }
            StyledText { text: "—"; anchors.verticalCenter: parent.verticalCenter }
            SField { implicitWidth: 80; text: page.a.lightTo; inputMask: "99:99"; onEdited: t => page.a.lightTo = t }
        }
        SRow {
            icon: "󰸉"
            title: I18n.tr("Источник цветов")
            desc: page.a.palette === "wallpaper" ? I18n.tr("Акцент и оттенки поверхностей берутся из обоев")
                : page.a.palette === "custom" ? I18n.tr("Вся палитра строится из одного вашего цвета")
                : I18n.tr("Готовая палитра: ") + (Palettes.sets[page.a.palette]?.name ?? "")
            SSegment {
                options: [{ value: "wallpaper", label: I18n.tr("Обои") }, { value: "custom", label: I18n.tr("Свой цвет") }, { value: "preset", label: I18n.tr("Готовая") }]
                current: page.dynamicPalette ? page.a.palette : "preset"
                onPicked: v => {
                    if (!page.dynamicPalette) page.lastPreset = page.a.palette;
                    page.a.palette = v === "preset" ? page.lastPreset : v;
                }
            }
        }
        SRow {
            visible: page.a.palette === "custom"
            icon: "󰈊"
            title: I18n.tr("Акцентный цвет")
            SColor {
                value: page.a.customAccent
                onPicked: c => page.a.customAccent = String(c)
            }
        }

        // готовые палитры — карточки с образцами цветов
        Flow {
            visible: !page.dynamicPalette
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 10
            spacing: 8
            Repeater {
                model: Palettes.order
                Rectangle {
                    id: pc
                    required property string modelData
                    readonly property var set: Palettes.sets[modelData][page.a.light ? "light" : "dark"]
                    readonly property bool active: page.a.palette === modelData
                    width: 168
                    height: 74
                    radius: Theme.radius
                    color: set.base
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : pcm.containsMouse ? Theme.surface2 : Theme.surface0
                    scale: pcm.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                    Column {
                        x: 12
                        y: 10
                        spacing: 9
                        Row {
                            spacing: 6
                            StyledText { text: Palettes.sets[pc.modelData].name; color: pc.set.text; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
                            MIcon { visible: pc.active; icon: "check"; color: pc.set.accent; size: Theme.fontSizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            spacing: 4
                            Rectangle { width: 30; height: 18; radius: 9; color: pc.set.accent }
                            Repeater {
                                model: ["accent2", "red", "peach", "yellow", "green", "teal"]
                                Rectangle { required property string modelData; width: 14; height: 18; radius: 7; color: pc.set[modelData] }
                            }
                            Rectangle { width: 14; height: 18; radius: 7; color: pc.set.surface1 }
                        }
                    }
                    MouseArea { id: pcm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.a.palette = pc.modelData }
                }
            }
        }

        // схема — как из одного цвета получается вся палитра
        SRow {
            visible: page.dynamicPalette
            icon: "tune"
            title: I18n.tr("Схема")
            desc: page.schemes.find(x => x.value === (page.a.scheme ?? "tonal"))?.desc ?? ""
            separator: false
        }
        Flow {
            visible: page.dynamicPalette
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 10
            spacing: 8
            Repeater {
                model: page.schemes
                Rectangle {
                    id: sc
                    required property var modelData
                    readonly property var pv: page.schemePreview(modelData.value)
                    readonly property bool active: (page.a.scheme ?? "tonal") === modelData.value
                    width: 132
                    height: 70
                    radius: Theme.radius
                    color: pv[0]
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : scm.containsMouse ? Theme.surface2 : Theme.surface0
                    Column {
                        x: 10
                        y: 9
                        spacing: 8
                        StyledText { text: sc.modelData.label; color: sc.pv[4]; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
                        Row {
                            spacing: 4
                            Rectangle { width: 26; height: 16; radius: 8; color: sc.pv[2] }
                            Rectangle { width: 16; height: 16; radius: 8; color: sc.pv[3] }
                            Rectangle { width: 16; height: 16; radius: 8; color: sc.pv[1] }
                        }
                    }
                    MouseArea { id: scm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.a.scheme = sc.modelData.value }
                }
            }
        }
        SRow {
            visible: page.dynamicPalette
            icon: "palette"
            title: I18n.tr("Согласовать цвета")
            desc: I18n.tr("Красный, зелёный и другие смысловые цвета чуть сдвигаются к оттенку акцента")
            SSwitch { checked: !!page.a.harmonize; onToggled: v => page.a.harmonize = v }
        }

        // свои цвета поверх любой палитры
        SRow {
            icon: "format_color_fill"
            title: I18n.tr("Свои цвета")
            desc: Object.keys(page.a.overrides ?? {}).length > 0 ? I18n.tr("Заменено цветов: ") + Object.keys(page.a.overrides).length
                : I18n.tr("Любой цвет палитры можно заменить своим — поверх обоев или готовой палитры")
            separator: false
            SButton {
                visible: Object.keys(page.a.overrides ?? {}).length > 0
                icon: "restart_alt"
                text: I18n.tr("Сбросить")
                onClicked: page.a.overrides = ({})
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 10
            spacing: 8
            Repeater {
                model: page.overrideKeys
                Rectangle {
                    id: oc
                    required property var modelData
                    readonly property bool set: !!(page.a.overrides ?? {})[modelData.key]
                    width: 168
                    height: 42
                    radius: Theme.radiusSmall + 2
                    color: Theme.mantle
                    border.width: 1
                    border.color: set ? Theme.accent : Theme.surface0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: 8
                        SColor {
                            compact: true
                            value: Theme[oc.modelData.key]
                            onPicked: c => page.setOverride(oc.modelData.key, String(c))
                        }
                        StyledText { Layout.fillWidth: true; text: oc.modelData.label; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight; font.bold: oc.set }
                        IconButton {
                            visible: oc.set
                            size: 22
                            iconSize: 12
                            icon: "close"
                            color: "transparent"
                            onClicked: page.setOverride(oc.modelData.key, "")
                        }
                    }
                }
            }
        }
        SRow {
            icon: "󰎆"
            title: I18n.tr("Цвет от обложки")
            desc: I18n.tr("Пока играет музыка, вся система перекрашивается в цвета обложки трека")
            SSwitch { checked: page.a.coverAccent; onToggled: v => page.a.coverAccent = v }
        }
        SRow {
            icon: "󰌁"
            title: I18n.tr("Насыщенность")
            SSlider { from: 0.4; to: 1.6; step: 0.05; value: page.a.saturation; percent: true; onMoved: v => page.a.saturation = v }
        }
        SRow {
            icon: "󰝤"
            title: I18n.tr("Окраска поверхностей")
            desc: I18n.tr("Насколько фон панелей окрашен в цвет акцента")
            SSlider { from: 0; to: 2; step: 0.05; value: page.a.tint; percent: true; onMoved: v => page.a.tint = v }
        }
    }

    SCard {
        title: I18n.tr("Материал")
        icon: "layers"

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            text: I18n.tr("Из чего сделаны панель, остров, Центр управления, лаунчер и меню.")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 6
            Layout.bottomMargin: 10
            spacing: 8
            Repeater {
                model: [
                    { value: "solid", label: I18n.tr("Сплошной"), desc: I18n.tr("Плотный цвет темы") },
                    { value: "glass", label: I18n.tr("Стекло"), desc: I18n.tr("Прозрачно, обои размыты") },
                    { value: "frosted", label: I18n.tr("Матовое"), desc: I18n.tr("Светлее, с бликом") },
                    { value: "acrylic", label: I18n.tr("Акрил"), desc: I18n.tr("Стекло с зерном") }
                ]
                Item {
                    id: mc
                    required property var modelData
                    readonly property bool active: (page.a.material ?? "solid") === modelData.value
                    readonly property string m: modelData.value
                    width: 196
                    height: 112
                    // превью: обои, на них — кусок панели из этого материала
                    Rectangle {
                        id: mcBg
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Theme.crust
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: Store.still ? "file://" + Store.still : ""
                            sourceSize: Qt.size(400, 230)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Item {
                            id: panelSrc
                            x: 14; y: 14
                            width: parent.width - 28
                            height: 52
                            visible: false
                            Image {
                                x: -panelSrc.x; y: -panelSrc.y
                                width: mcBg.width; height: mcBg.height
                                source: Store.still ? "file://" + Store.still : ""
                                sourceSize: Qt.size(400, 230)
                                fillMode: Image.PreserveAspectCrop
                            }
                        }
                        // размытая подложка — так, как её покажет Hyprland
                        MultiEffect {
                            visible: mc.m !== "solid"
                            source: panelSrc
                            anchors.fill: panelSrc
                            blurEnabled: true
                            blur: 1.0
                            blurMax: 32
                        }
                        Rectangle {
                            x: panelSrc.x; y: panelSrc.y
                            width: panelSrc.width; height: panelSrc.height
                            radius: Theme.radiusSmall + 4
                            readonly property real al: page.a.panelOpacity * ({ solid: 1, glass: 0.6, frosted: 0.86, acrylic: 0.72 })[mc.m]
                            color: mc.m === "frosted" ? Theme.alpha(Qt.tint(Theme.base, Theme.alpha(Theme.light ? "#ffffff" : Theme.text, Theme.light ? 0.35 : 0.06)), al)
                                : Theme.alpha(Theme.base, al)
                            border.width: 1
                            border.color: mc.m === "solid" ? Theme.surface0 : Theme.alpha(Theme.light ? "#ffffff" : Theme.text, Theme.light ? 0.55 : 0.13)
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: mc.m === "frosted" || mc.m === "acrylic"
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Theme.light ? 0.18 : 0.08) }
                                    GradientStop { position: 0.5; color: "transparent" }
                                }
                            }
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                visible: mc.m === "acrylic"
                                source: visible ? Quickshell.shellPath("assets/noise.png") : ""
                                fillMode: Image.Tile
                                opacity: 0.08
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Rectangle { width: 20; height: 8; radius: 4; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                Repeater { model: 3; Rectangle { width: 8; height: 8; radius: 4; color: Theme.overlay1; anchors.verticalCenter: parent.verticalCenter } }
                            }
                        }
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 38
                            color: Theme.alpha(Theme.crust, 0.82)
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                StyledText { text: mc.modelData.label; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: mc.active ? Theme.accent : Theme.text }
                                StyledText { text: mc.modelData.desc; font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.overlay1 }
                            }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius
                        color: "transparent"
                        border.width: mc.active ? 2 : 1
                        border.color: mc.active ? Theme.accent : mcm.containsMouse ? Theme.surface2 : Theme.surface0
                    }
                    MouseArea { id: mcm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.a.material = mc.m }
                }
            }
        }
        SRow {
            icon: "󰂵"
            title: I18n.tr("Непрозрачность")
            desc: (page.a.material ?? "solid") === "solid" ? I18n.tr("Насколько плотный фон панелей") : I18n.tr("Меньше — больше видно размытые обои")
            SSlider { from: 0.5; to: 1; step: 0.02; value: page.a.panelOpacity; percent: true; onMoved: v => page.a.panelOpacity = v }
        }
        SRow {
            icon: "border_style"
            title: I18n.tr("Обводка")
            desc: I18n.tr("Кромка вокруг панелей и карточек")
            SSegment {
                options: [{ value: 0, label: I18n.tr("Нет") }, { value: 1, label: I18n.tr("Тонкая") }, { value: 2, label: I18n.tr("Толстая") }]
                current: page.a.borderWidth ?? 1
                onPicked: v => page.a.borderWidth = v
            }
        }
        SRow {
            icon: "shadow"
            title: I18n.tr("Тени")
            separator: false
            SSlider { from: 0; to: 1.6; step: 0.05; value: page.a.shadow ?? 1; percent: true; onMoved: v => page.a.shadow = v }
        }
    }

    SCard {
        title: I18n.tr("Компоненты")
        icon: "widgets"

        SRow {
            icon: "toggle_on"
            title: I18n.tr("Плитки Центра управления")
            desc: (page.a.tileStyle ?? "tiles") === "round" ? I18n.tr("Подстраница (Wi-Fi, Bluetooth…) — правой кнопкой") : ""
            SSegment {
                options: [{ value: "tiles", label: I18n.tr("Плитки") }, { value: "round", label: I18n.tr("Кнопки") }, { value: "list", label: I18n.tr("Список") }]
                current: page.a.tileStyle ?? "tiles"
                onPicked: v => page.a.tileStyle = v
            }
        }
        SRow {
            icon: "check_circle"
            title: I18n.tr("Включённая плитка")
            SSegment {
                options: [{ value: "fill", label: I18n.tr("Заливка") }, { value: "tint", label: I18n.tr("Подсветка") }, { value: "outline", label: I18n.tr("Обводка") }]
                current: page.a.tileOn ?? "fill"
                onPicked: v => page.a.tileOn = v
            }
        }
        SRow {
            icon: "volume_up"
            title: I18n.tr("Громкость и яркость")
            desc: I18n.tr("Как остров показывает изменение громкости, микрофона и яркости")
            SSegment {
                options: [{ value: "slider", label: I18n.tr("Ползунок") }, { value: "ring", label: I18n.tr("Кольцо") }, { value: "minimal", label: I18n.tr("Полоска") }]
                current: page.a.osdStyle ?? "slider"
                onPicked: v => page.a.osdStyle = v
            }
        }
        SRow {
            icon: "notifications"
            title: I18n.tr("Уведомления")
            SSegment {
                options: [{ value: "compact", label: I18n.tr("Кратко") }, { value: "normal", label: I18n.tr("Обычно") }, { value: "rich", label: I18n.tr("Подробно") }]
                current: page.a.notifStyle ?? "normal"
                onPicked: v => page.a.notifStyle = v
            }
        }
        SRow {
            icon: "lock"
            title: I18n.tr("Экран блокировки")
            separator: false
            SSegment {
                options: [{ value: "center", label: I18n.tr("Центр") }, { value: "side", label: I18n.tr("Сбоку") }, { value: "minimal", label: I18n.tr("Минимум") }, { value: "poster", label: I18n.tr("Плакат") }]
                current: page.a.lockStyle ?? "center"
                onPicked: v => page.a.lockStyle = v
            }
            SButton {
                icon: "visibility"
                text: I18n.tr("Показать")
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "lock", "preview"])
            }
        }
    }

    SCard {
        title: I18n.tr("Приложения")
        icon: "apps"

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            text: I18n.tr("Цвета Cove уходят и в сторонние приложения: меняются вместе с обоями и темой. Выключенное возвращается к своему прежнему виду.")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }
        Repeater {
            model: AppThemes.targets
            SRow {
                id: tr
                required property var modelData
                required property int index
                readonly property string res: AppThemes.results[modelData.id] ?? ""
                icon: modelData.icon
                title: I18n.tr(modelData.name)
                desc: !modelData.installed ? (modelData.package ? I18n.tr("Не установлено — нужен пакет ") + modelData.package : I18n.tr("Не установлено"))
                    : res.startsWith("error") ? I18n.tr("Ошибка: ") + res.slice(7)
                    : I18n.tr(modelData.hint)
                separator: index < AppThemes.targets.length - 1
                opacity: modelData.installed ? 1 : 0.55
                SButton {
                    visible: tr.modelData.installed && tr.modelData.action !== "" && AppThemes.enabled(tr.modelData.id)
                    text: I18n.tr(tr.modelData.action)
                    onClicked: AppThemes.action(tr.modelData.id)
                }
                SSwitch {
                    visible: tr.modelData.installed
                    checked: AppThemes.enabled(tr.modelData.id)
                    onToggled: v => AppThemes.setEnabled(tr.modelData.id, v)
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Шрифт и формы")
        icon: "󰛖"

        SRow {
            icon: "󰛖"
            title: I18n.tr("Шрифт интерфейса")
            SDropdown {
                implicitWidth: 280
                options: page.fontOptions
                current: page.a.font
                onPicked: v => page.a.font = v
            }
        }
        SRow {
            icon: "title"
            title: I18n.tr("Шрифт заголовков")
            desc: I18n.tr("Заголовки, часы и крупные числа")
            SDropdown {
                implicitWidth: 280
                options: [{ value: "", label: I18n.tr("Как у интерфейса") }].concat(page.fontOptions)
                current: page.a.fontHeading ?? ""
                onPicked: v => page.a.fontHeading = v
            }
        }
        SRow {
            icon: "󰬴"
            title: I18n.tr("Размер шрифта")
            SSlider { from: 10; to: 18; step: 1; value: page.a.fontSize; suffix: " px"; onMoved: v => page.a.fontSize = v }
        }
        SRow {
            icon: "density_medium"
            title: I18n.tr("Плотность")
            desc: I18n.tr("Высота строк настроек, плиток Центра управления и отступы в капсулах панели")
            SSegment {
                options: [{ value: "compact", label: I18n.tr("Плотно") }, { value: "normal", label: I18n.tr("Обычно") }, { value: "comfy", label: I18n.tr("Просторно") }]
                current: page.a.density ?? "normal"
                onPicked: v => page.a.density = v
            }
        }
        SRow {
            icon: "󰢡"
            title: I18n.tr("Скругление элементов")
            SSlider { from: 0; to: 28; step: 1; value: page.a.radius; suffix: " px"; onMoved: v => page.a.radius = v }
        }
        SRow {
            icon: "󰕰"
            title: I18n.tr("Высота панели")
            SSlider { from: 26; to: 52; step: 1; value: page.a.barHeight; suffix: " px"; onMoved: v => page.a.barHeight = v }
        }
        SRow {
            icon: "󰹞"
            title: I18n.tr("Рамка экрана")
            desc: I18n.tr("Вогнутые углы у панели и краёв экрана")
            SSwitch { checked: page.a.frame; onToggled: v => page.a.frame = v }
        }
        SRow {
            visible: page.a.frame
            icon: "󰆾"
            title: I18n.tr("Радиус рамки")
            separator: false
            SSlider { from: 6; to: 36; step: 1; value: page.a.frameRadius; suffix: " px"; onMoved: v => page.a.frameRadius = v }
        }
    }

    SCard {
        title: I18n.tr("Анимации")
        icon: "󰑮"

        SRow {
            icon: "󰑮"
            title: I18n.tr("Анимации")
            SSwitch { checked: page.a.animations; onToggled: v => page.a.animations = v }
        }
        SRow {
            icon: "󰓅"
            title: I18n.tr("Скорость")
            SSlider {
                from: 0.4; to: 2.5; step: 0.05; value: page.a.animSpeed
                format: v => v < 0.8 ? I18n.tr("плавно") : v > 1.4 ? I18n.tr("быстро") : v.toFixed(2) + "×"
                onMoved: v => page.a.animSpeed = v
            }
        }
        SRow {
            icon: "󰦨"
            title: I18n.tr("Упругость острова")
            desc: I18n.tr("Меньше — сильнее «пружинит» при смене состояний")
            separator: false
            SSlider {
                from: 0.12; to: 0.7; step: 0.02; value: page.a.springiness
                format: v => v < 0.25 ? I18n.tr("желе") : v < 0.4 ? I18n.tr("упруго") : I18n.tr("мягко")
                onMoved: v => page.a.springiness = v
            }
        }
    }

    SCard {
        title: I18n.tr("Иконки и курсор")
        icon: "󰀻"

        SRow {
            icon: "interests"
            title: I18n.tr("Значки шелла")
            desc: I18n.tr("Набор значков панели, острова, меню и настроек")
            SSegment {
                options: [{ value: "rounded", label: I18n.tr("Округлые") }, { value: "outlined", label: I18n.tr("Контурные") }, { value: "sharp", label: I18n.tr("Острые") }]
                current: page.a.iconStyle ?? "rounded"
                onPicked: v => page.a.iconStyle = v
            }
        }
        // превью значков в текущем стиле
        Row {
            Layout.leftMargin: 50
            Layout.bottomMargin: 6
            spacing: 14
            Repeater {
                model: ["home", "wifi", "bluetooth", "volume_up", "notifications", "settings", "favorite", "bolt", "folder", "search"]
                MIcon { required property string modelData; icon: modelData; size: 20; color: Theme.subtext1 }
            }
        }
        SRow {
            icon: "format_color_fill"
            title: I18n.tr("Залитые значки")
            desc: I18n.tr("Все значки сплошные, а не контуром")
            SSwitch { checked: !!page.a.iconFill; onToggled: v => page.a.iconFill = v }
        }
        SRow {
            icon: "line_weight"
            title: I18n.tr("Толщина значков")
            SSlider {
                from: 200; to: 700; step: 100; value: page.a.iconWeight ?? 400
                format: v => v <= 200 ? I18n.tr("тонкие") : v >= 600 ? I18n.tr("жирные") : String(v)
                onMoved: v => page.a.iconWeight = v
            }
        }
        SRow {
            icon: "󰀻"
            title: I18n.tr("Тема иконок")
            desc: I18n.tr("Применится после перезапуска шелла")
            SDropdown { options: page.iconThemes; current: page.a.iconTheme; onPicked: v => page.a.iconTheme = v }
        }
        SRow {
            icon: "󰇀"
            title: I18n.tr("Курсор")
            desc: page.prettyCursor(page.a.cursorTheme) + (page.isAnime(page.a.cursorTheme) ? I18n.tr(" · аниме") : "") + I18n.tr(" — применяется сразу")
            SSegment {
                options: [{ value: "all", label: I18n.tr("Все") }, { value: "classic", label: I18n.tr("Классика") }, { value: "anime", label: I18n.tr("Аниме") }]
                current: page.cursorFilter
                onPicked: v => page.cursorFilter = v
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            spacing: 8
            Repeater {
                model: page.shownCursors
                Rectangle {
                    id: ct
                    required property string modelData
                    readonly property bool active: page.a.cursorTheme === modelData
                    width: 196
                    height: 92
                    radius: Theme.radius
                    color: cm.containsMouse ? Theme.surface0 : Theme.mantle
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : cm.containsMouse ? Theme.surface2 : Theme.surface0
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        height: 44
                        width: parent.width - 20
                        fillMode: Image.PreserveAspectFit
                        source: "file://" + page.previewDir + ct.modelData + ".png"
                        sourceSize.height: 48
                        asynchronous: true
                        smooth: true
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 62
                        spacing: 4
                        MIcon {
                            visible: ct.active
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "check"
                            color: Theme.accent
                            size: Theme.fontSizeSmall
                        }
                        StyledText {
                            width: Math.min(implicitWidth, ct.width - 16 - (ct.active ? Theme.fontSizeSmall + 4 : 0))
                            text: page.prettyCursor(ct.modelData)
                            color: ct.active ? Theme.accent : Theme.text
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: ct.active
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.a.cursorTheme = ct.modelData }
                }
            }
        }
        SRow {
            icon: "󰆿"
            title: I18n.tr("Размер курсора")
            separator: false
            SSlider { from: 16; to: 48; step: 2; value: page.a.cursorSize; suffix: " px"; onMoved: v => page.a.cursorSize = v }
        }
    }
}
