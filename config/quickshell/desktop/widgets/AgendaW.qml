import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Ближайшие события из календарей (раздел «Время» в настройках).
ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)

    spacing: 6
    implicitWidth: 300

    readonly property var list: Agenda.upcoming(root.opts.days ?? 3).slice(0, root.opts.count ?? 6)

    function when(e): string {
        const d = e.start, now = new Date(Agenda.now);
        const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        const day = Agenda.sameDay(d, now) ? I18n.tr("Сегодня") : Agenda.sameDay(d, tomorrow) ? I18n.tr("Завтра") : I18n.locale.toString(d, "ddd, d MMM");
        if (e.allDay) return day + I18n.tr(" · весь день");
        if (e.start.getTime() <= Agenda.now) return I18n.tr("Сейчас · до ") + I18n.locale.toString(e.end, "HH:mm");
        return day + " · " + I18n.locale.toString(d, "HH:mm");
    }

    RowLayout {
        spacing: 10
        MIcon { icon: "calendar_month"; color: Theme.accent; size: Theme.iconSize }
        StyledText { text: root.opts.title || I18n.tr("События"); font.bold: true }
    }

    Repeater {
        model: root.list
        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 3
                radius: 2
                color: modelData.start.getTime() <= Agenda.now ? Theme.green : [Theme.accent, Theme.accent2, Theme.teal, Theme.peach][modelData.cal % 4]
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { Layout.fillWidth: true; text: modelData.title; elide: Text.ElideRight }
                StyledText {
                    Layout.fillWidth: true
                    text: root.when(modelData) + (modelData.location ? " · " + modelData.location : "")
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }
    }

    StyledText {
        visible: root.list.length === 0
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: (Settings.general.calendars ?? []).length === 0
            ? I18n.tr("Добавьте календарь: Настройки → Время → Календари")
            : I18n.tr("Ближайших событий нет")
        color: Theme.overlay1
        font.pixelSize: Theme.fontSizeSmall
    }
}
