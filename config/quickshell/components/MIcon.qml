import QtQuick
import qs.config

// Значок интерфейса. icon — Nerd-глиф или имя Material Symbols; по таблице Icons рисуется
// единым набором Material Symbols Rounded, логотипы брендов — как есть.
Text {
    id: root

    property string icon: ""
    property real size: Theme.iconSize
    property bool fill: false          // залитый вариант (для активных состояний)
    readonly property string ms: cove ? "" : Icons.name(icon)
    readonly property bool cove: icon === "cove"

    // "cove" — знак Cove (векторный); em-пробел держит размер как у обычного глифа
    text: cove ? "\u2003" : ms || icon
    color: Theme.text
    font.family: ms ? Icons.family : Theme.font
    font.pixelSize: ms ? Math.round(size * 1.15) : size
    font.variableAxes: ms ? { "FILL": fill ? 1 : 0, "wght": 400, "GRAD": 0, "opsz": 24 } : {}
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    // NativeRendering: у QtRendering (поле расстояний) артефакты на осях вариативного шрифта (FILL)
    renderType: Text.NativeRendering
    CoveLogo {
        visible: root.cove
        anchors.centerIn: parent
        size: root.size * 1.05
        color: root.color
    }
    // в масштабируемом контейнере (виджеты рабочего стола) — кривыми, как StyledText
    Component.onCompleted: {
        for (let p = parent; p; p = p.parent)
            if (p.scalableText === true) { renderType = Text.CurveRendering; break; }
    }
}
