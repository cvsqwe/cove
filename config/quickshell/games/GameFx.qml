import QtQuick
import QtMultimedia
import Quickshell
import qs.config

// Звуки и эффекты игр. Слой лежит поверх игры (без мыши — клики проходят).
// Игры зовут его через сигналы sfx/fx (см. GamesWindow): координаты — уже в координатах слоя.
//   sound(name)                    — assets/sounds/games/<name>.wav (SoundEffect: без задержки, звуки накладываются)
//   floatText(x, y, text, color)   — всплывающие очки «+40»
//   burst(x, y, color, count)      — искры во все стороны
//   confetti()                     — конфетти сверху (рекорд, победа)
//   shake(power)                   — встряска (dx — сдвиг для Translate у игры)
//   flash(color)                   — вспышка всего поля
Item {
    id: root
    property bool muted: false
    property real volume: 0.7

    // ---- звук: на каждое имя — несколько SoundEffect по кругу, чтобы частые звуки не обрывали друг друга ----
    readonly property var names: ["move", "pop", "merge", "line", "combo", "boom", "flag", "reveal", "jump", "flap",
        "point", "hit", "over", "win", "record", "key", "err", "flip", "match", "start"]
    property var pool: ({})
    property var turn: ({})
    Component {
        id: sfxC
        SoundEffect { }
    }
    Component.onCompleted: {
        const p = {};
        for (const n of names) {
            p[n] = [];
            for (let i = 0; i < (n === "key" || n === "move" || n === "pop" ? 4 : 2); i++)
                p[n].push(sfxC.createObject(root, { source: "file://" + Quickshell.shellPath("assets/sounds/games/" + n + ".wav") }));
        }
        pool = p;
    }
    function sound(name: string): void {
        if (muted || !pool[name]) return;
        const list = pool[name], k = ((turn[name] ?? -1) + 1) % list.length;
        turn[name] = k;
        const s = list[k];
        s.volume = volume;
        s.stop();
        s.play();
    }

    // ---- всплывающий текст ----
    Component {
        id: floatC
        Text {
            id: ft
            property color tint: Theme.text
            color: tint
            font.family: Theme.fontHeading
            font.pixelSize: 26
            font.bold: true
            style: Text.Outline
            styleColor: Theme.alpha(Theme.crust, 0.6)
            Component.onCompleted: anim.start()
            ParallelAnimation {
                id: anim
                NumberAnimation { target: ft; property: "y"; to: ft.y - 70; duration: 750; easing.type: Easing.OutCubic }
                NumberAnimation { target: ft; property: "scale"; from: 0.6; to: 1.15; duration: 220; easing.type: Easing.OutBack }
                SequentialAnimation {
                    PauseAnimation { duration: 400 }
                    NumberAnimation { target: ft; property: "opacity"; to: 0; duration: 350 }
                }
                onFinished: ft.destroy()
            }
        }
    }
    function floatText(x: real, y: real, text: string, color: color): void {
        const t = floatC.createObject(root, { text, tint: color });
        t.x = x - t.implicitWidth / 2;
        t.y = y - t.implicitHeight / 2;
    }

    // ---- частицы: прямоугольники, летят по параболе, крутятся и гаснут ----
    Component {
        id: bitC
        Rectangle {
            id: bit
            property real vx: 0
            property real vy: 0
            property real g: 900
            property real life: 0.8
            property real t: 0
            property real x0: 0
            property real y0: 0
            property real spin: 0
            radius: width / 3
            antialiasing: true
            x: x0 + vx * t
            y: y0 + vy * t + g * t * t / 2
            rotation: spin * t
            opacity: Math.max(0, 1 - t / life)
            NumberAnimation on t {
                from: 0
                to: bit.life
                duration: bit.life * 1000
                onFinished: bit.destroy()
            }
        }
    }
    function burst(x: real, y: real, color: color, count: int): void {
        if (!Settings.appearance.animations) return;
        for (let i = 0; i < (count || 18); i++) {
            const a = Math.random() * Math.PI * 2, sp = 140 + Math.random() * 320, sz = 4 + Math.random() * 6;
            bitC.createObject(root, {
                x0: x - sz / 2, y0: y - sz / 2, width: sz, height: sz, color: Qt.lighter(color, 0.8 + Math.random() * 0.6),
                vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 120, g: 700, life: 0.5 + Math.random() * 0.45, spin: (Math.random() - 0.5) * 900
            });
        }
    }
    function confetti(): void {
        if (!Settings.appearance.animations) return;
        const cs = [Theme.red, Theme.yellow, Theme.green, Theme.accent, Theme.accent2, Theme.peach, Theme.pink, Theme.teal];
        for (let i = 0; i < 90; i++) {
            const w = 6 + Math.random() * 6;
            bitC.createObject(root, {
                x0: Math.random() * width, y0: -20 - Math.random() * 120, width: w, height: w * 0.45, color: cs[i % cs.length],
                vx: (Math.random() - 0.5) * 160, vy: 80 + Math.random() * 200, g: 260, life: 1.8 + Math.random() * 1.2, spin: (Math.random() - 0.5) * 720
            });
        }
    }

    // ---- встряска: сдвиг dx, его берёт Translate у игры ----
    property real dx: 0
    property real shakePower: 0
    function shake(power: real): void {
        if (!Settings.appearance.animations) return;
        shakePower = power || 8;
        shakeAnim.restart();
    }
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "dx"; to: root.shakePower; duration: 35 }
        NumberAnimation { target: root; property: "dx"; to: -root.shakePower * 0.8; duration: 50 }
        NumberAnimation { target: root; property: "dx"; to: root.shakePower * 0.5; duration: 50 }
        NumberAnimation { target: root; property: "dx"; to: -root.shakePower * 0.25; duration: 50 }
        NumberAnimation { target: root; property: "dx"; to: 0; duration: 50 }
    }

    // ---- вспышка ----
    Rectangle {
        id: flashRect
        anchors.fill: parent
        opacity: 0
        NumberAnimation { id: flashAnim; target: flashRect; property: "opacity"; from: 0.28; to: 0; duration: 320; easing.type: Easing.OutQuad }
    }
    function flash(color: color): void {
        if (!Settings.appearance.animations) return;
        flashRect.color = color;
        flashAnim.restart();
    }
}
