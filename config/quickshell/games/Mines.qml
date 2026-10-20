import QtQuick
import QtQuick.Layouts
import qs.config
import "keys.js" as K
import qs.components

// Сапёр: ЛКМ — открыть, ПКМ — флажок, ЛКМ по цифре с нужным числом флажков вокруг — открыть соседей.
// Первый клик всегда безопасный. Рекорд — время на каждом уровне.
Item {
    id: root
    property bool active: false
    property string level: "easy"
    readonly property var levels: ({ easy: [9, 9, 10], medium: [16, 16, 40], hard: [30, 16, 99], extreme: [30, 20, 150] })

    // профиль (GamesWindow)
    property bool legacy: false
    property var perks: []
    property string skin: ""
    property var modes: []
    signal event(string name, var data)
    property bool flagged: false            // ставили ли флажки (достижение «без флажков»)
    property bool vestUsed: false           // перк «сапёрский жилет»
    readonly property int cols: levels[level][0]
    readonly property int rows: levels[level][1]
    readonly property int mines: levels[level][2]
    readonly property int n: cols * rows

    property var mine: []
    property var cnt: []
    property var st: []            // 0 — закрыта, 1 — открыта, 2 — флажок
    property int rev: 0
    property bool started: false
    property bool over: false
    property bool won: false
    property int flags: 0
    property int seconds: 0
    property int boom: -1          // клетка, на которой подорвались

    readonly property string status: "💣 " + (mines - flags) + "   ⏱ " + seconds + I18n.tr(" с")
    readonly property string bestKey: "mines-" + level
    readonly property bool lowerBetter: true
    function bestText(v: real): string { return v + I18n.tr(" с"); }
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    // ---- читы: окно проставляет cheats (открытые id); слово набирается во время игры ----
    property var cheats: []
    readonly property var cheatCodes: [
        { id: "mines.xray", code: "eye", run: () => { if (over || !started) return false; xray = true; xrayTimer.restart(); return true; } },
        { id: "mines.hint", code: "hint", run: () => {
            if (over || !started) return false;
            // безопасная закрытая клетка рядом с открытой; таких нет — любая безопасная
            const safe = [];
            for (let k = 0; k < n; k++) if (st[k] === 0 && !mine[k]) safe.push(k);
            if (!safe.length) return false;
            const edge = safe.filter(k => nb(k).some(j => st[j] === 1));
            const pool = edge.length ? edge : safe;
            const k = pool[Math.floor(Math.random() * pool.length)];
            reveal(k);
            const c = cellCenter(k);
            fx("burst", grid_, c.x, c.y, "12", Theme.accent);
            checkWin(); rev++;
            return true;
        } }
    ]
    property bool xray: false
    Timer { id: xrayTimer; interval: 2500; onTriggered: root.xray = false }
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
    onLevelChanged: restart()

    function restart(): void {
        mine = new Array(n).fill(false);
        cnt = new Array(n).fill(0);
        st = new Array(n).fill(0);
        started = false; over = false; won = false; flags = 0; seconds = 0; boom = -1;
        xray = false; flagged = false; vestUsed = false;
        rev++;
    }
    Component.onCompleted: restart()

    function nb(i: int): var {
        const x = i % cols, y = Math.floor(i / cols), out = [];
        for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
            if (!dx && !dy) continue;
            const nx = x + dx, ny = y + dy;
            if (nx >= 0 && ny >= 0 && nx < cols && ny < rows) out.push(ny * cols + nx);
        }
        return out;
    }
    function plant(safe: int): void {
        const banned = new Set([safe, ...nb(safe)]);
        let left = mines;
        while (left > 0) {
            const i = Math.floor(Math.random() * n);
            if (mine[i] || banned.has(i)) continue;
            mine[i] = true;
            left--;
        }
        for (let i = 0; i < n; i++) cnt[i] = nb(i).filter(j => mine[j]).length;
        started = true;
    }
    function reveal(i: int): void {
        const stack = [i];
        while (stack.length) {
            const k = stack.pop();
            if (st[k] !== 0) continue;
            st[k] = 1;
            if (mine[k]) {
                if (perks.includes("mines.secondChance") && !vestUsed) {
                    vestUsed = true;
                    st[k] = 2; flags++;
                    sfx("boom");
                    fx("shake", null, 0, 0, "8", Theme.peach);
                    const c = cellCenter(k);
                    fx("float", grid_, c.x, c.y, I18n.tr("жилет спас!"), Theme.peach);
                    continue;
                }
                boom = k; lose(); return;
            }
            if (cnt[k] === 0) for (const j of nb(k)) if (st[j] === 0) stack.push(j);
        }
    }
    function lose(): void {
        over = true;
        sfx("boom");
        fx("shake", null, 0, 0, "14", Theme.red);
        fx("flash", null, 0, 0, "", Theme.red);
        const bc = cellCenter(boom);
        fx("burst", grid_, bc.x, bc.y, "40", Theme.peach);
        for (let k = 0; k < n; k++) if (mine[k] && st[k] !== 2) st[k] = 1;
        event("end", { won: false, level, seconds });
    }
    function checkWin(): void {
        if (over) return;
        for (let k = 0; k < n; k++) if (!mine[k] && st[k] !== 1) return;
        over = true; won = true;
        for (let k = 0; k < n; k++) if (mine[k]) st[k] = 2;
        flags = mines;
        sfx("win");
        fx("confetti", null, 0, 0, "", Theme.green);
        unlock("mines.hint");
        if (level !== "easy") unlock("mines.xray");
        event("win", { level, seconds, flagged });
        event("end", { won: true, level, seconds });
        record(Math.max(1, seconds));
    }
    function open(i: int): void {
        if (over) return;
        if (!started) plant(i);
        if (st[i] === 0) {
            const before = st.filter(v => v === 1).length;
            reveal(i);
            if (!over) {
                const opened = st.filter(v => v === 1).length - before;
                sfx(opened > 8 ? "line" : "reveal");
                if (opened > 8) { const c = cellCenter(i); fx("burst", grid_, c.x, c.y, "16", Theme.accent); }
            }
        }
        else if (st[i] === 1 && cnt[i] > 0) {
            // аккорд: флажков вокруг столько, сколько мин — открываем остальных соседей
            const around = nb(i);
            if (around.filter(j => st[j] === 2).length === cnt[i])
                for (const j of around) if (st[j] === 0) { reveal(j); if (over) break; }
        }
        checkWin();
        rev++;
    }
    function flag(i: int): void {
        if (over || st[i] === 1) return;
        st[i] = st[i] === 2 ? 0 : 2;
        if (st[i] === 2) flagged = true;
        sfx("flag");
        flags += st[i] === 2 ? 1 : -1;
        rev++;
    }

    Timer {
        running: root.active && root.started && !root.over
        interval: 1000
        repeat: true
        onTriggered: root.seconds++
    }

    function cellCenter(i: int): point { return Qt.point((i % cols + 0.5) * board.cell, (Math.floor(i / cols) + 0.5) * board.cell); }

    readonly property var numColors: [Theme.text, Theme.accent2, Theme.green, Theme.red, Theme.accent, Theme.peach, Theme.teal, Theme.text, Theme.overlay1]

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        SSegment {
            Layout.alignment: Qt.AlignHCenter
            options: [{ value: "easy", label: I18n.tr("Новичок") }, { value: "medium", label: I18n.tr("Любитель") }, { value: "hard", label: I18n.tr("Профи") }]
                .concat(root.modes.includes("mines.extreme") ? [{ value: "extreme", label: I18n.tr("Экстрим") }] : [])
            current: root.level
            onPicked: v => { root.level = v; root.forceActiveFocus(); }
        }

        Rectangle {
            id: board
            readonly property real cell: Math.floor(Math.min(40, (root.width - 60) / root.cols, (root.height - 150) / root.rows))
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: cell * root.cols + 12
            implicitHeight: cell * root.rows + 12
            radius: Theme.radius
            color: Theme.mantle

            Grid {
                id: grid_
                x: 6; y: 6
                columns: root.cols
                Repeater {
                    model: root.n
                    Rectangle {
                        id: c
                        required property int index
                        readonly property int s: { void root.rev; return root.st[index] ?? 0; }
                        readonly property bool isMine: { void root.rev; return root.mine[index] ?? false; }
                        readonly property int num: { void root.rev; return root.cnt[index] ?? 0; }
                        width: board.cell
                        height: board.cell
                        color: "transparent"
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1.5
                            radius: Math.max(3, board.cell * 0.18)
                            color: c.s === 1 ? (c.index === root.boom ? Theme.red : Theme.alpha(Theme.surface0, 0.45))
                                : cm.containsMouse && !root.over ? Theme.surface2 : Theme.surface1
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }
                        StyledText {
                            anchors.centerIn: parent
                            visible: c.s === 1 && !c.isMine && c.num > 0
                            text: c.num
                            font.bold: true
                            font.pixelSize: board.cell * 0.5
                            color: root.numColors[c.num]
                        }
                        MIcon {
                            anchors.centerIn: parent
                            visible: c.s === 2 || (c.s === 1 && c.isMine) || (root.xray && c.isMine)
                            opacity: c.s === 0 ? 0.55 : 1
                            icon: c.s === 2 ? "flag" : "brightness_7"
                            fill: true
                            size: board.cell * 0.5
                            color: c.s === 2 ? (root.over && !c.isMine ? Theme.overlay1 : Theme.red)
                                : c.index === root.boom ? Theme.crust : Theme.text
                        }
                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: m => m.button === Qt.RightButton ? root.flag(c.index) : root.open(c.index)
                        }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                visible: root.over
                width: res.implicitWidth + 48
                height: res.implicitHeight + 36
                radius: Theme.radius + 4
                color: Theme.alpha(Theme.base, 0.92)
                border.width: 1
                border.color: root.won ? Theme.green : Theme.red
                Column {
                    id: res
                    anchors.centerIn: parent
                    spacing: 10
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.won ? I18n.tr("Поле разминировано!") : I18n.tr("Бум!")
                        font.pixelSize: 26
                        font.bold: true
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.won
                        text: I18n.tr("Время: ") + root.seconds + I18n.tr(" с")
                        color: Theme.subtext0
                    }
                    SButton { anchors.horizontalCenter: parent.horizontalCenter; primary: true; icon: "refresh"; text: I18n.tr("Ещё раз"); onClicked: { root.restart(); root.forceActiveFocus(); } }
                }
            }
        }
    }

    Keys.onPressed: e => { const L = K.letter(e); feed(L); if (L === "r") { restart(); e.accepted = true; } }
}
