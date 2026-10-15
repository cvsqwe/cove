import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components

ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    spacing: 0
    implicitWidth: 220
    SystemClock { id: c; precision: SystemClock.Minutes }
    readonly property var target: new Date((opts.date || "2027-01-01") + "T00:00:00")
    readonly property int days: isNaN(target) ? 0 : Math.ceil((target - c.date) / 86400000)
    function plural(n: int): string { return I18n.plural(n, "день", "дня", "дней"); }

    StyledText { text: "" + (root.opts.title || I18n.tr("Событие")); color: Theme.accent; font.bold: true }
    RowLayout {
        spacing: 10
        StyledText { text: Math.abs(root.days); font.pixelSize: 64; font.bold: true }
        StyledText {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 12
            text: root.plural(root.days) + (root.days < 0 ? I18n.tr(" назад") : root.days === 0 ? I18n.tr(" — сегодня!") : "")
            color: Theme.subtext1
            font.pixelSize: 20
        }
    }
    StyledText {
        text: isNaN(root.target) ? I18n.tr("Дата в формате ГГГГ-ММ-ДД") : I18n.locale.toString(root.target, "d MMMM yyyy")
        color: Theme.overlay1
        font.pixelSize: Theme.fontSizeSmall
    }
}
