import QtQuick
import QtQuick.Shapes

// Вогнутый угол: заливка «прижата» к указанному углу квадрата, внутри — четверть круга.
// Используется, чтобы остров и ящики плавно «вытекали» из панели.
Item {
    id: root

    property string corner: "topLeft" // topLeft | topRight | bottomLeft | bottomRight
    property color color: "black"
    property real radius: 16

    width: radius
    height: radius
    rotation: corner === "topRight" ? 90 : corner === "bottomRight" ? 180 : corner === "bottomLeft" ? 270 : 0

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color
            startX: 0
            startY: 0
            PathLine { x: root.radius; y: 0 }
            PathArc {
                x: 0
                y: root.radius
                radiusX: root.radius
                radiusY: root.radius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }
}
