import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.services

// Погода сейчас, прогноз на 3 дня и курсы валют.
Card {
    id: card
    implicitWidth: 220

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            spacing: 10
            MIcon {
                icon: Weather.ready ? Weather.icon : "󰖐"
                color: Theme.yellow
                size: 38
            }
            ColumnLayout {
                spacing: 0
                StyledText {
                    text: Weather.ready ? Math.round(Weather.temp) + "°" : "—"
                    font.pixelSize: 26
                    font.bold: true
                }
                StyledText {
                    text: Settings.general.city
                    color: Theme.overlay1
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Weather.ready ? I18n.tr("{0}\nОщущается {1}° · ветер {2} м/с", Weather.description, Math.round(Weather.feels), Math.round(Weather.wind / 3.6)) : I18n.tr("Загрузка…")
            color: Theme.subtext0
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }

        Repeater {
            model: Weather.daily.slice(1, 4)
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                StyledText {
                    Layout.preferredWidth: 30
                    text: I18n.locale.toString(modelData.day, "ddd")
                    color: Theme.subtext1
                    font.pixelSize: Theme.fontSizeSmall
                }
                MIcon {
                    icon: Weather.iconFor(modelData.code, true)
                    color: Theme.yellow
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: `${Math.round(modelData.max)}° / ${Math.round(modelData.min)}°`
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }

        RowLayout {
            Layout.fillWidth: true
            visible: Weather.usd > 0
            StyledText { text: "$"; color: Theme.green; font.bold: true }
            StyledText { text: Weather.usd.toFixed(2); font.pixelSize: Theme.fontSizeSmall }
            Item { Layout.fillWidth: true }
            StyledText { text: "€"; color: Theme.accent2; font.bold: true }
            StyledText { text: Weather.eur.toFixed(2); font.pixelSize: Theme.fontSizeSmall }
        }
    }
}
