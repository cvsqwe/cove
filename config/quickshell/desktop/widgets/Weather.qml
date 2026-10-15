import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

ColumnLayout {
    id: root
    property var opts: ({})
    property bool editing: false
    property bool shown: Weather.ready
    signal setOpt(string key, var value)
    spacing: 14

    RowLayout {
        spacing: 16
        MIcon { icon: Weather.icon; size: 58; color: Theme.yellow }
        ColumnLayout {
            spacing: 0
            StyledText { text: Math.round(Weather.temp) + "°"; font.pixelSize: 42; font.bold: true }
            StyledText { text: Weather.description; color: Theme.subtext1 }
            StyledText { text: Settings.general.city + I18n.tr(" · ощущается ") + Math.round(Weather.feels) + "°"; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
        }
    }
    Rectangle { visible: root.opts.forecast !== false; Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.text, 0.1) }
    RowLayout {
        visible: root.opts.forecast !== false
        Layout.fillWidth: true
        spacing: 18
        Repeater {
            model: Weather.daily.slice(0, 4)
            ColumnLayout {
                required property var modelData
                required property int index
                spacing: 4
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: index === 0 ? I18n.tr("Сегодня") : I18n.locale.toString(modelData.day, "ddd")
                    color: Theme.subtext0
                    font.pixelSize: Theme.fontSizeSmall
                }
                MIcon { Layout.alignment: Qt.AlignHCenter; icon: Weather.iconFor(modelData.code, true); size: 24; color: Theme.yellow }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Math.round(modelData.max) + "° " ; font.bold: true; font.pixelSize: Theme.fontSizeSmall }
                StyledText { Layout.alignment: Qt.AlignHCenter; text: Math.round(modelData.min) + "°"; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
            }
        }
    }
}
