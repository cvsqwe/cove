import QtQuick
import qs.config
import qs.services

// АЧХ эквалайзера (services/SoundFx) с точками полос.
// Тянуть точку: влево-вправо — частота, вверх-вниз — усиление; колесо — ширина (Q);
// двойной клик по пустому месту — новая полоса, ПКМ по точке — убрать.
Item {
    id: root

    property bool editable: true
    property bool labels: true
    property int selected: -1
    readonly property var bands: SoundFx.bands
    readonly property var ks: SoundFx.chainCoeffs(bands, Settings.sound.bass)
    readonly property real pre: Settings.sound.preamp
    readonly property bool active: Settings.sound.enabled

    // диапазон по вертикали подстраивается под кривую: ±12, ±18, ±24…; пока тянут точку — замирает,
    // иначе масштаб поменяется под курсором
    property real heldRange: 0
    readonly property real range: heldRange > 0 ? heldRange : autoRange
    readonly property real autoRange: {
        let m = 0;
        for (let i = 0; i <= 60; i++) m = Math.max(m, Math.abs(SoundFx.response(ks, fAt(i / 60), pre)));
        for (const b of bands) m = Math.max(m, Math.abs(b.g));
        return Math.min(36, Math.max(12, Math.ceil((m + 2) / 6) * 6));
    }

    readonly property real fMin: 20
    readonly property real fMax: 20000
    readonly property real padL: labels ? 30 : 6
    readonly property real padB: labels ? 18 : 6
    readonly property real w: width - padL - 6
    readonly property real h: height - padB - 6

    function fAt(t: real): real { return fMin * Math.pow(fMax / fMin, t); }
    function xOf(f: real): real { return padL + w * Math.log(f / fMin) / Math.log(fMax / fMin); }
    function fOf(x: real): real { return fAt(Math.max(0, Math.min(1, (x - padL) / w))); }
    function yOf(g: real): real { return 6 + h / 2 - g / range * (h / 2); }
    // биквады PipeWire принимают усиление от −120 до +20 дБ
    function gOf(y: real): real { return Math.max(-Math.min(range, 24), Math.min(Math.min(range, 20), -(y - 6 - h / 2) / (h / 2) * range)); }
    function hasGain(b): bool { return b.type === "bell" || b.type === "lowshelf" || b.type === "highshelf"; }
    function fmtF(f: real): string { return f >= 1000 ? (f / 1000).toFixed(f >= 10000 ? 0 : 1) + I18n.tr(" кГц") : Math.round(f) + I18n.tr(" Гц"); }

    onKsChanged: canvas.requestPaint()
    onPreChanged: canvas.requestPaint()
    onRangeChanged: canvas.requestPaint()
    onActiveChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    Connections { target: Theme; function onAccentChanged(): void { canvas.requestPaint(); } }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const grid = Theme.alpha(Theme.text, 0.07);
            c.lineWidth = 1;
            c.strokeStyle = grid;
            c.fillStyle = Theme.overlay0;
            c.font = `${Theme.fontSizeSmall - 2}px "${Theme.font}"`;
            // частоты
            for (const f of [50, 100, 200, 500, 1000, 2000, 5000, 10000]) {
                const x = Math.round(root.xOf(f)) + 0.5;
                c.beginPath(); c.moveTo(x, 6); c.lineTo(x, 6 + root.h); c.stroke();
                if (root.labels && [100, 1000, 10000, 50, 500, 5000].includes(f))
                    c.fillText(f >= 1000 ? f / 1000 + "k" : String(f), x - 8, height - 4);
            }
            // децибелы
            const step = root.range >= 24 ? 12 : 6;
            for (let g = -root.range; g <= root.range; g += step) {
                const y = Math.round(root.yOf(g)) + 0.5;
                c.strokeStyle = g === 0 ? Theme.alpha(Theme.text, 0.18) : grid;
                c.beginPath(); c.moveTo(root.padL, y); c.lineTo(root.padL + root.w, y); c.stroke();
                if (root.labels) c.fillText((g > 0 ? "+" : "") + g, 2, y + 4);
            }
            // кривая
            const pts = [];
            const n = Math.max(80, Math.round(root.w / 3));
            for (let i = 0; i <= n; i++) {
                const f = root.fAt(i / n);
                pts.push([root.xOf(f), root.yOf(Math.max(-root.range, Math.min(root.range, SoundFx.response(root.ks, f, root.pre))))]);
            }
            const col = root.active ? Theme.accent : Theme.overlay1;
            const zero = root.yOf(0);
            c.beginPath();
            c.moveTo(pts[0][0], zero);
            for (const p of pts) c.lineTo(p[0], p[1]);
            c.lineTo(pts[pts.length - 1][0], zero);
            c.closePath();
            const grad = c.createLinearGradient(0, 6, 0, 6 + root.h);
            grad.addColorStop(0, Theme.alpha(col, 0.32));
            grad.addColorStop(0.5, Theme.alpha(col, 0.06));
            grad.addColorStop(1, Theme.alpha(col, 0.32));
            c.fillStyle = grad;
            c.fill();
            c.beginPath();
            pts.forEach((p, i) => i ? c.lineTo(p[0], p[1]) : c.moveTo(p[0], p[1]));
            c.strokeStyle = col;
            c.lineWidth = 2.2;
            c.lineJoin = "round";
            c.stroke();
        }
    }

    // точки полос
    Repeater {
        model: root.bands
        Rectangle {
            id: dot
            required property var modelData
            required property int index
            readonly property bool sel: root.selected === index
            readonly property bool hot: sel || area.hoverIdx === index
            width: hot ? 16 : 12
            height: width
            radius: width / 2
            x: root.xOf(modelData.f) - width / 2
            y: root.yOf(root.hasGain(modelData) ? Math.max(-root.range, Math.min(root.range, modelData.g)) : 0) - height / 2
            color: sel ? Theme.accent : Theme.base
            border.width: 2
            border.color: root.active ? Theme.accent : Theme.overlay1
            visible: root.editable || Math.abs(modelData.g) > 0.05
            Behavior on width { NumberAnimation { duration: Theme.animFast } }
        }
    }

    // подпись выбранной/наведённой полосы
    Rectangle {
        readonly property int idx: area.hoverIdx >= 0 ? area.hoverIdx : root.selected
        readonly property var b: idx >= 0 ? root.bands[idx] : null
        visible: root.editable && b !== null && b !== undefined
        x: b ? Math.max(root.padL, Math.min(root.width - width - 4, root.xOf(b.f) - width / 2)) : 0
        y: 8
        width: tip.implicitWidth + 16
        height: tip.implicitHeight + 8
        radius: height / 2
        color: Theme.alpha(Theme.crust, 0.85)
        StyledText {
            id: tip
            anchors.centerIn: parent
            text: parent.b ? root.fmtF(parent.b.f) + (root.hasGain(parent.b) ? `  ${parent.b.g > 0 ? "+" : ""}${parent.b.g.toFixed(1)} ${I18n.tr("дБ")}` : "") + `  Q ${parent.b.q.toFixed(2)}` : ""
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.editable
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: drag >= 0 ? Qt.ClosedHandCursor : hoverIdx >= 0 ? Qt.OpenHandCursor : Qt.CrossCursor
        property int drag: -1
        property int hoverIdx: -1

        function hit(mx: real, my: real): int {
            let best = -1, bd = 14 * 14;
            root.bands.forEach((b, i) => {
                const dx = root.xOf(b.f) - mx, dy = root.yOf(root.hasGain(b) ? b.g : 0) - my, d = dx * dx + dy * dy;
                if (d < bd) { bd = d; best = i; }
            });
            return best;
        }
        onPositionChanged: m => {
            if (drag < 0) { hoverIdx = hit(m.x, m.y); return; }
            const b = root.bands[drag];
            const patch = { f: Math.round(Math.max(20, Math.min(20000, root.fOf(m.x))) * 10) / 10 };
            if (root.hasGain(b)) patch.g = Math.round(root.gOf(m.y) * 10) / 10;
            SoundFx.setBand(drag, patch);
        }
        onExited: hoverIdx = -1
        onPressed: m => {
            const i = hit(m.x, m.y);
            if (m.button === Qt.RightButton) {
                if (i >= 0) { SoundFx.removeBand(i); root.selected = -1; hoverIdx = -1; }
                return;
            }
            root.selected = i;
            drag = i;
            root.heldRange = root.range;
        }
        onReleased: {
            drag = -1;
            root.heldRange = 0;
        }
        onDoubleClicked: m => {
            if (hit(m.x, m.y) >= 0) return;
            root.selected = SoundFx.addBand(root.fOf(m.x), Math.round(root.gOf(m.y) * 10) / 10);
        }
        onWheel: w => {
            const i = hoverIdx >= 0 ? hoverIdx : root.selected;
            if (i < 0) return;
            const q = root.bands[i].q * (w.angleDelta.y > 0 ? 1.12 : 1 / 1.12);
            SoundFx.setBand(i, { q: Math.round(Math.max(0.1, Math.min(12, q)) * 100) / 100 });
        }
    }
}
