import QtQuick
import qs.config

Rectangle {
    default property alias content: inner.data
    property int padding: 14

    implicitWidth: inner.childrenRect.width + padding * 2
    implicitHeight: 250
    radius: Theme.radius
    color: Theme.mantle
    border.width: 1
    border.color: Theme.surface0

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.padding
    }
}
