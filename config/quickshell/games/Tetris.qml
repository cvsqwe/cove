import QtQuick
import QtQuick.Layouts
import qs.config
import "keys.js" as K
import qs.components

// Тетрис: ←→ — сдвиг, ↑ / X — поворот, Z — обратно, ↓ — вниз быстрее, пробел — сбросить,
// C / Shift — отложить фигуру, P — пауза. Мешок из семи фигур, тень падения, повороты с отскоком от стен.
Item {
    id: root
    property bool active: false
    property int score: 0
    property int lines: 0
    readonly property int level: Math.floor(lines / 10) + 1
    property bool over: false
    property bool paused: false
    property bool started: false
    readonly property string status: I18n.tr("Счёт: ") + score + I18n.tr(" · линии: ") + lines + I18n.tr(" · уровень ") + level + (paused ? I18n.tr(" · пауза") : "")
    readonly property string bestKey: "tetris"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true
    readonly property int cols: 10
    readonly property int rows: 20
    readonly property var shapes: ({
        I: ["....", "####", "....", "...."], O: ["##", "##"], T: [".#.", "###", "..."],
        S: [".##", "##.", "..."], Z: ["##.", ".##", "..."], J: ["#..", "###", "..."], L: ["..#", "###", "..."]
    })
    function colorOf(k: string): color {
        return ({ I: Theme.teal, O: Theme.yellow, T: Theme.accent, S: Theme.green, Z: Theme.red, J: Theme.accent2, L: Theme.peach })[k] ?? Theme.text;
    }

    property var grid: []          // rows × cols: "" или буква фигуры
    property var cur: null         // { k, m (матрица), x, y }
    property var queue: []
    property string hold: ""
    property bool holdUsed: false
    property int rev: 0

    function matrix(k: string): var { return shapes[k].map(r => r.split("").map(ch => ch === "#")); }
    function rotate(m, dir: int): var {
        const n = m.length, out = [];
        for (let y = 0; y < n; y++) {
            out.push([]);
            for (let x = 0; x < n; x++) out[y].push(dir > 0 ? m[n - 1 - x][y] : m[x][n - 1 - y]);
        }
        return out;
    }
    function bag(): var {
        const b = ["I", "O", "T", "S", "Z", "J", "L"];
        for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]]; }
        return b;
    }
    function fits(m, x: int, y: int): bool {
        for (let r = 0; r < m.length; r++) for (let c = 0; c < m.length; c++) {
            if (!m[r][c]) continue;
            const gx = x + c, gy = y + r;
            if (gx < 0 || gx >= cols || gy >= rows) return false;
            if (gy >= 0 && grid[gy][gx]) return false;
        }
        return true;
    }
    function spawn(k: string): void {
        if (!k) {
            if (queue.length < 7) queue = queue.concat(bag());
            k = queue[0];
            queue = queue.slice(1);
        }
        const m = matrix(k);
        cur = { k, m, x: Math.floor((cols - m.length) / 2), y: k === "I" ? -1 : 0 };
        if (!fits(cur.m, cur.x, cur.y)) { over = true; sfx("over"); fx("shake", null, 0, 0, "10", Theme.red); record(score); }
        rev++;
    }
    function restart(): void {
        if (score > 0 && !over) record(score);
        const g = [];
        for (let r = 0; r < rows; r++) g.push(new Array(cols).fill(""));
        grid = g;
        queue = bag().concat(bag());
        hold = ""; holdUsed = false;
        score = 0; lines = 0; over = false; paused = false; started = false;
        spawn("");
    }
    Component.onCompleted: restart()

    function shift(dx: int, dy: int): bool {
        if (!cur || !fits(cur.m, cur.x + dx, cur.y + dy)) return false;
        cur = Object.assign({}, cur, { x: cur.x + dx, y: cur.y + dy });
        rev++;
        return true;
    }
    function turn(dir: int): void {
        if (!cur || cur.k === "O") return;
        const m = rotate(cur.m, dir);
        for (const [dx, dy] of [[0, 0], [-1, 0], [1, 0], [0, -1], [-2, 0], [2, 0], [0, 1]]) {
            if (fits(m, cur.x + dx, cur.y + dy)) { cur = Object.assign({}, cur, { m, x: cur.x + dx, y: cur.y + dy }); rev++; return; }
        }
    }
    function lock(): void {
        const g = grid.map(r => r.slice());
        for (let r = 0; r < cur.m.length; r++) for (let c = 0; c < cur.m.length; c++)
            if (cur.m[r][c] && cur.y + r >= 0) g[cur.y + r][cur.x + c] = cur.k;
        const kept = g.filter(r => r.some(v => !v));
        const cleared = rows - kept.length;
        while (kept.length < rows) kept.unshift(new Array(cols).fill(""));
        grid = kept;
        if (cleared > 0) {
            const pts = [0, 100, 300, 500, 800][cleared] * level;
            const lvl = level;
            score += pts;
            lines += cleared;
            flash.restart();
            sfx(cleared >= 4 ? "combo" : "line");
            const midY = (cur.y + cur.m.length / 2) * well.cell + 4;
            fx("float", well, well.width / 2, midY, cleared >= 4 ? I18n.tr("ТЕТРИС! +") + pts : "+" + pts, cleared >= 4 ? Theme.yellow : Theme.text);
            for (let i = 0; i < 4; i++) fx("burst", well, well.width * (0.15 + i * 0.23), midY, "10", colorOf(cur.k));
            if (cleared >= 4) fx("shake", null, 0, 0, "9", Theme.yellow);
            if (level > lvl) { sfx("win"); fx("float", well, well.width / 2, midY - 50, I18n.tr("Уровень ") + level, Theme.accent); }
        } else sfx("pop");
        holdUsed = false;
        spawn("");
    }
    function tick(): void { if (!shift(0, 1)) lock(); }
    function drop(): void {
        let d = 0;
        while (shift(0, 1)) d++;
        score += d * 2;
        if (d > 3) fx("shake", null, 0, 0, "4", Theme.text);
        lock();
    }
    function swapHold(): void {
        if (holdUsed) return;
        const k = cur.k;
        if (hold) spawn(hold); else spawn("");
        hold = k;
        holdUsed = true;
    }
    function ghostY(): int {
        if (!cur) return 0;
        let y = cur.y;
        while (fits(cur.m, cur.x, y + 1)) y++;
        return y;
    }

    Timer {
        running: root.active && root.started && !root.over && !root.paused
        repeat: true
        interval: Math.max(70, 800 - (root.level - 1) * 75)
        onTriggered: root.tick()
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        const k = e.key;
        if (L === "r") { restart(); e.accepted = true; return; }
        if (over) return;
        if (L === "p") { paused = !paused; e.accepted = true; return; }
        if (paused) return;
        started = true;
        if (k === Qt.Key_Left || L === "a") shift(-1, 0);
        else if (k === Qt.Key_Right || L === "d") shift(1, 0);
        else if (k === Qt.Key_Down || L === "s") { if (shift(0, 1)) score += 1; }
        else if (k === Qt.Key_Up || L === "x" || L === "w") { turn(1); sfx("move"); }
        else if (L === "z") turn(-1);
        else if (k === Qt.Key_Space) drop();
        else if (L === "c" || k === Qt.Key_Shift) swapHold();
        else return;
        e.accepted = true;
    }

    // маленькая фигура для «отложено» и «дальше»
    component PieceView: Canvas {
        property string k: ""
        width: 84; height: 56
        onKChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            if (!k) return;
            const m = root.matrix(k), s = 16;
            let minR = 9, maxR = -1, minC = 9, maxC = -1;
            m.forEach((row, r) => row.forEach((v, c) => { if (v) { minR = Math.min(minR, r); maxR = Math.max(maxR, r); minC = Math.min(minC, c); maxC = Math.max(maxC, c); } }));
            const ox = (width - (maxC - minC + 1) * s) / 2 - minC * s, oy = (height - (maxR - minR + 1) * s) / 2 - minR * s;
            g.fillStyle = root.colorOf(k);
            m.forEach((row, r) => row.forEach((v, c) => { if (v) { g.beginPath(); g.roundedRect(ox + c * s + 1, oy + r * s + 1, s - 2, s - 2, 3, 3); g.fill(); } }));
        }
    }
    component Side: Rectangle {
        property string title: ""
        default property alias content: col.data
        implicitWidth: 120
        implicitHeight: col.implicitHeight + 20
        radius: Theme.radius
        color: Theme.mantle
        Column {
            id: col
            x: 10; y: 10
            width: parent.width - 20
            spacing: 6
            StyledText { text: parent.parent.title; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
        }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 20

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Side { title: I18n.tr("Отложено (C)"); PieceView { k: root.hold; opacity: root.holdUsed ? 0.4 : 1 } }
            Side {
                title: I18n.tr("Управление")
                StyledText { width: 100; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.subtext0
                    text: I18n.tr("←→ сдвиг\n↑ поворот\n↓ быстрее\nпробел — сбросить\nP — пауза") }
            }
        }

        Rectangle {
            id: well
            readonly property real cell: Math.floor(Math.min(32, (root.height - 50) / root.rows))
            implicitWidth: cell * root.cols + 8
            implicitHeight: cell * root.rows + 8
            radius: Theme.radius
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface0

            Canvas {
                id: canvas
                x: 4; y: 4
                width: well.cell * root.cols
                height: well.cell * root.rows
                property int rev: root.rev
                onRevChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d"), s = well.cell;
                    g.reset();
                    g.strokeStyle = Theme.alpha(Theme.surface0, 0.6);
                    g.lineWidth = 1;
                    for (let x = 1; x < root.cols; x++) { g.beginPath(); g.moveTo(x * s + 0.5, 0); g.lineTo(x * s + 0.5, height); g.stroke(); }
                    for (let y = 1; y < root.rows; y++) { g.beginPath(); g.moveTo(0, y * s + 0.5); g.lineTo(width, y * s + 0.5); g.stroke(); }
                    const cellAt = (x, y, col, ghost) => {
                        g.beginPath();
                        g.roundedRect(x * s + 1, y * s + 1, s - 2, s - 2, s * 0.18, s * 0.18);
                        if (ghost) { g.strokeStyle = col; g.lineWidth = 2; g.stroke(); }
                        else { g.fillStyle = col; g.fill(); }
                    };
                    root.grid.forEach((row, y) => row.forEach((k, x) => { if (k) cellAt(x, y, root.colorOf(k), false); }));
                    if (root.cur && !root.over) {
                        const gy = root.ghostY(), col = root.colorOf(root.cur.k);
                        root.cur.m.forEach((row, r) => row.forEach((v, c) => {
                            if (!v) return;
                            if (gy + r >= 0) cellAt(root.cur.x + c, gy + r, Theme.alpha(col, 0.45), true);
                            if (root.cur.y + r >= 0) cellAt(root.cur.x + c, root.cur.y + r, col, false);
                        }));
                    }
                }
            }
            // вспышка при сборе линии
            Rectangle {
                id: flashRect
                anchors.fill: parent
                radius: parent.radius
                color: Theme.text
                opacity: 0
                NumberAnimation { id: flash; target: flashRect; property: "opacity"; from: 0.18; to: 0; duration: 260 }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: root.over || !root.started || root.paused
                color: Theme.alpha(Theme.base, 0.82)
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.over ? I18n.tr("Конец игры") : root.paused ? I18n.tr("Пауза") : I18n.tr("Тетрис")
                        font.pixelSize: 30
                        font.bold: true
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.over ? I18n.tr("Счёт: ") + root.score : root.paused ? I18n.tr("P — продолжить") : I18n.tr("Любая клавиша — старт")
                        color: Theme.subtext0
                    }
                    SButton { anchors.horizontalCenter: parent.horizontalCenter; visible: root.over; primary: true; icon: "refresh"; text: I18n.tr("Заново"); onClicked: { root.restart(); root.forceActiveFocus(); } }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 12
            Side {
                title: I18n.tr("Дальше")
                Repeater {
                    model: root.queue.slice(0, 3)
                    PieceView { required property string modelData; k: modelData }
                }
            }
        }
    }
}
