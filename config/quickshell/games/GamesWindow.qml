import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "keys.js" as K

// Окно «Игры»: витрина, страницы профиля и сами игры (games/*.qml).
// Два экземпляра (shell.qml): обычный — `qs ipc call games open [id]` — с прокачкой, достижениями
// и читами; Legacy (legacy: true) — `qs ipc call gamesLegacy open [id]` — чистые игры и свои рекорды.
//
// Игра — Item с:
//   property bool active          — окно на экране и игра открыта (иначе таймеры стоят);
//   property string status        — строка для шапки («Счёт: 120 · Уровень 3»);
//   property string bestKey       — ключ рекорда в Store.gameScores (может зависеть от режима);
//   property bool lowerBetter     — рекорд — меньшее значение (время, ходы);
//   function bestText(v): string  — как показать рекорд (необязательно);
//   function restart()
//   signal record(real value)     — партия закончена с результатом value
//   signal sfx(string name)       — звук (GameFx.names)
//   signal fx(string kind, Item at, real x, real y, string text, color tint)
//                                 — эффект: float | burst | confetti | shake | flash; x, y — в координатах at
//   signal event(string name, var data) — для профиля: "end" { score, … } обязательно, остальные — свои
// необязательные свойства, которые проставляет окно: legacy, cheats (+ unlock/cheatUsed),
// perks (надетые перки), skin (id скина), modes (открытые режимы).
Scope {
    id: root

    property bool legacy: false
    property bool shown: false
    property string current: ""   // id открытой игры; "" — витрина
    property string page: ""      // страница вместо витрины: secrets | ach | prog

    readonly property var games: [
        { id: "rhythm", file: "Rhythm", name: I18n.tr("Ритм"), icon: "music_note", color: Theme.pink, desc: I18n.tr("Как osu!: круги, дорожки, барабан — под любую музыку") },
        { id: "survival", file: "Survival", name: I18n.tr("Выживание"), icon: "swords", color: Theme.red, desc: I18n.tr("Волны врагов, оружие само стреляет, выбор улучшений") },
        { id: "blocks", file: "Blocks", name: I18n.tr("Блоки"), icon: "grid_view", color: Theme.accent, desc: I18n.tr("Ставь фигуры на поле 8×8, собирай линии") },
        { id: "g2048", file: "Game2048", name: "2048", icon: "filter_9_plus", color: Theme.yellow, desc: I18n.tr("Сдвигай плитки, складывай одинаковые") },
        { id: "tetris", file: "Tetris", name: I18n.tr("Тетрис"), icon: "view_quilt", color: Theme.accent2, desc: I18n.tr("Классика: собирай ряды из падающих фигур") },
        { id: "snake", file: "Snake", name: I18n.tr("Змейка"), icon: "gesture", color: Theme.green, desc: I18n.tr("Ешь и расти, не врезайся в себя") },
        { id: "mines", file: "Mines", name: I18n.tr("Сапёр"), icon: "flag", color: Theme.red, desc: I18n.tr("Открой всё поле и не подорвись") },
        { id: "typing", file: "Typing", name: I18n.tr("Печать"), icon: "keyboard", color: Theme.teal, desc: I18n.tr("Скорость печати, как MonkeyType") },
        { id: "flappy", file: "Flappy", name: "Flappy", icon: "flutter_dash", color: Theme.peach, desc: I18n.tr("Пролети между трубами") },
        { id: "dino", file: "Dino", name: I18n.tr("Динозавр"), icon: "directions_run", color: Theme.lavender, desc: I18n.tr("Беги и прыгай через кактусы") },
        { id: "memory", file: "Memory", name: I18n.tr("Пары"), icon: "style", color: Theme.pink, desc: I18n.tr("Найди все одинаковые карточки") }
    ]
    readonly property var game: games.find(g => g.id === current) ?? null

    // Скрытые читы: сначала открыть достижением, потом набрать слово во время игры.
    // Буквы — по физическим клавишам (games/keys.js) и не пересекаются с управлением игры.
    // tier: 1 — бронза (слабый, открыть легко), 2 — серебро, 3 — золото (сильный, открыть трудно).
    // charge — перезарядка: { sec } — секунды игры, { ev, n, field, unit } — n событий ev (или сумма поля field),
    // { run: true } — раз за партию. Все читы снова готовы, когда партия кончается.
    readonly property var cheatList: [
        { id: "blocks.swap", game: "blocks", tier: 1, name: I18n.tr("Перетасовка"), code: "swap", how: I18n.tr("Сделай серию ×3"), desc: I18n.tr("Заменить три фигуры в лотке"), charge: { ev: "clear", field: "lines", n: 4, unit: I18n.tr("лин.") } },
        { id: "blocks.tiny", game: "blocks", tier: 2, name: I18n.tr("Крошки"), code: "tiny", how: I18n.tr("Сделай серию ×6"), desc: I18n.tr("Лоток — три одиночных клетки"), charge: { ev: "clear", field: "lines", n: 10, unit: I18n.tr("лин.") } },
        { id: "blocks.wipe", game: "blocks", tier: 3, name: I18n.tr("Чистый лист"), code: "wipe", how: I18n.tr("Очисти поле целиком"), desc: I18n.tr("Стереть всё поле"), charge: { run: true } },
        { id: "g2048.undo", game: "g2048", tier: 1, name: I18n.tr("Отмена хода"), code: "nope", how: I18n.tr("Собери плитку 256"), desc: I18n.tr("Вернуть последний ход"), charge: { sec: 30 } },
        { id: "g2048.clean", game: "g2048", tier: 2, name: I18n.tr("Уборка"), code: "pop", how: I18n.tr("Собери плитку 1024"), desc: I18n.tr("Убрать с поля все двойки"), charge: { sec: 120 } },
        { id: "tetris.long", game: "tetris", tier: 1, name: I18n.tr("Палка"), code: "long", how: I18n.tr("Собери 20 линий за партию"), desc: I18n.tr("Следующая фигура — длинная палка"), charge: { ev: "clear", field: "n", n: 6, unit: I18n.tr("лин.") } },
        { id: "tetris.slow", game: "tetris", tier: 1, name: I18n.tr("Замедление"), code: "yolo", how: I18n.tr("Дойди до третьего уровня"), desc: I18n.tr("Фигуры падают медленнее 20 секунд"), charge: { sec: 60 } },
        { id: "tetris.bonk", game: "tetris", tier: 2, name: I18n.tr("Ластик"), code: "bonk", how: I18n.tr("Собери четыре линии разом"), desc: I18n.tr("Стереть четыре нижних ряда"), charge: { ev: "clear", field: "n", n: 16, unit: I18n.tr("лин.") } },
        { id: "snake.ghost", game: "snake", tier: 1, name: I18n.tr("Призрак"), code: "boo", how: I18n.tr("Съешь 20 яблок"), desc: I18n.tr("10 секунд можно проходить сквозь себя"), charge: { sec: 40 } },
        { id: "snake.cut", game: "snake", tier: 2, name: I18n.tr("Ножницы"), code: "cut", how: I18n.tr("Съешь 45 яблок"), desc: I18n.tr("Отрезать половину хвоста, очки остаются"), charge: { sec: 90 } },
        { id: "mines.hint", game: "mines", tier: 1, name: I18n.tr("Подсказка"), code: "hint", how: I18n.tr("Разминируй поле на любом уровне"), desc: I18n.tr("Открыть одну безопасную клетку у края открытого"), charge: { sec: 30 } },
        { id: "mines.xray", game: "mines", tier: 2, name: I18n.tr("Рентген"), code: "eye", how: I18n.tr("Разминируй «Средний» уровень"), desc: I18n.tr("На 2,5 секунды видно мины"), charge: { run: true } },
        { id: "flappy.shield", game: "flappy", tier: 1, name: I18n.tr("Щит"), code: "shield", how: I18n.tr("Пролети 20 труб"), desc: I18n.tr("Одно столкновение не считается"), charge: { sec: 30 } },
        { id: "flappy.calm", game: "flappy", tier: 2, name: I18n.tr("Штиль"), code: "calm", how: I18n.tr("Пролети 40 труб"), desc: I18n.tr("8 секунд всё вдвое медленнее"), charge: { sec: 60 } },
        { id: "dino.double", game: "dino", tier: 2, name: I18n.tr("Двойной прыжок"), code: "jump", how: I18n.tr("Набери 500 очков"), desc: I18n.tr("Прыжок в воздухе — до конца забега"), charge: { run: true } },
        { id: "dino.god", game: "dino", tier: 3, name: I18n.tr("Бессмертие"), code: "god", how: I18n.tr("Набери 1500 очков"), desc: I18n.tr("6 секунд кактусы и птицы не страшны"), charge: { sec: 90 } },
        { id: "memory.duo", game: "memory", tier: 1, name: I18n.tr("Пара даром"), code: "duo", how: I18n.tr("Найди все пары на 6 × 4"), desc: I18n.tr("Одна пара находится сама, без хода"), charge: { sec: 30 } },
        { id: "memory.peek", game: "memory", tier: 2, name: I18n.tr("Подсмотреть"), code: "peek", how: I18n.tr("Пройди 4 × 4 не больше чем за 12 ходов"), desc: I18n.tr("На полторы секунды открыть все карточки"), charge: { run: true } },
        { id: "rhythm.heal", game: "rhythm", tier: 1, name: I18n.tr("Второе дыхание"), code: "heal", how: I18n.tr("Собери комбо 100"), desc: I18n.tr("Восстановить половину здоровья"), charge: { sec: 45 } },
        { id: "rhythm.calm", game: "rhythm", tier: 2, name: I18n.tr("Хладнокровие"), code: "calm", how: I18n.tr("Пройди трек на «Сложно»"), desc: I18n.tr("15 секунд промахи не сбивают комбо и не ранят"), charge: { sec: 90 } },
        { id: "rhythm.auto", game: "rhythm", tier: 3, name: I18n.tr("Автопилот"), code: "bot", how: I18n.tr("Пройди трек на «Безумно» с точностью 90%"), desc: I18n.tr("10 секунд ноты отбиваются сами"), charge: { run: true } },
        { id: "survival.fix", game: "survival", tier: 1, name: I18n.tr("Аптечка"), code: "fix", how: I18n.tr("Дойди до 5 уровня за забег"), desc: I18n.tr("Вернуть половину здоровья"), charge: { sec: 60 } },
        { id: "survival.bomb", game: "survival", tier: 2, name: I18n.tr("Бомба"), code: "boom", how: I18n.tr("Продержись 2 минуты"), desc: I18n.tr("Уничтожить всех врагов на экране, боссу — треть здоровья"), charge: { sec: 120 } },
        { id: "survival.kill", game: "survival", tier: 3, name: I18n.tr("Ярость"), code: "kill", how: I18n.tr("Победи босса"), desc: I18n.tr("15 секунд урон ×3 и оружие перезаряжается вдвое быстрее"), charge: { sec: 180 } }
    ]
    readonly property var tierColors: ["", "#cd8a5a", "#b9c3cf", Theme.yellow]
    function chargeText(c): string {
        const ch = c.charge ?? {};
        return ch.sec ? I18n.tr("перезарядка ") + ch.sec + I18n.tr(" с") : ch.ev ? I18n.tr("заново — через ") + ch.n + " " + ch.unit : I18n.tr("раз за партию");
    }

    // перезарядка: id → { left, total }; пока запись есть, игра этот чит не получает
    property var cheatCd: ({})
    function cdStart(id: string): void {
        const ch = cheat(id)?.charge;
        if (!ch) return;
        const cd = Object.assign({}, cheatCd);
        const n = ch.sec ?? ch.n ?? 1;
        cd[id] = { left: n, total: n };
        cheatCd = cd;
    }
    // amount(ch) — на сколько продвинуть перезарядку этого чита
    function cdAdvance(amount): void {
        let changed = false;
        const cd = Object.assign({}, cheatCd);
        for (const id in cd) {
            const a = amount(cheat(id)?.charge ?? {});
            if (!a) continue;
            changed = true;
            const left = cd[id].left - a;
            if (left <= 0) delete cd[id]; else cd[id] = { left, total: cd[id].total };
        }
        if (changed) cheatCd = cd;
    }
    function cdText(id: string): string {
        const st = cheatCd[id], ch = cheat(id)?.charge ?? {};
        if (!st) return "";
        if (ch.sec) { const s = Math.ceil(st.left); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
        if (ch.ev) return Math.ceil(st.left) + " " + ch.unit;
        return "✕";
    }
    Timer {
        interval: 250
        repeat: true
        running: root.shown && root.current !== "" && Object.keys(root.cheatCd).length > 0
        onTriggered: root.cdAdvance(ch => ch.sec ? 0.25 : 0)
    }
    onCurrentChanged: cheatCd = ({})

    function cheat(id: string): var { return cheatList.find(c => c.id === id) ?? null; }
    function unlocked(id: string): bool { return (Store.gameCheats ?? []).includes(id); }

    function open(id: string): void {
        current = games.some(g => g.id === id) ? id : current;
        if (current !== "") page = "";
        shown = true;
        Panels.closeAll();
    }

    // рекорды; у Legacy — свои, с приставкой
    function key(k: string): string { return legacy ? "legacy:" + k : k; }
    function best(k: string): var { return (Store.gameScores ?? {})[key(k)]; }
    function report(k: string, v: real, lowerBetter: bool): bool {
        if (!k || !(v > 0)) return false;
        const old = best(k);
        if (old !== undefined && (lowerBetter ? v >= old : v <= old)) return false;
        const s = Object.assign({}, Store.gameScores ?? {});
        s[key(k)] = v;
        Store.gameScores = s;
        return true;
    }

    // опыт за партию — по результату, примерно 10–100 за хорошую игру
    function xpFor(g: string, d): int {
        const s = d.score ?? 0;
        switch (g) {
        case "g2048": return s / 120;
        case "tetris": return (d.lines ?? 0) * 2.5;
        case "snake": return s * 1.5;
        case "mines": return d.won ? ({ easy: 15, medium: 45, hard: 110, extreme: 200 })[d.level] ?? 15 : 3;
        case "blocks": return s / 25;
        case "typing": return (d.wpm ?? 0) * (d.duration ?? 30) / 40;
        case "flappy": return s * 2;
        case "dino": return s / 30;
        case "memory": return d.won ? (d.size === 24 ? 35 : 20) : 2;
        case "survival": return (d.survived ?? 0) / 6 + (d.kills ?? 0) / 20 + (d.won ? 80 : 0);
        case "rhythm": return d.failed ? 5 : (d.notes ?? 0) * (d.acc ?? 0) / 100 * ({ easy: 0.15, normal: 0.25, hard: 0.4, insane: 0.6 })[d.diff];
        default: return s / 10;
        }
    }
    property real segStart: Date.now()   // начало текущей партии — для «времени в играх»

    IpcHandler {
        target: root.legacy ? "gamesLegacy" : "games"
        function toggle(): void { root.shown ? (root.shown = false) : root.open(""); }
        function open(id: string): void { root.open(id); }
        // для проверки: открыть чит (id или all) / сбросить читы, рекорды или профиль
        function unlock(id: string): void {
            Store.gameCheats = id === "all" ? root.cheatList.map(c => c.id) : (root.unlocked(id) || !root.cheat(id) ? Store.gameCheats : (Store.gameCheats ?? []).concat([id]));
        }
        function reset(what: string): void {
            if (what === "cheats") { Store.gameCheats = []; Store.gameSecrets = false; }
            else if (what === "scores") Store.gameScores = ({});
            else if (what === "profile") Store.gameProfile = ({});
        }
        function xp(n: int): void { if (!root.legacy) Profile.addXp(n, "ipc"); }
        // снимок и восстановление (для тестов): what — profile | scores | rhythm | cheats
        function dump(what: string): string { return JSON.stringify(what === "scores" ? Store.gameScores : what === "cheats" ? Store.gameCheats : what === "rhythm" ? Store.gameRhythm : Store.gameProfile); }
        function load(what: string, json: string): void {
            // читы можно передать списком через «;» — qs ipc портит кавычки и запятые в JSON
            const v = what === "cheats" && !json.startsWith("[") ? json.split(";").filter(x => x) : JSON.parse(json);
            if (what === "scores") Store.gameScores = v; else if (what === "cheats") Store.gameCheats = v; else if (what === "rhythm") Store.gameRhythm = v; else Store.gameProfile = v;
        }
    }

    // уведомления профиля — только у обычного окна и только пока оно открыто
    Connections {
        target: root.legacy ? null : Profile
        function onAchieved(a): void {
            if (!root.shown) return;
            toast.show("military_tech", ["", "#cd8a5a", "#b9c3cf", Theme.yellow][a.tier], I18n.tr("Достижение: ") + a.name, a.desc + " · +" + Profile.tierXp[a.tier] + I18n.tr(" опыта"));
            fx.sound("win");
        }
        function onLevelUp(l: int): void {
            if (!root.shown) return;
            const r = Profile.rewards.filter(x => x.level === l).map(x => x.name);
            toast.show("upgrade", Profile.frameOf(l), I18n.tr("Уровень ") + l + " · " + Profile.titleOf(l), r.length ? I18n.tr("Открыто: ") + r.join(", ") : I18n.tr("Так держать!"));
            fx.sound("record");
            fx.confetti();
        }
        function onXpGained(n: int, why: string): void {
            if (root.shown && root.current !== "") fx.floatText(fx.width / 2, 40, "+" + n + I18n.tr(" опыта"), Theme.accent);
        }
    }

    FloatingWindow {
        id: win
        visible: root.shown
        title: root.legacy ? I18n.tr("Игры Legacy") : I18n.tr("Игры Cove")
        implicitWidth: 1060
        implicitHeight: 760
        minimumSize: Qt.size(820, 620)
        color: Theme.base
        onVisibleChanged: if (!visible) root.shown = false

        // Esc: из игры — на витрину, со страницы — на витрину, с витрины — закрыть
        Shortcut {
            sequence: "Escape"
            onActivated: root.current !== "" ? (root.current = "") : root.page !== "" ? (root.page = "") : (root.shown = false)
        }

        // ---------- витрина ----------
        Item {
            id: hub
            anchors.fill: parent
            visible: root.current === "" && root.page === ""
            focus: visible
            onVisibleChanged: if (visible) forceActiveFocus()

            // код Konami: ↑ ↑ ↓ ↓ ← → ← → B A — открывает «Секреты» (не в Legacy)
            property var seq: []
            Keys.onPressed: e => {
                if (root.legacy) return;
                const t = e.key === Qt.Key_Up ? "U" : e.key === Qt.Key_Down ? "D" : e.key === Qt.Key_Left ? "L" : e.key === Qt.Key_Right ? "R" : K.letter(e);
                if (!t) return;
                seq = seq.concat([t]).slice(-10);
                if (seq.join("") === "UUDDLRLRba") {
                    seq = [];
                    Store.gameSecrets = true;
                    root.page = "secrets";
                    fx.sound("cheat");
                    Profile.check("konami", {});
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 32
                spacing: 6

                RowLayout {
                    spacing: 14
                    MIcon { icon: root.legacy ? "history" : "sports_esports"; size: 34; color: root.legacy ? Theme.subtext0 : Theme.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText { text: root.legacy ? I18n.tr("Игры Legacy") : I18n.tr("Игры"); font.pixelSize: 28; font.bold: true }
                        StyledText {
                            text: root.legacy ? I18n.tr("Без прокачки, достижений и читов — свои рекорды") : I18n.tr("Пока что-то собирается или грузится")
                            color: Theme.overlay1
                        }
                    }
                    ProfileBadge { visible: !root.legacy }
                }

                // страницы профиля
                RowLayout {
                    visible: !root.legacy
                    Layout.topMargin: 14
                    spacing: 8
                    SButton { icon: "emoji_events"; text: I18n.tr("Достижения ") + Profile.gotCount + "/" + Profile.achievements.length; onClicked: root.page = "ach" }
                    SButton { icon: "upgrade"; text: I18n.tr("Прокачка"); onClicked: root.page = "prog" }
                    SButton {
                        visible: Store.gameSecrets
                        icon: "key"
                        text: I18n.tr("Секреты ") + (Store.gameCheats ?? []).length + "/" + root.cheatList.length
                        onClicked: root.page = "secrets"
                    }
                    Item { Layout.fillWidth: true }
                    // надетые перки
                    Repeater {
                        model: Profile.perks.filter(x => Profile.has(x))
                        Rectangle {
                            required property string modelData
                            implicitWidth: pr.implicitWidth + 16
                            implicitHeight: 26
                            radius: 13
                            color: Theme.alpha(Theme.accent, 0.14)
                            Row {
                                id: pr
                                anchors.centerIn: parent
                                spacing: 4
                                MIcon { icon: "bolt"; fill: true; size: 13; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { anchors.verticalCenter: parent.verticalCenter; text: (Profile.rewards.find(r => r.id === modelData)?.name ?? "").split(": ").slice(-1)[0]; font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.accent }
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.topMargin: 16
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: root.games
                        Rectangle {
                            id: card
                            required property var modelData
                            readonly property var rec: root.best(modelData.id)
                            Layout.fillWidth: true
                            implicitHeight: 140
                            radius: Theme.radius + 4
                            color: cm.containsMouse ? Theme.surface0 : Theme.mantle
                            border.width: 1
                            border.color: cm.containsMouse ? card.modelData.color : Theme.surface0
                            scale: cm.pressed ? 0.98 : 1
                            Behavior on scale { NumberAnimation { duration: 90 } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Rectangle {
                                x: 18; y: 18
                                width: 52; height: 52
                                radius: 16
                                color: Theme.alpha(root.legacy ? Theme.overlay1 : card.modelData.color, 0.16)
                                MIcon { anchors.centerIn: parent; icon: card.modelData.icon; size: 28; color: root.legacy ? Theme.subtext0 : card.modelData.color; fill: true }
                            }
                            ColumnLayout {
                                x: 18
                                y: 80
                                width: parent.width - 36
                                spacing: 2
                                StyledText { text: card.modelData.name; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                                StyledText { Layout.fillWidth: true; text: card.modelData.desc; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
                            }
                            // значки: открытый чит, достижения игры
                            Row {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 14
                                spacing: 6
                                visible: !root.legacy
                                MIcon {
                                    visible: root.cheatList.some(c => c.game === card.modelData.id && root.unlocked(c.id))
                                    icon: "key"; fill: true; size: 16; color: Theme.yellow
                                }
                                StyledText {
                                    readonly property var all: Profile.achievements.filter(a => a.game === card.modelData.id)
                                    text: all.filter(a => Profile.got[a.id]).length + "/" + all.length
                                    color: Theme.overlay1
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                MIcon { icon: "military_tech"; size: 15; color: Theme.overlay1 }
                            }
                            MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.current = card.modelData.id }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                StyledText {
                    text: root.legacy ? I18n.tr("Esc — назад к играм · рекорды Legacy хранятся отдельно") : I18n.tr("Esc — назад к играм · рекорды сохраняются")
                    color: Theme.overlay0
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // ---------- страницы профиля ----------
        SecretsPage {
            anchors.fill: parent
            visible: root.current === "" && root.page === "secrets"
            games: root.games
            cheats: root.cheatList
            tierColors: root.tierColors
            chargeText: root.chargeText
            onBack: root.page = ""
        }
        AchievementsPage {
            anchors.fill: parent
            visible: root.current === "" && root.page === "ach"
            games: root.games
            onBack: root.page = ""
        }
        ProgressPage {
            anchors.fill: parent
            visible: root.current === "" && root.page === "prog"
            games: root.games
            onBack: root.page = ""
        }

        // ---------- игра ----------
        Item {
            id: gameView
            anchors.fill: parent
            visible: root.current !== ""

            property bool newRecord: false
            Timer { id: recTimer; interval: 2600; onTriggered: gameView.newRecord = false }

            // шапка
            Rectangle {
                id: head
                width: parent.width
                height: 60
                color: Theme.mantle
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12
                    IconButton { icon: "arrow_back"; onClicked: root.current = "" }
                    MIcon { icon: root.game?.icon ?? ""; color: root.game?.color ?? Theme.accent; size: 22; fill: true }
                    StyledText { text: root.game?.name ?? ""; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                    StyledText {
                        Layout.leftMargin: 10
                        text: loader.item?.status ?? ""
                        color: Theme.subtext1
                    }
                    // открытые читы этой игры: слово и перезарядка
                    Row {
                        Layout.leftMargin: 6
                        spacing: 6
                        Repeater {
                            model: root.legacy ? [] : root.cheatList.filter(c => c.game === root.current && root.unlocked(c.id))
                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property var st: root.cheatCd[modelData.id]
                                readonly property color tint: root.tierColors[modelData.tier]
                                implicitWidth: chipT.implicitWidth + 16
                                implicitHeight: 24
                                radius: 12
                                clip: true
                                color: st ? Theme.surface0 : Theme.alpha(tint, 0.16)
                                border.width: 1
                                border.color: st ? Theme.surface1 : tint
                                Rectangle {
                                    visible: !!chip.st
                                    width: chip.st ? parent.width * (1 - chip.st.left / chip.st.total) : 0
                                    height: parent.height
                                    color: Theme.alpha(chip.tint, 0.22)
                                    Behavior on width { NumberAnimation { duration: 240 } }
                                }
                                StyledText {
                                    id: chipT
                                    anchors.centerIn: parent
                                    text: chip.modelData.code.toUpperCase() + (chip.st ? "  " + root.cdText(chip.modelData.id) : "")
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: chip.st ? Theme.overlay1 : chip.tint
                                }
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    // «Новый рекорд!»
                    Rectangle {
                        visible: opacity > 0
                        opacity: gameView.newRecord ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
                        implicitWidth: nr.implicitWidth + 24
                        implicitHeight: 30
                        radius: 15
                        color: Theme.yellow
                        Row {
                            id: nr
                            anchors.centerIn: parent
                            spacing: 6
                            MIcon { icon: "emoji_events"; fill: true; color: Theme.crust; size: 15; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: I18n.tr("Новый рекорд!"); color: Theme.crust; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Row {
                        spacing: 6
                        readonly property var b: loader.item ? root.best(loader.item.bestKey) : undefined
                        visible: b !== undefined
                        MIcon { icon: "emoji_events"; color: Theme.yellow; size: 16; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.b === undefined ? "" : loader.item.bestText ? loader.item.bestText(parent.b) : String(parent.b)
                            color: Theme.subtext0
                        }
                    }
                    // уровень игрока
                    Rectangle {
                        visible: !root.legacy
                        implicitWidth: 30; implicitHeight: 30; radius: 15
                        color: "transparent"
                        border.width: 2
                        border.color: Profile.frameOf(Profile.level)
                        StyledText { anchors.centerIn: parent; text: Profile.level; font.bold: true; font.pixelSize: Theme.fontSizeSmall; color: Profile.frameOf(Profile.level) }
                    }
                    IconButton {
                        icon: Store.gameSound ? "volume_up" : "volume_off"
                        iconColor: Store.gameSound ? Theme.text : Theme.overlay1
                        onClicked: { Store.gameSound = !Store.gameSound; loader.item?.forceActiveFocus(); }
                    }
                    IconButton { icon: "refresh"; onClicked: { loader.item?.restart(); loader.item?.forceActiveFocus(); } }
                }
            }

            Loader {
                id: loader
                anchors.top: head.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                active: root.current !== ""
                source: root.game ? Qt.resolvedUrl(root.game.file + ".qml") : ""
                focus: true
                onLoaded: { item.forceActiveFocus(); fx.sound("start"); root.segStart = Date.now(); root.cheatCd = ({}); }
                transform: Translate { x: fx.dx }
            }
            Toast {
                id: toast
                z: 20
                anchors.horizontalCenter: parent.horizontalCenter
                y: head.height + 16
            }
            GameFx {
                id: fx
                anchors.fill: loader
                z: 10
                muted: !Store.gameSound
                volume: 0.25 + 0.6 * Settings.general.soundVolume   // игры тише интерфейса: звуков много и они частые
            }
            Binding { target: loader.item; property: "active"; value: win.visible && root.current !== ""; when: loader.status === Loader.Ready }
            Binding { target: loader.item; property: "legacy"; value: root.legacy; when: loader.status === Loader.Ready }
            Binding { target: loader.item; property: "cheats"; value: root.legacy ? [] : (Store.gameCheats ?? []).filter(id => !root.cheatCd[id]); when: loader.status === Loader.Ready }
            Binding { target: loader.item; property: "perks"; value: root.legacy ? [] : Profile.perks.filter(x => Profile.has(x)); when: loader.status === Loader.Ready }
            Binding { target: loader.item; property: "skin"; value: root.legacy ? "" : Profile.skinOf(root.current); when: loader.status === Loader.Ready }
            Binding { target: loader.item; property: "modes"; value: root.legacy ? [] : Profile.modesFor(root.current).map(m => m.id); when: loader.status === Loader.Ready }
            Connections {
                target: loader.item
                ignoreUnknownSignals: true
                function onRecord(v: real): void {
                    if (root.report(loader.item.bestKey, v, loader.item.lowerBetter)) {
                        gameView.newRecord = true;
                        recTimer.restart();
                        fx.sound("record");
                        fx.confetti();
                        if (!root.legacy) Profile.event(root.current, "record", { value: v });
                    }
                }
                function onEvent(name: string, data): void {
                    if (root.legacy) return;
                    const d = Object.assign({}, data ?? {});
                    if (name === "end") root.cheatCd = ({});   // новая партия — все читы снова готовы
                    else root.cdAdvance(ch => ch.ev === name ? (ch.field ? Number(d[ch.field] ?? 0) : 1) : 0);
                    if (name === "end") {
                        d.seconds = Math.min(3600, (Date.now() - root.segStart) / 1000);
                        d.xp = root.xpFor(root.current, d);
                        root.segStart = Date.now();
                    }
                    Profile.event(root.current, name, d);
                }
                function onSfx(name: string): void { fx.sound(name); }
                function onUnlock(id: string): void {
                    if (root.legacy || root.unlocked(id) || !root.cheat(id)) return;
                    Store.gameCheats = (Store.gameCheats ?? []).concat([id]);
                    const c = root.cheat(id);
                    toast.show("key", Theme.yellow, I18n.tr("Открыт секрет: ") + c.name,
                        I18n.tr("Набери ") + c.code.toUpperCase() + I18n.tr(" во время игры — ") + c.desc.charAt(0).toLowerCase() + c.desc.slice(1));
                    fx.sound("cheat");
                    fx.confetti();
                    Profile.check("cheatUnlocked", { total: root.cheatList.length });
                }
                function onCheatUsed(id: string): void {
                    const c = root.cheat(id);
                    root.cdStart(id);
                    fx.sound("cheat");
                    fx.flash(Theme.accent);
                    fx.floatText(fx.width / 2, fx.height / 2, "✦ " + (c?.name ?? id), Theme.accent);
                }
                function onFx(kind: string, at: Item, x: real, y: real, text: string, tint: color): void {
                    const p = at ? at.mapToItem(fx, x, y) : Qt.point(x, y);
                    if (kind === "float") fx.floatText(p.x, p.y, text, tint);
                    else if (kind === "burst") fx.burst(p.x, p.y, tint, Number(text) || 18);
                    else if (kind === "confetti") fx.confetti();
                    else if (kind === "shake") fx.shake(Number(text) || 8);
                    else if (kind === "flash") fx.flash(tint);
                }
            }
        }
    }
}
