import QtQuick
import qs.kit
import qs.services

// Вся мышь вида файлов: клик, Ctrl/Shift, рамка, двойной клик, перетаскивание, колесо с Ctrl — масштаб
MouseArea {
    id: m
    property var view
    property var items
    anchors.fill: parent
    z: 5
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
    property int pressIdx: -1
    property int pendingOnly: -1
    property point pressPt
    property bool dragging: false

    function idxAt(x: real, y: real): int {
        const cx = x + m.x + view.contentX, cy = y + m.y + view.contentY;
        const i = view.indexAt(cx, cy);
        if (i < 0) return -1;
        if (items.grid) {
            // пустые поля ячейки — это фон
            const k = i % items.cols(), r = Math.floor(i / items.cols());
            const lx = cx - k * view.cellWidth, ly = cy - r * view.cellHeight;
            if (lx < 8 || lx > view.cellWidth - 8 || ly < 4 || ly > view.cellHeight - 4) return -1;
        }
        return i;
    }

    onPositionChanged: e => {
        items.hovered = idxAt(e.x, e.y);
        if (!pressed) return;
        if (items.banding) {
            items.bandB = Qt.point(e.x + m.x + view.contentX, e.y + m.y + view.contentY);
            items.bandSelect();
            scroller.dy = e.y < 30 ? -14 : e.y > height - 30 ? 14 : 0;
            return;
        }
        if (pressIdx >= 0 && !dragging && (e.buttons & Qt.LeftButton) && Math.hypot(e.x - pressPt.x, e.y - pressPt.y) > 12) {
            dragging = true;
            pendingOnly = -1;
            items.startDrag();
        }
    }
    onExited: items.hovered = -1
    onPressed: e => {
        items.forceActiveFocus();
        const i = idxAt(e.x, e.y);
        const p = items.pane;
        pressIdx = i;
        pressPt = Qt.point(e.x, e.y);
        dragging = false;
        pendingOnly = -1;
        if (e.button === Qt.BackButton) { p.back(); return; }
        if (e.button === Qt.ForwardButton) { p.forward(); return; }
        if (e.button === Qt.MiddleButton) {
            if (i >= 0 && p.entries[i].dir) items.open(p.entries[i], true);
            return;
        }
        const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier;
        if (e.button === Qt.RightButton) {
            if (i >= 0 && !p.sel[p.entries[i].path]) p.selectOnly(i);
            if (i < 0) p.clearSel();
            const pt = m.mapToItem(items, e.x, e.y);
            items.menu(i >= 0 ? p.entries[i] : null, pt.x, pt.y);
            return;
        }
        if (i < 0) {
            if (!ctrl && !shift) p.clearSel();
            items.bandBase = ctrl || shift ? Object.assign({}, p.sel) : ({});
            items.bandA = items.bandB = Qt.point(e.x + m.x + view.contentX, e.y + m.y + view.contentY);
            items.banding = true;
            return;
        }
        if (shift) p.selectRange(i, ctrl);
        else if (ctrl) p.toggle(i);
        else if (!p.sel[p.entries[i].path]) p.selectOnly(i);
        else { pendingOnly = i; p.cursor = i; }   // уже выделено: может, это начало перетаскивания
    }
    onReleased: {
        if (pendingOnly >= 0 && !dragging) items.pane.selectOnly(pendingOnly);
        pendingOnly = -1;
        items.banding = false;
        scroller.dy = 0;
    }
    onDoubleClicked: e => {
        const i = idxAt(e.x, e.y);
        if (e.button === Qt.LeftButton && i >= 0) items.open(items.pane.entries[i], false);
    }
    onWheel: w => {
        if (w.modifiers & Qt.ControlModifier) {
            items.zoom(w.angleDelta.y > 0 ? 1 : -1);
            w.accepted = true;
        } else w.accepted = false;
    }
    Timer {
        id: scroller
        property real dy: 0
        interval: 16
        repeat: true
        running: dy !== 0
        onTriggered: {
            const v = m.view;
            v.contentY = Math.max(v.originY - v.topMargin, Math.min(v.contentY + dy, v.contentHeight + v.originY - v.height + v.bottomMargin));
            items.bandB = Qt.point(items.bandB.x, items.bandB.y + dy);
            items.bandSelect();
        }
    }
}
