import QtQuick
import qs.config

// Сегментированный выбор: [{ value, label, icon }]. Подсветка «переезжает» к выбранному.
Rectangle {
    id: root

    property var options: []
    property var current
    signal picked(var value)

    readonly property int idx: Math.max(0, options.findIndex(o => o.value === current))

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 34
    radius: Theme.radiusSmall + 2
    color: Theme.surface0

    Rectangle {
        id: hl
        y: 4
        height: parent.height - 8
        radius: Theme.radiusSmall
        color: Theme.accent
        readonly property var it: rep.count > 0 && root.width > 0 ? rep.itemAt(root.idx) : null
        x: (it?.x ?? 0) + 4
        width: it?.width ?? 0
        Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
    }

    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: rep
            model: root.options

            Item {
                required property var modelData
                required property int index
                width: lbl.implicitWidth + 24
                height: root.height - 8

                StyledText {
                    id: lbl
                    anchors.centerIn: parent
                    text: (modelData.icon ? modelData.icon + (modelData.label ? "  " : "") : "") + (modelData.label ?? "")
                    color: index === root.idx ? Theme.onAccent : Theme.subtext1
                    font.pixelSize: Theme.fontSizeSmall + 1
                    font.bold: index === root.idx
                    Behavior on color { ColorAnimation { duration: Theme.anim } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.value)
                }
            }
        }
    }
}
