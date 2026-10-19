import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.bar
import qs.services

SPage {
    id: page
    title: I18n.tr("Панель")
    subtitle: I18n.tr("Какие модули показывать, в каком порядке и как. Перемещайте стрелками, переносите между сторонами.")

    readonly property var b: Settings.bar
    readonly property var catalog: ({
        launcher: { icon: "󰣇", label: I18n.tr("Кнопка лаунчера") },
        workspaces: { icon: "󰍹", label: I18n.tr("Воркспейсы") },
        window: { icon: "󰖯", label: I18n.tr("Заголовок окна") },
        tray: { icon: "󱊔", label: I18n.tr("Трей") },
        sysmon: { icon: "󰍛", label: I18n.tr("Нагрузка CPU/RAM") },
        weather: { icon: "󰖐", label: I18n.tr("Погода") },
        layout: { icon: "󰌌", label: I18n.tr("Раскладка") },
        network: { icon: "󰈀", label: I18n.tr("Сеть") },
        bluetooth: { icon: "󰂯", label: "Bluetooth" },
        volume: { icon: "󰕾", label: I18n.tr("Громкость") },
        mic: { icon: "󰍬", label: I18n.tr("Микрофон") },
        notifs: { icon: "󰂚", label: I18n.tr("Уведомления") },
        clock: { icon: "󰥔", label: I18n.tr("Часы (дублирует остров)") },
        focus: { icon: "󰔟", label: I18n.tr("Фокус-таймер") },
        power: { icon: "󰐥", label: I18n.tr("Кнопка питания") },
        updates: { icon: "system_update_alt", label: I18n.tr("Обновления (видно, когда есть)") },
        battery: { icon: "battery_full", label: I18n.tr("Батарея (видно на ноутбуке)") },
        vpn: { icon: "vpn_lock", label: I18n.tr("VPN (видно, когда подключён)") }
    })
    readonly property var unused: Object.keys(catalog).filter(k => !b.left.includes(k) && !b.right.includes(k))

    function move(side: string, i: int, d: int): void {
        const l = [...b[side]];
        const j = i + d;
        if (j < 0 || j >= l.length) return;
        [l[i], l[j]] = [l[j], l[i]];
        b[side] = l;
    }
    function remove(side: string, i: int): void { const l = [...b[side]]; l.splice(i, 1); b[side] = l; }
    function swapSide(side: string, i: int): void {
        const other = side === "left" ? "right" : "left";
        const l = [...b[side]], o = [...b[other]];
        const [m] = l.splice(i, 1);
        side === "left" ? o.unshift(m) : o.push(m);
        b[side] = l;
        b[other] = o;
    }

    component ModuleList: SCard {
        id: card
        property string side
        Repeater {
            model: page.b[card.side]
            SRow {
                required property string modelData
                required property int index
                icon: page.catalog[modelData]?.icon ?? "?"
                title: page.catalog[modelData]?.label ?? modelData
                separator: index < page.b[card.side].length - 1
                IconButton { size: 30; iconSize: 14; icon: "󰁝"; onClicked: page.move(card.side, index, -1) }
                IconButton { size: 30; iconSize: 14; icon: "󰁅"; onClicked: page.move(card.side, index, 1) }
                IconButton { size: 30; iconSize: 14; icon: card.side === "left" ? "󰁔" : "󰁍"; onClicked: page.swapSide(card.side, index) }
                IconButton { size: 30; iconSize: 14; icon: "󰅖"; iconColor: Theme.red; onClicked: page.remove(card.side, index) }
            }
        }
        StyledText {
            visible: page.b[card.side].length === 0
            Layout.margins: 16
            text: I18n.tr("Пусто")
            color: Theme.overlay0
        }
    }

    SCard {
        title: I18n.tr("Стиль панели")
        icon: "󰏘"

        // пресеты: миниатюры на текущих обоях и палитре
        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            Repeater {
                model: BarStyles.presets
                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool active: BarStyles.current === modelData.name
                    implicitWidth: 248
                    implicitHeight: 112
                    radius: Theme.radius
                    color: tileMouse.containsMouse ? Theme.surface0 : Theme.mantle
                    border.width: active ? 2 : 1
                    border.color: active ? Theme.accent : tileMouse.containsMouse ? Theme.surface2 : Theme.surface0
                    scale: tileMouse.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    BarPreview {
                        x: 8
                        y: 8
                        cfg: tile.modelData.cfg
                    }
                    StyledText {
                        x: 12
                        y: 72
                        text: tile.modelData.name
                        font.bold: true
                        color: tile.active ? Theme.accent : Theme.text
                    }
                    StyledText {
                        x: 12
                        y: 90
                        width: parent.width - 24
                        text: tile.modelData.desc
                        color: Theme.overlay1
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BarStyles.apply(tile.modelData.cfg)
                    }
                }
            }
        }

        StyledText {
            Layout.leftMargin: 16
            Layout.bottomMargin: 4
            text: BarStyles.current ? I18n.tr("Ниже — ручная настройка; любое изменение превращает пресет в свой стиль")
                                    : I18n.tr("Свой стиль — цвета и размеры всё равно берутся из темы")
            color: Theme.overlay0
            font.pixelSize: Theme.fontSizeSmall
        }

        SRow {
            icon: "󱂩"
            title: I18n.tr("Расположение")
            SSegment {
                options: [{ value: "floating", label: I18n.tr("Плавающая") }, { value: "notch", label: I18n.tr("Чёлка") }, { value: "drops", label: I18n.tr("Капли") }, { value: "docked", label: I18n.tr("У края") }]
                current: page.b.style
                onPicked: v => page.b.style = v
            }
        }
        SRow {
            icon: "󰕰"
            title: I18n.tr("Капсулы")
            desc: I18n.tr("Подложки под модулями")
            SSegment {
                options: [{ value: "none", label: I18n.tr("Нет") }, { value: "groups", label: I18n.tr("Группами") }, { value: "each", label: I18n.tr("У каждого") }]
                current: page.b.capsules
                onPicked: v => page.b.capsules = v
            }
        }
        SRow {
            visible: page.b.capsules !== "none"
            icon: "󰏘"
            title: I18n.tr("Заливка капсул")
            SSegment {
                options: [{ value: "dark", label: I18n.tr("Тёмная") }, { value: "light", label: I18n.tr("Светлая") }, { value: "outline", label: I18n.tr("Контур") }]
                current: page.b.capsuleFill
                onPicked: v => page.b.capsuleFill = v
            }
        }
        SRow {
            visible: page.b.capsules === "none"
            icon: "󰇘"
            title: I18n.tr("Точки между модулями")
            SSwitch { checked: page.b.separators; onToggled: v => page.b.separators = v }
        }
        SRow {
            icon: "󰆼"
            title: I18n.tr("Подписи модулей")
            desc: I18n.tr("«При наведении» — в панели только значки, текст выезжает под курсором")
            SSegment {
                options: [{ value: "always", label: I18n.tr("Всегда") }, { value: "hover", label: I18n.tr("При наведении") }]
                current: page.b.labels
                onPicked: v => page.b.labels = v
            }
        }
        SRow {
            icon: "󰢡"
            title: I18n.tr("Форма")
            desc: I18n.tr("Скругление — из «Оформления»")
            SSegment {
                options: [{ value: "round", label: I18n.tr("Круглая") }, { value: "soft", label: I18n.tr("Мягкая") }]
                current: page.b.shape
                onPicked: v => page.b.shape = v
            }
        }
        SRow {
            icon: "󰃟"
            title: I18n.tr("Фон панели")
            desc: I18n.tr("Ниже 100% — с размытием обоев; 0% — без полосы, только капсулы")
            SSlider { from: 0; to: 1; step: 0.05; percent: true; value: page.b.bodyOpacity; onMoved: v => page.b.bodyOpacity = v }
        }
        SRow {
            icon: "󰏘"
            title: I18n.tr("Цвет иконок")
            desc: I18n.tr("Состояния (нет сети, выключен микрофон, нагрузка) подсвечиваются всегда")
            separator: false
            SSegment {
                options: [{ value: "mono", label: I18n.tr("Моно") }, { value: "accent", label: I18n.tr("Акцент") }, { value: "colorful", label: I18n.tr("Цветные") }]
                current: page.b.iconColors
                onPicked: v => page.b.iconColors = v
            }
        }
    }

    ModuleList { title: I18n.tr("Слева"); icon: "󰁍"; side: "left" }
    ModuleList { title: I18n.tr("Справа"); icon: "󰁔"; side: "right" }

    SCard {
        visible: page.unused.length > 0
        title: I18n.tr("Скрытые модули — нажмите, чтобы добавить")
        icon: "󰐕"
        Flow {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8
            Repeater {
                model: page.unused
                SButton {
                    required property string modelData
                    icon: page.catalog[modelData].icon
                    text: page.catalog[modelData].label
                    onClicked: page.b.right = [...page.b.right, modelData]
                }
            }
        }
    }

    // живое превью: настоящий компонент бара в капсуле
    component PreviewCapsule: Rectangle {
        default property alias content: holder.data
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 12
        Layout.bottomMargin: 4
        implicitWidth: holder.childrenRect.width + 8
        implicitHeight: Theme.capsuleHeight
        radius: Theme.capsuleRadius
        color: Theme.capsule
        border.width: 1
        border.color: Theme.capsuleBorder
        Item { id: holder; x: 4; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }

    SCard {
        title: I18n.tr("Кнопка лаунчера")
        icon: "󰀻"

        PreviewCapsule {
            Pill {
                readonly property var bb: Settings.bar
                icon: bb.launcherStyle === "text" ? "" : bb.launcherIcon
                label: bb.launcherStyle === "icon" ? "" : bb.launcherText
                pinLabel: true
                iconColor: bb.launcherColor === "mono" ? Theme.barIcon : Theme.accent
                textColor: bb.launcherColor === "mono" ? Theme.text : Theme.accent
            }
        }
        SRow {
            icon: "󰏘"
            title: I18n.tr("Значок")
            Flow {
                Layout.maximumWidth: 420
                spacing: 4
                Repeater {
                    model: ["cove", "waves", "󰣇", "apps", "grid_view", "menu", "search", "star", "auto_awesome", "favorite",
                        "bedtime", "pets", "eco", "local_florist", "spa", "diamond", "token", "cyclone", "bubble_chart", "rocket_launch", "deployed_code"]
                    IconButton {
                        required property string modelData
                        size: 32
                        iconSize: 16
                        icon: modelData
                        active: page.b.launcherIcon === modelData
                        onClicked: page.b.launcherIcon = modelData
                    }
                }
            }
        }
        SRow {
            icon: "󰊄"
            title: I18n.tr("Вид")
            SSegment {
                options: [{ value: "icon", label: I18n.tr("Значок") }, { value: "both", label: I18n.tr("Значок и текст") }, { value: "text", label: I18n.tr("Текст") }]
                current: page.b.launcherStyle
                onPicked: v => page.b.launcherStyle = v
            }
        }
        SRow {
            visible: page.b.launcherStyle !== "icon"
            icon: "󰗴"
            title: I18n.tr("Текст")
            SField { implicitWidth: 180; text: page.b.launcherText; onEdited: t => page.b.launcherText = t }
        }
        SRow {
            icon: "󰏘"
            title: I18n.tr("Цвет")
            SSegment {
                options: [{ value: "accent", label: I18n.tr("Акцент") }, { value: "mono", label: I18n.tr("Как все") }]
                current: page.b.launcherColor
                onPicked: v => page.b.launcherColor = v
            }
        }
        SRow {
            icon: "󰍽"
            title: I18n.tr("По клику")
            separator: false
            SSegment {
                options: [{ value: "launcher", label: I18n.tr("Лаунчер") }, { value: "control", label: I18n.tr("Центр управления") }, { value: "overview", label: I18n.tr("Обзор окон") }]
                current: page.b.launcherAction
                onPicked: v => page.b.launcherAction = v
            }
        }
    }

    SCard {
        title: I18n.tr("Воркспейсы")
        icon: "󰍹"

        PreviewCapsule { Workspaces {} }
        SRow {
            icon: "󰕰"
            title: I18n.tr("Стиль")
            SDropdown {
                options: [
                    { value: "pills", label: I18n.tr("Капли") }, { value: "dots", label: I18n.tr("Точки") }, { value: "lines", label: I18n.tr("Линии") },
                    { value: "squares", label: I18n.tr("Квадраты") }, { value: "numbers", label: I18n.tr("Цифры") }, { value: "kanji", label: I18n.tr("Кандзи  一 二 三") },
                    { value: "roman", label: I18n.tr("Римские  I II III") }, { value: "icons", label: I18n.tr("Значки приложений") }
                ]
                current: page.b.workspaceStyle
                onPicked: v => page.b.workspaceStyle = v
            }
        }
        SRow {
            icon: "󰍹"
            title: I18n.tr("Сколько показывать")
            desc: I18n.tr("Минимум; занятые с большим номером появятся сами")
            SSlider { from: 1; to: 10; step: 1; value: page.b.workspaces; onMoved: v => page.b.workspaces = v }
        }
        SRow {
            icon: "󰈈"
            title: I18n.tr("Только занятые")
            desc: I18n.tr("Пустые воркспейсы прячутся, кроме текущего")
            SSwitch { checked: page.b.workspaceOccupiedOnly; onToggled: v => page.b.workspaceOccupiedOnly = v }
        }
        SRow {
            icon: "󰏘"
            title: I18n.tr("Цвет текущего")
            SSegment {
                options: [{ value: "accent", label: I18n.tr("Акцент") }, { value: "text", label: I18n.tr("Светлый") }]
                current: page.b.workspaceActive
                onPicked: v => page.b.workspaceActive = v
            }
        }
        SRow {
            icon: "󰎆"
            title: I18n.tr("Спектр вдоль панели")
            desc: I18n.tr("Тонкая полоска эквалайзера по нижней кромке, пока играет музыка")
            separator: false
            SSwitch { checked: page.b.visualizerStrip; onToggled: v => page.b.visualizerStrip = v }
        }
    }
}
