import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

SPage {
    id: page
    title: I18n.tr("Время")
    subtitle: I18n.tr("Будильники, таймеры и календари. Таймер из лаунчера: «+5m чай».")

    readonly property var g: Settings.general
    readonly property var dayNames: [I18n.tr("Пн"), I18n.tr("Вт"), I18n.tr("Ср"), I18n.tr("Чт"), I18n.tr("Пт"), I18n.tr("Сб"), I18n.tr("Вс")]

    SCard {
        title: I18n.tr("Будильники")
        icon: "alarm"

        Repeater {
            model: Store.alarms ?? []
            SRow {
                id: al
                required property var modelData
                required property int index
                icon: modelData.on ? "alarm_on" : "alarm_off"
                title: modelData.time + (modelData.label ? " · " + modelData.label : "")
                desc: (modelData.days ?? []).length === 0 ? I18n.tr("Один раз")
                    : modelData.days.length === 7 ? I18n.tr("Каждый день")
                    : modelData.days.map(d => page.dayNames[d - 1]).join(" ")
                // дни недели: пусто — разовый
                Row {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            readonly property bool on: (al.modelData.days ?? []).includes(index + 1)
                            width: 26; height: 26; radius: 13
                            color: on ? Theme.accent : Theme.surface0
                            StyledText {
                                anchors.centerIn: parent
                                text: page.dayNames[parent.index]
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: parent.on ? Theme.onAccent : Theme.subtext0
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = parent.index + 1, cur = al.modelData.days ?? [];
                                    Timers.updateAlarm(al.modelData.id, { days: cur.includes(d) ? cur.filter(x => x !== d) : [...cur, d].sort() });
                                }
                            }
                        }
                    }
                }
                SSwitch { checked: al.modelData.on; onToggled: v => Timers.updateAlarm(al.modelData.id, { on: v }) }
                IconButton { size: 30; iconSize: 14; icon: "delete"; iconColor: Theme.red; onClicked: Timers.removeAlarm(al.modelData.id) }
            }
        }
        SRow {
            icon: "add_alarm"
            title: I18n.tr("Новый будильник")
            desc: Timers.nextAlarm ? I18n.tr("Ближайший: {0}", I18n.locale.toString(Timers.nextAlarm.at, "ddd HH:mm")) : I18n.tr("Звонит даже в «Не беспокоить»")
            separator: false
            SField { id: alTime; implicitWidth: 80; placeholderText: "07:30"; inputMask: "99:99" }
            SField { id: alLabel; implicitWidth: 160; placeholderText: I18n.tr("Подпись") }
            SButton {
                text: I18n.tr("Добавить")
                primary: true
                onClicked: { Timers.addAlarm(alTime.text, alLabel.text, [1, 2, 3, 4, 5]); alLabel.text = ""; }
            }
        }
    }

    SCard {
        title: I18n.tr("Таймеры")
        icon: "timer"
        Repeater {
            model: Timers.timers
            SRow {
                required property var modelData
                icon: modelData.left !== undefined ? "pause_circle" : "timer"
                title: (modelData.label || I18n.tr("Таймер")) + " · " + Timers.format(Timers.remaining(modelData))
                IconButton { size: 30; iconSize: 14; icon: parent.modelData.left !== undefined ? "play_arrow" : "pause"; onClicked: Timers.togglePause(parent.modelData.id) }
                IconButton { size: 30; iconSize: 14; icon: "close"; iconColor: Theme.red; onClicked: Timers.cancel(parent.modelData.id) }
            }
        }
        SRow {
            icon: "more_time"
            title: I18n.tr("Быстрый старт")
            separator: false
            Repeater {
                model: [1, 5, 10, 25, 60]
                SButton {
                    required property int modelData
                    text: modelData + I18n.tr(" мин")
                    onClicked: Timers.start(modelData * 60, "")
                }
            }
        }
    }

    SCard {
        title: I18n.tr("Календари")
        icon: "calendar_month"
        StyledText {
            Layout.fillWidth: true
            Layout.margins: 14
            Layout.bottomMargin: 4
            wrapMode: Text.Wrap
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            text: I18n.tr("Ссылка на календарь в формате iCal: Google — «Настройки календаря → Секретный адрес в формате iCal», Яндекс — «Экспорт → ссылка ICS». Можно и путь к .ics-файлу.")
        }
        Repeater {
            model: page.g.calendars ?? []
            SRow {
                required property string modelData
                required property int index
                icon: "event_note"
                title: modelData.replace(/^https?:\/\//, "").slice(0, 60) + (modelData.length > 68 ? "…" : "")
                IconButton {
                    size: 30; iconSize: 14; icon: "delete"; iconColor: Theme.red
                    onClicked: page.g.calendars = page.g.calendars.filter((_, i) => i !== parent.index)
                }
            }
        }
        SRow {
            icon: "add_link"
            title: I18n.tr("Добавить календарь")
            desc: Agenda.loading ? I18n.tr("Загрузка…") : Agenda.error ? Agenda.error
                : (page.g.calendars ?? []).length ? I18n.tr("Событий на две недели: {0}", Agenda.events.length) : ""
            SField { id: calUrl; implicitWidth: 300; placeholderText: "https://calendar.google.com/…/basic.ics" }
            SButton {
                text: I18n.tr("Добавить")
                primary: true
                onClicked: {
                    const u = calUrl.text.trim();
                    if (u) page.g.calendars = [...(page.g.calendars ?? []), u];
                    calUrl.text = "";
                }
            }
            SButton { icon: "refresh"; onClicked: Agenda.refresh() }
        }
        SRow {
            icon: "notifications_active"
            title: I18n.tr("Напоминать до начала")
            separator: false
            SSlider { from: 0; to: 60; step: 5; value: page.g.calendarRemind; format: v => v === 0 ? I18n.tr("не напоминать") : v + I18n.tr(" мин"); onMoved: v => page.g.calendarRemind = v }
        }
    }

    SCard {
        visible: Agenda.events.length > 0
        title: I18n.tr("Ближайшие события")
        icon: "upcoming"
        Repeater {
            model: Agenda.upcoming(7).slice(0, 12)
            SRow {
                required property var modelData
                icon: modelData.allDay ? "today" : "schedule"
                title: modelData.title
                desc: I18n.locale.toString(modelData.start, modelData.allDay ? "ddd, d MMMM" : "ddd, d MMMM · HH:mm") + (modelData.location ? " · " + modelData.location : "")
            }
        }
    }
}
