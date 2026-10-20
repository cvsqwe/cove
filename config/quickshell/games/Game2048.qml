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
    readonly property string bestKey: "g2048"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true
    property int nextId: 1
    property var merges: []

    ListModel { id: tiles }

    function cellsFree(): var {
        const used = {};
        for (let i = 0; i < tiles.count; i++) { const t = tiles.get(i); if (!t.dying) used[t.r * 4 + t.c] = true; }
        const out = [];
        for (let k = 0; k < 16; k++) if (!used[k]) out.push(k);
        return out;
    }
    function spawn(): void {
        const free = cellsFree();
        if (!free.length) return;
        const k = free[Math.floor(Math.random() * free.length)];
        tiles.append({ tid: nextId++, v: Math.random() < 0.9 ? 2 : 4, r: Math.floor(k / 4), c: k % 4, dying: false });
    }
    function restart(): void {
        if (score > 0) record(score);
        tiles.clear();
        score = 0; over = false; won = false; keepGoing = false;
        spawn(); spawn();
    }
    Component.onCompleted: restart()

    function grid(): var {
        const g = [];
        for (let r = 0; r < 4; r++) g.push([-1, -1, -1, -1]);
        for (let i = 0; i < tiles.count; i++) { const t = tiles.get(i); if (!t.dying) g[t.r][t.c] = i; }
        return g;
    }
    function canMove(): bool {
        if (cellsFree().length) return true;
        const g = grid();
        for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++) {
            const v = tiles.get(g[r][c]).v;
            if (c < 3 && tiles.get(g[r][c + 1]).v === v) return true;
            if (r < 3 && tiles.get(g[r + 1][c]).v === v) return true;
        }
        return false;
    }

    // dr, dc — направление сдвига
    function move(dr: int, dc: int): void {
        if (over || (won && !keepGoing) || removeTimer.running) return;
        const g = grid();
        let moved = false;
        merges = [];
        for (let line = 0; line < 4; line++) {
            // клетки линии в порядке «от стенки, к которой едем»
            const cells = [];
            for (let k = 0; k < 4; k++) {
                const p = dr === 0 ? [line, dc < 0 ? k : 3 - k] : [dr < 0 ? k : 3 - k, line];
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
            if (!root.canMove()) { root.over = true; root.sfx("over"); root.fx("shake", null, 0, 0, "6", Theme.red); root.record(root.score); }
        }
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        const k = e.key;
        if (k === Qt.Key_Left || L === "a" || L === "h") move(0, -1);
        else if (k === Qt.Key_Right || L === "d" || L === "l") move(0, 1);
        else if (k === Qt.Key_Up || L === "w" || L === "k") move(-1, 0);
        else if (k === Qt.Key_Down || L === "s" || L === "j") move(1, 0);
        else if (L === "r") restart();
        else return;
        e.accepted = true;
    }

    function tileColor(v: int): color {
        const cs = [Theme.surface1, Theme.surface2, Theme.teal, Theme.green, Theme.yellow, Theme.peach,
            Theme.red, Theme.pink, Theme.accent2, Theme.accent, Theme.lavender];
        return cs[Math.min(cs.length - 1, Math.round(Math.log2(v)) - 1)];
    }

    // ---- поле ----
    Rectangle {
        id: board
        readonly property real gap: 12
        readonly property real cell: (width - 5 * gap) / 4
        width: Math.min(parent.width - 60, parent.height - 60)
        height: width
        anchors.centerIn: parent
        radius: Theme.radius + 6
        color: Theme.mantle

        Repeater {
            model: 16
            Rectangle {
                required property int index
                x: board.gap + (index % 4) * (board.cell + board.gap)
                y: board.gap + Math.floor(index / 4) * (board.cell + board.gap)
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
                    color: tile.v <= 4 ? Theme.text : Theme.crust
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
