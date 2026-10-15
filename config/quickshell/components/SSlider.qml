import QtQuick
import QtQuick.Layouts
import qs.config

// Слайдер с диапазоном, шагом и подписью значения.
RowLayout {
    id: root

    property real from: 0
    property real to: 1
    property real step: 0.01
    property real value: 0
    property int decimals: 0
    property string suffix: ""
    property bool percent: false   // показывать как %
    property var format: null      // функция v => строка
    signal moved(real value)

    spacing: 12

    function snap(v: real): real {
        const s = Math.round((v - from) / step) * step + from;
        return Math.max(from, Math.min(to, Number(s.toFixed(4))));
    }
    readonly property string label: format ? format(value)
        : percent ? Math.round(value * 100) + "%"
        : value.toFixed(decimals) + suffix

    Item {
        Layout.preferredWidth: 220
        implicitHeight: 24

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: Theme.surface1

            Rectangle {
                width: parent.width * (root.value - root.from) / Math.max(0.0001, root.to - root.from)
                height: parent.height
                radius: 3
                color: Theme.accent
            }
        }
        Rectangle {
            id: knob
            width: 18
            height: 18
            radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - width) * (root.value - root.from) / Math.max(0.0001, root.to - root.from)
            color: Theme.text
            border.width: 3
            border.color: Theme.accent
            scale: area.pressed ? 1.2 : area.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function upd(x: real): void {
                const t = Math.max(0, Math.min(1, (x - 6) / (width - 12)));
                const v = root.snap(root.from + t * (root.to - root.from));
                if (v !== root.value) root.moved(v);
            }
            onPressed: m => upd(m.x)
            onPositionChanged: m => { if (pressed) upd(m.x); }
            onWheel: w => root.moved(root.snap(root.value + (w.angleDelta.y > 0 ? root.step : -root.step)))
        }
    }

    StyledText {
        Layout.preferredWidth: 58
        horizontalAlignment: Text.AlignRight
        text: root.label
        color: Theme.subtext1
        font.pixelSize: Theme.fontSizeSmall + 1
    }
}
