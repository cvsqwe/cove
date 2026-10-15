import QtQuick
import QtQuick.Controls
import qs.config

// Текстовое поле. edited() — по Enter или потере фокуса.
TextField {
    id: root

    signal edited(string text)

    implicitWidth: 240
    implicitHeight: 34
    color: Theme.text
    placeholderTextColor: Theme.overlay0
    selectionColor: Theme.accent
    selectedTextColor: Theme.onAccent
    font.family: Theme.font
    font.pixelSize: Theme.fontSizeSmall + 1
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        radius: Theme.radiusSmall + 2
        color: Theme.surface0
        border.width: root.activeFocus ? 1 : 0
        border.color: Theme.accent
    }
    onEditingFinished: root.edited(text)
}
