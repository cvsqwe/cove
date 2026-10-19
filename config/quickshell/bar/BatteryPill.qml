import QtQuick
import qs.config
import qs.components
import qs.services

// Батарея ноутбука (на компьютере без батареи не видна): клик — центр управления, колесо — яркость.
Pill {
    visible: Power.hasBattery
    icon: Power.icon()
    iconColor: Power.charging || Power.full ? Theme.barTint(Theme.green) : Power.low ? Theme.red : Theme.barTint(Theme.accent)
    label: Power.percent + "%"
    pinLabel: Power.low   // на исходе — число видно всегда
    textColor: Power.low ? Theme.red : Theme.text
    onClicked: Panels.toggle("control")
    onWheel: w => Power.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
}
