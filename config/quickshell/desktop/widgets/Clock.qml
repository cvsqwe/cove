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
    readonly property int align: opts.align === "center" ? Qt.AlignHCenter : opts.align === "right" ? Qt.AlignRight : Qt.AlignLeft
    spacing: -6

    SystemClock { id: c; precision: root.opts.seconds ? SystemClock.Seconds : SystemClock.Minutes }

    StyledText {
        Layout.alignment: root.align
        text: Qt.formatDateTime(c.date, (root.opts.format === "12" ? "h:mm" : "HH:mm") + (root.opts.seconds ? ":ss" : ""))
        font.pixelSize: 110
        font.weight: root.opts.weight === "light" ? Font.Light : Font.Bold
        color: Theme.text
        style: Text.Raised
        styleColor: Theme.alpha(Theme.crust, 0.5)
    }
    StyledText {
        visible: root.opts.date !== false
        Layout.alignment: root.align
        text: { const s = I18n.locale.toString(c.date, "dddd, d MMMM"); return s.charAt(0).toUpperCase() + s.slice(1); }
        font.pixelSize: 24
        color: Theme.accent
        leftPadding: 6
        rightPadding: 6
    }
}
