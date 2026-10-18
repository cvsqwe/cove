import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Терминал")
    subtitle: I18n.tr("Вид kitty: шрифт, отступы, прозрачность, курсор и вкладки. Цвета берутся из обоев. Применяется сразу ко всем окнам.")

    readonly property var t: Settings.terminal

    // живой пример: как будет выглядеть окно
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Theme.radius
        color: Theme.alpha(Theme.base, page.t.opacity)
        border.width: 1
        border.color: Theme.surface1
        clip: true
        Rectangle {
            visible: page.t.tabs !== "hidden"
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            color: Theme.crust
            Row {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Rectangle { width: 90; height: 16; radius: page.t.tabs === "powerline" ? 0 : 4; color: Theme.accent
                    StyledText { anchors.centerIn: parent; text: "fish"; color: Theme.crust; font.pixelSize: 10; font.family: page.t.font } }
                Rectangle { width: 90; height: 16; radius: 4; color: Theme.mantle
                    StyledText { anchors.centerIn: parent; text: "nvim"; color: Theme.subtext0; font.pixelSize: 10; font.family: page.t.font } }
            }
        }
        Column {
            x: page.t.padding + 6
            y: (page.t.tabs !== "hidden" ? 22 : 0) + page.t.padding + 4
            spacing: 2
            Row {
                spacing: 0
                StyledText { text: "~/cove "; color: Theme.accent; font.family: page.t.font; font.pixelSize: Math.round(page.t.fontSize * 4 / 3); font.bold: true }
                StyledText { text: "on \ue0a0 main "; color: Theme.accent2; font.family: page.t.font; font.pixelSize: Math.round(page.t.fontSize * 4 / 3) }
            }
            Row {
                StyledText { text: "❯ "; color: Theme.green; font.family: page.t.font; font.pixelSize: Math.round(page.t.fontSize * 4 / 3) }
                StyledText { text: "git status"; color: Theme.accent; font.family: page.t.font; font.pixelSize: Math.round(page.t.fontSize * 4 / 3); font.bold: true }
                Rectangle {
                    width: page.t.cursor === "block" ? 9 : page.t.cursor === "beam" ? 2 : 9
                    height: page.t.cursor === "underline" ? 2 : 16
                    anchors.bottom: parent.bottom
                    color: Theme.accent
                    SequentialAnimation on opacity {
                        running: page.t.cursorBlink
                        loops: Animation.Infinite
                        NumberAnimation { to: 0; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Шрифт")
        icon: "font_download"
        SRow {
            icon: "text_fields"
            title: I18n.tr("Семейство")
            desc: I18n.tr("Только моноширинные; для значков в промпте нужен Nerd Font")
            SDropdown {
                options: TerminalLook.fonts.map(f => ({ value: f, label: f }))
                current: page.t.font
                onPicked: v => page.t.font = v
            }
        }
        SRow {
            icon: "format_size"
            title: I18n.tr("Размер")
            separator: false
            SSlider { from: 8; to: 20; step: 0.5; value: page.t.fontSize; format: v => v.toFixed(1) + " pt"; onMoved: v => page.t.fontSize = v }
        }
    }

    SCard {
        title: I18n.tr("Окно")
        icon: "terminal"
        SRow {
            icon: "padding"
            title: I18n.tr("Отступ от краёв")
            SSlider { from: 0; to: 30; step: 1; value: page.t.padding; suffix: " px"; onMoved: v => page.t.padding = v }
        }
        SRow {
            icon: "opacity"
            title: I18n.tr("Непрозрачность фона")
            SSlider { from: 0.5; to: 1; step: 0.02; value: page.t.opacity; percent: true; onMoved: v => page.t.opacity = v }
        }
        SRow {
            icon: "tab"
            title: I18n.tr("Вкладки")
            SSegment {
                options: [
                    { value: "powerline", label: "Powerline" }, { value: "slant", label: I18n.tr("Наклон") },
                    { value: "fade", label: I18n.tr("Плавные") }, { value: "separator", label: I18n.tr("Простые") },
                    { value: "hidden", label: I18n.tr("Скрыть") }
                ]
                current: page.t.tabs
                onPicked: v => page.t.tabs = v
            }
        }
        SRow {
            icon: "text_select_end"
            title: I18n.tr("Курсор")
            SSegment {
                options: [{ value: "beam", label: I18n.tr("Черта") }, { value: "block", label: I18n.tr("Блок") }, { value: "underline", label: I18n.tr("Подчёркивание") }]
                current: page.t.cursor
                onPicked: v => page.t.cursor = v
            }
        }
        SRow {
            icon: "flare"
            title: I18n.tr("Мигающий курсор")
            separator: false
            SSwitch { checked: page.t.cursorBlink; onToggled: v => page.t.cursorBlink = v }
        }
    }

    SCard {
        title: "fish"
        icon: "set_meal"
        SRow {
            icon: "waving_hand"
            title: I18n.tr("Приветствие fastfetch")
            desc: I18n.tr("Сведения о системе в первом окне терминала за сессию")
            separator: false
            SSwitch { checked: page.t.greeting; onToggled: v => page.t.greeting = v }
        }
    }
}
