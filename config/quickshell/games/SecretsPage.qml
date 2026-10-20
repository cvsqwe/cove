import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components

// Секреты (читы): открытые — со словом, неоткрытые — «???» и подсказка, как открыть.
Item {
    id: root
    property var games: []
    property var cheats: []
    property var tierColors: []
    property var chargeText: c => ""
    signal back()
    function unlocked(id: string): bool { return (Store.gameCheats ?? []).includes(id); }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 6
        RowLayout {
            spacing: 14
            IconButton { icon: "arrow_back"; onClicked: root.back() }
            MIcon { icon: "key"; size: 30; color: Theme.yellow; fill: true }
            ColumnLayout {
                spacing: 0
                StyledText { text: I18n.tr("Секреты"); font.pixelSize: 26; font.bold: true }
                StyledText { text: I18n.tr("Открой достижением, потом набери слово прямо во время игры"); color: Theme.overlay1 }
            }
        }
        Flickable {
            Layout.topMargin: 16
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
        GridLayout {
            id: grid
            width: parent.width
            columns: 3
            rowSpacing: 10
            columnSpacing: 10
            Repeater {
                model: root.cheats
                Rectangle {
                    id: sc
                    required property var modelData
                    readonly property bool open: root.unlocked(modelData.id)
                    readonly property var g: root.games.find(x => x.id === modelData.game) ?? ({ icon: "help", color: Theme.accent, name: "" })
                    Layout.fillWidth: true
                    implicitHeight: 128
                    radius: Theme.radius + 2
                    color: open ? Theme.alpha(g.color, 0.1) : Theme.mantle
                    border.width: 1
                    border.color: open ? Theme.alpha(g.color, 0.6) : Theme.surface0
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        RowLayout {
                            spacing: 8
                            MIcon { icon: sc.g.icon; color: sc.g.color; size: 16; fill: true }
                            StyledText { text: sc.g.name; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
                            Item { Layout.fillWidth: true }
                            MIcon { icon: sc.open ? "lock_open" : "lock"; color: sc.open ? Theme.yellow : Theme.overlay0; size: 16 }
                        }
                        StyledText { text: sc.open ? sc.modelData.name : "???"; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                        StyledText {
                            Layout.fillWidth: true
                            text: sc.open ? sc.modelData.desc : I18n.tr("Как открыть: ") + sc.modelData.how.charAt(0).toLowerCase() + sc.modelData.how.slice(1)
                            color: Theme.subtext0
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            spacing: 8
                        Rectangle {
                            visible: sc.open
                            implicitWidth: codeT.implicitWidth + 16
                            implicitHeight: 24
                            radius: 6
                            color: Theme.surface0
                            StyledText { id: codeT; anchors.centerIn: parent; text: sc.modelData.code.toUpperCase(); font.family: "JetBrainsMono Nerd Font"; font.bold: true; color: Theme.yellow }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.chargeText(sc.modelData)
                            color: Theme.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                        }
                    }
                    // уровень чита: бронза, серебро, золото
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        anchors.leftMargin: 0
                        width: 3
                        radius: 2
                        color: root.tierColors[sc.modelData.tier] ?? Theme.surface1
                    }
                }
            }
        }
        }
    }
}
