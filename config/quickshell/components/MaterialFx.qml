import QtQuick
import QtQuick.Effects
import qs.config

// Слой материала поверх фона поверхности (класть ребёнком в скруглённую поверхность, radius — её скругление):
// у «Акрила» — зерно и мягкий блик сверху, у «Матового» — только блик. Сплошному и стеклу не нужен.
Item {
    id: root
    property real radius: 0
    anchors.fill: parent
    visible: Theme.noise || Theme.sheen
    z: -1

    Item {
        id: fx
        anchors.fill: parent
        layer.enabled: root.visible && root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        Rectangle {
            anchors.fill: parent
            visible: Theme.sheen
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Theme.light ? 0.18 : 0.06) }
                GradientStop { position: 0.45; color: "transparent" }
            }
        }
        Image {
            anchors.fill: parent
            visible: Theme.noise
            source: visible ? Qt.resolvedUrl("../assets/noise.png") : ""
            fillMode: Image.Tile
            smooth: false
            opacity: Theme.light ? 0.05 : 0.045
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }
}
