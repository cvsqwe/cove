import QtQuick

// Значок Material Symbols Rounded по имени («folder», «delete»…)
Text {
    property string icon: ""
    property real size: 18
    property bool fill: false
    text: icon
    color: Cove.text
    font.family: Cove.iconFont
    font.pixelSize: Math.round(size * 1.15)
    font.variableAxes: { "FILL": fill ? 1 : 0, "wght": 400, "GRAD": 0, "opsz": 24 }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
