import QtQuick
import Quickshell
import qs.config
import qs.components

Item {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: true
    signal setOpt(string key, var value)
    implicitWidth: 200
    implicitHeight: 200

    SystemClock { id: c; precision: root.opts.seconds !== false ? SystemClock.Seconds : SystemClock.Minutes }
    readonly property real hours: c.date.getHours() % 12 + c.date.getMinutes() / 60
    readonly property real minutes: c.date.getMinutes() + c.date.getSeconds() / 60

    component Hand: Item {
        property real len
        property real thick
        property color color
        anchors.fill: parent
        Rectangle {
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - parent.len
            width: parent.thick
            height: parent.len + 12
            radius: width / 2
            color: parent.color
            antialiasing: true
        }
    }

    Repeater {
        model: 60
        Item {
            required property int index
            readonly property bool hour: index % 5 === 0
            anchors.fill: parent
            rotation: index * 6
            visible: hour || !root.opts.numbers
            Rectangle {
                x: parent.width / 2 - width / 2
                y: 4
                width: parent.hour ? 3 : 1.5
                height: parent.hour ? 12 : 5
                radius: 1
                color: parent.hour ? Theme.text : Theme.overlay0
                antialiasing: true
            }
        }
    }
    Repeater {
        model: root.opts.numbers ? 12 : 0
        StyledText {
            required property int index
            readonly property real a: (index + 1) * Math.PI / 6
            x: root.width / 2 + Math.sin(a) * 74 - width / 2
            y: root.height / 2 - Math.cos(a) * 74 - height / 2
            text: index + 1
            color: Theme.subtext1
            font.pixelSize: 15
            font.bold: (index + 1) % 3 === 0
        }
    }

    Hand { len: 50; thick: 6; color: Theme.text; rotation: root.hours * 30 }
    Hand { len: 74; thick: 4; color: Theme.subtext1; rotation: root.minutes * 6 }
    Hand { visible: root.opts.seconds !== false; len: 82; thick: 2; color: Theme.accent; rotation: c.date.getSeconds() * 6 }
    Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: Theme.accent }
}
