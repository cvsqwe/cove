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
    readonly property var items: opts.items ?? []
    readonly property int remaining: items.filter(i => !i.d).length
    spacing: 8
    implicitWidth: 300

    function toggle(i: int): void {
        const l = JSON.parse(JSON.stringify(items));
        l[i].d = !l[i].d;
        root.setOpt("items", l);
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText { text: "" + (root.opts.title || I18n.tr("Задачи")); font.bold: true; color: Theme.accent; Layout.fillWidth: true }
        StyledText { text: root.remaining > 0 ? root.remaining + I18n.tr(" осталось") : I18n.tr("всё готово"); color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
    }
    Repeater {
        model: root.items
        Item {
            id: row
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: rl.implicitHeight
            implicitWidth: rl.implicitWidth
          RowLayout {
            id: rl
            width: parent.width
            spacing: 10
            Rectangle {
                implicitWidth: 20
                implicitHeight: 20
                radius: 6
                color: row.modelData.d ? Theme.accent : "transparent"
                border.width: row.modelData.d ? 0 : 2
                border.color: hov.containsMouse ? Theme.accent : Theme.overlay0
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                MIcon { anchors.centerIn: parent; visible: row.modelData.d; icon: "󰄬"; color: Theme.onAccent; size: 13 }
            }
            StyledText {
                Layout.fillWidth: true
                text: row.modelData.t
                color: row.modelData.d ? Theme.overlay0 : Theme.text
                font.strikeout: row.modelData.d
                wrapMode: Text.Wrap
            }
          }
            MouseArea {
                id: hov
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.editing
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggle(row.index)
            }
        }
    }
    StyledText {
        visible: root.items.length === 0
        text: I18n.tr("Пусто — пункты добавляются в редакторе")
        color: Theme.overlay0
        font.pixelSize: Theme.fontSizeSmall
    }
}
