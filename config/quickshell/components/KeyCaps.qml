import QtQuick
import qs.config

// Сочетание клавиш в виде «клавиш»: [󰖳] [Shift] [R].
Row {
    id: root

    property var keys: []
    property bool dim: false
    spacing: 4

    Repeater {
        model: root.keys

        Rectangle {
            required property string modelData
            width: Math.max(26, t.implicitWidth + 14)
            height: 26
            radius: 6
            color: Theme.surface0
            border.width: 1
            border.color: Theme.surface2
            opacity: root.dim ? 0.5 : 1

            Rectangle { // нижняя «грань» клавиши
                anchors.bottom: parent.bottom
                width: parent.width
                height: 3
                radius: 6
                color: Theme.surface2
                opacity: 0.6
            }
            StyledText {
                id: t
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -1
                text: parent.modelData
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
    }
}
