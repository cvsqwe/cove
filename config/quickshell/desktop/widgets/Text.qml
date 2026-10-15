import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    readonly property int align: opts.align === "center" ? Qt.AlignHCenter : opts.align === "right" ? Qt.AlignRight : Qt.AlignLeft
    spacing: 6

    StyledText {
        Layout.alignment: root.align
        Layout.maximumWidth: 900
        text: root.opts.text || I18n.tr("Текст")
        font.pixelSize: root.opts.size ?? 34
        font.italic: !!root.opts.italic
        font.bold: !root.opts.italic
        color: root.opts.accent ? Theme.accent : Theme.text
        horizontalAlignment: root.opts.align === "center" ? Text.AlignHCenter : root.opts.align === "right" ? Text.AlignRight : Text.AlignLeft
        wrapMode: Text.Wrap
        style: Text.Raised
        styleColor: Theme.alpha(Theme.crust, 0.5)
    }
    StyledText {
        visible: !!root.opts.author
        Layout.alignment: root.align
        text: "— " + root.opts.author
        color: Theme.subtext0
        font.pixelSize: Math.max(13, (root.opts.size ?? 34) * 0.45)
    }
}
