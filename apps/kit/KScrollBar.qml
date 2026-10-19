import QtQuick
import QtQuick.Controls

// Тонкая полоса прокрутки, расширяется при наведении
ScrollBar {
    id: bar
    minimumSize: 0.06
    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 8 : 4
        radius: width / 2
        color: bar.pressed ? Cove.overlay1 : Cove.surface2
        opacity: bar.active || bar.hovered ? 1 : 0.0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on implicitWidth { NumberAnimation { duration: 120 } }
    }
    background: Item {}
}
