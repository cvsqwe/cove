import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    spacing: 4
    SystemClock { id: c; precision: SystemClock.Minutes }
    readonly property int h: c.date.getHours()
    readonly property string hello: h < 5 ? I18n.tr("Доброй ночи") : h < 12 ? I18n.tr("Доброе утро") : h < 18 ? I18n.tr("Добрый день") : I18n.tr("Добрый вечер")

    StyledText {
        text: root.hello + ", " + Settings.displayName
        font.pixelSize: 44
        font.bold: true
        color: Theme.text
        style: Text.Raised
        styleColor: Theme.alpha(Theme.crust, 0.5)
    }
    StyledText {
        text: {
            const d = I18n.locale.toString(c.date, "dddd, d MMMM");
            const w = root.opts.weather !== false && Weather.ready ? `  ·  ${Weather.icon} ${Math.round(Weather.temp)}° ${Weather.description.toLowerCase()}` : "";
            return d.charAt(0).toUpperCase() + d.slice(1) + w;
        }
        font.pixelSize: 20
        color: Theme.accent
        leftPadding: 2
    }
}
