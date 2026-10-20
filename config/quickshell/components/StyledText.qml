import QtQuick
import qs.config

Text {
    id: root
    color: Theme.text
    // крупный текст (заголовки, часы, большие числа) — шрифтом заголовков
    font.family: font.pixelSize >= 20 ? Theme.fontHeading : Theme.font
    font.pixelSize: Theme.fontSize
    font.features: { "tnum": 1 }   // табличные цифры: часы и проценты не «дрожат» в пропорциональном шрифте
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    // Внутри масштабируемого контейнера (виджеты рабочего стола: scale) «родной» хинтованный текст
    // растягивается как картинка и мылится — там рисуем буквы кривыми, они чёткие при любом масштабе.
    Component.onCompleted: {
        for (let p = parent; p; p = p.parent)
            if (p.scalableText === true) { renderType = Text.CurveRendering; break; }
    }
}
