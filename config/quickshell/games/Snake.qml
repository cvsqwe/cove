import QtQuick
import qs.config
import "keys.js" as K
import qs.components

// Змейка: стрелки / WASD, пробел — пауза. С каждым яблоком чуть быстрее.
// Края поля сквозные — врезаться можно только в себя.
Item {
    id: root
    property bool active: false
    property int score: 0
    property bool over: false
    property bool paused: true
    readonly property string status: I18n.tr("Счёт: ") + score + (paused && !over ? I18n.tr(" · пауза") : "")
    readonly property string bestKey: "snake"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true
    readonly property int cols: 26
    readonly property int rows: 18
    property var body: []          // [[x, y], …], голова — первая
    property var dir: [1, 0]
    property var queue: []         // повороты, нажатые между шагами
    property var food: [0, 0]

    function restart(): void {
        if (score > 0 && !over) record(score);
        const y = Math.floor(rows / 2);
        body = [[6, y], [5, y], [4, y]];
        dir = [1, 0];
        queue = [];
        score = 0; over = false; paused = true;   // стартует с первой стрелки
        placeFood();
        canvas.requestPaint();
    }
    Component.onCompleted: restart()

    function placeFood(): void {
        const taken = new Set(body.map(p => p[0] + "," + p[1]));
        let x, y;
        do { x = Math.floor(Math.random() * cols); y = Math.floor(Math.random() * rows); } while (taken.has(x + "," + y));
        food = [x, y];
    }

    function turn(dx: int, dy: int): void {
        if (over) return;
        if (paused) { paused = false; if (score === 0 && body.length === 3) sfx("start"); }
        const last = queue.length ? queue[queue.length - 1] : dir;
        if (last[0] === -dx && last[1] === -dy) return;   // разворот на месте нельзя
        if (last[0] === dx && last[1] === dy) return;
        if (queue.length < 3) queue = queue.concat([[dx, dy]]);
    }

    function step(): void {
        if (queue.length) { dir = queue[0]; queue = queue.slice(1); }
        const h = body[0];
        const nh = [(h[0] + dir[0] + cols) % cols, (h[1] + dir[1] + rows) % rows];
        const eat = nh[0] === food[0] && nh[1] === food[1];
        const rest = eat ? body : body.slice(0, -1);
        if (rest.some(p => p[0] === nh[0] && p[1] === nh[1])) {
            over = true;
            sfx("hit");
            fx("shake", null, 0, 0, "10", Theme.red);
            fx("flash", null, 0, 0, "", Theme.red);
            fx("burst", field, (nh[0] + 0.5) * field.cell, (nh[1] + 0.5) * field.cell, "24", Theme.accent);
            record(score);
            canvas.requestPaint();
            return;
        }
        body = [nh].concat(rest);
        if (eat) {
            score += 1;
            sfx("point");
            fx("burst", field, (food[0] + 0.5) * field.cell, (food[1] + 0.5) * field.cell, "14", Theme.red);
            if (score % 10 === 0) fx("float", field, (food[0] + 0.5) * field.cell, food[1] * field.cell, score + "!", Theme.yellow);
            placeFood();
        }
        canvas.requestPaint();
    }

    Timer {
        running: root.active && !root.over && !root.paused
        repeat: true
        interval: Math.max(55, 140 - root.score * 3)
        onTriggered: root.step()
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        const k = e.key;
        if (k === Qt.Key_Left || L === "a" || L === "h") turn(-1, 0);
        else if (k === Qt.Key_Right || L === "d" || L === "l") turn(1, 0);
        else if (k === Qt.Key_Up || L === "w" || L === "k") turn(0, -1);
        else if (k === Qt.Key_Down || L === "s" || L === "j") turn(0, 1);
        else if (k === Qt.Key_Space) { if (over) restart(); else paused = !paused; }
        else if (L === "r") restart();
        else return;
        e.accepted = true;
    }

    Rectangle {
        id: field
        readonly property real cell: Math.floor(Math.min((parent.width - 60) / root.cols, (parent.height - 60) / root.rows))
        width: cell * root.cols
        height: cell * root.rows
        anchors.centerIn: parent
        radius: Theme.radius
        color: Theme.mantle
        border.width: 1
        border.color: Theme.surface0

        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d");
                const s = field.cell;
                g.reset();
                // клетчатый фон
                g.fillStyle = Theme.alpha(Theme.surface0, 0.35);
                for (let y = 0; y < root.rows; y++)
                    for (let x = (y % 2); x < root.cols; x += 2) g.fillRect(x * s, y * s, s, s);
                // яблоко
                g.fillStyle = Theme.red;
                g.beginPath();
                g.arc(root.food[0] * s + s / 2, root.food[1] * s + s / 2, s * 0.36, 0, Math.PI * 2);
                g.fill();
                // змейка: голова ярче, хвост бледнеет
                const n = root.body.length;
                root.body.forEach((p, i) => {
                    g.fillStyle = i === 0 ? Theme.accent : Theme.alpha(Theme.green, 1 - 0.55 * i / Math.max(1, n));
                    const pad = i === 0 ? 1 : 2;
                    g.beginPath();
                    g.roundedRect(p[0] * s + pad, p[1] * s + pad, s - 2 * pad, s - 2 * pad, s * 0.3, s * 0.3);
                    g.fill();
                });
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.over || (root.paused && root.score === 0)
            color: Theme.alpha(Theme.base, 0.8)
            Column {
                anchors.centerIn: parent
                spacing: 12
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.over ? I18n.tr("Игра окончена") : I18n.tr("Змейка")
                    font.pixelSize: 32
                    font.bold: true
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.over ? I18n.tr("Съедено яблок: ") + root.score : I18n.tr("Стрелки — начать · пробел — пауза")
                    color: Theme.subtext0
                }
                SButton { anchors.horizontalCenter: parent.horizontalCenter; visible: root.over; primary: true; icon: "refresh"; text: I18n.tr("Заново"); onClicked: { root.restart(); root.forceActiveFocus(); } }
            }
        }
    }
}
