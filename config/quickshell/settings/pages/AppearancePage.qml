import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

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
            source: "file://" + Store.wallpaper
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
            icon: "󰸉"
            title: I18n.tr("Источник цветов")
            desc: page.a.palette === "wallpaper" ? I18n.tr("Акцент и оттенки поверхностей берутся из обоев") : page.a.palette === "custom" ? I18n.tr("Свой акцентный цвет") : I18n.tr("Классический Catppuccin")
            SSegment {
                options: [{ value: "wallpaper", label: I18n.tr("Обои") }, { value: "custom", label: I18n.tr("Свой") }, { value: "catppuccin", label: "Catppuccin" }]
                current: page.a.palette
                onPicked: v => page.a.palette = v
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
        SRow {
            icon: "󰂵"
            title: I18n.tr("Непрозрачность панелей")
            separator: false
            SSlider { from: 0.5; to: 1; step: 0.02; value: page.a.panelOpacity; percent: true; onMoved: v => page.a.panelOpacity = v }
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
                options: Qt.fontFamilies().filter(f => !/Noto (Sans|Serif) (?!Mono)[A-Z]/.test(f) || f === "Noto Sans").map(f => ({ value: f, label: f, font: f }))
                current: page.a.font
                onPicked: v => page.a.font = v
            }
        }
        SRow {
            icon: "󰬴"
            title: I18n.tr("Размер шрифта")
            SSlider { from: 10; to: 18; step: 1; value: page.a.fontSize; suffix: " px"; onMoved: v => page.a.fontSize = v }
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
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 62
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: (ct.active ? "󰄬 " : "") + page.prettyCursor(ct.modelData)
                        color: ct.active ? Theme.accent : Theme.text
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: ct.active
                        elide: Text.ElideRight
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
