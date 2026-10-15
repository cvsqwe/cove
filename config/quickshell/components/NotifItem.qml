import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.services

// Содержимое уведомления: иконка, приложение, заголовок, текст, кнопки действий.
// Используется в острове и в истории центра управления.
ColumnLayout {
    id: root

    required property var notification
    property int bodyLines: 3
    property bool compact: false

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var buttons: (notification?.actions ?? []).filter(a => a.identifier !== "default")

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: root.compact ? 32 : 42
            implicitHeight: implicitWidth
            radius: Theme.radiusSmall
            color: Theme.surface0
            visible: true

            IconImage {
                id: img
                anchors.fill: parent
                source: Notifs.iconFor(root.notification)
                visible: status === Image.Ready
            }
            MIcon {
                id: icon
                anchors.centerIn: parent
                visible: !img.visible
                icon: "󰂚"
                color: root.critical ? Theme.red : Theme.accent
                size: 18
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.notification?.appName || I18n.tr("Уведомление")
                    color: root.critical ? Theme.red : Theme.accent
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
                MIcon {
                    icon: "󰅖"
                    color: close.containsMouse ? Theme.red : Theme.overlay1
                    MouseArea {
                        id: close
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification?.body ?? ""
                textFormat: Text.StyledText
                color: Theme.subtext0
                font.pixelSize: Theme.fontSizeSmall + 1
                wrapMode: Text.Wrap
                maximumLineCount: root.bodyLines
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        visible: root.buttons.length > 0
        spacing: 6

        Repeater {
            model: root.buttons

            Rectangle {
                required property var modelData
                implicitWidth: label.implicitWidth + 22
                implicitHeight: 28
                radius: Theme.radiusSmall
                color: act.containsMouse ? Theme.surface1 : Theme.surface0

                StyledText {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.text
                    font.pixelSize: Theme.fontSizeSmall
                }
                MouseArea {
                    id: act
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
