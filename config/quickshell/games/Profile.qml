pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Профиль игрока: опыт и уровни, достижения, перки, скины, режимы. Всё хранится в Store.gameProfile.
// Игры сообщают о происходящем событиями (GamesWindow → Profile.event(game, name, data)):
//   "end"  { score, … }  — партия окончена (обязательно для всех игр)
//   прочие — свои у каждой игры (см. достижения ниже).
// Legacy-окно профиль не трогает.
Singleton {
    id: root

    // ---------- данные ----------
    readonly property var p: Store.gameProfile ?? ({})
    readonly property int xp: p.xp ?? 0
    readonly property var got: p.ach ?? ({})                 // id → время получения
    readonly property var stats: p.stats ?? ({})
    readonly property var perks: p.perks ?? []                // надетые перки
    readonly property var skins: p.skins ?? ({})              // игра → id скина

    function save(patch): void {
        Store.gameProfile = Object.assign({}, Store.gameProfile ?? {}, patch);
    }
    function bump(key: string, by: real): void {
        const s = Object.assign({}, stats);
        s[key] = (s[key] ?? 0) + (by ?? 1);
        save({ stats: s });
    }
    function setMax(key: string, v: real): void {
        if ((stats[key] ?? -Infinity) >= v) return;
        const s = Object.assign({}, stats);
        s[key] = v;
        save({ stats: s });
    }

    // ---------- уровни ----------
    readonly property int maxLevel: 50
    // опыт, нужный, чтобы дойти до уровня n (с 1-го): 120 · (n-1)^1.55
    function xpAt(n: int): int { return Math.round(120 * Math.pow(Math.max(0, n - 1), 1.55)); }
    readonly property int level: { let n = 1; while (n < maxLevel && xp >= xpAt(n + 1)) n++; return n; }
    readonly property real levelProgress: level >= maxLevel ? 1 : (xp - xpAt(level)) / Math.max(1, xpAt(level + 1) - xpAt(level))
    readonly property var titles: [I18n.tr("Новичок"), I18n.tr("Любитель"), I18n.tr("Игрок"), I18n.tr("Знаток"), I18n.tr("Мастер"),
        I18n.tr("Эксперт"), I18n.tr("Виртуоз"), I18n.tr("Легенда"), I18n.tr("Миф"), I18n.tr("Бог Cove")]
    function titleOf(n: int): string { return titles[Math.min(titles.length - 1, Math.floor((n - 1) / 5))]; }
    readonly property string title: titleOf(level)
    // рамка профиля по уровню
    function frameOf(n: int): color {
        return n >= 45 ? Theme.yellow : n >= 35 ? Theme.pink : n >= 25 ? Theme.accent : n >= 15 ? Theme.teal : n >= 5 ? Theme.overlay1 : Theme.surface2;
    }
    readonly property int perkSlots: level >= 30 ? 4 : level >= 20 ? 3 : level >= 10 ? 2 : level >= 3 ? 1 : 0

    signal levelUp(int level)
    signal achieved(var a)
    signal xpGained(int amount, string why)

    function addXp(n: int, why: string): void {
        if (n <= 0) return;
        if (perks.includes("xp.boost")) n = Math.round(n * 1.15);
        const before = level;
        save({ xp: xp + n });
        xpGained(n, why);
        if (level > before) {
            for (let l = before + 1; l <= level; l++) levelUp(l);
            check("level", {});
        }
    }

    // ---------- награды за уровни ----------
    // kind: perk | skin | mode | slot
    readonly property var rewards: [
        { level: 2, kind: "skin", game: "g2048", id: "g2048.classic", name: I18n.tr("2048: классические цвета") },
        { level: 3, kind: "slot", name: I18n.tr("Слот перка") },
        { level: 3, kind: "perk", id: "blocks.keepStreak", name: I18n.tr("Блоки: серия не слетает"), desc: I18n.tr("Один ход без линии не сбрасывает серию") },
        { level: 4, kind: "skin", game: "snake", id: "snake.rainbow", name: I18n.tr("Змейка: радуга") },
        { level: 5, kind: "perk", id: "tetris.next5", name: I18n.tr("Тетрис: дальний прогноз"), desc: I18n.tr("Видно пять следующих фигур, а не три") },
        { level: 6, kind: "perk", id: "snake.forgive", name: I18n.tr("Змейка: второй шанс"), desc: I18n.tr("Первое столкновение с собой за партию прощается") },
        { level: 7, kind: "skin", game: "dino", id: "dino.night", name: I18n.tr("Динозавр: ночь") },
        { level: 8, kind: "perk", id: "memory.glimpse", name: I18n.tr("Пары: первый взгляд"), desc: I18n.tr("В начале партии все карточки открыты на секунду") },
        { level: 9, kind: "skin", game: "flappy", id: "flappy.cardinal", name: I18n.tr("Flappy: красная птица") },
        { level: 10, kind: "slot", name: I18n.tr("Второй слот перка") },
        { level: 10, kind: "perk", id: "flappy.startShield", name: I18n.tr("Flappy: стартовый щит"), desc: I18n.tr("Каждый полёт начинается со щитом") },
        { level: 11, kind: "mode", game: "g2048", id: "g2048.5x5", name: I18n.tr("2048: поле 5 × 5") },
        { level: 12, kind: "perk", id: "g2048.freeUndo", name: I18n.tr("2048: право на ошибку"), desc: I18n.tr("Одна бесплатная отмена хода за партию (U)") },
        { level: 13, kind: "skin", game: "tetris", id: "tetris.retro", name: I18n.tr("Тетрис: ретро") },
        { level: 14, kind: "perk", id: "mines.secondChance", name: I18n.tr("Сапёр: сапёрский жилет"), desc: I18n.tr("Первый взрыв за партию не смертелен") },
        { level: 15, kind: "mode", game: "tetris", id: "tetris.sprint", name: I18n.tr("Тетрис: спринт 40 линий") },
        { level: 16, kind: "perk", id: "xp.boost", name: I18n.tr("Опыт +15%"), desc: I18n.tr("Больше опыта за всё") },
        { level: 17, kind: "skin", game: "blocks", id: "blocks.jelly", name: I18n.tr("Блоки: желе") },
        { level: 18, kind: "perk", id: "dino.calm", name: I18n.tr("Динозавр: спокойный старт"), desc: I18n.tr("Скорость растёт вдвое медленнее") },
        { level: 19, kind: "mode", game: "snake", id: "snake.walls", name: I18n.tr("Змейка: стены и препятствия") },
        { level: 20, kind: "slot", name: I18n.tr("Третий слот перка") },
        { level: 21, kind: "perk", id: "blocks.hold", name: I18n.tr("Блоки: запасной слот"), desc: I18n.tr("Четвёртый слот в лотке: отложить фигуру на потом") },
        { level: 22, kind: "skin", game: "g2048", id: "g2048.neon", name: I18n.tr("2048: неон") },
        { level: 23, kind: "mode", game: "blocks", id: "blocks.10x10", name: I18n.tr("Блоки: поле 10 × 10") },
        { level: 24, kind: "perk", id: "tetris.softLock", name: I18n.tr("Тетрис: задержка фиксации"), desc: I18n.tr("Фигура фиксируется на полсекунды позже — можно довернуть") },
        { level: 26, kind: "skin", game: "memory", id: "memory.neon", name: I18n.tr("Пары: неоновые рубашки") },
        { level: 27, kind: "mode", game: "mines", id: "mines.extreme", name: I18n.tr("Сапёр: экстрим 30 × 20") },
        { level: 6, kind: "perk", id: "rhythm.wide", name: I18n.tr("Ритм: широкое окно"), desc: I18n.tr("Попадания засчитываются чуть щедрее (+12 мс)") },
        { level: 15, kind: "perk", id: "rhythm.noFail", name: I18n.tr("Ритм: без провала"), desc: I18n.tr("Здоровье не кончается — доиграешь любой трек") },
        { level: 28, kind: "perk", id: "typing.forgive", name: I18n.tr("Печать: мягкий счёт"), desc: I18n.tr("Исправленные ошибки не снижают точность") },
        { level: 30, kind: "slot", name: I18n.tr("Четвёртый слот перка") },
        { level: 32, kind: "skin", game: "dino", id: "dino.pink", name: I18n.tr("Динозавр: розовый") },
        { level: 35, kind: "skin", game: "flappy", id: "flappy.ghost", name: I18n.tr("Flappy: призрачная птица") },
        { level: 40, kind: "skin", game: "tetris", id: "tetris.glass", name: I18n.tr("Тетрис: стекло") },
        { level: 45, kind: "skin", game: "blocks", id: "blocks.gold", name: I18n.tr("Блоки: золото") },
        { level: 50, kind: "skin", game: "snake", id: "snake.gold", name: I18n.tr("Змейка: золотая") }
    ]
    function has(id: string): bool { return rewards.some(r => r.id === id && r.level <= level); }
    readonly property var perkList: rewards.filter(r => r.kind === "perk")
    function perkOn(id: string): bool { return perks.includes(id) && has(id); }
    function togglePerk(id: string): void {
        if (!has(id)) return;
        let l = perks.filter(x => has(x));
        if (l.includes(id)) l = l.filter(x => x !== id);
        else if (l.length < perkSlots) l = l.concat([id]);
        else return;
        save({ perks: l });
    }
    function skinsFor(game: string): var { return rewards.filter(r => r.kind === "skin" && r.game === game); }
    function skinOf(game: string): string { const s = skins[game] ?? ""; return s && has(s) ? s : ""; }
    function setSkin(game: string, id: string): void {
        const s = Object.assign({}, skins);
        s[game] = id;
        save({ skins: s });
    }
    function modesFor(game: string): var { return rewards.filter(r => r.kind === "mode" && r.game === game && r.level <= level); }

    // ---------- достижения ----------
    // tier: 1 бронза (25 опыта) · 2 серебро (75) · 3 золото (200); secret — скрыто, пока не получено.
    // test(e) — e: { game, name, d (данные события), s (stats) }; true — получено.
    readonly property var tierXp: [0, 25, 75, 200]
    readonly property var achievements: [
        // сквозные
        { id: "any.first", game: "", tier: 1, name: I18n.tr("Первый шаг"), desc: I18n.tr("Сыграй любую партию"), test: e => e.name === "end" },
        { id: "any.all", game: "", tier: 2, name: I18n.tr("Всеядный"), desc: I18n.tr("Сыграй в каждую игру"), test: e => e.name === "end" && root.gamesPlayed() >= root.gameIds.length },
        { id: "any.p50", game: "", tier: 1, name: I18n.tr("Разогрев"), desc: I18n.tr("50 партий"), test: e => (e.s.plays ?? 0) >= 50 },
        { id: "any.p250", game: "", tier: 2, name: I18n.tr("Завсегдатай"), desc: I18n.tr("250 партий"), test: e => (e.s.plays ?? 0) >= 250 },
        { id: "any.p1000", game: "", tier: 3, name: I18n.tr("Жизнь в играх"), desc: I18n.tr("1000 партий"), test: e => (e.s.plays ?? 0) >= 1000 },
        { id: "any.hour", game: "", tier: 1, name: I18n.tr("Час пролетел"), desc: I18n.tr("Час в играх в сумме"), test: e => (e.s.seconds ?? 0) >= 3600 },
        { id: "any.ten", game: "", tier: 3, name: I18n.tr("Десять часов"), desc: I18n.tr("Десять часов в играх в сумме"), test: e => (e.s.seconds ?? 0) >= 36000 },
        { id: "any.rec5", game: "", tier: 1, name: I18n.tr("Рекордсмен"), desc: I18n.tr("Побей 5 рекордов"), test: e => (e.s.records ?? 0) >= 5 },
        { id: "any.rec25", game: "", tier: 2, name: I18n.tr("Выше головы"), desc: I18n.tr("Побей 25 рекордов"), test: e => (e.s.records ?? 0) >= 25 },
        { id: "any.d3", game: "", tier: 1, name: I18n.tr("Привычка"), desc: I18n.tr("Играй 3 дня подряд"), test: e => (e.s.streak ?? 0) >= 3 },
        { id: "any.d7", game: "", tier: 2, name: I18n.tr("Неделя"), desc: I18n.tr("Играй 7 дней подряд"), test: e => (e.s.streak ?? 0) >= 7 },
        { id: "any.d30", game: "", tier: 3, name: I18n.tr("Месяц"), desc: I18n.tr("Играй 30 дней подряд"), test: e => (e.s.streak ?? 0) >= 30 },
        { id: "any.l10", game: "", tier: 1, name: I18n.tr("Десятка"), desc: I18n.tr("Достигни 10 уровня"), test: e => root.level >= 10 },
        { id: "any.l25", game: "", tier: 2, name: I18n.tr("Полпути"), desc: I18n.tr("Достигни 25 уровня"), test: e => root.level >= 25 },
        { id: "any.l50", game: "", tier: 3, name: I18n.tr("Бог Cove"), desc: I18n.tr("Достигни 50 уровня"), test: e => root.level >= 50 },
        { id: "any.cheat", game: "", tier: 1, secret: true, name: I18n.tr("Хакер"), desc: I18n.tr("Открой первый секрет"), test: e => e.name === "cheatUnlocked" },
        { id: "any.cheats", game: "", tier: 3, secret: true, name: I18n.tr("Ключник"), desc: I18n.tr("Открой все секреты"), test: e => e.name === "cheatUnlocked" && (Store.gameCheats ?? []).length >= (e.d.total ?? 11) },
        { id: "any.konami", game: "", tier: 1, secret: true, name: I18n.tr("↑↑↓↓←→←→BA"), desc: I18n.tr("Найди страницу секретов"), test: e => e.name === "konami" },
        { id: "any.night", game: "", tier: 1, secret: true, name: I18n.tr("Сова"), desc: I18n.tr("Сыграй партию между двумя и пятью часами ночи"), test: e => e.name === "end" && new Date().getHours() >= 2 && new Date().getHours() < 5 },
        // 2048
        { id: "g2048.256", game: "g2048", tier: 1, name: I18n.tr("Четверть пути"), desc: I18n.tr("Собери плитку 256"), test: e => e.name === "tile" && e.d.v >= 256 },
        { id: "g2048.1024", game: "g2048", tier: 2, name: I18n.tr("Килобайт"), desc: I18n.tr("Собери плитку 1024"), test: e => e.name === "tile" && e.d.v >= 1024 },
        { id: "g2048.2048", game: "g2048", tier: 3, name: "2048", desc: I18n.tr("Собери плитку 2048"), test: e => e.name === "tile" && e.d.v >= 2048 },
        { id: "g2048.s10k", game: "g2048", tier: 2, name: I18n.tr("Пять цифр"), desc: I18n.tr("10 000 очков за партию"), test: e => e.name === "end" && e.d.score >= 10000 },
        { id: "g2048.pure", game: "g2048", tier: 2, secret: true, name: I18n.tr("Без оглядки"), desc: I18n.tr("Собери 1024 без отмен хода"), test: e => e.name === "tile" && e.d.v >= 1024 && !e.d.undone },
        // Тетрис
        { id: "tetris.four", game: "tetris", tier: 1, name: I18n.tr("Тетрис!"), desc: I18n.tr("Собери четыре линии разом"), test: e => e.name === "clear" && e.d.n >= 4 },
        { id: "tetris.l40", game: "tetris", tier: 1, name: I18n.tr("Сорок линий"), desc: I18n.tr("40 линий за партию"), test: e => e.name === "end" && e.d.lines >= 40 },
        { id: "tetris.lv8", game: "tetris", tier: 2, name: I18n.tr("Разгон"), desc: I18n.tr("Дойди до 8 уровня"), test: e => e.name === "clear" && e.d.level >= 8 },
        { id: "tetris.s20k", game: "tetris", tier: 2, name: I18n.tr("Ровные ряды"), desc: I18n.tr("20 000 очков за партию"), test: e => e.name === "end" && e.d.score >= 20000 },
        { id: "tetris.b2b", game: "tetris", tier: 3, name: I18n.tr("Дважды тетрис"), desc: I18n.tr("Два тетриса подряд"), test: e => e.name === "clear" && e.d.n >= 4 && e.d.prev >= 4 },
        { id: "tetris.nohold", game: "tetris", tier: 2, secret: true, name: I18n.tr("Без запаса"), desc: I18n.tr("20 линий, ни разу не отложив фигуру"), test: e => e.name === "end" && e.d.lines >= 20 && !e.d.held },
        // Змейка
        { id: "snake.10", game: "snake", tier: 1, name: I18n.tr("Перекус"), desc: I18n.tr("10 яблок за партию"), test: e => e.name === "end" && e.d.score >= 10 },
        { id: "snake.30", game: "snake", tier: 2, name: I18n.tr("Удав"), desc: I18n.tr("30 яблок за партию"), test: e => e.name === "end" && e.d.score >= 30 },
        { id: "snake.60", game: "snake", tier: 3, name: I18n.tr("Анаконда"), desc: I18n.tr("60 яблок за партию"), test: e => e.name === "end" && e.d.score >= 60 },
        { id: "snake.oops", game: "snake", tier: 1, secret: true, name: I18n.tr("Ой"), desc: I18n.tr("Врежься в себя, не съев ни одного яблока"), test: e => e.name === "end" && e.d.score === 0 && e.d.died },
        // Сапёр
        { id: "mines.easy", game: "mines", tier: 1, name: I18n.tr("Сапёр"), desc: I18n.tr("Разминируй поле «Новичок»"), test: e => e.name === "win" && e.d.level === "easy" },
        { id: "mines.medium", game: "mines", tier: 2, name: I18n.tr("Профессионал"), desc: I18n.tr("Разминируй поле «Любитель»"), test: e => e.name === "win" && e.d.level === "medium" },
        { id: "mines.hard", game: "mines", tier: 3, name: I18n.tr("Ас разминирования"), desc: I18n.tr("Разминируй поле «Профи»"), test: e => e.name === "win" && (e.d.level === "hard" || e.d.level === "extreme") },
        { id: "mines.fast", game: "mines", tier: 2, name: I18n.tr("Молния"), desc: I18n.tr("«Новичок» быстрее 20 секунд"), test: e => e.name === "win" && e.d.level === "easy" && e.d.seconds < 20 },
        { id: "mines.noflag", game: "mines", tier: 2, secret: true, name: I18n.tr("Без флажков"), desc: I18n.tr("Выиграй, не поставив ни одного флажка"), test: e => e.name === "win" && !e.d.flagged },
        // Блоки
        { id: "blocks.500", game: "blocks", tier: 1, name: I18n.tr("Строитель"), desc: I18n.tr("500 очков за партию"), test: e => e.name === "end" && e.d.score >= 500 },
        { id: "blocks.2000", game: "blocks", tier: 2, name: I18n.tr("Архитектор"), desc: I18n.tr("2000 очков за партию"), test: e => e.name === "end" && e.d.score >= 2000 },
        { id: "blocks.5000", game: "blocks", tier: 3, name: I18n.tr("Градостроитель"), desc: I18n.tr("5000 очков за партию"), test: e => e.name === "end" && e.d.score >= 5000 },
        { id: "blocks.combo5", game: "blocks", tier: 2, name: I18n.tr("Серия ×5"), desc: I18n.tr("Пять ходов подряд с линиями"), test: e => e.name === "clear" && e.d.combo >= 5 },
        { id: "blocks.triple", game: "blocks", tier: 2, name: I18n.tr("Крест-накрест"), desc: I18n.tr("Убери три линии одной фигурой"), test: e => e.name === "clear" && e.d.lines >= 3 },
        { id: "blocks.empty", game: "blocks", tier: 3, secret: true, name: I18n.tr("Чистый лист"), desc: I18n.tr("Очисти поле полностью посреди партии"), test: e => e.name === "clear" && e.d.empty },
        // Печать
        { id: "typing.40", game: "typing", tier: 1, name: I18n.tr("Уверенно"), desc: "40 WPM", test: e => e.name === "end" && e.d.wpm >= 40 },
        { id: "typing.70", game: "typing", tier: 2, name: I18n.tr("Быстрые пальцы"), desc: "70 WPM", test: e => e.name === "end" && e.d.wpm >= 70 },
        { id: "typing.100", game: "typing", tier: 3, name: I18n.tr("Стенографист"), desc: "100 WPM", test: e => e.name === "end" && e.d.wpm >= 100 },
        { id: "typing.acc", game: "typing", tier: 2, name: I18n.tr("Без единой ошибки"), desc: I18n.tr("100% точности за тест от 30 секунд"), test: e => e.name === "end" && e.d.acc >= 100 && e.d.duration >= 30 && e.d.wpm >= 20 },
        { id: "typing.both", game: "typing", tier: 1, name: I18n.tr("Билингва"), desc: I18n.tr("Пройди тест на русском и на английском"), test: e => e.name === "end" && (e.s["typing.ru"] ?? 0) > 0 && (e.s["typing.en"] ?? 0) > 0 },
        // Flappy
        { id: "flappy.10", game: "flappy", tier: 1, name: I18n.tr("Взлёт"), desc: I18n.tr("10 труб"), test: e => e.name === "end" && e.d.score >= 10 },
        { id: "flappy.30", game: "flappy", tier: 2, name: I18n.tr("Пилот"), desc: I18n.tr("30 труб"), test: e => e.name === "end" && e.d.score >= 30 },
        { id: "flappy.75", game: "flappy", tier: 3, name: I18n.tr("Ас"), desc: I18n.tr("75 труб"), test: e => e.name === "end" && e.d.score >= 75 },
        { id: "flappy.zero", game: "flappy", tier: 1, secret: true, name: I18n.tr("Упорство"), desc: I18n.tr("10 раз подряд разбейся на первой трубе"), test: e => e.name === "end" && (e.s["flappy.zeroRun"] ?? 0) >= 10 },
        // Динозавр
        { id: "dino.500", game: "dino", tier: 1, name: I18n.tr("Пробежка"), desc: I18n.tr("500 очков"), test: e => e.name === "end" && e.d.score >= 500 },
        { id: "dino.1500", game: "dino", tier: 2, name: I18n.tr("Марафонец"), desc: I18n.tr("1500 очков"), test: e => e.name === "end" && e.d.score >= 1500 },
        { id: "dino.3000", game: "dino", tier: 3, name: I18n.tr("Вымирание отменяется"), desc: I18n.tr("3000 очков"), test: e => e.name === "end" && e.d.score >= 3000 },
        { id: "dino.duck", game: "dino", tier: 1, name: I18n.tr("Пригнись"), desc: I18n.tr("Пронырни под 10 птицами за забег"), test: e => e.name === "end" && e.d.ducked >= 10 },
        // Выживание
        { id: "survival.3", game: "survival", tier: 1, name: I18n.tr("Три минуты"), desc: I18n.tr("Продержись 3 минуты"), test: e => e.name === "end" && e.d.survived >= 180 },
        { id: "survival.win", game: "survival", tier: 2, name: I18n.tr("Выживший"), desc: I18n.tr("Продержись все 10 минут"), test: e => e.name === "end" && e.d.won },
        { id: "survival.boss", game: "survival", tier: 2, name: I18n.tr("Убийца великанов"), desc: I18n.tr("Победи босса"), test: e => e.name === "boss" },
        { id: "survival.k500", game: "survival", tier: 2, name: I18n.tr("Жатва"), desc: I18n.tr("500 врагов за забег"), test: e => e.name === "end" && e.d.kills >= 500 },
        { id: "survival.lv20", game: "survival", tier: 3, name: I18n.tr("Сверхсила"), desc: I18n.tr("20 уровень за забег"), test: e => e.name === "end" && e.d.level >= 20 },
        // Ритм
        { id: "rhythm.clear", game: "rhythm", tier: 1, name: I18n.tr("Первый трек"), desc: I18n.tr("Пройди трек до конца"), test: e => e.name === "end" && !e.d.failed },
        { id: "rhythm.a", game: "rhythm", tier: 1, name: I18n.tr("Хороший слух"), desc: I18n.tr("Оценка A или выше"), test: e => e.name === "end" && !e.d.failed && ["A", "S", "SS"].includes(e.d.grade) },
        { id: "rhythm.s", game: "rhythm", tier: 2, name: I18n.tr("Ранг S"), desc: I18n.tr("Оценка S на «Норме» или сложнее"), test: e => e.name === "end" && !e.d.failed && ["S", "SS"].includes(e.d.grade) && e.d.diff !== "easy" },
        { id: "rhythm.ss", game: "rhythm", tier: 3, name: I18n.tr("Идеально"), desc: I18n.tr("Оценка SS — все попадания на 300"), test: e => e.name === "end" && e.d.grade === "SS" && !e.d.failed },
        { id: "rhythm.fc", game: "rhythm", tier: 2, name: I18n.tr("Полное комбо"), desc: I18n.tr("Ни одного промаха на «Сложно»"), test: e => e.name === "end" && e.d.fc && (e.d.diff === "hard" || e.d.diff === "insane") },
        { id: "rhythm.insane", game: "rhythm", tier: 3, name: I18n.tr("Безумец"), desc: I18n.tr("Пройди «Безумно» с точностью от 90%"), test: e => e.name === "end" && !e.d.failed && e.d.diff === "insane" && e.d.acc >= 90 },
        { id: "rhythm.combo", game: "rhythm", tier: 2, name: I18n.tr("Комбо 300"), desc: I18n.tr("Набери комбо 300"), test: e => e.name === "end" && e.d.maxCombo >= 300 },
        { id: "rhythm.modes", game: "rhythm", tier: 2, name: I18n.tr("Мультиинструменталист"), desc: I18n.tr("Пройди трек во всех трёх режимах"), test: e => e.name === "end" && !e.d.failed && ["circles", "mania", "taiko"].every(m => (e.s["rhythm." + m] ?? 0) > 0) },
        { id: "rhythm.custom", game: "rhythm", tier: 1, name: I18n.tr("Своя музыка"), desc: I18n.tr("Добавь свой трек"), test: e => e.name === "custom" },
        { id: "rhythm.fail", game: "rhythm", tier: 1, secret: true, name: I18n.tr("Не мой ритм"), desc: I18n.tr("Провали трек в первые 10 секунд"), test: e => e.name === "end" && e.d.failed && (e.d.seconds ?? 99) < 12 },
        // Пары
        { id: "memory.win", game: "memory", tier: 1, name: I18n.tr("Память"), desc: I18n.tr("Найди все пары на 4 × 4"), test: e => e.name === "win" && e.d.size === 16 },
        { id: "memory.big", game: "memory", tier: 1, name: I18n.tr("Большая колода"), desc: I18n.tr("Найди все пары на 6 × 4"), test: e => e.name === "win" && e.d.size === 24 },
        { id: "memory.sharp", game: "memory", tier: 2, name: I18n.tr("Острая память"), desc: I18n.tr("4 × 4 не больше чем за 11 ходов"), test: e => e.name === "win" && e.d.size === 16 && e.d.moves <= 11 },
        { id: "memory.photo", game: "memory", tier: 3, name: I18n.tr("Фотографическая"), desc: I18n.tr("6 × 4 не больше чем за 18 ходов"), test: e => e.name === "win" && e.d.size === 24 && e.d.moves <= 18 },
        { id: "memory.lucky", game: "memory", tier: 2, secret: true, name: I18n.tr("Везунчик"), desc: I18n.tr("Три пары подряд с первой попытки в начале партии"), test: e => e.name === "luck" && e.d.n >= 3 }
    ]
    readonly property var gameIds: ["rhythm", "survival", "blocks", "g2048", "tetris", "snake", "mines", "typing", "flappy", "dino", "memory"]
    function gamesPlayed(): int { return gameIds.filter(g => (stats["plays." + g] ?? 0) > 0).length; }
    readonly property int gotCount: Object.keys(got).length

    function check(name: string, d): void {
        const e = { game: "", name, d: d ?? {}, s: stats };
        for (const a of achievements) if (!got[a.id]) tryAch(a, e);
    }
    function tryAch(a, e): void {
        let ok = false;
        try { ok = !!a.test(e); } catch (err) {}
        if (!ok) return;
        const g = Object.assign({}, got);
        g[a.id] = Date.now();
        save({ ach: g });
        achieved(a);
        addXp(tierXp[a.tier], a.name);
    }

    // ---------- события из игр ----------
    function day(t): string { const d = new Date(t); return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate(); }
    function event(game: string, name: string, d): void {
        d = d ?? {};
        if (name === "end") {
            const s = Object.assign({}, stats);
            s.plays = (s.plays ?? 0) + 1;
            s["plays." + game] = (s["plays." + game] ?? 0) + 1;
            s.seconds = (s.seconds ?? 0) + Math.max(0, d.seconds ?? 0);
            // дни подряд
            const today = day(Date.now()), yest = day(Date.now() - 86400000);
            if (s.lastDay !== today) { s.streak = s.lastDay === yest ? (s.streak ?? 0) + 1 : 1; s.lastDay = today; }
            if (game === "typing") s["typing." + (d.lang ?? "ru")] = (s["typing." + (d.lang ?? "ru")] ?? 0) + 1;
            if (game === "flappy") s["flappy.zeroRun"] = d.score === 0 ? (s["flappy.zeroRun"] ?? 0) + 1 : 0;
            if (game === "rhythm" && !d.failed) s["rhythm." + d.mode] = (s["rhythm." + d.mode] ?? 0) + 1;
            save({ stats: s });
            addXp(Math.round(8 + Math.min(120, d.xp ?? 0)), I18n.tr("партия"));
        }
        if (name === "record") { bump("records", 1); addXp(30, I18n.tr("рекорд")); }
        const e = { game, name, d, s: stats };
        for (const a of achievements) if (!got[a.id] && (a.game === "" || a.game === game)) tryAch(a, e);
    }
}
