import QtQuick

// Текст в стиле Cove
Text {
    color: Cove.text
    font.family: Cove.font
    font.pixelSize: Cove.fontSize
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    elide: Text.ElideRight
}
