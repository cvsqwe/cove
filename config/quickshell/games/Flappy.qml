import QtQuick
import qs.config
import "keys.js" as K
import qs.components

// Flappy: пробел / ↑ / клик — взмах. Трубы постепенно ускоряются, просвет понемногу сужается.
Item {
    id: root
    property bool active: false
    // профиль (GamesWindow) — у всех игр одинаковый набор, иначе Binding в окне зацикливается
    property var modes: []
    property int score: 0
    property bool running: false
    property bool over: false
    readonly property string status: I18n.tr("Счёт: ") + score
    readonly property string bestKey: "flappy"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    // ---- читы: окно проставляет cheats (открытые id); слово набирается во время игры ----
    property var cheats: []
    // профиль (GamesWindow)
    property bool legacy: false
    property var perks: []
    property string skin: ""
    signal event(string name, var data)
    onPerksChanged: if (!running && !over && score === 0) shield = perks.includes("flappy.startShield")
    readonly property var cheatCodes: [
        { id: "flappy.shield", code: "shield", run: () => { if (over || shield) return false; shield = true; return true; } },
        { id: "flappy.calm", code: "calm", run: () => { if (over || calm) return false; calm = true; calmTimer.restart(); return true; } }
    ]
    property bool calm: false          // «штиль»: всё вдвое медленнее
    Timer { id: calmTimer; interval: 8000; onTriggered: root.calm = false }
    property bool shield: false
    // щит гасит одно столкновение: трубу, в которую врезались, дальше не проверяем
    function useShield(p): void {
        shield = false;
        if (p) p.ghost = true;
        sfx("pop");
        fx("flash", null, 0, 0, "", Theme.accent2);
        fx("burst", field, birdX, by, "20", Theme.accent2);
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
        score = 0; over = false; running = false; shield = perks.includes("flappy.startShield"); calm = false;
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
        event("end", { score });
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
            const dt = Math.min(0.033, frameTime) * (root.calm ? 0.5 : 1);
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
                    if (root.score >= 20) root.unlock("flappy.shield");
                    if (root.score >= 40) root.unlock("flappy.calm");
                    root.sfx("point");
                    if (root.score % 10 === 0) root.fx("float", field, root.birdX, root.by - 40, root.score + "!", Theme.yellow);
                }
                // столкновение: круг птицы с прямоугольниками трубы
                const inX = root.birdX + root.birdR > p.x - 30 && root.birdX - root.birdR < p.x + 30;
                if (!p.ghost && inX && (root.by - root.birdR < p.gapY - p.gap / 2 || root.by + root.birdR > p.gapY + p.gap / 2)) {
                    if (root.shield) root.useShield(p); else { root.die(); break; }
                }
            }
            root.pipes = ps;
            if (root.by + root.birdR > root.fh - 24 || root.by < -40) {
                // о землю щит подбрасывает вверх
                if (root.shield && root.running) { root.useShield(null); root.vy = -520; root.by = Math.min(root.by, root.fh - 24 - root.birdR - 1); }
                else root.die();
            }
            canvas.requestPaint();
        }
    }

    Keys.onPressed: e => {
        const L = K.letter(e);
        feed(L);
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
                if (root.shield) {
                    g.strokeStyle = Theme.alpha(Theme.accent2, 0.8);
                    g.lineWidth = 3;
                    g.beginPath(); g.arc(0, 0, root.birdR + 7 + Math.sin(root.t * 8) * 1.5, 0, Math.PI * 2); g.stroke();
                }
                g.fillStyle = root.skin === "flappy.cardinal" ? "#e8484f" : root.skin === "flappy.ghost" ? Qt.rgba(0.92, 0.95, 1, 0.55) : Theme.yellow;
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
