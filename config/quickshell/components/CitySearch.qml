import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.config
import qs.services

// Поиск города (open-meteo, без ключа): пишет город и координаты в Settings.general.
// Для погоды, восхода/заката (Sun) и ночного света.
ColumnLayout {
    id: root
    spacing: 6

    property var results: []

    Process {
        id: geo
        property string q: ""
        command: ["curl", "-sf", "-m", "10", `https://geocoding-api.open-meteo.com/v1/search?count=5&language=${I18n.en ? "en" : "ru"}&name=` + encodeURIComponent(q)]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.results = JSON.parse(text).results ?? []; } catch (e) { root.results = []; }
            }
        }
    }
    Timer { id: debounce; interval: 350; onTriggered: if (geo.q) geo.running = true }

    SField {
        id: field
        Layout.fillWidth: true
        placeholderText: Settings.general.city || I18n.tr("Найти город…")
        onTextChanged: { geo.q = text.trim(); if (geo.q) debounce.restart(); else root.results = []; }
    }

    Repeater {
        model: root.results
        Rectangle {
            id: item
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.radiusSmall
            color: ma.containsMouse ? Theme.surface1 : Theme.surface0
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                MIcon { icon: "location_on"; color: Theme.accent; size: 16 }
                StyledText { text: item.modelData.name; font.bold: true }
                StyledText {
                    Layout.fillWidth: true
                    text: [item.modelData.admin1, item.modelData.country].filter(Boolean).join(", ")
                    color: Theme.overlay1
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const g = Settings.general, c = item.modelData;
                    g.city = c.name;
                    g.latitude = c.latitude;
                    g.longitude = c.longitude;
                    Qt.callLater(Weather.refresh);
                    field.text = ""; // очищает и список — последним
                }
            }
        }
    }
}
