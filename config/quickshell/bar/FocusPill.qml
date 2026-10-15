import QtQuick
import qs.config
import qs.components
import qs.services

// Фокус-таймер: «▶» когда выключен, оставшееся время — когда идёт. ПКМ — пропустить фазу.
Pill {
    icon: Focus.phase === "break" ? "󰅶" : "󰔟"
    iconColor: Focus.phase === "work" ? Theme.red : Focus.phase === "break" ? Theme.green : Theme.barTint(Theme.subtext0)
    pinLabel: true   // идущий таймер виден всегда
    label: Focus.active ? Focus.timeText : ""
    onClicked: m => m.button === Qt.RightButton ? Focus.skip() : Focus.toggle()
}
