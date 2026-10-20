import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components

// Все достижения: фильтр по игре, полученные — в цвете медали, секретные скрыты до получения.
Item {
    id: root
    property var games: []
    property string filter: ""          // "" — все, "any" — общие, иначе id игры
    signal back()

    readonly property var medal: [Theme.overlay0, "#cd8a5a", "#b9c3cf", Theme.yellow]
    readonly property var list: Profile.achievements.filter(a => filter === "" || (filter === "any" ? a.game === "" : a.game === filter))

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 12

        RowLayout {
            spacing: 14
            IconButton { icon: "arrow_back"; onClicked: root.back() }
            MIcon { icon: "emoji_events"; size: 30; color: Theme.yellow; fill: true }
            ColumnLayout {
                spacing: 0
                StyledText { text: I18n.tr("Достижения"); font.pixelSize: 26; font.bold: true }
                StyledText {
                    text: I18n.tr("Получено ") + Profile.gotCount + I18n.tr(" из ") + Profile.achievements.length
                        + " · " + Math.round(Profile.gotCount / Profile.achievements.length * 100) + "%"
                    color: Theme.overlay1
                }
            }
        }

        // фильтр
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{ id: "", name: I18n.tr("Все"), icon: "apps" }, { id: "any", name: I18n.tr("Общие"), icon: "public" }].concat(root.games)
                Rectangle {
                    required property var modelData
                    readonly property bool on: root.filter === modelData.id
                    width: fr.implicitWidth + 20
                    height: 30
                    radius: 15
                    color: on ? Theme.accent : fm.containsMouse ? Theme.surface1 : Theme.surface0
                    Row {
                        id: fr
                        anchors.centerIn: parent
                        spacing: 6
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: modelData.icon; size: 14; color: parent.parent.on ? Theme.onAccent : Theme.subtext1 }
                        StyledText { anchors.verticalCenter: parent.verticalCenter; text: modelData.name; font.pixelSize: Theme.fontSizeSmall; color: parent.parent.on ? Theme.onAccent : Theme.text }
                    }
                    MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.filter = parent.modelData.id }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            GridLayout {
                width: parent.width
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Repeater {
                    model: root.list
                    Rectangle {
                        id: ac
                        required property var modelData
                        readonly property bool done: !!Profile.got[modelData.id]
                        readonly property bool hidden: !!modelData.secret && !done
                        readonly property var g: root.games.find(x => x.id === modelData.game)
                        Layout.fillWidth: true
                        implicitHeight: 64
                        radius: Theme.radius
                        color: done ? Theme.alpha(root.medal[modelData.tier], 0.1) : Theme.mantle
                        border.width: 1
                        border.color: done ? Theme.alpha(root.medal[modelData.tier], 0.55) : Theme.surface0
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 12
                            Rectangle {
                                implicitWidth: 42; implicitHeight: 42; radius: 21
                                color: ac.done ? Theme.alpha(root.medal[ac.modelData.tier], 0.22) : Theme.surface0
                                MIcon {
                                    anchors.centerIn: parent
                                    icon: ac.hidden ? "help" : ac.done ? "military_tech" : (ac.g?.icon ?? "public")
                                    fill: ac.done
                                    size: 22
                                    color: ac.done ? root.medal[ac.modelData.tier] : Theme.overlay0
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                StyledText { Layout.fillWidth: true; text: ac.hidden ? I18n.tr("Секретное достижение") : ac.modelData.name; font.bold: true; color: ac.done ? Theme.text : Theme.subtext0; elide: Text.ElideRight }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: ac.hidden ? I18n.tr("Узнаешь, когда получишь") : ac.modelData.desc
                                    color: Theme.overlay1
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                            }
                            StyledText {
                                text: "+" + Profile.tierXp[ac.modelData.tier]
                                color: ac.done ? root.medal[ac.modelData.tier] : Theme.overlay0
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
