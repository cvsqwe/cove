import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.config
import qs.services

// Содержимое уведомления: иконка, приложение, заголовок, текст, кнопки действий, ответ.
// notification — живое уведомление (остров) или запись истории Notifs.list (центр управления):
// у записи живой объект в .n, после перезагрузки его нет — остаётся текст без кнопок.
ColumnLayout {
    id: root

    required property var notification
    property int bodyLines: 3
    property bool compact: false
    property bool canReply: true        // в острове нет фокуса клавиатуры — отвечают из центра управления
    property bool replying: false

    readonly property bool isRecord: notification?.key !== undefined
    readonly property var live: isRecord ? notification.n : notification
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var buttons: (live?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool hasReply: canReply && (live?.hasInlineReply ?? false)

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
                StyledText {
                    visible: root.isRecord
                    text: Notifs.ago(root.notification?.time ?? 0)
                    color: Theme.overlay0
                    font.pixelSize: Theme.fontSizeSmall - 1
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
                        onClicked: Notifs.dismiss(root.notification)
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
        visible: root.buttons.length > 0 || (root.hasReply && !root.replying)
        spacing: 6

        Rectangle {
            visible: root.hasReply && !root.replying
            implicitWidth: replyRow.implicitWidth + 22
            implicitHeight: 28
            radius: Theme.radiusSmall
            color: replyBtn.containsMouse ? Theme.alpha(Theme.accent, 0.3) : Theme.alpha(Theme.accent, 0.16)
            Row {
                id: replyRow
                anchors.centerIn: parent
                spacing: 6
                MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "reply"; size: 14; color: Theme.accent }
                StyledText { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Ответить"); font.pixelSize: Theme.fontSizeSmall }
            }
            MouseArea {
                id: replyBtn
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.replying = true; Qt.callLater(() => replyField.forceActiveFocus()); }
            }
        }

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

    // ответ прямо из уведомления (мессенджеры с inline-reply)
    RowLayout {
        Layout.fillWidth: true
        visible: root.replying
        spacing: 6
        SField {
            id: replyField
            Layout.fillWidth: true
            placeholderText: root.live?.inlineReplyPlaceholder || I18n.tr("Ответ…")
            Keys.onEscapePressed: { text = ""; root.replying = false; }
            onAccepted: send()
            function send(): void {
                const t = text.trim();
                if (!t || !root.live) return;
                root.live.sendInlineReply(t);
                text = "";
                root.replying = false;
            }
        }
        IconButton { size: 32; iconSize: 15; icon: "send"; active: true; onClicked: replyField.send() }
    }
    onLiveChanged: if (!live) replying = false
}
