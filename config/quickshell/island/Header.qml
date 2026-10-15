import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.components
import qs.services

// Содержимое капсулы. Слева — постоянные индикаторы (запись, фокус), дальше — одно из:
// тост (воркспейс/раскладка/Caps), плеер, или «покой» (часы / погода / приветствие).
Item {
    id: root

    property var toast: null // { icon, text, color }
    readonly property bool media: Media.active && !GameMode.active
    readonly property string content: toast ? "toast" : media ? "media" : "idle"
    readonly property var isl: Settings.island

    readonly property real mainWidth: content === "toast" ? toastRow.implicitWidth
        : content === "media" ? mediaRow.implicitWidth
        : idleRow.implicitWidth

    implicitWidth: indicators.implicitWidth + (indicators.implicitWidth > 0 ? 10 : 0) + mainWidth
    implicitHeight: Theme.barHeight - 8

    SystemClock {
        id: clock
        precision: root.isl.clockFormat.includes("ss") ? SystemClock.Seconds : SystemClock.Minutes
    }

    function greeting(): string {
        const h = clock.date.getHours();
        return h < 5 ? I18n.tr("Доброй ночи") : h < 12 ? I18n.tr("Доброе утро") : h < 18 ? I18n.tr("Добрый день") : I18n.tr("Добрый вечер");
    }

    // ---- индикаторы ----
    Row {
        id: indicators
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // запись экрана: пульсирующая точка + время, клик — стоп
        Rectangle {
            visible: Recorder.recording
            width: recRow.implicitWidth + 16
            height: 22
            radius: 11
            color: Theme.alpha(Theme.red, 0.2)
            Row {
                id: recRow
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8; height: 8; radius: 4
                    color: Theme.red
                    SequentialAnimation on opacity {
                        running: Recorder.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }
                StyledText { text: Recorder.timeText; color: Theme.red; font.pixelSize: Theme.fontSizeSmall; font.bold: true }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Recorder.stop() }
        }

        // фокус-таймер: кольцо прогресса + время, клик — пауза
        Item {
            visible: Focus.active
            width: focusRow.implicitWidth
            height: 22
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Focus.paused = !Focus.paused }
        Row {
            id: focusRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Item {
                width: 18; height: 18
                anchors.verticalCenter: parent.verticalCenter
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: Theme.surface1; strokeWidth: 3; fillColor: "transparent"
                        PathAngleArc { centerX: 9; centerY: 9; radiusX: 7; radiusY: 7; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: Focus.phase === "break" ? Theme.green : Theme.red
                        strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 9; centerY: 9; radiusX: 7; radiusY: 7; startAngle: -90; sweepAngle: 360 * Focus.progress }
                    }
                }
            }
            StyledText {
                text: (Focus.paused ? "⏸ " : "") + Focus.timeText
                color: Focus.phase === "break" ? Theme.green : Theme.text
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
        }
    }

    Item {
        id: main
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.mainWidth
        height: parent.height

        // ---- тост ----
        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            opacity: root.content === "toast" ? 1 : 0
            visible: opacity > 0
            scale: root.content === "toast" ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
            MIcon { icon: root.toast?.icon ?? ""; color: root.toast?.color ?? Theme.accent; size: Theme.iconSize }
            StyledText { text: root.toast?.text ?? ""; font.bold: true }
        }

        // ---- покой ----
        RowLayout {
            id: idleRow
            anchors.centerIn: parent
            spacing: 8
            opacity: root.content === "idle" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }

            StyledText {
                visible: root.isl.idle === "weather" && Weather.ready
                text: `${Weather.icon} ${Math.round(Weather.temp)}°`
                color: Theme.yellow
            }
            StyledText {
                visible: root.isl.idle === "greeting"
                text: `${root.greeting()}, ${Settings.displayName}`
                color: Theme.accent
            }
            Rectangle { visible: root.isl.idle !== "clock"; implicitWidth: 4; implicitHeight: 4; radius: 2; color: Theme.surface2 }
            StyledText {
                text: I18n.locale.toString(clock.date, root.isl.clockFormat)
                font.bold: true
                color: Theme.text
            }
            Rectangle { visible: root.isl.showDate; implicitWidth: 4; implicitHeight: 4; radius: 2; color: Theme.accent }
            StyledText {
                visible: root.isl.showDate
                text: I18n.locale.toString(clock.date, root.isl.dateFormat)
                color: Theme.subtext0
            }
        }

        // ---- плеер ----
        RowLayout {
            id: mediaRow
            anchors.centerIn: parent
            spacing: 10
            opacity: root.content === "media" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }

            Rectangle {
                implicitWidth: 22
                implicitHeight: 22
                radius: 11
                color: Theme.surface0
                clip: true
                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.art
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(64, 64)
                    visible: status === Image.Ready
                    RotationAnimation on rotation {
                        running: Media.playing && cover.visible && Settings.appearance.animations
                        from: cover.rotation
                        to: cover.rotation + 360
                        duration: 9000
                        loops: Animation.Infinite
                    }
                }
                MIcon { anchors.centerIn: parent; visible: !cover.visible; icon: "󰎆"; color: Media.accent }
            }
            StyledText {
                Layout.maximumWidth: 200
                text: Media.title
                elide: Text.ElideRight
                color: Theme.text
                font.weight: Font.Medium
            }
            StyledText {
                visible: Media.artist !== ""
                Layout.maximumWidth: 140
                Layout.leftMargin: -4
                text: Media.artist
                elide: Text.ElideRight
                color: Theme.subtext0
            }
            // мини-эквалайзер; на паузе на его месте — значок паузы (ширина та же — остров не прыгает)
            Item {
                visible: root.isl.visualizer
                implicitWidth: eq.implicitWidth
                implicitHeight: eq.implicitHeight
                Visualizer {
                    id: eq
                    bands: 5
                    barWidth: 3
                    spacing: 2
                    maxHeight: 14
                    minHeight: 3
                    mirrored: true
                    opacity: Media.playing ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                }
                MIcon {
                    anchors.centerIn: parent
                    icon: "pause"
                    size: 13
                    color: Theme.overlay1
                    opacity: Media.playing ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                }
            }
            StyledText {
                text: I18n.locale.toString(clock.date, root.isl.clockFormat)
                color: Theme.subtext0
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
