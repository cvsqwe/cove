import QtQuick
import qs.config
import "keys.js" as K
import qs.components

// 2048: стрелки / WASD / HJKL или свайп мышью. Плитки — ListModel со стабильными делегатами,
// чтобы сдвиг анимировался (у Repeater по массиву делегаты пересоздавались бы).
Item {
    id: root
    property bool active: false
    property int score: 0
    property bool over: false
    property bool won: false
    property bool keepGoing: false
    readonly property string status: I18n.tr("Счёт: ") + score
    readonly property string bestKey: n === 5 ? "g2048-5" : "g2048"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    // ---- читы: окно проставляет cheats (открытые id); слово набирается во время игры ----
    property var cheats: []
    readonly property var cheatCodes: [
        { id: "g2048.undo", code: "nope", run: () => undo() },
        { id: "g2048.clean", code: "pop", run: () => {
            if (over || removeTimer.running) return false;
            let n = 0;
            for (let i = tiles.count - 1; i >= 0; i--) { const t = tiles.get(i); if (!t.dying && t.v === 2) { tiles.remove(i); n++; } }
            if (!n) return false;
            history = [];          // после уборки отмена вернула бы двойки
            if (!tiles.count) { spawn(); spawn(); }
            fx("float", board, board.width / 2, board.height / 2, "−" + n + " × 2", Theme.accent);
            return true;
        } }
    ]
    property var history: []        // снимки до хода: [{ tiles: [{v, r, c}], score, won }]
    function snapshot(): var {
        const t = [];
        for (let i = 0; i < tiles.count; i++) { const x = tiles.get(i); if (!x.dying) t.push({ v: x.v, r: x.r, c: x.c }); }
        return { tiles: t, score, won };
    }
    function undo(): bool {
        if (!history.length || removeTimer.running) return false;
        const s = history[history.length - 1];
        history = history.slice(0, -1);
        tiles.clear();
        for (const t of s.tiles) tiles.append({ tid: nextId++, v: t.v, r: t.r, c: t.c, dying: false });
        score = s.score; won = s.won; over = false;
        undone = true;
        return true;
    }
    signal unlock(string id)
    signal cheatUsed(string id)
    property string typedBuf: ""
    function feed(L: string): void {
        if (!L) return;
        typedBuf = (typedBuf + L).slice(-8);
        for (const c of cheatCodes)
            if (typedBuf.endsWith(c.code) && cheats.includes(c.id)) { typedBuf = ""; if (c.run() !== false) cheatUsed(c.id); }
    }

    focus: true
    property int nextId: 1
    // профиль (GamesWindow): перки, скин, открытые режимы
    property bool legacy: false
    property var perks: []
    property string skin: ""
    property var modes: []
    signal event(string name, var data)
    property string size: "4"                 // "4" | "5" (режим g2048.5x5)
    readonly property int n: size === "5" && modes.includes("g2048.5x5") ? 5 : 4
    onNChanged: restart()
    property int maxTile: 0
    property bool undone: false               // была ли отмена хода в партии
    property bool freeUsed: false             // перк «право на ошибку»
    function finish(): void { event("end", { score, max: maxTile }); }
    property var merges: []

    ListModel { id: tiles }

    function cellsFree(): var {
        const used = {};
        for (let i = 0; i < tiles.count; i++) { const t = tiles.get(i); if (!t.dying) used[t.r * root.n + t.c] = true; }
        const out = [];
        for (let k = 0; k < n * n; k++) if (!used[k]) out.push(k);
        return out;
    }
    function spawn(): void {
        const free = cellsFree();
        if (!free.length) return;
        const k = free[Math.floor(Math.random() * free.length)];
        tiles.append({ tid: nextId++, v: Math.random() < 0.9 ? 2 : 4, r: Math.floor(k / n), c: k % n, dying: false });
    }
    function restart(): void {
        if (score > 0) record(score);
        if (score > 0 && !over) finish();
        tiles.clear();
        score = 0; over = false; won = false; keepGoing = false;
        history = []; maxTile = 0; undone = false; freeUsed = false;
        spawn(); spawn();
    }
    Component.onCompleted: restart()

    function grid(): var {
        const g = [];
        for (let r = 0; r < n; r++) g.push(new Array(n).fill(-1));
        for (let i = 0; i < tiles.count; i++) { const t = tiles.get(i); if (!t.dying) g[t.r][t.c] = i; }
        return g;
    }
    function canMove(): bool {
        if (cellsFree().length) return true;
        const g = grid();
        for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) {
            const v = tiles.get(g[r][c]).v;
            if (c < n - 1 && tiles.get(g[r][c + 1]).v === v) return true;
            if (r < n - 1 && tiles.get(g[r + 1][c]).v === v) return true;
        }
        return false;
    }

    // dr, dc — направление сдвига
    function move(dr: int, dc: int): void {
        if (over || (won && !keepGoing) || removeTimer.running) return;
        const before = snapshot();
        const g = grid();
        let moved = false;
        merges = [];
        for (let line = 0; line < n; line++) {
            // клетки линии в порядке «от стенки, к которой едем»
            const cells = [];
            for (let k = 0; k < n; k++) {
                const p = dr === 0 ? [line, dc < 0 ? k : n - 1 - k] : [dr < 0 ? k : n - 1 - k, line];
                cells.push(p);
            }
            let t = 0, last = -1, lastMerged = false;
            for (const [r, c] of cells) {
                const i = g[r][c];
                if (i < 0) continue;
                const tile = tiles.get(i);
                if (last >= 0 && !lastMerged && tiles.get(last).v === tile.v) {
                    // сливается: едет на место предыдущей и исчезает, та удваивается
                    const lt = tiles.get(last);
                    tiles.setProperty(i, "r", lt.r);
                    tiles.setProperty(i, "c", lt.c);
                    tiles.setProperty(i, "dying", true);
                    tiles.setProperty(last, "v", lt.v * 2);
                    score += lt.v;
                    merges.push({ r: lt.r, c: lt.c, v: lt.v });
                    if (lt.v === 2048 && !won) won = true;
                    lastMerged = true;
                    moved = true;
                } else {
                    const [nr, nc] = cells[t];
                    if (nr !== r || nc !== c) moved = true;
                    tiles.setProperty(i, "r", nr);
                    tiles.setProperty(i, "c", nc);
                    last = i;
                    lastMerged = false;
                    t++;
                }
            }
        }
        if (!moved) return;
        history = history.concat([before]).slice(-3);
        if (merges.some(m => m.v >= 256)) unlock("g2048.undo");
        if (merges.some(m => m.v >= 1024)) unlock("g2048.clean");   // v — уже удвоенное значение
        const top = merges.reduce((a, m) => Math.max(a, m.v), 0);
        if (top > maxTile) { maxTile = top; if (top >= 128) event("tile", { v: top, undone }); }
        if (merges.length) {
            sfx("merge");
            const sum = merges.reduce((a, m) => a + m.v, 0);
            const m0 = merges[0];
            fx("float", board, board.gap + (m0.c + 0.5) * (board.cell + board.gap), board.gap + (m0.r + 0.5) * (board.cell + board.gap), "+" + sum, tileColor(m0.v));
            for (const m of merges) if (m.v >= 64)
                fx("burst", board, board.gap + (m.c + 0.5) * (board.cell + board.gap), board.gap + (m.r + 0.5) * (board.cell + board.gap), String(10 + Math.log2(m.v) * 2), tileColor(m.v));
            if (won && merges.some(m => m.v === 2048)) { sfx("win"); fx("confetti", null, 0, 0, "", Theme.accent); }
        } else sfx("move");
        removeTimer.restart();
    }
    Timer {
        id: removeTimer
        interval: 120
        onTriggered: {
            for (let i = tiles.count - 1; i >= 0; i--) if (tiles.get(i).dying) tiles.remove(i);
            root.spawn();
            if (!root.canMove()) { root.over = true; root.finish(); root.sfx("over"); root.fx("shake", null, 0, 0, "6", Theme.red); root.record(root.score); }
        }
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        feed(L);
        const k = e.key;
        if (k === Qt.Key_Left || L === "a" || L === "h") move(0, -1);
        else if (k === Qt.Key_Right || L === "d" || L === "l") move(0, 1);
        else if (k === Qt.Key_Up || L === "w" || L === "k") move(-1, 0);
        else if (k === Qt.Key_Down || L === "s" || L === "j") move(1, 0);
        else if (L === "r") restart();
        else if (L === "u" && perks.includes("g2048.freeUndo") && !freeUsed) {
            if (undo()) { freeUsed = true; sfx("cheat"); fx("float", board, board.width / 2, board.height / 2, I18n.tr("↶ отмена"), Theme.accent); }
        }
        else return;
        e.accepted = true;
    }

    function tileColor(v: int): color {
        const i = Math.round(Math.log2(v)) - 1;
        if (skin === "g2048.classic") {
            const cs = ["#eee4da", "#ede0c8", "#f2b179", "#f59563", "#f67c5f", "#f65e3b", "#edcf72", "#edcc61", "#edc850", "#edc53f", "#edc22e"];
            return cs[Math.min(cs.length - 1, i)];
        }
        if (skin === "g2048.neon") return Qt.hsla((0.55 + i * 0.07) % 1, 0.9, 0.62, 1);
        const cs = [Theme.surface1, Theme.surface2, Theme.teal, Theme.green, Theme.yellow, Theme.peach,
            Theme.red, Theme.pink, Theme.accent2, Theme.accent, Theme.lavender];
        return cs[Math.min(cs.length - 1, i)];
    }
    function textColor(v: int): color {
        if (skin === "g2048.classic") return v <= 4 ? "#776e65" : "#f9f6f2";
        return v <= 4 && skin !== "g2048.neon" ? Theme.text : Theme.crust;
    }

    SSegment {
        visible: root.modes.includes("g2048.5x5")
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        z: 5
        options: [{ value: "4", label: "4 × 4" }, { value: "5", label: "5 × 5" }]
        current: root.size
        onPicked: v => { root.size = v; root.forceActiveFocus(); }
    }

    // ---- поле ----
    Rectangle {
        id: board
        readonly property real gap: 12
        readonly property real cell: (width - (root.n + 1) * gap) / root.n
        width: Math.min(parent.width - 60, parent.height - (root.modes.includes("g2048.5x5") ? 110 : 60))
        anchors.verticalCenterOffset: root.modes.includes("g2048.5x5") ? 22 : 0
        height: width
        anchors.centerIn: parent
        radius: Theme.radius + 6
        color: Theme.mantle

        Repeater {
            model: root.n * root.n
            Rectangle {
                required property int index
                x: board.gap + (index % root.n) * (board.cell + board.gap)
                y: board.gap + Math.floor(index / root.n) * (board.cell + board.gap)
                width: board.cell
                height: board.cell
                radius: Theme.radius
                color: Theme.surface0
                opacity: 0.6
            }
        }

        Repeater {
            model: tiles
            Rectangle {
                id: tile
                required property int v
                required property int r
                required property int c
                required property bool dying
                x: board.gap + c * (board.cell + board.gap)
                y: board.gap + r * (board.cell + board.gap)
                z: dying ? 0 : 1
                width: board.cell
                height: board.cell
                radius: Theme.radius
                color: root.tileColor(v)
                Behavior on x { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 120 } }
                scale: 0.4
                Component.onCompleted: scale = 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                onVChanged: pop.restart()
                SequentialAnimation {
                    id: pop
                    PauseAnimation { duration: 90 }
                    NumberAnimation { target: tile; property: "scale"; to: 1.14; duration: 70 }
                    NumberAnimation { target: tile; property: "scale"; to: 1; duration: 90 }
                }
                StyledText {
                    anchors.centerIn: parent
                    text: tile.v
                    font.pixelSize: board.cell * (tile.v >= 1024 ? 0.28 : tile.v >= 128 ? 0.34 : 0.42)
                    font.bold: true
                    color: root.textColor(tile.v)
                }
            }
        }

        // свайп мышью
        MouseArea {
            anchors.fill: parent
            property point start
            onPressed: m => { start = Qt.point(m.x, m.y); root.forceActiveFocus(); }
            onReleased: m => {
                const dx = m.x - start.x, dy = m.y - start.y;
                if (Math.max(Math.abs(dx), Math.abs(dy)) < 30) return;
                if (Math.abs(dx) > Math.abs(dy)) root.move(0, dx > 0 ? 1 : -1);
                else root.move(dy > 0 ? 1 : -1, 0);
            }
        }

        // конец партии / победа — поверх плиток (у них z: 1)
        Rectangle {
            z: 10
            anchors.fill: parent
            radius: parent.radius
            visible: root.over || (root.won && !root.keepGoing)
            color: Theme.alpha(Theme.base, 0.82)
            Column {
                anchors.centerIn: parent
                spacing: 14
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.over ? I18n.tr("Ходов больше нет") : "2048!"
                    font.pixelSize: 34
                    font.bold: true
                }
                StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Счёт: ") + root.score; color: Theme.subtext0 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    SButton { visible: !root.over; text: I18n.tr("Играть дальше"); onClicked: { root.keepGoing = true; root.forceActiveFocus(); } }
                    SButton { primary: true; icon: "refresh"; text: I18n.tr("Заново"); onClicked: { root.restart(); root.forceActiveFocus(); } }
                }
            }
        }
    }
}
