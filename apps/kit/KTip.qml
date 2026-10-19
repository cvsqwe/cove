import QtQuick
import QtQuick.Controls

// Подсказка при наведении (появляется с задержкой)
ToolTip {
    id: tip
    property bool shown: false
    visible: shown && text !== ""
    delay: 600
    padding: 6
    background: Rectangle { color: Cove.crust; radius: Cove.radiusSmall; border.color: Cove.surface1 }
    contentItem: KText { text: tip.text; font.pixelSize: Cove.fontSizeSmall }
}
