import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

// Разговор с ассистентом в лаунчере (префикс *). Вопрос — в поле поиска, Enter — спросить.
ColumnLayout {
    id: root
    spacing: 8

    readonly property string provider: Settings.assistant.provider
    readonly property string providerLabel: Assistant.providers.find(p => p.value === provider)?.label ?? provider

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: chat.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
        // ответ растёт — держим низ на виду
        onContentHeightChanged: if (Assistant.busy) contentY = Math.max(0, contentHeight - height)

        ColumnLayout {
            id: chat
            width: flick.width - 6
            spacing: 10

            Repeater {
                model: Assistant.messages
                Rectangle {
                    id: msg
                    required property var modelData
                    readonly property bool mine: modelData.role === "user"
                    Layout.alignment: mine ? Qt.AlignRight : Qt.AlignLeft
                    Layout.maximumWidth: chat.width * (mine ? 0.85 : 1)
                    Layout.preferredWidth: mine ? body.implicitWidth + 24 : chat.width
                    implicitHeight: body.implicitHeight + 18
                    radius: Theme.radius
                    color: mine ? Theme.alpha(Theme.accent, 0.16) : Theme.surface0

                    TextEdit {
                        id: body
                        x: 12
                        y: 9
                        width: parent.width - 24
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: msg.mine ? TextEdit.PlainText : TextEdit.MarkdownText
                        text: msg.modelData.content || "…"
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.onAccent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }
        }

        // пустой разговор — подсказка
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 40
            visible: Assistant.messages.length === 0
            spacing: 8
            MIcon { Layout.alignment: Qt.AlignHCenter; icon: "auto_awesome"; color: Theme.accent; size: 36 }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.provider === "off" ? I18n.tr("Ассистент выключен. Включить: Настройки → Лаунчер → Ассистент.")
                    : I18n.tr("Спросите что угодно и нажмите Enter. Разговор сохранится, пока не начнёте новый.")
                color: Theme.subtext0
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: Assistant.error !== ""
        text: Assistant.error
        color: Theme.red
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontSizeSmall
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        MIcon { icon: Assistant.busy ? "progress_activity" : "auto_awesome"; color: Theme.overlay1; size: 14
            RotationAnimation on rotation { running: Assistant.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
        }
        StyledText {
            Layout.fillWidth: true
            text: (Assistant.busy ? I18n.tr("Отвечает") + " · " : "") + root.providerLabel + (Settings.assistant.model ? " · " + Settings.assistant.model : "")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
        SButton {
            visible: Assistant.busy
            icon: "stop"
            text: I18n.tr("Стоп")
            onClicked: Assistant.stop()
        }
        SButton {
            visible: !Assistant.busy && Assistant.lastAnswer !== ""
            icon: "content_copy"
            text: I18n.tr("Копировать")
            onClicked: Quickshell.execDetached(["wl-copy", Assistant.lastAnswer])
        }
        SButton {
            visible: Assistant.messages.length > 0
            icon: "add_comment"
            text: I18n.tr("Новый чат")
            onClicked: Assistant.reset()
        }
    }
}
