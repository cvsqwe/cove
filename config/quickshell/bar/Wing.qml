import QtQuick
import QtQuick.Effects
import qs.config

// «Чёлка»: стеклянное крыло под модулями одной стороны панели (размытие обоев — layer_rule qs-bar).
Rectangle {
    property Item target
    visible: Theme.barNotch && !!target && target.width > 0
    x: target ? target.x - 12 : 0
    width: target ? target.width + 24 : 0
    height: Theme.capsuleHeight + 2
    anchors.verticalCenter: target ? target.verticalCenter : undefined
    radius: height / 2
    color: Theme.wing
    border.width: 1
    border.color: Theme.alpha(Theme.text, 0.08)
    RectangularShadow {
        z: -1
        anchors.fill: parent
        radius: parent.radius
        offset.y: 3
        blur: 16
        color: Qt.rgba(0, 0, 0, 0.25)
    }
}
