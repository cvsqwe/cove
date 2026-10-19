import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Модальный диалог по центру окна: заголовок, текст, своё содержимое, кнопки.
// buttons: [{ text, primary, danger, run }]; Enter — первая primary, Esc — закрыть.
Popup {
    id: root
    property string title: ""
    property string message: ""
    property string icon: ""
    property var buttons: []
    default property alias content: slot.data

    function accept(): void {
        const b = buttons.find(x => x.primary);
        if (b) { if (!b.keep) close(); if (b.run) b.run(); }
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(460, (parent?.width ?? 500) - 40)
    modal: true
    focus: true
    padding: 22
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Cove.alpha(Cove.crust, 0.55) }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 180; easing.type: Easing.OutBack } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }
    background: Rectangle {
        color: Cove.base
        radius: Cove.radius + 4
        border.color: Cove.surface1
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 14
        Keys.onReturnPressed: root.accept()
        RowLayout {
            spacing: 12
            visible: root.title !== ""
            Rectangle {
                visible: root.icon !== ""
                implicitWidth: 38
                implicitHeight: 38
                radius: 12
                color: Cove.alpha(Cove.accent, 0.16)
                KIcon { anchors.centerIn: parent; icon: root.icon; color: Cove.accent; size: 20 }
            }
            KText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Cove.fontSizeLarge
                font.bold: true
            }
        }
        KText {
            Layout.fillWidth: true
            visible: root.message !== ""
            text: root.message
            color: Cove.subtext0
            wrapMode: Text.Wrap
            elide: Text.ElideNone
        }
        ColumnLayout {
            id: slot
            Layout.fillWidth: true
            spacing: 10
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: 4
            spacing: 8
            Repeater {
                model: root.buttons
                KButton {
                    required property var modelData
                    text: modelData.text
                    primary: modelData.primary ?? false
                    danger: modelData.danger ?? false
                    // keep: кнопка сама решает, закрывать ли (например, при ошибке в имени)
                    onClicked: { if (!modelData.keep) root.close(); if (modelData.run) modelData.run(); }
                }
            }
        }
    }
}
