import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Обои")
    subtitle: I18n.tr("Папка, режим смены и эффект перехода. Палитра шелла подстраивается под обои автоматически.")

    readonly property var w: Settings.wallpaper

    // полоска миниатюр для выбора
    component Chooser: ListView {
        id: ch
        property string current: ""
        signal chosen(string path)
        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 14
        Layout.bottomMargin: 12
        implicitHeight: 92
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        model: Wallpapers.files
        delegate: Rectangle {
            required property string modelData
            width: 150
            height: 86
            radius: Theme.radiusSmall
            color: Theme.surface0
            border.width: modelData === ch.current ? 3 : 0
            border.color: Theme.accent
            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: "file://" + parent.modelData
                sourceSize: Qt.size(160, 90)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ch.chosen(parent.modelData) }
        }
    }

    SCard {
        title: I18n.tr("Текущие")
        icon: "󰸉"
        Chooser { current: Store.wallpaper; onChosen: p => Wallpapers.set(p) }
        SRow {
            icon: "󰉋"
            title: I18n.tr("Папка с обоями")
            desc: Wallpapers.files.length + I18n.tr(" изображений")
            SField { implicitWidth: 260; text: page.w.dir; onEdited: t => { page.w.dir = t; Wallpapers.refresh(); } }
            SButton { icon: "󰑓"; onClicked: Wallpapers.refresh() }
        }
        SRow {
            icon: "󰔟"
            title: I18n.tr("Эффект перехода")
            separator: false
            SDropdown {
                options: [
                    { value: "grow", label: I18n.tr("Рост из центра") }, { value: "outer", label: I18n.tr("Схлопывание") },
                    { value: "wipe", label: I18n.tr("Шторка") }, { value: "wave", label: I18n.tr("Волна") },
                    { value: "fade", label: I18n.tr("Растворение") }, { value: "center", label: I18n.tr("Из центра") },
                    { value: "random", label: I18n.tr("Случайный") }
                ]
                current: page.w.transition
                onPicked: v => page.w.transition = v
            }
        }
    }

    SCard {
        title: I18n.tr("Режим")
        icon: "󰑖"
        SRow {
            icon: "󰑖"
            title: I18n.tr("Смена обоев")
            desc: ({ fixed: I18n.tr("Одни обои, пока не смените сами"), time: I18n.tr("Дневные и ночные по расписанию"),
                     workspace: I18n.tr("Свои обои на каждом воркспейсе"), slideshow: I18n.tr("Случайные из папки по таймеру") })[page.w.mode]
            separator: false
            SSegment {
                options: [{ value: "fixed", label: I18n.tr("Один") }, { value: "time", label: I18n.tr("По времени") }, { value: "workspace", label: I18n.tr("Воркспейсы") }, { value: "slideshow", label: I18n.tr("Слайд-шоу") }]
                current: page.w.mode
                onPicked: v => page.w.mode = v
            }
        }
    }

    SCard {
        visible: page.w.mode === "time"
        title: I18n.tr("День")
        icon: "󰖙"
        Chooser { current: page.w.day; onChosen: p => { page.w.day = p; Wallpapers.evaluate(); } }
        SRow {
            icon: "󰖜"
            title: I18n.tr("Начало дня")
            separator: false
            SField { implicitWidth: 80; text: page.w.dayStart; inputMask: "99:99"; onEdited: t => page.w.dayStart = t }
        }
    }
    SCard {
        visible: page.w.mode === "time"
        title: I18n.tr("Ночь")
        icon: "󰖔"
        Chooser { current: page.w.night; onChosen: p => { page.w.night = p; Wallpapers.evaluate(); } }
        SRow {
            icon: "󰖛"
            title: I18n.tr("Начало ночи")
            separator: false
            SField { implicitWidth: 80; text: page.w.nightStart; inputMask: "99:99"; onEdited: t => page.w.nightStart = t }
        }
    }

    Repeater {
        model: page.w.mode === "workspace" ? 10 : 0
        SCard {
            required property int index
            title: I18n.tr("Воркспейс ") + (index + 1)
            icon: "󰍹"
            Chooser {
                current: (page.w.perWorkspace ?? {})[String(index + 1)] ?? ""
                onChosen: p => {
                    const m = Settings.copy(page.w.perWorkspace ?? {});
                    m[String(index + 1)] = p;
                    page.w.perWorkspace = m;
                    Wallpapers.evaluate();
                }
            }
        }
    }

    SCard {
        visible: page.w.mode === "slideshow"
        title: I18n.tr("Слайд-шоу")
        icon: "󰒭"
        SRow {
            icon: "󱎫"
            title: I18n.tr("Менять каждые")
            SSlider { from: 1; to: 180; step: 1; value: page.w.slideshowMinutes; suffix: I18n.tr(" мин"); onMoved: v => page.w.slideshowMinutes = v }
        }
        SRow {
            icon: "󰒭"
            title: I18n.tr("Следующие обои")
            separator: false
            SButton { icon: "󰒭"; text: I18n.tr("Сейчас"); onClicked: Wallpapers.next() }
        }
    }
}
