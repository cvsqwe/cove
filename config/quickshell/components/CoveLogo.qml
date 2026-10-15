import QtQuick
import QtQuick.Shapes
import qs.config

// Знак Cove: бухта (дуга берега, открытая вправо) и волна внутри. Рисуется векторно в цветах темы;
// color2 — второй цвет градиента (по умолчанию однотонно). progress 0→1 — прорисовка контура.
Item {
    id: root

    property real size: 24
    property color color: Theme.accent
    property color color2: color
    property color waveColor: color
    property real progress: 1
    // на мелких размерах вторая волна сливается — оставляем одну
    readonly property bool detailed: size >= 28
    readonly property real k: size / 64

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // берег: дуга r=24 вокруг (32,32) от -48° до 48° через левую сторону
        ShapePath {
            strokeWidth: (root.detailed ? 7 : 8) * root.k
            strokeColor: root.color
            strokeGradient: LinearGradient {
                x1: 0; y1: 0; x2: root.size; y2: root.size
                GradientStop { position: 0; color: root.color }
                GradientStop { position: 1; color: root.color2 }
            }
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            trim.end: root.progress
            startX: (32 + 24 * 0.669) * root.k; startY: (32 - 24 * 0.743) * root.k
            PathArc {
                x: (32 + 24 * 0.669) * root.k; y: (32 + 24 * 0.743) * root.k
                radiusX: 24 * root.k; radiusY: 24 * root.k
                useLargeArc: true
                direction: PathArc.Counterclockwise
            }
        }

        // волна
        ShapePath {
            strokeWidth: (root.detailed ? 4.5 : 6) * root.k
            strokeColor: root.waveColor
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            trim.end: Math.max(0, root.progress * 1.6 - 0.6)
            startX: (root.detailed ? 21 : 20) * root.k; startY: (root.detailed ? 30 : 32) * root.k
            PathQuad {
                x: 32 * root.k; y: (root.detailed ? 30 : 32) * root.k
                controlX: 26.5 * root.k; controlY: (root.detailed ? 24 : 25) * root.k
            }
            PathQuad {
                x: (root.detailed ? 43 : 44) * root.k; y: (root.detailed ? 30 : 32) * root.k
                controlX: 37.5 * root.k; controlY: (root.detailed ? 36 : 39) * root.k
            }
        }

        // вторая, тише
        ShapePath {
            strokeWidth: 4 * root.k
            strokeColor: root.detailed ? Qt.alpha(root.waveColor, 0.5) : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            trim.end: Math.max(0, root.progress * 2 - 1)
            startX: 26 * root.k; startY: 41 * root.k
            PathQuad { x: 37 * root.k; y: 41 * root.k; controlX: 31.5 * root.k; controlY: 35.5 * root.k }
        }
    }
}
