import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

// Цитата дня из assets/quotes.json: каждый день новая, клик — следующая.
ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)

    spacing: 8
    implicitWidth: root.opts.width ?? 380

    property var quotes: []
    property int shift: 0
    SystemClock { id: clock; precision: SystemClock.Hours }
    readonly property int day: Math.floor((clock.date - new Date(clock.date.getFullYear(), 0, 0)) / 86400000)
    readonly property var q: quotes.length ? quotes[(day * 7 + shift) % quotes.length] : ["", ""]

    FileView {
        path: Quickshell.shellPath("assets/quotes.json")
        onLoaded: { try { root.quotes = JSON.parse(text()); } catch (e) {} }
    }

    MIcon { icon: "format_quote"; fill: true; color: Theme.accent; size: 28 }
    StyledText {
        Layout.fillWidth: true
        text: root.q[0]
        wrapMode: Text.Wrap
        font.pixelSize: root.opts.size ?? 22
        font.italic: true
        color: Theme.text
    }
    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        text: "— " + root.q[1]
        color: Theme.subtext0
        font.pixelSize: Theme.fontSizeSmall + 1
    }

    TapHandler { onTapped: root.shift++ }
}
