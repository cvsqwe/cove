import QtQuick
import QtQuick.Shapes
import qs.config

// Кольцо-индикатор векторными фигурами (а не Canvas): чёткое при любом масштабе.
Item {
    id: root

    property real value: 0          // 0…1
    property color color: Theme.accent
    property color track: Theme.alpha(Theme.text, 0.1)
    property real thickness: 8

    readonly property real r: Math.min(width, height) / 2 - thickness / 2 - 1
    readonly property real shown: Math.max(0, Math.min(1, value))
    property real animated: shown
    // анимируем только заметные скачки: системные кольца обновляются раз в 2 с, асинхронно, и плавный
    // доезд на каждый 1% держал перерисовку слоя виджетов почти непрерывно (~40 кадров/с, ~10% CPU)
    Behavior on animated {
        enabled: Math.abs(root.shown - root.animated) > 0.03
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.track
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r; radiusY: root.r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.animated > 0.005 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r; radiusY: root.r; startAngle: -90; sweepAngle: 360 * root.animated }
        }
    }
}
