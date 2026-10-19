import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Остров при наведении: плеер (если что-то играет) и быстрые действия.
// Подпись под кнопками показывает, что делает кнопка под курсором.
ColumnLayout {
    id: root

    property bool shown: false
    signal done()   // закрыть остров перед действием — чтобы он не попал на скриншот

    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    spacing: 10

    property string hint: ""

    readonly property var actions: [
        { icon: "screenshot_region", label: I18n.tr("Скриншот области"), run: () => { root.done(); Qt.callLater(Screenshot.area); } },
        { icon: Recorder.recording ? "stop_circle" : "screen_record", label: Recorder.recording ? I18n.tr("Остановить запись") : I18n.tr("Запись экрана"),
          on: Recorder.recording, color: Theme.red, run: () => { root.done(); Recorder.toggle(); } },
        { icon: "colorize", label: I18n.tr("Пипетка"), run: () => { root.done(); Picker.pick(); } },
        { icon: "do_not_disturb_on", label: Store.dnd ? I18n.tr("Не беспокоить: вкл") : I18n.tr("Не беспокоить"), on: Store.dnd, run: () => Toggles.dnd() },
        { icon: "coffee", label: Store.caffeine ? I18n.tr("Не засыпать: вкл") : I18n.tr("Не засыпать"), on: Store.caffeine, run: () => Toggles.caffeine() },
        { icon: "dashboard", label: I18n.tr("Дашборд"), run: () => Panels.toggle("dashboard") },
        { icon: "tune", label: I18n.tr("Центр управления"), run: () => { root.done(); Panels.toggle("control"); } }
    ]

    // плеер
    RowLayout {
        visible: Media.active && Settings.island.media
        Layout.alignment: Qt.AlignHCenter
        spacing: 8
        IconButton { size: 34; iconSize: 18; icon: "skip_previous"; onClicked: Media.player?.previous() }
        IconButton {
            size: 42; iconSize: 22
            icon: Media.playing ? "pause" : "play_arrow"
            active: true
            activeColor: Media.accent
            onClicked: Media.player?.togglePlaying()
        }
        IconButton { size: 34; iconSize: 18; icon: "skip_next"; onClicked: Media.player?.next() }
    }

    // быстрые действия
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 6
        Repeater {
            model: root.actions
            IconButton {
                id: b
                required property var modelData
                size: 36
                iconSize: 17
                icon: modelData.icon
                active: !!modelData.on
                activeColor: modelData.color ?? Theme.accent
                onClicked: modelData.run()
                HoverHandler { onHoveredChanged: root.hint = hovered ? b.modelData.label : (root.hint === b.modelData.label ? "" : root.hint) }
            }
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: root.hint || " "
        color: Theme.subtext0
        font.pixelSize: Theme.fontSizeSmall
    }
}
