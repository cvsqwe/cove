import QtQuick
import qs.config
import qs.components

// Всплывающие сообщения поверх игры: достижение, новый уровень, открытый секрет.
// Идут по очереди, каждое ~4 секунды. show(icon, color, title, text)
Rectangle {
    id: root
    property var queue: []
    property var cur: null
    function show(icon: string, tint: color, title: string, text: string): void {
        queue = queue.concat([{ icon, tint, title, text }]);
        if (!cur) next();
    }
    function next(): void {
        if (!queue.length) { cur = null; opacity = 0; return; }
        cur = queue[0];
        queue = queue.slice(1);
        opacity = 1;
        pop.restart();
        hide.restart();
    }
    Timer { id: hide; interval: 4200; onTriggered: { root.opacity = 0; gap.restart(); } }
    Timer { id: gap; interval: 350; onTriggered: root.next() }

    width: row.implicitWidth + 36
    height: 64
    radius: 18
    color: Theme.alpha(Theme.crust, 0.95)
    border.width: 1
    border.color: cur?.tint ?? Theme.accent
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    SequentialAnimation {
        id: pop
        NumberAnimation { target: root; property: "scale"; from: 0.85; to: 1.04; duration: 160; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "scale"; to: 1; duration: 120 }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 12
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: Theme.alpha(root.cur?.tint ?? Theme.accent, 0.18)
            MIcon { anchors.centerIn: parent; icon: root.cur?.icon ?? ""; fill: true; size: 22; color: root.cur?.tint ?? Theme.accent }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            StyledText { text: root.cur?.title ?? ""; font.bold: true }
            StyledText { text: root.cur?.text ?? ""; color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall }
        }
    }
}
