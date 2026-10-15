import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Уведомления")
    subtitle: I18n.tr("Звуки, «Не беспокоить» по расписанию и приложения, которые не должны отвлекать.")

    readonly property var n: Settings.notifications

    SCard {
        title: I18n.tr("Основное")
        icon: "󰂚"
        SRow {
            icon: "󰂛"
            title: I18n.tr("Не беспокоить")
            desc: I18n.tr("Сейчас: ") + (Notifs.quiet ? I18n.tr("включено") + (Notifs.scheduled ? I18n.tr(" по расписанию") : "") : I18n.tr("выключено"))
            SSwitch { checked: Store.dnd; onToggled: v => Store.dnd = v }
        }
        SRow {
            icon: "󰃰"
            title: I18n.tr("По расписанию")
            SSwitch { checked: page.n.dndSchedule; onToggled: v => page.n.dndSchedule = v }
        }
        SRow {
            visible: page.n.dndSchedule
            icon: "󱑆"
            title: I18n.tr("С и до")
            SField { implicitWidth: 80; text: page.n.dndFrom; inputMask: "99:99"; onEdited: t => page.n.dndFrom = t }
            StyledText { text: "—"; anchors.verticalCenter: parent.verticalCenter }
            SField { implicitWidth: 80; text: page.n.dndTo; inputMask: "99:99"; onEdited: t => page.n.dndTo = t }
        }
        SRow {
            icon: "󰕾"
            title: I18n.tr("Звуки интерфейса")
            desc: I18n.tr("Уведомления, громкость, разблокировка")
            SButton { text: I18n.tr("Проверить"); icon: "󰐊"; onClicked: Sounds.play("notify") }
            SSwitch { checked: Settings.general.sounds; onToggled: v => Settings.general.sounds = v }
        }
        SRow {
            icon: "󰝝"
            title: I18n.tr("Громкость звуков")
            separator: false
            SSlider { from: 0.1; to: 1; step: 0.05; value: Settings.general.soundVolume; percent: true; onMoved: v => Settings.general.soundVolume = v }
        }
    }

    SCard {
        title: I18n.tr("Приложения")
        icon: "󰀻"

        StyledText {
            visible: (Store.seenApps ?? []).length === 0
            Layout.margins: 16
            text: I18n.tr("Здесь появятся приложения, которые присылали уведомления.")
            color: Theme.overlay0
        }

        Repeater {
            model: Store.seenApps ?? []
            SRow {
                required property string modelData
                required property int index
                icon: "󰂚"
                title: modelData
                desc: (page.n.muted ?? []).includes(modelData) ? I18n.tr("Только в истории, без всплывашек и звука") : I18n.tr("Показывать в острове")
                separator: index < (Store.seenApps ?? []).length - 1
                SSwitch {
                    checked: !(page.n.muted ?? []).includes(modelData)
                    onToggled: v => {
                        const m = (page.n.muted ?? []).filter(x => x !== modelData);
                        page.n.muted = v ? m : [...m, modelData];
                    }
                }
            }
        }
    }

    SButton {
        icon: "󰂚"
        text: I18n.tr("Отправить тестовое уведомление")
        onClicked: Quickshell.execDetached(["notify-send", "-a", I18n.tr("Настройки"), I18n.tr("Привет!"), I18n.tr("Так выглядит уведомление в острове.")])
    }
}
