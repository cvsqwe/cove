import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.components

SPage {
    id: page
    title: I18n.tr("Клавиатура и мышь")
    subtitle: I18n.tr("Раскладки, их переключение, повтор клавиш, чувствительность.")

    readonly property var inp: Settings.input
    // карточка «Тачпад» — только если он есть (или QS_TOUCHPAD=1 для проверки на компьютере)
    property bool touchpad: false
    Process {
        running: true
        command: ["sh", "-c", "if [ \"$QS_TOUCHPAD\" = 1 ] || hyprctl devices -j | grep -qi '\"name\": \"[^\"]*touchpad'; then echo yes; else echo no; fi"]
        stdout: StdioCollector { onStreamFinished: page.touchpad = text.trim() === "yes" }
    }
    readonly property var known: [
        { value: "us", label: I18n.tr("🇺🇸 Английская (US)") }, { value: "ru", label: I18n.tr("🇷🇺 Русская") },
        { value: "ua", label: I18n.tr("🇺🇦 Украинская") }, { value: "by", label: I18n.tr("🇧🇾 Белорусская") },
        { value: "kz", label: I18n.tr("🇰🇿 Казахская") }, { value: "de", label: I18n.tr("🇩🇪 Немецкая") },
        { value: "fr", label: I18n.tr("🇫🇷 Французская") }, { value: "es", label: I18n.tr("🇪🇸 Испанская") },
        { value: "gb", label: I18n.tr("🇬🇧 Английская (UK)") }, { value: "pl", label: I18n.tr("🇵🇱 Польская") },
        { value: "jp", label: I18n.tr("🇯🇵 Японская") }, { value: "ge", label: I18n.tr("🇬🇪 Грузинская") },
        { value: "am", label: I18n.tr("🇦🇲 Армянская") }, { value: "tr", label: I18n.tr("🇹🇷 Турецкая") }
    ]

    SCard {
        title: I18n.tr("Раскладки")
        icon: "󰌌"

        Flow {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 8

            Repeater {
                model: page.inp.layouts
                Rectangle {
                    required property string modelData
                    required property int index
                    implicitWidth: chip.implicitWidth + 44
                    implicitHeight: 34
                    radius: 17
                    color: index === 0 ? Theme.accent : Theme.surface0
                    StyledText {
                        id: chip
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        text: page.known.find(k => k.value === modelData)?.label ?? modelData
                        color: index === 0 ? Theme.onAccent : Theme.text
                        font.pixelSize: Theme.fontSizeSmall + 1
                    }
                    MIcon {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: page.inp.layouts.length > 1
                        icon: "󰅖"
                        color: index === 0 ? Theme.onAccent : Theme.overlay1
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { const l = [...page.inp.layouts]; l.splice(index, 1); page.inp.layouts = l; }
                        }
                    }
                }
            }

            SDropdown {
                implicitWidth: 200
                placeholder: I18n.tr("+ Добавить раскладку")
                options: page.known.filter(k => !page.inp.layouts.includes(k.value))
                onPicked: v => page.inp.layouts = [...page.inp.layouts, v]
            }
        }

        SRow {
            icon: "󰯍"
            title: I18n.tr("Переключение раскладки")
            separator: false
            SDropdown {
                options: [
                    { value: "grp:alt_shift_toggle", label: "Alt + Shift" },
                    { value: "grp:win_space_toggle", label: I18n.tr("Super + Пробел") },
                    { value: "grp:ctrl_shift_toggle", label: "Ctrl + Shift" },
                    { value: "grp:caps_toggle", label: "Caps Lock" },
                    { value: "grp:alt_space_toggle", label: I18n.tr("Alt + Пробел") },
                    { value: "grp:rctrl_toggle", label: I18n.tr("Правый Ctrl") }
                ]
                current: page.inp.switchKey
                onPicked: v => page.inp.switchKey = v
            }
        }
    }

    SCard {
        title: I18n.tr("Повтор клавиш")
        icon: "󰌓"
        SRow {
            icon: "󱎫"
            title: I18n.tr("Задержка перед повтором")
            SSlider { from: 150; to: 1000; step: 25; value: page.inp.repeatDelay; suffix: I18n.tr(" мс"); onMoved: v => page.inp.repeatDelay = v }
        }
        SRow {
            icon: "󰓅"
            title: I18n.tr("Скорость повтора")
            separator: false
            SSlider { from: 10; to: 80; step: 1; value: page.inp.repeatRate; suffix: I18n.tr("/с"); onMoved: v => page.inp.repeatRate = v }
        }
    }

    SCard {
        title: I18n.tr("Мышь")
        icon: "󰍽"
        SRow {
            icon: "󰍽"
            title: I18n.tr("Чувствительность")
            SSlider { from: -1; to: 1; step: 0.05; value: page.inp.sensitivity; decimals: 2; onMoved: v => page.inp.sensitivity = v }
        }
        SRow {
            icon: "󰓅"
            title: I18n.tr("Ускорение")
            SSegment {
                options: [{ value: "adaptive", label: I18n.tr("Адаптивное") }, { value: "flat", label: I18n.tr("Без ускорения") }]
                current: page.inp.accel
                onPicked: v => page.inp.accel = v
            }
        }
        SRow {
            icon: "󰟸"
            title: I18n.tr("Естественная прокрутка")
            SSwitch { checked: page.inp.naturalScroll; onToggled: v => page.inp.naturalScroll = v }
        }
        SRow {
            icon: "󰆽"
            title: I18n.tr("Фокус следует за мышью")
            separator: false
            SSwitch { checked: page.inp.followMouse === 1; onToggled: v => page.inp.followMouse = v ? 1 : 0 }
        }
    }

    SCard {
        visible: page.touchpad
        title: I18n.tr("Тачпад")
        icon: "touchpad_mouse"
        SRow {
            icon: "touch_app"
            title: I18n.tr("Касание — клик")
            desc: I18n.tr("Лёгкое касание вместо нажатия")
            SSwitch { checked: page.inp.tapToClick; onToggled: v => page.inp.tapToClick = v }
        }
        SRow {
            icon: "swipe_vertical"
            title: I18n.tr("Естественная прокрутка")
            desc: I18n.tr("Как на телефоне: страница едет за пальцами")
            SSwitch { checked: page.inp.tpNatural; onToggled: v => page.inp.tpNatural = v }
        }
        SRow {
            icon: "speed"
            title: I18n.tr("Скорость прокрутки")
            SSlider { from: 0.2; to: 3; step: 0.1; decimals: 1; suffix: "×"; value: page.inp.tpScroll; onMoved: v => page.inp.tpScroll = v }
        }
        SRow {
            icon: "ads_click"
            title: I18n.tr("Правый клик двумя пальцами")
            desc: I18n.tr("Иначе — нажатием в правый нижний угол")
            SSwitch { checked: page.inp.tpClickfinger; onToggled: v => page.inp.tpClickfinger = v }
        }
        SRow {
            icon: "keyboard"
            title: I18n.tr("Не мешать при наборе")
            desc: I18n.tr("Тачпад не реагирует, пока вы печатаете")
            SSwitch { checked: page.inp.tpTyping; onToggled: v => page.inp.tpTyping = v }
        }
        SRow {
            icon: "swipe"
            title: I18n.tr("Жесты")
            desc: I18n.tr("Три пальца влево-вправо — соседний воркспейс")
            separator: false
            SSwitch { checked: page.inp.gestures; onToggled: v => page.inp.gestures = v }
        }
    }
}
