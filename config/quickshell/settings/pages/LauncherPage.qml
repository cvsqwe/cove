import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Лаунчер")
    subtitle: I18n.tr("Как выглядит меню приложений (Super+Пробел): где появляется, список или сетка, размер и плотность.")

    readonly property var l: Settings.launcher

    // миниатюра: экран с обоями, панель и лаунчер в нужном месте
    component Preview: ClippingRectangle {
        id: pv
        property var cfg: ({})
        readonly property real k: width / 1920
        implicitWidth: 232
        implicitHeight: 130
        radius: Theme.radiusSmall
        color: Theme.crust
        Image { anchors.fill: parent; source: Store.still ? "file://" + Store.still : ""; sourceSize: Qt.size(320, 180); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Rectangle { x: 4; y: 4; width: parent.width - 8; height: 8; radius: 4; color: Theme.alpha(Theme.base, 0.95) }
        Rectangle {
            id: card
            readonly property bool center: pv.cfg.position === "center"
            width: Math.round((pv.cfg.width ?? 560) * pv.k)
            height: Math.round((pv.cfg.height ?? 540) * pv.k)
            x: center ? (pv.width - width) / 2 : pv.cfg.position === "right" ? pv.width - width - 4 : 4
            y: center ? 16 + Math.round(1080 * 0.12 * pv.k) : 16
            radius: 5
            color: Theme.base
            border.width: 1
            border.color: Theme.surface1
            Column {
                x: 5; y: 5
                spacing: 3
                Rectangle { visible: (pv.cfg.header ?? "greeting") !== "none"; width: card.width * 0.45; height: 3; radius: 1.5; color: Theme.text }
                Rectangle { width: card.width - 10; height: 7; radius: 3; color: Theme.mantle; border.width: 1; border.color: Theme.accent }
                Repeater {
                    model: pv.cfg.layout === "grid" ? 0 : Math.max(1, Math.floor((card.height - 30) / (pv.cfg.density === "compact" ? 6 : 8)))
                    Row {
                        required property int index
                        spacing: 3
                        Rectangle { width: pv.cfg.density === "compact" ? 3 : 4; height: width; radius: 1; color: index === 0 ? Theme.accent : Theme.overlay1 }
                        Column {
                            spacing: 1
                            Rectangle { width: card.width * 0.4; height: 2; radius: 1; color: index === 0 ? Theme.accent : Theme.subtext0 }
                            Rectangle { visible: !!pv.cfg.descriptions && pv.cfg.density !== "compact"; width: card.width * 0.55; height: 1.5; radius: 1; color: Theme.overlay0 }
                        }
                    }
                }
                Grid {
                    visible: pv.cfg.layout === "grid"
                    columns: Math.max(3, Math.floor(card.width / 13))
                    spacing: 4
                    Repeater {
                        model: pv.cfg.layout === "grid" ? Math.max(3, Math.floor(card.width / 13)) * Math.max(1, Math.floor((card.height - 24) / 13)) : 0
                        Rectangle { required property int index; width: 8; height: 8; radius: 2; color: index === 0 ? Theme.accent : Theme.overlay1 }
                    }
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Стиль")
        icon: "󰏘"

        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            Repeater {
                model: LauncherStyles.presets
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool active: LauncherStyles.current === modelData.name
                    implicitWidth: 248
                    implicitHeight: 186
                    radius: Theme.radius
                    color: tm.containsMouse ? Theme.surface0 : Theme.mantle
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : tm.containsMouse ? Theme.surface2 : Theme.surface0
                    scale: tm.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Preview { x: 8; y: 8; cfg: tile.modelData.cfg }
                    StyledText { x: 12; y: 146; text: tile.modelData.name; font.bold: true; color: tile.active ? Theme.accent : Theme.text }
                    StyledText { x: 12; y: 164; width: parent.width - 24; text: tile.modelData.desc; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: LauncherStyles.apply(tile.modelData.cfg) }
                }
            }
        }
        SRow {
            icon: "󰍉"
            title: I18n.tr("Посмотреть")
            desc: I18n.tr("Открыть лаунчер с текущими настройками")
            separator: false
            SButton { icon: "󰍉"; text: I18n.tr("Открыть"); primary: true; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "launcher", "toggle"]) }
        }
    }

    SCard {
        title: I18n.tr("Ручная настройка")
        icon: "󰒓"
        SRow {
            icon: "󰍹"
            title: I18n.tr("Расположение")
            SSegment {
                options: [{ value: "left", label: I18n.tr("Слева") }, { value: "center", label: I18n.tr("По центру") }, { value: "right", label: I18n.tr("Справа") }]
                current: page.l.position
                onPicked: v => page.l.position = v
            }
        }
        SRow {
            icon: "󰕰"
            title: I18n.tr("Приложения")
            desc: I18n.tr("Сетка — только для приложений; калькулятор, файлы и команды всегда списком")
            SSegment {
                options: [{ value: "list", label: I18n.tr("Список") }, { value: "grid", label: I18n.tr("Сетка") }]
                current: page.l.layout
                onPicked: v => page.l.layout = v
            }
        }
        SRow {
            icon: "󰘞"
            title: I18n.tr("Плотность")
            SSegment {
                options: [{ value: "normal", label: I18n.tr("Обычная") }, { value: "compact", label: I18n.tr("Компактная") }]
                current: page.l.density
                onPicked: v => page.l.density = v
            }
        }
        SRow {
            icon: "󰋩"
            title: I18n.tr("Размер иконок")
            SSlider { from: 18; to: 64; step: 2; value: page.l.iconSize; suffix: " px"; onMoved: v => page.l.iconSize = v }
        }
        SRow {
            icon: "󰦨"
            title: I18n.tr("Описания приложений")
            desc: I18n.tr("Вторая строка под названием (в компактном режиме скрыта)")
            SSwitch { checked: page.l.descriptions; onToggled: v => page.l.descriptions = v }
        }
        SRow {
            icon: "󰩨"
            title: I18n.tr("Ширина")
            SSlider { from: 400; to: 1100; step: 20; value: page.l.width; suffix: " px"; onMoved: v => page.l.width = v }
        }
        SRow {
            icon: "󰡏"
            title: I18n.tr("Высота")
            separator: false
            SSlider { from: 280; to: 860; step: 20; value: page.l.height; suffix: " px"; onMoved: v => page.l.height = v }
        }
    }

    SCard {
        title: I18n.tr("Оформление")
        icon: "󰏘"
        SRow {
            icon: "󰋩"
            title: I18n.tr("Фон")
            desc: I18n.tr("Стекло — полупрозрачный с размытием обоев; «Обои» — размытая текущая обоина")
            SSegment {
                options: [{ value: "solid", label: I18n.tr("Сплошной") }, { value: "glass", label: I18n.tr("Стекло") }, { value: "wallpaper", label: I18n.tr("Обои") }]
                current: page.l.background
                onPicked: v => page.l.background = v
            }
        }
        SRow {
            icon: "󰍉"
            title: I18n.tr("Поле поиска")
            SSegment {
                options: [{ value: "top", label: I18n.tr("Сверху") }, { value: "bottom", label: I18n.tr("Снизу") }]
                current: page.l.searchPos
                onPicked: v => page.l.searchPos = v
            }
        }
        SRow {
            icon: "󰡏"
            title: I18n.tr("Стиль поля")
            SSegment {
                options: [{ value: "filled", label: I18n.tr("Заливка") }, { value: "line", label: I18n.tr("Линия") }, { value: "bare", label: I18n.tr("Без рамки") }]
                current: page.l.searchStyle
                onPicked: v => page.l.searchStyle = v
            }
        }
        SRow {
            icon: "󰗴"
            title: I18n.tr("Подсказка в поле")
            desc: I18n.tr("Пусто — подсказка по умолчанию")
            SField { implicitWidth: 260; text: page.l.placeholder; placeholderText: I18n.tr("Что запустим?"); onEdited: t => page.l.placeholder = t }
        }
        SRow {
            icon: "󰒅"
            title: I18n.tr("Выделение")
            SSegment {
                options: [{ value: "bar", label: I18n.tr("Полоса") }, { value: "fill", label: I18n.tr("Заливка") }, { value: "outline", label: I18n.tr("Рамка") }, { value: "zoom", label: I18n.tr("Увеличение") }]
                current: page.l.highlight
                onPicked: v => page.l.highlight = v
            }
        }
        SRow {
            icon: "󰣐"
            title: I18n.tr("Шапка")
            SSegment {
                options: [{ value: "greeting", label: I18n.tr("Приветствие") }, { value: "clock", label: I18n.tr("Часы") }, { value: "weather", label: I18n.tr("Погода") }, { value: "none", label: I18n.tr("Нет") }]
                current: page.l.header
                onPicked: v => page.l.header = v
            }
        }
        SRow {
            icon: "󰑓"
            title: I18n.tr("Появление")
            SSegment {
                options: [{ value: "slide", label: I18n.tr("Выезд") }, { value: "grow", label: I18n.tr("Рост") }, { value: "fade", label: I18n.tr("Проявление") }]
                current: page.l.anim
                onPicked: v => page.l.anim = v
            }
        }
        SRow {
            icon: "󰃟"
            title: I18n.tr("Затемнять экран")
            desc: I18n.tr("Как в Spotlight; клик по затемнению закрывает лаунчер")
            SSwitch { checked: page.l.dim; onToggled: v => page.l.dim = v }
        }
        SRow {
            icon: "󰋗"
            title: I18n.tr("Подсказка префиксов")
            desc: I18n.tr("«= / > ? : # ! @» в шапке")
            separator: false
            SSwitch { checked: page.l.hints; onToggled: v => page.l.hints = v }
        }
    }

    SCard {
        title: I18n.tr("Приложения")
        icon: "󰀻"
        SRow {
            icon: "󰐃"
            title: I18n.tr("Избранное сверху")
            desc: I18n.tr("Закрепить — правый клик по приложению в лаунчере")
            SSwitch { checked: page.l.favorites; onToggled: v => page.l.favorites = v }
        }
        Repeater {
            model: page.l.pinned ?? []
            SRow {
                required property string modelData
                readonly property var e: DesktopEntries.applications.values.find(x => x.id === modelData)
                icon: "󰐃"
                title: e?.name ?? modelData
                desc: I18n.tr("Закреплено")
                IconButton { size: 30; iconSize: 14; icon: "keep_off"; onClicked: page.l.pinned = (page.l.pinned ?? []).filter(x => x !== modelData) }
            }
        }
        Repeater {
            model: page.l.hidden ?? []
            SRow {
                required property string modelData
                readonly property var e: DesktopEntries.applications.values.find(x => x.id === modelData)
                icon: "󰈉"
                title: e?.name ?? modelData
                desc: I18n.tr("Скрыто из списка")
                SButton { text: I18n.tr("Вернуть"); onClicked: page.l.hidden = (page.l.hidden ?? []).filter(x => x !== modelData) }
            }
        }
        SRow {
            icon: "󰒺"
            title: I18n.tr("Порядок")
            SSegment {
                options: [{ value: "frequent", label: I18n.tr("Частые") }, { value: "recent", label: I18n.tr("Недавние") }, { value: "alpha", label: I18n.tr("По алфавиту") }]
                current: page.l.sort
                onPicked: v => page.l.sort = v
            }
        }
        SRow {
            icon: "󰍉"
            title: I18n.tr("Нечёткий поиск")
            desc: I18n.tr("«ffx» найдёт Firefox, «vsc» — VS Code")
            separator: false
            SSwitch { checked: page.l.fuzzy; onToggled: v => page.l.fuzzy = v }
        }
    }

    SCard {
        title: I18n.tr("Быстрые поиски")
        icon: "󰖟"
        StyledText {
            Layout.leftMargin: 16
            Layout.topMargin: 8
            text: I18n.tr("В лаунчере: «!yt котики» — поиск на YouTube. %s в адресе заменяется запросом. «@» — переключиться на открытое окно.")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.rightMargin: 16
        }
        Repeater {
            model: page.l.bangs ?? []
            RowLayout {
                id: bangRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                spacing: 8
                function set(k, v): void { const l = Settings.copy(page.l.bangs); l[index][k] = v; page.l.bangs = l; }
                SField { implicitWidth: 70; text: "!" + bangRow.modelData.key; onEdited: t => bangRow.set("key", t.replace(/^!/, "").trim()) }
                SField { implicitWidth: 150; text: bangRow.modelData.name; onEdited: t => bangRow.set("name", t) }
                SField { Layout.fillWidth: true; text: bangRow.modelData.url; onEdited: t => bangRow.set("url", t) }
                IconButton { size: 30; iconSize: 14; icon: "delete"; iconColor: Theme.red
                    onClicked: { const l = Settings.copy(page.l.bangs); l.splice(bangRow.index, 1); page.l.bangs = l; } }
            }
        }
        SRow {
            icon: "󰐕"
            title: I18n.tr("Добавить поиск")
            separator: false
            SButton { icon: "󰐕"; text: I18n.tr("Добавить"); onClicked: page.l.bangs = [...Settings.copy(page.l.bangs ?? []), { key: "new", name: I18n.tr("Новый поиск"), url: "https://example.com/?q=%s" }] }
        }
    }
}
