import QtQuick
import QtQuick.Shapes
import qs.config

// Мини-график истории значений 0..1 с заливкой.
Shape {
    id: root

    property var values: []
    property color color: Theme.accent
    property int max: 60

    preferredRendererType: Shape.CurveRenderer

    readonly property var pts: {
        const v = values.slice(-max), n = Math.max(2, max);
        return v.map((y, i) => Qt.point((i + (max - v.length)) / (n - 1) * width, height - Math.max(0, Math.min(1, y)) * (height - 2) - 1));
    }

    ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillGradient: LinearGradient {
            y1: 0; y2: root.height
            GradientStop { position: 0; color: Theme.alpha(root.color, 0.35) }
            GradientStop { position: 1; color: Theme.alpha(root.color, 0.0) }
        }
        startX: root.pts[0]?.x ?? 0
        startY: root.height
        PathLine { x: root.pts[0]?.x ?? 0; y: root.pts[0]?.y ?? root.height }
        PathPolyline { path: root.pts }
        PathLine { x: root.pts[root.pts.length - 1]?.x ?? root.width; y: root.height }
    }
    ShapePath {
        strokeWidth: 1.5
        strokeColor: root.color
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathPolyline { path: root.pts }
    }
}
