import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import "keys.js" as K

// Выживание (как Vampire Survivors): WASD / стрелки — бег, оружие стреляет само.
// Кристаллы опыта → уровень → выбор одного из трёх улучшений (1 / 2 / 3 или мышью).
// Враги густеют со временем, каждые 3 минуты — босс. Продержаться 10 минут — победа.
// Между забегами — осколки и «Лавка» с постоянными улучшениями (Store.gameProfile.survival; в Legacy её нет).
Item {
    id: root
    property bool active: false
    // профиль (GamesWindow) — у всех игр одинаковый набор, иначе Binding в окне зацикливается
    property var cheats: []
    property string skin: ""
    property var modes: []
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)
    property bool legacy: false
    property var perks: []
    signal event(string name, var data)
    signal unlock(string id)
    signal cheatUsed(string id)

    // ---- читы: окно проставляет cheats (открытые id); слово набирается во время забега ----
    property real rageUntil: -1        // «ярость»: до этого момента забега урон ×3 и перезарядка вдвое быстрее
    readonly property real rage: time < rageUntil ? 1 : 0
    readonly property var cheatCodes: [
        { id: "survival.fix", code: "fix", run: () => {
            if (screen !== "run" || hp >= hpMax) return false;
            hp = Math.min(hpMax, hp + hpMax / 2);
            fx("float", view, view.width / 2, view.height / 2 - 40, "+" + Math.round(hpMax / 2), Theme.green);
            return true;
        } },
        { id: "survival.kill", code: "kill", run: () => {
            if (screen !== "run") return false;
            rageUntil = time + 15;
            fx("flash", null, 0, 0, "", Theme.red);
            sfx("combo");
            return true;
        } },
        { id: "survival.bomb", code: "boom", run: () => {
            if (screen !== "run") return false;
            const hw = view.width / 2 + 40, hh = view.height / 2 + 40;
            for (const f of foes.slice())
                if (f.hp > 0 && Math.abs(f.x - px) < hw && Math.abs(f.y - py) < hh) hurtFoe(f, f.kind === "boss" ? f.max * 0.3 : f.hp);
            sfx("boom");
            fx("shake", null, 0, 0, "14", Theme.yellow);
            return true;
        } }
    ]
    property string typedBuf: ""
    function feed(L: string): void {
        if (!L) return;
        typedBuf = (typedBuf + L).slice(-8);
        for (const c of cheatCodes)
            if (typedBuf.endsWith(c.code) && cheats.includes(c.id)) { typedBuf = ""; if (c.run() !== false) cheatUsed(c.id); }
    }

    focus: true
    readonly property string bestKey: "survival"
    readonly property bool lowerBetter: false
    function bestText(v: real): string { return mmss(v); }
    function mmss(s: real): string { return Math.floor(s / 60) + ":" + String(Math.floor(s % 60)).padStart(2, "0"); }
    readonly property string status: screen === "run" ? mmss(time) + I18n.tr(" · ур. ") + lvl + I18n.tr(" · убито ") + kills + (rage ? I18n.tr(" · ярость") : "")
        : screen === "shop" ? I18n.tr("Осколки: ") + shards : ""

    // ---------- мета-прогресс (лавка) ----------
    readonly property var meta: legacy ? ({}) : ((Store.gameProfile ?? {}).survival ?? {})
    readonly property int shards: meta.shards ?? 0
    function metaLv(id: string): int { return (meta.up ?? {})[id] ?? 0; }
    readonly property var shop: [
        { id: "hp", name: I18n.tr("Крепкое здоровье"), desc: I18n.tr("+15 к здоровью"), max: 5, cost: 40 },
        { id: "dmg", name: I18n.tr("Острота"), desc: I18n.tr("+8% урона"), max: 5, cost: 60 },
        { id: "spd", name: I18n.tr("Лёгкий шаг"), desc: I18n.tr("+5% скорости"), max: 3, cost: 50 },
        { id: "mag", name: I18n.tr("Магнит"), desc: I18n.tr("+20% радиуса сбора"), max: 3, cost: 35 },
        { id: "regen", name: I18n.tr("Живучесть"), desc: I18n.tr("+0.2 здоровья в секунду"), max: 3, cost: 70 },
        { id: "reroll", name: I18n.tr("Второй взгляд"), desc: I18n.tr("+1 перебор улучшений за забег"), max: 3, cost: 80 },
        { id: "start", name: I18n.tr("Арсенал"), desc: I18n.tr("Начинать с «Орбитой»"), max: 1, cost: 150 }
    ]
    function price(s): int { return Math.round(s.cost * Math.pow(1.6, metaLv(s.id))); }
    function buy(s): void {
        if (legacy || metaLv(s.id) >= s.max || shards < price(s)) return;
        const up = Object.assign({}, meta.up ?? {});
        up[s.id] = metaLv(s.id) + 1;
        saveMeta({ shards: shards - price(s), up });
        sfx("merge");
    }
    function saveMeta(patch): void {
        if (legacy) return;
        const p = Object.assign({}, Store.gameProfile ?? {});
        p.survival = Object.assign({}, p.survival ?? {}, patch);
        Store.gameProfile = p;
    }

    // ---------- состояние ----------
    property string screen: "menu"     // menu | run | pick | over | shop
    property real time: 0
    property int kills: 0
    property int lvl: 1
    property real xp: 0
    readonly property real xpNeed: 5 + lvl * 4 + Math.pow(lvl, 1.6)
    property var choices: []
    property int rerolls: 0
    property bool won: false
    property bool bossKilled: false
    property int runShards: 0

    // игрок
    property real px: 0
    property real py: 0
    property real hp: 100
    property real hpMax: 100
    property real hurtAt: 0
    property real face: 0              // куда смотрим (для «Искры» без целей)
    property var stats: ({})           // множители улучшений
    property var weapons: ({})         // id → уровень
    property var held: ({})            // нажатые направления

    // мир
    readonly property real worldW: 3000
    readonly property real worldH: 2000
    property var foes: []              // { x, y, r, hp, max, sp, kind, dmg, t (таймер атаки), hit (вспышка) }
    property var shots: []             // { x, y, vx, vy, r, dmg, life, pierce, foe (вражеский) }
    property var gems: []              // { x, y, v }
    property var bolts: []             // молнии для отрисовки { pts, t }
    property var rings: []             // волны для отрисовки { x, y, r, t }
    property var floats: []            // всплывающий урон { x, y, v, t }
    property real spawnAcc: 0
    property var cd: ({})              // перезарядки оружия

    readonly property var weaponInfo: ({
        spark: { name: I18n.tr("Искра"), icon: "auto_awesome", desc: I18n.tr("Самонаводящийся снаряд в ближайшего") },
        orbit: { name: I18n.tr("Орбита"), icon: "radar", desc: I18n.tr("Клинки кружат вокруг героя") },
        wave: { name: I18n.tr("Волна"), icon: "waves", desc: I18n.tr("Удар по площади вокруг") },
        chain: { name: I18n.tr("Молния"), icon: "bolt", desc: I18n.tr("Перескакивает между врагами") },
        fan: { name: I18n.tr("Веер"), icon: "flare", desc: I18n.tr("Залп во все стороны") }
    })
    readonly property var passiveInfo: ({
        might: { name: I18n.tr("Сила"), icon: "fitness_center", desc: I18n.tr("+15% урона") },
        haste: { name: I18n.tr("Спешка"), icon: "speed", desc: I18n.tr("Оружие перезаряжается на 10% быстрее") },
        boots: { name: I18n.tr("Сапоги"), icon: "directions_run", desc: I18n.tr("+10% скорости бега") },
        heart: { name: I18n.tr("Сердце"), icon: "favorite", desc: I18n.tr("+20 к здоровью и лечение") },
        magnet: { name: I18n.tr("Магнит"), icon: "attractions", desc: I18n.tr("Кристаллы притягиваются издалека") },
        multi: { name: I18n.tr("Дубль"), icon: "content_copy", desc: I18n.tr("+1 снаряд «Искры» и «Веера»") }
    })

    function s(k: string): real { return stats[k] ?? 0; }
    function dmgMul(): real { return (1 + 0.15 * s("might")) * (1 + 0.08 * metaLv("dmg")) * (rage ? 3 : 1); }
    function cdMul(): real { return Math.pow(0.9, s("haste")) * (rage ? 0.5 : 1); }

    function newRun(): void {
        px = worldW / 2; py = worldH / 2;
        hpMax = 100 + 15 * metaLv("hp"); hp = hpMax;
        time = 0; kills = 0; lvl = 1; xp = 0; won = false; bossKilled = false; runShards = 0;
        foes = []; shots = []; gems = []; bolts = []; rings = []; floats = [];
        stats = {}; weapons = metaLv("start") ? { spark: 1, orbit: 1 } : { spark: 1 };
        cd = {}; held = {}; spawnAcc = 0; rageUntil = -1; typedBuf = "";
        rerolls = 1 + metaLv("reroll");
        screen = "run";
        root.forceActiveFocus();
        sfx("start");
    }
    function restart(): void { newRun(); }

    // ---------- улучшения ----------
    function offer(): void {
        const pool = [];
        for (const id in weaponInfo) if ((weapons[id] ?? 0) < 6 && (weapons[id] || Object.keys(weapons).length < 4)) pool.push({ type: "w", id });
        for (const id in passiveInfo) if (s(id) < 5) pool.push({ type: "p", id });
        const out = [];
        while (out.length < 3 && pool.length) out.push(pool.splice(Math.floor(Math.random() * pool.length), 1)[0]);
        if (!out.length) out.push({ type: "heal" });
        choices = out;
        screen = "pick";
        sfx("win");
    }
    function take(c): void {
        if (c.type === "w") { const w = Object.assign({}, weapons); w[c.id] = (w[c.id] ?? 0) + 1; weapons = w; }
        else if (c.type === "p") {
            const st = Object.assign({}, stats); st[c.id] = (st[c.id] ?? 0) + 1; stats = st;
            if (c.id === "heart") { hpMax += 20; hp = Math.min(hpMax, hp + 40); }
        } else hp = hpMax;
        screen = "run";
        root.forceActiveFocus();
        sfx("merge");
    }

    // ---------- враги ----------
    function spawn(kind: string): void {
        const a = Math.random() * Math.PI * 2, d = 650 + Math.random() * 150;
        const x = Math.max(20, Math.min(worldW - 20, px + Math.cos(a) * d)), y = Math.max(20, Math.min(worldH - 20, py + Math.sin(a) * d));
        const k = time / 60;          // минуты — враги крепнут
        const T = ({
            slime: { r: 14, hp: 8 + k * 6, sp: 65 + k * 3, dmg: 6, col: 0 },
            runner: { r: 10, hp: 6 + k * 4, sp: 150 + k * 4, dmg: 6, col: 1 },
            tank: { r: 26, hp: 60 + k * 30, sp: 45, dmg: 18, col: 2 },
            shooter: { r: 13, hp: 14 + k * 6, sp: 60, dmg: 10, col: 3 },
            boss: { r: 56, hp: 1500 + k * 900, sp: 85, dmg: 30, col: 4 }
        })[kind];
        foes.push({ x, y, r: T.r, hp: T.hp, max: T.hp, sp: T.sp, dmg: T.dmg, kind, col: T.col, t: Math.random() * 2, hit: 0 });
        if (kind === "boss") { sfx("boom"); fx("float", view, view.width / 2, 90, I18n.tr("БОСС!"), Theme.red); fx("shake", null, 0, 0, "10", Theme.red); }
    }
    function hurtFoe(f, dmg: real): void {
        if (f.hp <= 0) return;
        f.hp -= dmg;
        f.hit = 0.12;
        if (floats.length < 40) floats.push({ x: f.x, y: f.y - f.r, v: Math.round(dmg), t: 0 });
        if (f.hp <= 0) {
            kills++;
            gems.push({ x: f.x, y: f.y, v: f.kind === "boss" ? 60 : f.kind === "tank" ? 6 : f.kind === "shooter" ? 3 : f.kind === "runner" ? 2 : 1 });
            if (f.kind === "boss") {
                bossKilled = true;
                unlock("survival.kill");
                sfx("combo");
                fx("confetti", null, 0, 0, "", Theme.yellow);
                event("boss", {});
            } else if (kills % 25 === 0) sfx("reveal");
        }
    }
    function nearest(x: real, y: real, maxD: real, skip): var {
        let best = null, bd = maxD * maxD;
        for (const f of foes) {
            if (f.hp <= 0 || (skip && skip.includes(f))) continue;
            const d = (f.x - x) ** 2 + (f.y - y) ** 2;
            if (d < bd) { bd = d; best = f; }
        }
        return best;
    }

    // ---------- такт мира ----------
    function step(dt: real): void {
        time += dt;
        // движение
        let mx = (held.r ? 1 : 0) - (held.l ? 1 : 0), my = (held.d ? 1 : 0) - (held.u ? 1 : 0);
        if (mx || my) {
            const l = Math.hypot(mx, my); mx /= l; my /= l;
            face = Math.atan2(my, mx);
            const sp = 210 * (1 + 0.1 * s("boots")) * (1 + 0.05 * metaLv("spd"));
            px = Math.max(16, Math.min(worldW - 16, px + mx * sp * dt));
            py = Math.max(16, Math.min(worldH - 16, py + my * sp * dt));
        }
        hp = Math.min(hpMax, hp + 0.2 * metaLv("regen") * dt);

        // волны врагов: плотность растёт со временем
        spawnAcc += dt * (0.55 + time / 40);   // волны густеют: ~2 врага/с к первой минуте, ~8 к пятой
        while (spawnAcc >= 1 && foes.length < 260) {
            spawnAcc -= 1;
            const r = Math.random(), m = time / 60;
            spawn(m > 1 && r < 0.18 ? "runner" : m > 2 && r < 0.26 ? "tank" : m > 1.5 && r < 0.34 ? "shooter" : "slime");
        }
        if (Math.floor((time - dt) / 180) < Math.floor(time / 180)) spawn("boss");
        if (time - dt < 120 && time >= 120) unlock("survival.bomb");
        if (time >= 600 && !won) { won = true; end(); return; }

        // оружие
        const dm = dmgMul(), cm = cdMul();
        const W_ = weapons;
        const ready = (id, base) => { cd[id] = (cd[id] ?? 0) - dt; if (cd[id] > 0) return false; cd[id] = base * cm; return true; };
        if (W_.spark && ready("spark", 0.7 - W_.spark * 0.05)) {
            const n = 1 + s("multi") + (W_.spark >= 4 ? 1 : 0);
            for (let i = 0; i < n; i++) {
                const t = nearest(px, py, 420, []);
                const a = t ? Math.atan2(t.y - py, t.x - px) + (i - (n - 1) / 2) * 0.18 : face + (i - (n - 1) / 2) * 0.2;
                shots.push({ x: px, y: py, vx: Math.cos(a) * 520, vy: Math.sin(a) * 520, r: 6, dmg: (9 + W_.spark * 4) * dm, life: 1.4, pierce: W_.spark >= 5 ? 2 : 0, foe: false, home: t });
            }
        }
        if (W_.fan && ready("fan", 1.9 - W_.fan * 0.15)) {
            const n = 6 + W_.fan * 2 + s("multi") * 2;
            for (let i = 0; i < n; i++) {
                const a = i / n * Math.PI * 2 + time;
                shots.push({ x: px, y: py, vx: Math.cos(a) * 380, vy: Math.sin(a) * 380, r: 5, dmg: (7 + W_.fan * 3) * dm, life: 0.9, pierce: 1, foe: false });
            }
        }
        if (W_.wave && ready("wave", 3.2 - W_.wave * 0.25)) {
            const R = 110 + W_.wave * 22;
            rings.push({ x: px, y: py, r: R, t: 0 });
            for (const f of foes) if ((f.x - px) ** 2 + (f.y - py) ** 2 < (R + f.r) ** 2) {
                hurtFoe(f, (14 + W_.wave * 6) * dm);
                const a = Math.atan2(f.y - py, f.x - px);
                if (f.kind !== "boss") { f.x += Math.cos(a) * 40; f.y += Math.sin(a) * 40; }
            }
            sfx("flap");
        }
        if (W_.chain && ready("chain", 2.2 - W_.chain * 0.18)) {
            let cur = nearest(px, py, 520, []), from = { x: px, y: py };
            const hitList = [], pts = [{ x: px, y: py }];
            for (let k = 0; k < 2 + W_.chain && cur; k++) {
                hurtFoe(cur, (16 + W_.chain * 6) * dm);
                hitList.push(cur); pts.push({ x: cur.x, y: cur.y });
                cur = nearest(cur.x, cur.y, 230, hitList);
            }
            if (pts.length > 1) { bolts.push({ pts, t: 0 }); sfx("flag"); }
        }
        if (W_.orbit) {
            const n = 1 + W_.orbit, R = 70 + W_.orbit * 6;
            for (let i = 0; i < n; i++) {
                const a = time * 3.2 + i / n * Math.PI * 2;
                const ox = px + Math.cos(a) * R, oy = py + Math.sin(a) * R;
                for (const f of foes) if (f.hp > 0 && (f.x - ox) ** 2 + (f.y - oy) ** 2 < (f.r + 12) ** 2 && (f.orbitCd ?? 0) <= 0) {
                    hurtFoe(f, (8 + W_.orbit * 3) * dm);
                    f.orbitCd = 0.35;
                }
            }
        }

        // снаряды
        for (const p of shots) {
            if (p.home && p.home.hp > 0) {   // «Искра» слегка доворачивает к цели
                const a = Math.atan2(p.home.y - p.y, p.home.x - p.x), sp = Math.hypot(p.vx, p.vy);
                const cur = Math.atan2(p.vy, p.vx);
                let d = a - cur; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI;
                const na = cur + Math.max(-4 * dt, Math.min(4 * dt, d));
                p.vx = Math.cos(na) * sp; p.vy = Math.sin(na) * sp;
            }
            p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt;
            if (p.foe) {
                if ((p.x - px) ** 2 + (p.y - py) ** 2 < (p.r + 14) ** 2) { damage(p.dmg); p.life = 0; }
                continue;
            }
            for (const f of foes) {
                if (f.hp <= 0 || p.life <= 0) continue;
                if ((f.x - p.x) ** 2 + (f.y - p.y) ** 2 < (f.r + p.r) ** 2) {
                    hurtFoe(f, p.dmg);
                    if (p.pierce > 0) p.pierce--; else p.life = 0;
                }
            }
        }
        shots = shots.filter(p => p.life > 0);

        // враги: идут к герою, стрелки держат дистанцию и стреляют
        for (const f of foes) {
            if (f.hp <= 0) continue;
            f.hit = Math.max(0, f.hit - dt);
            f.orbitCd = (f.orbitCd ?? 0) - dt;
            const dx = px - f.x, dy = py - f.y, d = Math.hypot(dx, dy) || 1;
            let sp = f.sp;
            if (f.kind === "shooter" && d < 320) sp = -f.sp * 0.6;
            if (f.kind === "boss") { f.t -= dt; if (f.t <= 0 && d < 500) { f.dash = 0.6; f.t = 4; } if (f.dash > 0) { f.dash -= dt; sp = f.sp * 4; } }
            f.x += dx / d * sp * dt; f.y += dy / d * sp * dt;
            if (f.kind === "shooter") {
                f.t -= dt;
                if (f.t <= 0 && d < 520) { f.t = 2.2; shots.push({ x: f.x, y: f.y, vx: dx / d * 220, vy: dy / d * 220, r: 7, dmg: f.dmg, life: 3, pierce: 0, foe: true }); }
            }
            if (d < f.r + 14) damage(f.dmg * dt * 2.2);
        }
        // враги не слипаются в одну точку
        for (let i = 0; i < foes.length; i += 2) {
            const a = foes[i], b = foes[(i + 7) % foes.length];
            if (!b || a === b) continue;
            const dx = a.x - b.x, dy = a.y - b.y, d = Math.hypot(dx, dy) || 1, mn = a.r + b.r;
            if (d < mn) { const push = (mn - d) / 2; a.x += dx / d * push; a.y += dy / d * push; b.x -= dx / d * push; b.y -= dy / d * push; }
        }
        foes = foes.filter(f => f.hp > 0);

        // кристаллы: притягиваются магнитом
        const mag = (120 + 45 * s("magnet")) * (1 + 0.2 * metaLv("mag"));
        for (const g of gems) {
            const dx = px - g.x, dy = py - g.y, d = Math.hypot(dx, dy);
            if (d < mag || g.pull) { g.pull = true; const sp = 420 + (mag - Math.min(d, mag)) * 3; g.x += dx / (d || 1) * sp * dt; g.y += dy / (d || 1) * sp * dt; }
            else if (d < 500) { g.x += dx / d * 35 * dt; g.y += dy / d * 35 * dt; }   // издалека кристаллы медленно ползут к герою
            if (d < 18) { xp += g.v; g.v = 0; }
        }
        gems = gems.filter(g => g.v > 0);
        if (gems.length > 400) gems = gems.slice(-400);
        if (xp >= xpNeed) { xp -= xpNeed; lvl++; if (lvl >= 5) unlock("survival.fix"); offer(); }

        bolts = bolts.filter(b => (b.t += dt) < 0.25);
        rings = rings.filter(r => (r.t += dt) < 0.35);
        floats = floats.filter(f => (f.t += dt) < 0.6);
    }
    function damage(d: real): void {
        hp -= d;
        if (Date.now() - hurtAt > 300) { hurtAt = Date.now(); sfx("hit"); }
        if (hp <= 0) { hp = 0; end(); }
    }
    function end(): void {
        if (screen !== "run") return;   // в одном кадре героя могут добить несколько врагов
        screen = "over";
        // осколки: за время, убийства и боссов
        const got = Math.round(time / 10 + kills / 15 + (bossKilled ? 40 : 0) + (won ? 100 : 0));
        runShards = got;
        if (!legacy) saveMeta({ shards: shards + got, best: Math.max(meta.best ?? 0, time) });
        record(Math.round(time));
        event("end", { seconds: time, survived: time, kills, level: lvl, won, boss: bossKilled, score: Math.round(time) });
        sfx(won ? "record" : "over");
        if (won) fx("confetti", null, 0, 0, "", Theme.yellow);
        else fx("shake", null, 0, 0, "12", Theme.red);
    }

    FrameAnimation {
        running: root.active && root.screen === "run"
        onTriggered: { root.step(Math.min(0.033, frameTime)); view.requestPaint(); }
    }

    // ---------- ввод ----------
    function dirOf(e): string {
        const L = K.letter(e);
        return e.key === Qt.Key_Left || L === "a" ? "l" : e.key === Qt.Key_Right || L === "d" ? "r" : e.key === Qt.Key_Up || L === "w" ? "u" : e.key === Qt.Key_Down || L === "s" ? "d" : "";
    }
    Keys.onPressed: e => {
        const d = dirOf(e);
        if (d) { const h = Object.assign({}, held); h[d] = true; held = h; e.accepted = true; return; }
        if (e.isAutoRepeat) return;
        if (screen === "pick" && e.key >= Qt.Key_1 && e.key <= Qt.Key_3) { const c = choices[e.key - Qt.Key_1]; if (c) take(c); e.accepted = true; }
        else if (screen === "pick" && K.letter(e) === "r" && rerolls > 0) { rerolls--; offer(); e.accepted = true; }
        else if ((screen === "menu" || screen === "over") && (e.key === Qt.Key_Space || e.key === Qt.Key_Return)) { newRun(); e.accepted = true; }
        else if (screen === "run" && e.key === Qt.Key_P) { screen = "paused"; e.accepted = true; }
        else if (screen === "run") feed(K.letter(e));
        else if (screen === "paused" && e.key === Qt.Key_P) { screen = "run"; e.accepted = true; }
    }
    Keys.onReleased: e => {
        const d = dirOf(e);
        if (d && !e.isAutoRepeat) { const h = Object.assign({}, held); h[d] = false; held = h; }
    }

    // ---------- отрисовка ----------
    Canvas {
        id: view
        anchors.fill: parent
        visible: root.screen === "run" || root.screen === "pick" || root.screen === "over" || root.screen === "paused"
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const cx = width / 2 - root.px, cy = height / 2 - root.py;
            g.fillStyle = Theme.crust; g.fillRect(0, 0, width, height);
            // сетка пола
            g.strokeStyle = Theme.alpha(Theme.surface0, 0.5); g.lineWidth = 1;
            const step = 80, sx = ((cx % step) + step) % step, sy = ((cy % step) + step) % step;
            for (let x = sx; x < width; x += step) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, height); g.stroke(); }
            for (let y = sy; y < height; y += step) { g.beginPath(); g.moveTo(0, y); g.lineTo(width, y); g.stroke(); }
            // граница мира
            g.strokeStyle = Theme.red; g.lineWidth = 3; g.strokeRect(cx, cy, root.worldW, root.worldH);
            const vis = (x, y, r) => x + cx > -r && x + cx < width + r && y + cy > -r && y + cy < height + r;
            // кристаллы
            for (const k of root.gems) {
                if (!vis(k.x, k.y, 8)) continue;
                g.fillStyle = k.v >= 60 ? Theme.yellow : k.v >= 6 ? Theme.pink : k.v >= 2 ? Theme.accent2 : Theme.teal;
                g.beginPath(); g.moveTo(k.x + cx, k.y + cy - 6); g.lineTo(k.x + cx + 5, k.y + cy); g.lineTo(k.x + cx, k.y + cy + 6); g.lineTo(k.x + cx - 5, k.y + cy); g.fill();
            }
            // волны
            for (const r of root.rings) {
                g.strokeStyle = Theme.alpha(Theme.accent, 1 - r.t / 0.35); g.lineWidth = 6;
                g.beginPath(); g.arc(r.x + cx, r.y + cy, r.r * (0.4 + r.t / 0.35 * 0.6), 0, Math.PI * 2); g.stroke();
            }
            // враги
            const cols = [Theme.green, Theme.peach, Theme.red, Theme.accent2, Theme.pink];
            for (const f of root.foes) {
                if (!vis(f.x, f.y, f.r)) continue;
                g.fillStyle = f.hit > 0 ? "#ffffff" : cols[f.col];
                g.beginPath(); g.arc(f.x + cx, f.y + cy, f.r, 0, Math.PI * 2); g.fill();
                g.fillStyle = Theme.crust;
                g.beginPath(); g.arc(f.x + cx - f.r * 0.3, f.y + cy - f.r * 0.15, f.r * 0.14, 0, Math.PI * 2); g.arc(f.x + cx + f.r * 0.3, f.y + cy - f.r * 0.15, f.r * 0.14, 0, Math.PI * 2); g.fill();
                if (f.kind === "boss" || f.kind === "tank") {
                    g.fillStyle = Theme.surface0; g.fillRect(f.x + cx - f.r, f.y + cy - f.r - 10, f.r * 2, 5);
                    g.fillStyle = Theme.red; g.fillRect(f.x + cx - f.r, f.y + cy - f.r - 10, f.r * 2 * f.hp / f.max, 5);
                }
            }
            // снаряды
            for (const p of root.shots) {
                g.fillStyle = p.foe ? Theme.red : Theme.yellow;
                g.beginPath(); g.arc(p.x + cx, p.y + cy, p.r, 0, Math.PI * 2); g.fill();
            }
            // молнии
            for (const b of root.bolts) {
                g.strokeStyle = Theme.alpha(Theme.accent2, 1 - b.t / 0.25); g.lineWidth = 3;
                g.beginPath();
                b.pts.forEach((p, i) => { const jx = i ? (Math.random() - 0.5) * 10 : 0; if (i) g.lineTo(p.x + cx + jx, p.y + cy + jx); else g.moveTo(p.x + cx, p.y + cy); });
                g.stroke();
            }
            // орбита
            if (root.weapons.orbit) {
                const n = 1 + root.weapons.orbit, R = 70 + root.weapons.orbit * 6;
                g.fillStyle = Theme.accent;
                for (let i = 0; i < n; i++) {
                    const a = root.time * 3.2 + i / n * Math.PI * 2;
                    g.beginPath(); g.arc(root.px + cx + Math.cos(a) * R, root.py + cy + Math.sin(a) * R, 9, 0, Math.PI * 2); g.fill();
                }
            }
            // герой
            const hurt = Date.now() - root.hurtAt < 150;
            g.fillStyle = hurt ? Theme.red : Theme.text;
            g.beginPath(); g.arc(width / 2, height / 2, 14, 0, Math.PI * 2); g.fill();
            g.fillStyle = Theme.accent;
            g.beginPath(); g.arc(width / 2 + Math.cos(root.face) * 8, height / 2 + Math.sin(root.face) * 8, 4, 0, Math.PI * 2); g.fill();
            // урон
            g.font = "bold 13px sans-serif"; g.textAlign = "center";
            for (const f of root.floats) { g.fillStyle = Theme.alpha(Theme.yellow, 1 - f.t / 0.6); g.fillText(String(f.v), f.x + cx, f.y + cy - f.t * 40); }
        }
    }

    // интерфейс забега: здоровье, опыт, время, оружие
    Item {
        anchors.fill: parent
        visible: root.screen === "run" || root.screen === "pick" || root.screen === "paused"
        Rectangle {
            anchors.top: parent.top; width: parent.width; height: 6; color: Theme.surface0
            Rectangle { width: parent.width * Math.min(1, root.xp / root.xpNeed); height: parent.height; color: Theme.accent2 }
        }
        StyledText { anchors.horizontalCenter: parent.horizontalCenter; y: 14; text: root.mmss(root.time) + " / 10:00"; font.pixelSize: 22; font.bold: true }
        Rectangle {
            x: parent.width / 2 - 30; y: parent.height / 2 + 22; width: 60; height: 6; radius: 3; color: Theme.surface0
            Rectangle { width: parent.width * root.hp / root.hpMax; height: parent.height; radius: 3; color: root.hp / root.hpMax > 0.3 ? Theme.green : Theme.red }
        }
        Row {
            x: 14; y: 16
            spacing: 6
            Repeater {
                model: Object.keys(root.weapons)
                Rectangle {
                    required property string modelData
                    width: 40; height: 40; radius: 10
                    color: Theme.alpha(Theme.base, 0.8)
                    MIcon { anchors.centerIn: parent; icon: root.weaponInfo[modelData].icon; fill: true; size: 20; color: Theme.accent }
                    StyledText { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 2; text: root.weapons[modelData]; font.pixelSize: 10; font.bold: true }
                }
            }
        }
        StyledText { anchors.right: parent.right; y: 16; anchors.rightMargin: 16; text: "☠ " + root.kills + "   ✦ " + root.lvl; font.bold: true }
    }

    // выбор улучшения
    Rectangle {
        anchors.fill: parent
        visible: root.screen === "pick" || root.screen === "paused"
        color: Theme.alpha(Theme.crust, 0.7)
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            visible: root.screen === "pick"
            StyledText { Layout.alignment: Qt.AlignHCenter; text: I18n.tr("Уровень ") + root.lvl + "!"; font.pixelSize: 30; font.bold: true; color: Theme.yellow }
            RowLayout {
                spacing: 14
                Repeater {
                    model: root.choices
                    Rectangle {
                        id: ch
                        required property var modelData
                        required property int index
                        readonly property var info: modelData.type === "w" ? root.weaponInfo[modelData.id] : modelData.type === "p" ? root.passiveInfo[modelData.id] : { name: I18n.tr("Лечение"), icon: "healing", desc: I18n.tr("Полное здоровье") }
                        readonly property int have: modelData.type === "w" ? (root.weapons[modelData.id] ?? 0) : modelData.type === "p" ? root.s(modelData.id) : 0
                        implicitWidth: 210; implicitHeight: 230
                        radius: Theme.radius + 6
                        color: chm.containsMouse ? Theme.surface0 : Theme.base
                        border.width: 2
                        border.color: modelData.type === "w" ? Theme.accent : Theme.accent2
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 8
                            StyledText { text: (ch.index + 1) + ""; color: Theme.overlay1; font.bold: true }
                            MIcon { Layout.alignment: Qt.AlignHCenter; icon: ch.info.icon; fill: true; size: 48; color: ch.modelData.type === "w" ? Theme.accent : Theme.accent2 }
                            StyledText { Layout.alignment: Qt.AlignHCenter; text: ch.info.name; font.bold: true; font.pixelSize: Theme.fontSizeLarge }
                            StyledText { Layout.alignment: Qt.AlignHCenter; text: ch.have ? I18n.tr("ур. ") + ch.have + " → " + (ch.have + 1) : ch.modelData.type === "w" ? I18n.tr("новое оружие") : ""; color: Theme.yellow; font.pixelSize: Theme.fontSizeSmall }
                            StyledText { Layout.fillWidth: true; text: ch.info.desc; color: Theme.subtext0; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Theme.fontSizeSmall }
                        }
                        MouseArea { id: chm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.take(ch.modelData) }
                    }
                }
            }
            StyledText { Layout.alignment: Qt.AlignHCenter; visible: root.rerolls > 0; text: I18n.tr("R — перебрать (осталось ") + root.rerolls + ")"; color: Theme.overlay1 }
        }
        StyledText { anchors.centerIn: parent; visible: root.screen === "paused"; text: I18n.tr("Пауза — P"); font.pixelSize: 36; font.bold: true }
    }

    // меню, итог, лавка
    Rectangle {
        anchors.fill: parent
        visible: root.screen === "menu" || root.screen === "over" || root.screen === "shop"
        color: root.screen === "over" ? Theme.alpha(Theme.crust, 0.82) : Theme.base

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 14
            visible: root.screen !== "shop"
            MIcon { Layout.alignment: Qt.AlignHCenter; icon: root.screen === "over" && root.won ? "emoji_events" : "swords"; size: 56; fill: true; color: root.screen === "over" && !root.won ? Theme.red : Theme.yellow }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.screen === "menu" ? I18n.tr("Выживание") : root.won ? I18n.tr("Ты выжил!") : I18n.tr("Забег окончен")
                font.pixelSize: 32; font.bold: true
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.screen === "menu" ? I18n.tr("WASD — бег · оружие стреляет само · продержись 10 минут")
                    : I18n.tr("Время ") + root.mmss(root.time) + I18n.tr(" · убито ") + root.kills + I18n.tr(" · уровень ") + root.lvl
                color: Theme.subtext0
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: root.screen === "over" && !root.legacy
                text: "+" + root.runShards + I18n.tr(" осколков")
                color: Theme.yellow; font.bold: true
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                SButton { visible: !root.legacy; icon: "storefront"; text: I18n.tr("Лавка · ") + root.shards; onClicked: root.screen = "shop" }
                SButton { primary: true; icon: "play_arrow"; text: root.screen === "menu" ? I18n.tr("В бой (пробел)") : I18n.tr("Ещё забег (пробел)"); onClicked: root.newRun() }
            }
        }

        // лавка
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            visible: root.screen === "shop"
            spacing: 10
            RowLayout {
                IconButton { icon: "arrow_back"; onClicked: root.screen = "menu" }
                StyledText { text: I18n.tr("Лавка"); font.pixelSize: 26; font.bold: true }
                Item { Layout.fillWidth: true }
                MIcon { icon: "diamond"; fill: true; color: Theme.yellow; size: 20 }
                StyledText { text: root.shards; font.pixelSize: 20; font.bold: true; color: Theme.yellow }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8; columnSpacing: 8
                Repeater {
                    model: root.shop
                    Rectangle {
                        id: si
                        required property var modelData
                        readonly property int lv: root.metaLv(modelData.id)
                        readonly property bool maxed: lv >= modelData.max
                        readonly property int cost: root.price(modelData)
                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: Theme.radius
                        color: Theme.mantle
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 12; spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                StyledText { text: si.modelData.name + "  " + "●".repeat(si.lv) + "○".repeat(si.modelData.max - si.lv); font.bold: true }
                                StyledText { text: si.modelData.desc; color: Theme.overlay1; font.pixelSize: Theme.fontSizeSmall }
                            }
                            SButton {
                                text: si.maxed ? I18n.tr("Максимум") : "◆ " + si.cost
                                enabled_: !si.maxed && root.shards >= si.cost
                                primary: !si.maxed && root.shards >= si.cost
                                onClicked: root.buy(si.modelData)
                            }
                        }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
