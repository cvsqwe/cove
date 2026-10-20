import QtQuick
import qs.config
import "keys.js" as K
import qs.components

// Flappy: пробел / ↑ / клик — взмах. Трубы постепенно ускоряются, просвет понемногу сужается.
Item {
    id: root
    property bool active: false
    property int score: 0
    property bool running: false
    property bool over: false
    readonly property string status: I18n.tr("Счёт: ") + score
    readonly property string bestKey: "flappy"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true

    // мир — в пикселях поля
    readonly property real fw: field.width
    readonly property real fh: field.height
    readonly property real birdX: fw * 0.28
    readonly property real birdR: 15
    property real by: 0
    property real vy: 0
    property var pipes: []            // [{ x, gapY, passed }]
    property real spawnIn: 0
    property real t: 0

    function restart(): void {
        if (score > 0 && !over) record(score);
        by = fh * 0.45; vy = 0; pipes = []; spawnIn = 0.6; t = 0;
        score = 0; over = false; running = false;
        canvas.requestPaint();
    }
    Component.onCompleted: Qt.callLater(restart)

    function flap(): void {
        if (over && Date.now() - diedAt < 450) return;   // нажатие в момент удара не перезапускает
        if (over) restart();      // и сразу взмах — новая партия с первого нажатия
        if (!running) sfx("start");
        running = true;
        vy = -430;
        sfx("flap");
    }
    property real diedAt: 0
    function die(): void {
        over = true;
        diedAt = Date.now();
        sfx("hit");
        fx("shake", null, 0, 0, "12", Theme.red);
        fx("flash", null, 0, 0, "", "#ffffff");
        fx("burst", field, birdX, by, "26", Theme.yellow);
        Qt.callLater(() => sfx("over"));
        running = false;
        record(score);
    }

    FrameAnimation {
        running: root.active && root.running
        onTriggered: {
            const dt = Math.min(0.033, frameTime);
            root.t += dt;
            const speed = 170 + Math.min(150, root.score * 4);
            const gap = Math.max(130, 175 - root.score * 1.5);
            root.vy += 1500 * dt;
            root.by += root.vy * dt;
            root.spawnIn -= dt;
            let ps = root.pipes.map(p => Object.assign({}, p, { x: p.x - speed * dt })).filter(p => p.x > -80);
            if (root.spawnIn <= 0) {
                const margin = 70;
                ps.push({ x: root.fw + 40, gapY: margin + gap / 2 + Math.random() * (root.fh - 2 * margin - gap), gap, passed: false });
                root.spawnIn = 1.55;
            }
            for (const p of ps) {
                if (!p.passed && p.x + 30 < root.birdX) {
                    p.passed = true;
                    root.score++;
                    root.sfx("point");
                    if (root.score % 10 === 0) root.fx("float", field, root.birdX, root.by - 40, root.score + "!", Theme.yellow);
                }
                // столкновение: круг птицы с прямоугольниками трубы
                const inX = root.birdX + root.birdR > p.x - 30 && root.birdX - root.birdR < p.x + 30;
                if (inX && (root.by - root.birdR < p.gapY - p.gap / 2 || root.by + root.birdR > p.gapY + p.gap / 2)) { root.die(); break; }
            }
            root.pipes = ps;
            if (root.by + root.birdR > root.fh - 24 || root.by < -40) root.die();
            canvas.requestPaint();
        }
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Up || L === "w") { flap(); e.accepted = true; }
        else if (L === "r") { restart(); e.accepted = true; }
    }

    Rectangle {
        id: field
        width: Math.min(520, parent.width - 60)
        height: Math.min(660, parent.height - 50)
        anchors.centerIn: parent
        radius: Theme.radius + 4
        clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(Theme.accent2, 0.22) }
            GradientStop { position: 1; color: Theme.mantle }
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d");
                g.reset();
                // трубы
                for (const p of root.pipes) {
                    g.fillStyle = Theme.green;
                    const top = p.gapY - p.gap / 2, bot = p.gapY + p.gap / 2;
                    g.beginPath(); g.roundedRect(p.x - 30, -10, 60, top + 10, 8, 8); g.fill();
                    g.beginPath(); g.roundedRect(p.x - 30, bot, 60, height - bot + 10, 8, 8); g.fill();
                    g.fillStyle = Theme.alpha(Theme.crust, 0.18);
                    g.fillRect(p.x + 14, -10, 10, top + 10);
                    g.fillRect(p.x + 14, bot, 10, height - bot);
                    g.fillStyle = Theme.teal;
                    g.beginPath(); g.roundedRect(p.x - 36, top - 22, 72, 22, 6, 6); g.fill();
                    g.beginPath(); g.roundedRect(p.x - 36, bot, 72, 22, 6, 6); g.fill();
                }
                // земля
                g.fillStyle = Theme.surface1;
                g.fillRect(0, height - 24, width, 24);
                g.fillStyle = Theme.surface2;
                const off = (root.t * 170) % 24;
                for (let x = -off; x < width; x += 24) g.fillRect(x, height - 24, 12, 4);
                // птица: наклон по скорости
                g.save();
                g.translate(root.birdX, root.by);
                g.rotate(Math.max(-0.5, Math.min(1.2, root.vy / 600)));
                g.fillStyle = Theme.yellow;
                g.beginPath(); g.arc(0, 0, root.birdR, 0, Math.PI * 2); g.fill();
                g.fillStyle = Theme.peach;
                g.beginPath(); g.moveTo(10, -2); g.lineTo(24, 3); g.lineTo(10, 8); g.fill();
                g.fillStyle = "#ffffff";
                g.beginPath(); g.arc(5, -5, 5, 0, Math.PI * 2); g.fill();
                g.fillStyle = "#1a1a1a";
                g.beginPath(); g.arc(6.5, -5, 2.4, 0, Math.PI * 2); g.fill();
                g.fillStyle = Theme.alpha(Theme.peach, 0.85);
                g.beginPath(); g.ellipse(-14, -1 + Math.sin(root.t * 22) * 3, 14, 8); g.fill();
                g.restore();
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 24
            visible: root.running || root.over
            text: root.score
            font.pixelSize: 54
            font.bold: true
            style: Text.Outline
            styleColor: Theme.crust
        }

        Column {
            anchors.centerIn: parent
            visible: !root.running
            spacing: 12
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.over ? I18n.tr("Бам!") : "Flappy"
                font.pixelSize: 34
                font.bold: true
                style: Text.Outline
                styleColor: Theme.crust
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.over ? I18n.tr("Пробел — ещё раз") : I18n.tr("Пробел или клик — взмах")
                color: Theme.subtext1
            }
        }

        MouseArea { anchors.fill: parent; onPressed: { root.forceActiveFocus(); root.flap(); } }
    }
}
