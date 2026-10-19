import QtQuick
import qs.kit

// Рамка выделения (рисуется в координатах содержимого вида)
Rectangle {
    property var items
    property var view
    parent: view.contentItem
    visible: items.banding
    x: Math.min(items.bandA.x, items.bandB.x)
    y: Math.min(items.bandA.y, items.bandB.y)
    width: Math.abs(items.bandA.x - items.bandB.x)
    height: Math.abs(items.bandA.y - items.bandB.y)
    color: Cove.alpha(Cove.accent, 0.14)
    border.color: Cove.alpha(Cove.accent, 0.7)
    radius: 4
    z: 10
}
