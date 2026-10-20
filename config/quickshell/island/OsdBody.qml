import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Громкость, микрофон и яркость в острове. Вид — Settings.appearance.osdStyle:
//   slider — значок, ползунок и число; ring — значок в кольце и крупное число; minimal — одна тонкая полоса.
Item {
    id: root
    property bool shown: false
    property string kind: "volume"   // volume | mic | brightness
    readonly property bool mic: kind === "mic"
    readonly property bool bright: kind === "brightness"
    readonly property string look: Settings.appearance.osdStyle ?? "slider"

    readonly property real value: bright ? Power.brightness : mic ? Audio.micVolume : Audio.volume
    readonly property bool muted: !bright && (mic ? Audio.micMuted : Audio.muted)
    readonly property color tint: bright ? Theme.yellow : mic ? Theme.accent2 : Theme.accent
    readonly property string icon: bright ? (Power.brightness > 0.5 ? "brightness_high" : "brightness_medium")
        : mic ? (Audio.micMuted ? "mic_off" : "mic") : Audio.icon(Audio.volume, Audio.muted)
    function set(v: real): void { bright ? Power.setBrightness(v) : mic ? Audio.setMic(v) : Audio.setVolume(v); }
    function toggle(): void { if (!bright) mic ? Audio.toggleMic() : Audio.toggleMute(); }

    // размер тела острова для каждого вида (Island.qml)
    readonly property real bodyW: look === "ring" ? 168 : look === "minimal" ? 280 : 360
    readonly property real bodyH: look === "ring" ? 64 : look === "minimal" ? 22 : 46

    implicitHeight: look === "ring" ? 50 : look === "minimal" ? 8 : 26
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    // ---- ползунок ----
    RowLayout {
        anchors.fill: parent
        visible: root.look === "slider"
        spacing: 12
        MIcon {
            icon: root.icon
            color: root.muted ? Theme.overlay1 : root.tint
            size: 18
            MouseArea { anchors.fill: parent; onClicked: root.toggle() }
        }
        Slider {
            Layout.fillWidth: true
            value: root.value
            dim: root.muted
            color: root.tint
            onMoved: v => root.set(v)
        }
        StyledText {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "—" : Math.round(root.value * 100)
        }
    }

    // ---- кольцо ----
    Row {
        anchors.centerIn: parent
        visible: root.look === "ring"
        spacing: 14
        Item {
            width: 50; height: 50
            RingArc {
                anchors.fill: parent
                thickness: 4
                value: root.value
                color: root.muted ? Theme.overlay1 : root.tint
            }
            MIcon {
                anchors.centerIn: parent
                icon: root.icon
                fill: !root.muted
                color: root.muted ? Theme.overlay1 : root.tint
                size: 20
                MouseArea { anchors.fill: parent; onClicked: root.toggle() }
            }
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            text: root.muted ? "—" : Math.round(root.value * 100) + "%"
            font.pixelSize: 24
            font.bold: true
            color: root.muted ? Theme.overlay1 : Theme.text
        }
    }

    // ---- тонкая полоса ----
    Rectangle {
        anchors.fill: parent
        visible: root.look === "minimal"
        radius: height / 2
        color: Theme.surface0
        Rectangle {
            width: Math.max(parent.height, parent.width * Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: root.muted ? Theme.overlay0 : root.tint
            Behavior on width { NumberAnimation { duration: 90 } }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            function upd(x: real): void { root.set(Math.max(0, Math.min(1, x / width))); }
            onPressed: m => upd(m.x)
            onPositionChanged: m => { if (pressed) upd(m.x); }
        }
    }
}
