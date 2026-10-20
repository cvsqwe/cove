import QtQuick
import QtQuick.Effects
import qs.config
import qs.components

// Подложка под модулями одной стороны панели (размытие обоев — layer_rule qs-bar):
// «Чёлка» — стеклянное крыло, «Острова» — плавающая таблетка во всю высоту панели.
Rectangle {
    property Item target
    readonly property bool pill: Theme.barIslands
    visible: (Theme.barNotch || pill) && !!target && target.width > 0
    x: target ? target.x - 12 : 0
    width: target ? target.width + 24 : 0
    height: pill ? Theme.barHeight : Theme.capsuleHeight + 2
    anchors.verticalCenter: target ? target.verticalCenter : undefined
    radius: pill ? Theme.barRadius : height / 2
    color: pill ? Theme.barPill : Theme.wing
    border.width: pill ? Theme.borderWidth : 1
    border.color: pill ? Theme.edge : Theme.alpha(Theme.text, 0.08)
    MaterialFx { visible: parent.pill && (Theme.noise || Theme.sheen); radius: parent.radius }
    RectangularShadow {
        z: -1
        anchors.fill: parent
        radius: parent.radius
        offset.y: 3
        blur: 16
        color: Qt.rgba(0, 0, 0, 0.25 * Theme.shadow)
    }
}
