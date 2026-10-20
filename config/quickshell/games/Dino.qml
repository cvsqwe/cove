import QtQuick
import qs.config
import "keys.js" as K
import qs.components

// Динозавр: пробел / ↑ — прыжок (дольше держишь — выше), ↓ — пригнуться (и быстрее упасть).
// Скорость растёт; после 300 очков появляются птицы.
Item {
    id: root
    property bool active: false
    property int score: Math.floor(dist / 12)
    property real dist: 0
    property bool running: false
    property bool over: false
    readonly property string status: I18n.tr("Очки: ") + score
    readonly property string bestKey: "dino"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true

    readonly property real fw: field.width
    readonly property real ground: field.height - 40
    readonly property real dinoX: 70
    property real dy: 0            // высота над землёй
    property real vy: 0
    property bool ducking: false
    property bool holding: false
    property var obs: []           // [{ x, w, h, y, bird }]
    property real spawnIn: 1
    property real t: 0
    property real speed: 380

    function restart(): void {
        if (score > 0 && !over) record(score);
        dist = 0; dy = 0; vy = 0; obs = []; spawnIn = 1; t = 0; speed = 380;
        ducking = false; over = false; running = false;
        canvas.requestPaint();
    }
    Component.onCompleted: Qt.callLater(restart)

    function jump(): void {
        if (over && Date.now() - diedAt < 450) return;   // нажатие в момент удара не перезапускает
        if (over) restart();      // и сразу дальше — новая партия с первого нажатия
        if (!running) sfx("start");
        running = true;
        if (dy <= 0.5) { vy = 780; sfx("jump"); }
    }
    property real diedAt: 0
    function die(): void {
        over = true; running = false; diedAt = Date.now();
        sfx("hit");
        fx("shake", null, 0, 0, "12", Theme.red);
        fx("burst", field, dinoX + 22, ground - dy - 26, "24", Theme.accent);
        record(score);
        canvas.requestPaint();
    }
    // каждые 100 очков — звон и вспышка счёта
    onScoreChanged: if (running && score > 0 && score % 100 === 0) { sfx("point"); fx("float", field, fw - 70, 60, String(score), Theme.yellow); }

    FrameAnimation {
        running: root.active && root.running
        onTriggered: {
            const dt = Math.min(0.033, frameTime);
            root.t += dt;
            root.speed = Math.min(950, 380 + root.t * 9);
            root.dist += root.speed * dt;
            // прыжок: пока держишь — гравитация слабее
            const g = root.ducking ? 5200 : root.holding && root.vy > 0 ? 1900 : 3000;
            root.vy -= g * dt;
            root.dy = Math.max(0, root.dy + root.vy * dt);
            if (root.dy === 0) root.vy = 0;

            root.spawnIn -= dt;
            let os = root.obs.map(o => Object.assign({}, o, { x: o.x - root.speed * dt * (o.bird ? 1.12 : 1) })).filter(o => o.x + o.w > -20);
            if (root.spawnIn <= 0) {
                if (root.score > 300 && Math.random() < 0.3) {
                    const lvl = [14, 46, 80][Math.floor(Math.random() * 3)];
                    os.push({ x: root.fw + 30, w: 42, h: 28, y: lvl, bird: true });
                } else {
                    const n = 1 + Math.floor(Math.random() * (root.speed > 600 ? 3 : 2));
                    const h = 36 + Math.random() * 22;
                    os.push({ x: root.fw + 30, w: 16 * n + 6 * (n - 1), h, y: 0, bird: false, n });
                }
                root.spawnIn = Math.max(0.55, (0.9 + Math.random() * 0.9) * 420 / root.speed);
            }
            root.obs = os;
            // столкновение с небольшим запасом
            const dh = root.ducking ? 30 : 50, dw = root.ducking ? 58 : 42;
            for (const o of os) {
                const ox1 = o.x + 4, ox2 = o.x + o.w - 4, oy1 = o.y + 3, oy2 = o.y + o.h - 3;
                if (root.dinoX + dw - 8 > ox1 && root.dinoX + 6 < ox2 && root.dy + 4 < oy2 && root.dy + dh - 6 > oy1) { root.die(); break; }
            }
            canvas.requestPaint();
        }
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        if (e.isAutoRepeat) { e.accepted = true; return; }
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Up || L === "w") { holding = true; jump(); }
        else if (e.key === Qt.Key_Down || L === "s") { if (running) ducking = true; }
        else if (L === "r") restart();
        else return;
        e.accepted = true;
    }
    Keys.onReleased: e => {
        const L = K.letter(e);
        if (e.isAutoRepeat) return;
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Up || L === "w") holding = false;
        else if (e.key === Qt.Key_Down || L === "s") ducking = false;
    }

    Rectangle {
        id: field
        width: Math.min(960, parent.width - 60)
        height: 300
        anchors.centerIn: parent
        radius: Theme.radius + 4
        color: Theme.mantle
        clip: true

        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const gy = root.ground;
                // облака
                g.fillStyle = Theme.alpha(Theme.text, 0.06);
                for (let i = 0; i < 4; i++) {
                    const x = ((i * 260 - root.dist * 0.15) % (width + 200) + width + 200) % (width + 200) - 100;
                    g.beginPath(); g.roundedRect(x, 40 + (i % 2) * 40, 90, 22, 11, 11); g.fill();
                }
                // земля
                g.fillStyle = Theme.overlay0;
                g.fillRect(0, gy, width, 2);
                g.fillStyle = Theme.surface2;
                const off = root.dist % 37;
                for (let x = -off; x < width; x += 37) g.fillRect(x, gy + 8 + (Math.floor((x + root.dist) / 37) % 3) * 6, 6, 2);
                // препятствия
                for (const o of root.obs) {
                    if (o.bird) {
                        g.fillStyle = Theme.peach;
                        const wing = Math.sin(root.t * 14) > 0 ? -10 : 8;
                        const by = gy - o.y - o.h / 2;
                        g.beginPath(); g.ellipse(o.x + 8, by - 7, 30, 14); g.fill();
                        g.beginPath(); g.moveTo(o.x + 14, by); g.lineTo(o.x + 30, by); g.lineTo(o.x + 22, by + wing); g.fill();
                        g.beginPath(); g.moveTo(o.x + 8, by - 3); g.lineTo(o.x - 2, by); g.lineTo(o.x + 8, by + 2); g.fill();
                    } else {
                        g.fillStyle = Theme.green;
                        for (let k = 0; k < o.n; k++) {
                            const cx = o.x + k * 22, h = o.h - (k % 2) * 8;
                            g.beginPath(); g.roundedRect(cx, gy - h, 16, h, 6, 6); g.fill();
                            g.beginPath(); g.roundedRect(cx - 6, gy - h * 0.62, 6, h * 0.3, 3, 3); g.fill();
                            g.beginPath(); g.roundedRect(cx + 16, gy - h * 0.75, 6, h * 0.3, 3, 3); g.fill();
                        }
                    }
                }
                // динозавр
                const x = root.dinoX, y = gy - root.dy;
                g.fillStyle = root.over ? Theme.red : Theme.accent;
                if (root.ducking && root.dy < 1) {
                    g.beginPath(); g.roundedRect(x, y - 30, 58, 24, 8, 8); g.fill();
                    g.beginPath(); g.roundedRect(x + 40, y - 34, 24, 18, 5, 5); g.fill();
                } else {
                    g.beginPath(); g.roundedRect(x, y - 40, 32, 30, 8, 8); g.fill();          // тело
                    g.beginPath(); g.roundedRect(x + 18, y - 56, 28, 20, 6, 6); g.fill();     // голова
                    g.beginPath(); g.moveTo(x, y - 34); g.lineTo(x - 14, y - 26); g.lineTo(x, y - 20); g.fill();   // хвост
                }
                // лапы: бегут, пока на земле
                const step = root.running && root.dy < 1 ? Math.floor(root.t * 14) % 2 : 0;
                g.fillRect(x + 6, y - 12, 6, step ? 12 : 8);
                g.fillRect(x + 20, y - 12, 6, step ? 8 : 12);
                // глаз
                g.fillStyle = Theme.crust;
                if (!(root.ducking && root.dy < 1)) g.fillRect(x + 34, y - 51, 4, 4);
                else g.fillRect(x + 54, y - 30, 3, 3);
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            text: String(root.score).padStart(5, "0")
            font.pixelSize: 22
            font.bold: true
            color: Theme.subtext1
        }
        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            visible: !root.running
            spacing: 10
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.over ? I18n.tr("Игра окончена") : I18n.tr("Динозавр")
                font.pixelSize: 30
                font.bold: true
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Пробел — прыжок · ↓ — пригнуться")
                color: Theme.subtext0
            }
        }
        MouseArea { anchors.fill: parent; onPressed: { root.forceActiveFocus(); root.holding = true; root.jump(); } onReleased: root.holding = false }
    }
}
