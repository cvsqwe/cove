import QtQuick
import QtQuick.Layouts
import qs.config
import "keys.js" as K
import qs.components

// Блоки (как Block Blast): перетаскивай три фигуры снизу на поле 8×8. Заполненные ряды и столбцы
// исчезают; несколько линий сразу и серия ходов с линиями подряд дают множитель.
// Партия кончается, когда ни одна из оставшихся фигур никуда не встаёт.
Item {
    id: root
    property bool active: false
    property int score: 0
    property int combo: 0
    property bool over: false
    readonly property string status: I18n.tr("Счёт: ") + score + (combo > 1 ? I18n.tr(" · серия ×") + combo : "")
    readonly property string bestKey: "blocks"
    readonly property bool lowerBetter: false
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)

    focus: true
    readonly property int size: 8
    property var board: []          // size*size: -1 — пусто, иначе номер цвета
    property var tray: []           // три фигуры { cells: [[r, c]…], color } или null
    property int rev: 0

    readonly property var tints: [Theme.red, Theme.peach, Theme.yellow, Theme.green, Theme.teal, Theme.accent2, Theme.accent, Theme.pink]
    // фигуры: клетки относительно левого верхнего угла
    readonly property var shapes: [
        [[0, 0]],
        [[0, 0], [0, 1]], [[0, 0], [1, 0]],
        [[0, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [2, 0]],
        [[0, 0], [0, 1], [0, 2], [0, 3]], [[0, 0], [1, 0], [2, 0], [3, 0]],
        [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]], [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]],
        [[0, 0], [0, 1], [1, 0], [1, 1]],
        [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2], [2, 0], [2, 1], [2, 2]],
        [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]], [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]],
        [[0, 0], [1, 0], [1, 1]], [[0, 1], [1, 0], [1, 1]], [[0, 0], [0, 1], [1, 0]], [[0, 0], [0, 1], [1, 1]],
        [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2]], [[0, 2], [1, 2], [2, 0], [2, 1], [2, 2]], [[0, 0], [0, 1], [0, 2], [1, 0], [2, 0]], [[0, 0], [0, 1], [0, 2], [1, 2], [2, 2]],
        [[0, 0], [0, 1], [0, 2], [1, 1]], [[0, 1], [1, 0], [1, 1], [1, 2]], [[0, 0], [1, 0], [1, 1], [2, 0]], [[0, 1], [1, 0], [1, 1], [2, 1]],
        [[0, 1], [0, 2], [1, 0], [1, 1]], [[0, 0], [0, 1], [1, 1], [1, 2]], [[0, 0], [1, 0], [1, 1], [2, 1]], [[0, 1], [1, 0], [1, 1], [2, 0]],
        [[0, 0], [1, 0], [2, 0], [2, 1]], [[0, 1], [1, 1], [2, 0], [2, 1]], [[0, 0], [0, 1], [1, 0], [2, 0]], [[0, 0], [0, 1], [1, 1], [2, 1]]
    ]

    function newPiece(): var {
        // крупные фигуры реже: веса по числу клеток
        let s;
        do { s = shapes[Math.floor(Math.random() * shapes.length)]; } while (s.length >= 6 && Math.random() < 0.5);
        return { cells: s, color: Math.floor(Math.random() * tints.length) };
    }
    // Новый набор всегда проходим: каждая из трёх фигур встаёт на поле сразу, и все три
    // можно поставить хотя бы в одном порядке (с учётом линий, которые исчезнут по пути). Не нашлось за 60 попыток —
    // берём фигуры помельче, лишь бы каждая куда-то вставала.
    function refill(): void {
        for (let attempt = 0; attempt < 60; attempt++) {
            const set = [newPiece(), newPiece(), newPiece()];
            // каждая встаёт уже сейчас (иначе в лотке бледная «недоступная» фигура) и весь набор проходим
            if (set.every(x => anyFitOn(board, x)) && solvable(board, set)) { tray = set; return; }
        }
        const small = shapes.filter(s => s.length <= 3);
        const set = [];
        for (let i = 0; i < 3; i++) {
            const fit = small.filter(s => anyFitOn(board, { cells: s }));
            const pick = (fit.length ? fit : small)[Math.floor(Math.random() * (fit.length || small.length))];
            set.push({ cells: pick, color: Math.floor(Math.random() * tints.length) });
        }
        tray = set;
    }

    // ---- проверка набора на чужой доске (не трогает board) ----
    function fitsOn(b, p, r: int, c: int): bool {
        for (const [dr, dc] of p.cells) {
            const rr = r + dr, cc = c + dc;
            if (rr < 0 || cc < 0 || rr >= size || cc >= size || b[rr * size + cc] >= 0) return false;
        }
        return true;
    }
    function anyFitOn(b, p): bool {
        for (let r = 0; r < size; r++) for (let c = 0; c < size; c++) if (fitsOn(b, p, r, c)) return true;
        return false;
    }
    // поставить и убрать заполненные линии; возвращает новую доску и сколько линий ушло
    function placeOn(b, p, r: int, c: int): var {
        const nb = b.slice();
        for (const [dr, dc] of p.cells) nb[(r + dr) * size + c + dc] = 0;
        const full = [];
        for (let i = 0; i < size; i++) {
            let fr = true, fc = true;
            for (let j = 0; j < size; j++) { if (nb[i * size + j] < 0) fr = false; if (nb[j * size + i] < 0) fc = false; }
            if (fr) for (let j = 0; j < size; j++) full.push(i * size + j);
            if (fc) for (let j = 0; j < size; j++) full.push(j * size + i);
        }
        for (const k of full) nb[k] = -1;
        return { b: nb, cleared: full.length };
    }
    // есть ли порядок, в котором встают все фигуры; на каждом шаге пробуем все позиции
    // (поиск с возвратом, но с отсечкой: доска 8×8 и три фигуры — это быстро)
    function solvable(b, pieces): bool {
        if (!pieces.length) return true;
        for (let i = 0; i < pieces.length; i++) {
            const rest = pieces.slice(0, i).concat(pieces.slice(i + 1));
            const tried = new Set();
            for (let r = 0; r < size; r++) for (let c = 0; c < size; c++) {
                if (!fitsOn(b, pieces[i], r, c)) continue;
                const next = placeOn(b, pieces[i], r, c);
                const key = next.b.join(",");
                if (tried.has(key)) continue;
                tried.add(key);
                if (solvable(next.b, rest)) return true;
            }
        }
        return false;
    }
    function restart(): void {
        if (score > 0 && !over) record(score);
        board = new Array(size * size).fill(-1);
        score = 0; combo = 0; over = false;
        refill();
        rev++;
    }
    Component.onCompleted: restart()

    function fits(p, r: int, c: int): bool {
        for (const [dr, dc] of p.cells) {
            const rr = r + dr, cc = c + dc;
            if (rr < 0 || cc < 0 || rr >= size || cc >= size || board[rr * size + cc] >= 0) return false;
        }
        return true;
    }
    function anyFit(p): bool {
        for (let r = 0; r < size; r++) for (let c = 0; c < size; c++) if (fits(p, r, c)) return true;
        return false;
    }
    // какие ряды и столбцы заполнятся, если поставить фигуру
    function wouldClear(p, r: int, c: int): var {
        const b = board.slice();
        for (const [dr, dc] of p.cells) b[(r + dr) * size + c + dc] = 0;
        const rowsF = [], colsF = [];
        for (let i = 0; i < size; i++) {
            let fr = true, fc = true;
            for (let j = 0; j < size; j++) { if (b[i * size + j] < 0) fr = false; if (b[j * size + i] < 0) fc = false; }
            if (fr) rowsF.push(i);
            if (fc) colsF.push(i);
        }
        return { rows: rowsF, cols: colsF };
    }
    function place(slot: int, r: int, c: int): bool {
        const p = tray[slot];
        if (!p || !fits(p, r, c)) return false;
        const clr = wouldClear(p, r, c);
        for (const [dr, dc] of p.cells) board[(r + dr) * size + c + dc] = p.color;
        score += p.cells.length;
        const n = clr.rows.length + clr.cols.length;
        const before = score;
        if (n > 0) {
            combo++;
            const gone = new Set();
            for (const i of clr.rows) for (let j = 0; j < size; j++) gone.add(i * size + j);
            for (const i of clr.cols) for (let j = 0; j < size; j++) gone.add(j * size + i);
            for (const k of gone) board[k] = -1;
            score += gone.size * n * combo;
            lastClear = Array.from(gone);
            sfx(n > 1 || combo > 1 ? "combo" : "line");
            const cell = board_.cell, pad = board_.pad;
            for (const i of clr.rows) fx("burst", board_, pad + 4 * cell, pad + (i + 0.5) * cell, "22", tints[p.color]);
            for (const i of clr.cols) fx("burst", board_, pad + (i + 0.5) * cell, pad + 4 * cell, "22", tints[p.color]);
            fx("float", board_, pad + (c + 1) * cell, pad + (r + 0.5) * cell, "+" + (score - before + p.cells.length), Theme.yellow);
            if (n >= 3) fx("shake", null, 0, 0, "7", Theme.yellow);
        } else { combo = 0; sfx("pop"); }
        const t = tray.slice();
        t[slot] = null;
        tray = t.every(x => !x) ? (refill(), tray) : t;
        rev++;
        if (!tray.some(x => x && anyFit(x))) { over = true; sfx("over"); fx("shake", null, 0, 0, "8", Theme.red); record(score); }
        return true;
    }

    // ---- перетаскивание ----
    property int dragSlot: -1
    property point dragPos: Qt.point(0, 0)
    readonly property var dragPiece: dragSlot >= 0 ? tray[dragSlot] : null
    property var target: null           // { r, c } — куда встанет
    property var lastClear: []
    readonly property var preview: target && dragPiece ? wouldClear(dragPiece, target.r, target.c) : ({ rows: [], cols: [] })
    function pieceSize(p): var {
        let h = 0, w = 0;
        for (const [r, c] of p.cells) { h = Math.max(h, r + 1); w = Math.max(w, c + 1); }
        return { w, h };
    }
    function updateTarget(): void {
        if (!dragPiece) { target = null; return; }
        const sz = pieceSize(dragPiece), cell = board_.cell;
        // фигура висит над курсором: её центр чуть выше указателя
        const tl = board_.mapFromItem(root, dragPos.x - sz.w * cell / 2, dragPos.y - sz.h * cell / 2 - 36);
        const r = Math.round((tl.y - board_.pad) / cell), c = Math.round((tl.x - board_.pad) / cell);
        target = fits(dragPiece, r, c) ? { r, c } : null;
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 22

        Rectangle {
            id: board_
            readonly property real pad: 8
            readonly property real cell: Math.floor(Math.min(58, (root.height - 230) / root.size, (root.width - 80) / root.size))
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: cell * root.size + 2 * pad
            implicitHeight: implicitWidth
            radius: Theme.radius + 4
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface0

            Repeater {
                model: root.size * root.size
                Item {
                    id: cellItem
                    required property int index
                    readonly property int r: Math.floor(index / root.size)
                    readonly property int c: index % root.size
                    readonly property int v: { void root.rev; return root.board[index] ?? -1; }
                    readonly property bool ghost: root.target && root.dragPiece ? root.dragPiece.cells.some(([dr, dc]) => root.target.r + dr === r && root.target.c + dc === c) : false
                    readonly property bool lineHit: root.preview.rows.includes(r) || root.preview.cols.includes(c)
                    x: board_.pad + c * board_.cell
                    y: board_.pad + r * board_.cell
                    width: board_.cell
                    height: board_.cell
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Math.max(4, board_.cell * 0.16)
                        color: cellItem.v >= 0 ? root.tints[cellItem.v]
                            : cellItem.ghost ? Theme.alpha(root.tints[root.dragPiece.color], 0.45)
                            : Theme.alpha(Theme.surface0, 0.55)
                        border.width: cellItem.v >= 0 && cellItem.lineHit && !!root.target ? 3 : 0
                        border.color: Theme.text
                        // объём: светлая кромка сверху
                        Rectangle {
                            visible: cellItem.v >= 0
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 3 }
                            height: parent.height * 0.22
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.22)
                        }
                    }
                }
            }

            // вспышка на месте собранных линий
            Repeater {
                model: root.lastClear
                Rectangle {
                    id: fx
                    required property int modelData
                    x: board_.pad + (modelData % root.size) * board_.cell + 2
                    y: board_.pad + Math.floor(modelData / root.size) * board_.cell + 2
                    width: board_.cell - 4
                    height: width
                    radius: 6
                    color: Theme.text
                    opacity: 0
                    Component.onCompleted: fade.start()
                    ParallelAnimation {
                        id: fade
                        NumberAnimation { target: fx; property: "opacity"; from: 0.85; to: 0; duration: 380; easing.type: Easing.OutQuad }
                        NumberAnimation { target: fx; property: "scale"; from: 1; to: 1.35; duration: 380; easing.type: Easing.OutQuad }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -46
                visible: root.combo > 1
                text: I18n.tr("Серия ×") + root.combo
                font.pixelSize: 22
                font.bold: true
                color: Theme.yellow
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: root.over
                color: Theme.alpha(Theme.base, 0.84)
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Места больше нет"); font.pixelSize: 28; font.bold: true }
                    StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Счёт: ") + root.score; color: Theme.subtext0 }
                    SButton { anchors.horizontalCenter: parent.horizontalCenter; primary: true; icon: "refresh"; text: I18n.tr("Заново"); onClicked: { root.restart(); root.forceActiveFocus(); } }
                }
            }
        }

        // лоток с тремя фигурами
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Repeater {
                model: 3
                Rectangle {
                    id: slot
                    required property int index
                    readonly property var p: { void root.rev; return root.tray[index] ?? null; }
                    readonly property bool usable: !!p && root.anyFit(p)
                    readonly property real mini: Math.min(24, board_.cell * 0.45)
                    width: 150
                    height: 150
                    radius: Theme.radius + 2
                    color: sm.containsMouse && usable ? Theme.surface0 : Theme.mantle
                    Item {
                        anchors.centerIn: parent
                        visible: !!slot.p && root.dragSlot !== slot.index
                        opacity: slot.usable ? 1 : 0.3
                        readonly property var sz: slot.p ? root.pieceSize(slot.p) : ({ w: 0, h: 0 })
                        width: sz.w * slot.mini
                        height: sz.h * slot.mini
                        Repeater {
                            model: slot.p ? slot.p.cells : []
                            Rectangle {
                                required property var modelData
                                x: modelData[1] * slot.mini + 1
                                y: modelData[0] * slot.mini + 1
                                width: slot.mini - 2
                                height: slot.mini - 2
                                radius: 4
                                color: root.tints[slot.p.color]
                            }
                        }
                    }
                    MouseArea {
                        id: sm
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: slot.usable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
                        onPressed: m => {
                            if (!slot.usable || root.over) return;
                            root.dragSlot = slot.index;
                            root.dragPos = mapToItem(root, m.x, m.y);
                            root.updateTarget();
                        }
                        onPositionChanged: m => {
                            if (root.dragSlot !== slot.index) return;
                            root.dragPos = mapToItem(root, m.x, m.y);
                            root.updateTarget();
                        }
                        onReleased: {
                            if (root.dragSlot !== slot.index) return;
                            if (root.target) root.place(slot.index, root.target.r, root.target.c);
                            root.dragSlot = -1;
                            root.target = null;
                        }
                    }
                }
            }
        }
    }

    // фигура под курсором
    Item {
        visible: !!root.dragPiece
        z: 100
        readonly property var sz: root.dragPiece ? root.pieceSize(root.dragPiece) : ({ w: 0, h: 0 })
        x: root.dragPos.x - sz.w * board_.cell / 2
        y: root.dragPos.y - sz.h * board_.cell / 2 - 36
        Repeater {
            model: root.dragPiece ? root.dragPiece.cells : []
            Rectangle {
                required property var modelData
                x: modelData[1] * board_.cell + 2
                y: modelData[0] * board_.cell + 2
                width: board_.cell - 4
                height: board_.cell - 4
                radius: Math.max(4, board_.cell * 0.16)
                color: root.tints[root.dragPiece?.color ?? 0]
                opacity: root.target ? 0.95 : 0.7
            }
        }
    }

    Keys.onPressed: e => { const L = K.letter(e); if (L === "r") { restart(); e.accepted = true; } }
}
