import QtQuick
import QtQuick.Layouts
import qs.config
import "keys.js" as K
import qs.components

// Пары: переворачивай по две карточки, находи одинаковые. Рекорд — наименьшее число ходов.
Item {
    id: root
    property bool active: false
    // профиль (GamesWindow) — у всех игр одинаковый набор, иначе Binding в окне зацикливается
    property var modes: []
    property string size: "16"
    readonly property int count: Number(size)
    readonly property int cols: count === 16 ? 4 : 6
    property var cards: []         // [{ icon, color }]
    property var cardState: []         // 0 — рубашкой вверх, 1 — открыта, 2 — найдена
    property var picked: []
    property int moves: 0
    property int found: 0
    property int rev: 0
    readonly property bool won: found === count / 2
    readonly property string status: I18n.tr("Ходы: ") + moves + I18n.tr(" · пары: ") + found + "/" + (count / 2)
    readonly property string bestKey: "memory-" + size
    readonly property bool lowerBetter: true
    function bestText(v: real): string { return v + I18n.tr(" ход."); }
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
    property int luckRun: 0          // пары подряд с первой попытки с начала партии
    property bool luckBroken: false
    onPerksChanged: if (moves === 0 && perks.includes("memory.glimpse")) glimpse()
    function glimpse(): void { peeking = true; peekTimer.interval = 1000; peekTimer.restart(); }
    readonly property var cheatCodes: [
        { id: "memory.peek", code: "peek", run: () => { if (won) return false; peeking = true; peekTimer.interval = 1500; peekTimer.restart(); return true; } },
        { id: "memory.duo", code: "duo", run: () => {
            if (won || hideTimer.running || peeking) return false;
            // пара к уже открытой карточке, иначе — первая ненайденная
            const a = picked.length ? picked[0] : cardState.findIndex(v => v === 0);
            if (a < 0) return false;
            const b = cards.findIndex((c, i) => i !== a && c.icon === cards[a].icon);
            cardState[a] = 2; cardState[b] = 2; found++; picked = [];
            luckBroken = true;
            sfx("match");
            for (const k of [a, b]) { const it = rep.itemAt(k); if (it) fx("burst", it, it.width / 2, it.height / 2, "14", cards[k].color); }
            rev++;
            if (won) finishWin();
            return true;
        } }
    ]
    property bool peeking: false
    Timer { id: peekTimer; interval: 1500; onTriggered: root.peeking = false }
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
    onSizeChanged: restart()

    readonly property var icons: ["favorite", "star", "bolt", "pets", "rocket_launch", "local_florist", "music_note", "sunny",
        "cookie", "diamond", "eco", "sports_esports", "cruelty_free", "icecream", "anchor", "nightlight"]
    readonly property var tints: [Theme.red, Theme.yellow, Theme.accent, Theme.green, Theme.peach, Theme.pink, Theme.accent2, Theme.teal]

    function restart(): void {
        if (moves > 0 && !won) event("end", { won: false, size: count, moves });
        const pairs = [];
        for (let i = 0; i < count / 2; i++) {
            const c = { icon: icons[i], color: tints[i % tints.length] };
            pairs.push(c, c);
        }
        for (let i = pairs.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [pairs[i], pairs[j]] = [pairs[j], pairs[i]]; }
        cards = pairs;
        cardState = new Array(count).fill(0);
        picked = []; moves = 0; found = 0; peeking = false; luckRun = 0; luckBroken = false;
        if (perks.includes("memory.glimpse")) Qt.callLater(glimpse);
        rev++;
    }
    Component.onCompleted: restart()

    function flip(i: int): void {
        if (hideTimer.running || peeking || cardState[i] !== 0 || won) return;
        cardState[i] = 1;
        sfx("flip");
        picked = picked.concat([i]);
        if (picked.length === 2) {
            moves++;
            const [a, b] = picked;
            if (cards[a].icon === cards[b].icon) {
                cardState[a] = 2; cardState[b] = 2; found++; picked = [];
                if (!luckBroken && moves === found) { luckRun++; event("luck", { n: luckRun }); }
                sfx("match");
                for (const k of [a, b]) {
                    const it = rep.itemAt(k);
                    if (it) fx("burst", it, it.width / 2, it.height / 2, "14", cards[k].color);
                }
                if (won) finishWin();
            } else { luckBroken = true; hideTimer.restart(); }
        }
        rev++;
    }
    function finishWin(): void {
        if (count === 16 && moves <= 12) unlock("memory.peek");
        if (count === 24) unlock("memory.duo");
        event("win", { size: count, moves });
        event("end", { won: true, size: count, moves });
        sfx("win"); fx("confetti", null, 0, 0, "", Theme.accent); record(moves);
    }
    Timer {
        id: hideTimer
        interval: 750
        onTriggered: { for (const i of root.picked) root.cardState[i] = 0; root.picked = []; root.rev++; }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 18

        SSegment {
            Layout.alignment: Qt.AlignHCenter
            options: [{ value: "16", label: I18n.tr("4 × 4") }, { value: "24", label: I18n.tr("6 × 4") }]
            current: root.size
            onPicked: v => { root.size = v; root.forceActiveFocus(); }
        }

        Grid {
            id: grid
            readonly property real cell: Math.min(118, (root.height - 140) / (root.count / root.cols) - 12, (root.width - 80) / root.cols - 12)
            Layout.alignment: Qt.AlignHCenter
            columns: root.cols
            spacing: 12
            Repeater {
                id: rep
                model: root.count
                Item {
                    id: card
                    required property int index
                    readonly property int s: { void root.rev; return root.cardState[index] ?? 0; }
                    readonly property var info: { void root.rev; return root.cards[index] ?? ({}); }
                    width: grid.cell
                    height: grid.cell

                    // переворот: половина поворота — рубашка, вторая — лицо
                    property real angle: s > 0 || root.peeking ? 180 : 0
                    Behavior on angle { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
                    transform: Rotation { origin.x: card.width / 2; origin.y: card.height / 2; axis { x: 0; y: 1; z: 0 } angle: card.angle }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius + 2
                        visible: card.angle < 90
                        color: root.skin === "memory.neon" ? Qt.hsla((card.index * 0.07) % 1, 0.7, cm.containsMouse ? 0.4 : 0.32, 1)
                            : cm.containsMouse ? Theme.surface2 : Theme.surface1
                        border.width: root.skin === "memory.neon" ? 2 : 0
                        border.color: Qt.hsla((card.index * 0.07) % 1, 0.9, 0.65, 1)
                        MIcon { anchors.centerIn: parent; icon: "cove"; size: card.width * 0.3; color: root.skin === "memory.neon" ? Qt.hsla((card.index * 0.07) % 1, 0.9, 0.75, 1) : Theme.overlay1 }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius + 2
                        visible: card.angle >= 90
                        // лицо зеркалим обратно, иначе значок перевёрнут
                        transform: Rotation { origin.x: card.width / 2; axis { x: 0; y: 1; z: 0 } angle: 180 }
                        color: card.s === 2 ? Theme.alpha(card.info.color ?? Theme.accent, 0.22) : Theme.mantle
                        border.width: 2
                        border.color: card.info.color ?? Theme.accent
                        MIcon { anchors.centerIn: parent; icon: card.info.icon ?? ""; fill: true; size: card.width * 0.42; color: card.info.color ?? Theme.accent }
                    }
                    MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.flip(card.index) }
                }
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.won
        width: res.implicitWidth + 56
        height: res.implicitHeight + 40
        radius: Theme.radius + 4
        color: Theme.alpha(Theme.base, 0.94)
        border.width: 1
        border.color: Theme.green
        Column {
            id: res
            anchors.centerIn: parent
            spacing: 10
            StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Все пары найдены!"); font.pixelSize: 26; font.bold: true }
            StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Ходов: ") + root.moves; color: Theme.subtext0 }
            SButton { anchors.horizontalCenter: parent.horizontalCenter; primary: true; icon: "refresh"; text: I18n.tr("Ещё раз"); onClicked: { root.restart(); root.forceActiveFocus(); } }
        }
    }

    Keys.onPressed: e => { const L = K.letter(e); feed(L); if (L === "r") { restart(); e.accepted = true; } }
}
