import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Группа уведомлений одного приложения в центре управления.
// Свёрнута — последнее уведомление и «стопка» под ним; клик по «Все N» — раскрыть.
Item {
    id: g

    required property string modelData   // приложение (ключ группы в Notifs.groups)
    property bool expanded: false
    readonly property var group: Notifs.groups.find(x => x.app === modelData) ?? null
    readonly property var items: group?.items ?? []
    readonly property bool many: items.length > 1
    readonly property bool stacked: many && !expanded

    implicitHeight: card.implicitHeight + (stacked ? 10 : 0)

    // «стопка» под свёрнутой группой
    Rectangle {
        visible: g.stacked && g.items.length > 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width - 36
        height: 20
        radius: Theme.radius
        color: Theme.alpha(Theme.mantle, 0.55)
    }
    Rectangle {
        visible: g.stacked
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: g.items.length > 2 ? 5 : 0
        width: parent.width - 18
        height: 20
        radius: Theme.radius
        color: Theme.alpha(Theme.mantle, 0.8)
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + 24
        radius: Theme.radius
        color: Theme.mantle

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                visible: g.many
                spacing: 8
                StyledText {
                    Layout.fillWidth: true
                    text: g.modelData
                    font.bold: true
                    font.pixelSize: Theme.fontSizeSmall + 1
                    elide: Text.ElideRight
                }
                Rectangle {
                    implicitWidth: more.implicitWidth + 20
                    implicitHeight: 24
                    radius: 12
                    color: moreArea.containsMouse ? Theme.surface1 : Theme.surface0
                    Row {
                        id: more
                        anchors.centerIn: parent
                        spacing: 4
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: g.expanded ? I18n.tr("Свернуть") : I18n.tr("Все {0}", g.items.length)
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: g.expanded ? "expand_less" : "expand_more"; size: 14; color: Theme.overlay1 }
                    }
                    MouseArea {
                        id: moreArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: g.expanded = !g.expanded
                    }
                }
                MIcon {
                    icon: "clear_all"
                    size: 18
                    color: clearArea.containsMouse ? Theme.red : Theme.overlay1
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismissApp(g.modelData)
                    }
                }
            }

            Repeater {
                model: ScriptModel { values: (g.expanded ? g.items : g.items.slice(0, 1)).map(i => i.key) }
                NotifItem {
                    required property string modelData
                    Layout.fillWidth: true
                    notification: g.items.find(i => i.key === modelData) ?? null
                    compact: true
                    bodyLines: g.expanded ? 3 : 4
                }
            }
        }
    }
}
