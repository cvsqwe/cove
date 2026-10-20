import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "keys.js" as K

// Ритм — как osu!: одна карта, три режима.
//   Круги    — мышь + Z / X (или кнопки мыши): попасть по кругу, когда сожмётся кольцо;
//   Дорожки  — D F J K: ноты падают по четырём дорожкам;
//   Барабан  — F / J — «дон» (красные), D / K — «кат» (синие).
// Карты: встроенные треки сочиняет assets/rhythm/music.py (кэш ~/.cache/cove/rhythm),
// свои — assets/rhythm/add.py (файл или ссылка → ~/.local/share/cove/rhythm).
// Карта — ноты { t (мс), s (сила 0…1), b (полоса 0 низ / 1 середина / 2 верх) }; режим и сложность
// строят из них свой набор нот (chart).
Item {
    id: root
    property bool active: false
    // профиль (GamesWindow) — у всех игр одинаковый набор, иначе Binding в окне зацикливается
    property var cheats: []
    property var modes: []
    signal record(real value)
    signal sfx(string name)
    signal fx(string kind, Item at, real x, real y, string text, color tint)
    // профиль (GamesWindow)
    property bool legacy: false
    property var perks: []
    property string skin: ""
    signal event(string name, var data)
    signal unlock(string id)
    signal cheatUsed(string id)

    // ---- читы: окно проставляет cheats (открытые id); слово набирается во время трека ----
    readonly property var cheatCodes: [
        { id: "rhythm.heal", code: "heal", run: () => { if (screen !== "play" || failed || hp >= 1) return false; hp = Math.min(1, hp + 0.5); return true; } },
        { id: "rhythm.calm", code: "calm", run: () => { if (screen !== "play" || failed) return false; calmUntil = now + 15000; return true; } },
        { id: "rhythm.auto", code: "bot", run: () => { if (screen !== "play" || failed) return false; autoUntil = now + 10000; return true; } }
    ]
    property real calmUntil: -1e9      // «хладнокровие»: до этого момента трека промахи не наказываются
    property real autoUntil: -1e9      // «автопилот»: до этого момента ноты отбиваются сами
    property string typedBuf: ""
    function feed(L: string): void {
        if (!L) return;
        typedBuf = (typedBuf + L).slice(-8);
        for (const c of cheatCodes)
            if (typedBuf.endsWith(c.code) && cheats.includes(c.id)) { typedBuf = ""; if (c.run() !== false) cheatUsed(c.id); }
    }

    focus: true
    readonly property string cache: Quickshell.env("HOME") + "/.cache/cove/rhythm"
    readonly property string py: Quickshell.shellPath("assets/rhythm")

    // ---------- состояние ----------
    property string screen: "select"          // select | play | result
    property string mode: (Store.gameRhythm ?? {}).mode ?? "circles"
    property string diff: (Store.gameRhythm ?? {}).diff ?? "normal"
    property int offset: (Store.gameRhythm ?? {}).offset ?? 0      // сдвиг звука, мс (+ — ноты позже)
    function remember(): void { Store.gameRhythm = Object.assign({}, Store.gameRhythm ?? {}, { mode, diff, offset }); }

    readonly property string status: screen === "play" ? I18n.tr("Счёт: ") + score + " · " + acc.toFixed(2) + "% · " + combo + "x"
        : (map ? map.title : I18n.tr("Выбери трек"))
    readonly property string bestKey: map ? "rhythm:" + map.id + ":" + mode + ":" + diff : "rhythm"
    readonly property bool lowerBetter: false
    function restart(): void { if (screen === "play" || screen === "result") start(); }

    // ---------- библиотека ----------
    property var builtin: []
    property var custom: []
    property string busy: ""                  // id трека, который сейчас сочиняется / добавляется
    property string error: ""
    Process {
        id: listBuiltin
        command: ["python3", root.py + "/music.py", "list", root.cache + "/builtin"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root.builtin = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: listCustom
        command: ["python3", root.py + "/add.py", "--list"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root.custom = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: maker
        property string want: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = "";
                listBuiltin.running = true;
                try { const r = JSON.parse(text); if (r.ok) root.loadMap(root.cache + "/builtin/" + r.id + ".json"); }
                catch (e) { root.error = I18n.tr("Не удалось сочинить трек"); }
            }
        }
    }
    Process {
        id: adder
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = "";
                try {
                    const r = JSON.parse(text);
                    if (r.ok) { listCustom.running = true; root.loadMap(r.map); root.error = ""; root.event("custom", {}); }
                    else root.error = r.error;
                } catch (e) { root.error = I18n.tr("Не удалось добавить трек"); }
            }
        }
    }
    function pickBuiltin(t): void {
        error = "";
        if (t.ready) { loadMap(t.map); return; }
        busy = t.id;
        maker.command = ["python3", py + "/music.py", "make", t.id, cache + "/builtin"];
        maker.running = true;
    }
    function addTrack(src: string): void {
        src = src.trim();
        if (!src || busy) return;
        error = "";
        busy = "add";
        adder.command = ["python3", py + "/add.py", src.replace(/^file:\/\//, "")];
        adder.running = true;
    }
    function removeTrack(id: string): void {
        Quickshell.execDetached(["python3", py + "/add.py", "--remove", id]);
        custom = custom.filter(c => c.id !== id);
        if (map?.id === id) map = null;
    }

    // ---------- карта ----------
    property var map: null
    FileView {
        id: mapFile
        onLoaded: { try { root.map = JSON.parse(text()); root.error = ""; } catch (e) { root.error = I18n.tr("Карта повреждена"); } }
    }
    function loadMap(path: string): void { mapFile.path = ""; mapFile.path = path; }

    readonly property var diffs: ({
        easy:   { name: I18n.tr("Лёгко"),  minS: 0.7,  gap: 430, approach: 1500, win: [60, 115, 165], drain: 0.5, speed: 0.45 },
        normal: { name: I18n.tr("Норма"),  minS: 0.5,  gap: 290, approach: 1200, win: [50, 100, 145], drain: 0.8, speed: 0.6 },
        hard:   { name: I18n.tr("Сложно"), minS: 0.33, gap: 185, approach: 900,  win: [40, 85, 125],  drain: 1.0, speed: 0.8 },
        insane: { name: I18n.tr("Безумно"), minS: 0.18, gap: 115, approach: 700, win: [32, 72, 110],  drain: 1.2, speed: 1.0 }
    })
    readonly property var dc: diffs[diff]
    // перк «широкое окно»: попадания засчитываются щедрее
    readonly property var win: perks.includes("rhythm.wide") ? dc.win.map(w => w + 12) : dc.win

    // ноты режима: { t, k (вид: don/kat для барабана), lane, x, y, n (номер в серии), big, j (оценка: 0 — нет) }
    property var chart: []
    function buildChart(): void {
        const src = (map?.notes ?? []).slice().sort((a, b) => a.t - b.t);
        const out = [];
        let last = -1e9;
        for (const n of src) {
            if (n.s < dc.minS) continue;
            if (n.t - last < dc.gap) {
                // слишком близко: оставить более сильную
                if (out.length && n.s > out[out.length - 1].s + 0.15) { out[out.length - 1] = Object.assign({}, n); last = n.t; }
                continue;
            }
            out.push(Object.assign({}, n));
            last = n.t;
        }
        // круги: плавная траектория по полю 512×384, расстояние растёт с паузой между нотами
        let x = 256, y = 192, ang = Math.random() * Math.PI * 2, num = 0, lastT = 0, lane = 0;
        for (let i = 0; i < out.length; i++) {
            const n = out[i];
            const dt = n.t - lastT;
            if (i === 0 || dt > 900) num = 0;
            num = num % 8 + 1;
            ang += (Math.random() - 0.5) * 1.6;
            const dist = Math.max(70, Math.min(230, dt * 0.32));
            let nx = x + Math.cos(ang) * dist, ny = y + Math.sin(ang) * dist;
            if (nx < 40 || nx > 472) { ang = Math.PI - ang; nx = Math.max(40, Math.min(472, x + Math.cos(ang) * dist)); }
            if (ny < 40 || ny > 344) { ang = -ang; ny = Math.max(40, Math.min(344, y + Math.sin(ang) * dist)); }
            x = nx; y = ny;
            // дорожки: низ слева, верх справа; подряд на одну дорожку — только при паузе
            const want = n.b === 0 ? (Math.random() < 0.5 ? 0 : 1) : n.b === 2 ? (Math.random() < 0.5 ? 2 : 3) : (Math.random() < 0.5 ? 1 : 2);
            const ln = (want === lane && dt < 200) ? (want + 1 + Math.floor(Math.random() * 3)) % 4 : want;
            lane = ln;
            Object.assign(n, { x, y, n: num, lane: ln, k: n.b === 0 ? "don" : "kat", big: n.s >= 0.92, j: 0 });
            lastT = n.t;
        }
        chart = out;
    }

    // ---------- игра ----------
    property real now: -2000                 // время песни, мс
    property real clock0: 0
    property int next: 0                     // первая ещё не оценённая нота
    property int score: 0
    property int combo: 0
    property int maxCombo: 0
    property var counts: [0, 0, 0, 0]       // промах, 50, 100, 300
    property real hp: 1
    property bool failed: false
    readonly property int judged: counts[0] + counts[1] + counts[2] + counts[3]
    readonly property real acc: judged ? (counts[3] * 300 + counts[2] * 100 + counts[1] * 50) / (judged * 3) : 100
    readonly property string grade: acc >= 100 ? "SS" : acc >= 95 && counts[0] === 0 ? "S" : acc >= 90 ? "A" : acc >= 80 ? "B" : acc >= 70 ? "C" : "D"
    property var pops: []                    // всплывающие оценки { x, y, j, t }

    function start(): void {
        if (!map) return;
        remember();
        buildChart();
        next = 0; score = 0; combo = 0; maxCombo = 0; counts = [0, 0, 0, 0]; hp = 1; failed = false; pops = [];
        calmUntil = -1e9; autoUntil = -1e9; typedBuf = "";
        player.stop();
        player.source = "file://" + map.audio;
        now = -2000;
        clock0 = Date.now() + 2000;
        screen = "play";
        root.forceActiveFocus();
        sfx("start");
    }
    function finish(): void {
        if (screen !== "play") return;   // stop() ниже может вызвать finish повторно через onPlaybackStateChanged
        player.stop();
        screen = "result";
        const fc = counts[0] === 0 && !failed;
        if (!failed) record(score);
        if (!failed && (diff === "hard" || diff === "insane")) unlock("rhythm.calm");
        if (!failed && diff === "insane" && acc >= 90) unlock("rhythm.auto");
        event("end", { score, acc: Math.round(acc * 100) / 100, grade, maxCombo, mode, diff, fc, failed, notes: chart.length, custom: !map.builtin });
        sfx(failed ? "over" : grade === "SS" || grade === "S" ? "record" : "win");
        if (!failed && (grade === "SS" || grade === "S")) fx("confetti", null, 0, 0, "", Theme.yellow);
    }
    function judge(i: int, j: int, px: real, py: real): void {
        const c = chart;
        c[i].j = j;
        const cnt = counts.slice();
        cnt[j === 300 ? 3 : j === 100 ? 2 : j === 50 ? 1 : 0]++;
        counts = cnt;
        if (j > 0) {
            combo++;
            maxCombo = Math.max(maxCombo, combo);
            if (combo === 100) unlock("rhythm.heal");
            score += Math.round(j * (1 + combo / 25) * (c[i].big && mode === "taiko" ? 2 : 1));
            hp = Math.min(1, hp + (j === 300 ? 0.025 : j === 100 ? 0.008 : -0.005));
            if (combo > 0 && combo % 50 === 0) { sfx("combo"); fx("float", stage, stage.width / 2, stage.height * 0.3, combo + "x", Theme.yellow); }
        } else if (now < calmUntil) {
            // «хладнокровие»: промах засчитан, но комбо и здоровье целы
        } else {
            if (combo >= 20) sfx("err");
            combo = 0;
            hp -= 0.07 * dc.drain;
            if (hp <= 0 && !perks.includes("rhythm.noFail")) { failed = true; finish(); return; }
            hp = Math.max(0, hp);
        }
        pops = pops.concat([{ x: px, y: py, j, t: now }]).filter(p => now - p.t < 500);
    }
    // ближайшая неоценённая нота, которая подходит под нажатие
    function tryHit(match): void {
        if (screen !== "play" || now < -200) return;
        for (let i = next; i < chart.length; i++) {
            const n = chart[i];
            if (n.j) continue;
            const d = n.t - now;
            if (d > win[2] + 40) break;
            if (Math.abs(d) > win[2] || !match(n)) continue;
            const a = Math.abs(d), j = a <= win[0] ? 300 : a <= win[1] ? 100 : 50;
            const p = notePos(n);
            judge(i, j, p.x, p.y);
            if (j === 300 && mode === "circles") fx("burst", stage, p.x, p.y, "8", Theme.accent);
            sfx(mode === "taiko" ? (n.k === "don" ? "pop" : "flag") : "pop");
            return;
        }
        if (mode !== "circles") sfx("move");   // холостой удар по барабану / дорожке
    }
    // экранные координаты ноты (для всплывающих оценок)
    function notePos(n): point {
        if (mode === "circles") return Qt.point(stage.ox + n.x * stage.sc, stage.oy + n.y * stage.sc);
        if (mode === "mania") return Qt.point(stage.laneX(n.lane) + stage.laneW / 2, stage.hitY - 40);
        return Qt.point(stage.taikoHitX, stage.height / 2 - 60);
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput { volume: Store.gameSound ? 0.8 : 0 }
        onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && root.screen === "play" && root.now > 1000 && !root.failed) root.finish()
    }

    FrameAnimation {
        running: root.active && root.screen === "play"
        onTriggered: {
            // часы: до старта — по системному времени, потом — по позиции плеера с подстройкой
            const sys = Date.now() - root.clock0;
            if (sys >= 0 && player.playbackState !== MediaPlayer.PlayingState && root.now < 0) player.play();
            let t = sys;
            if (player.playbackState === MediaPlayer.PlayingState) {
                const drift = player.position - sys;
                if (Math.abs(drift) > 40) root.clock0 -= drift * 0.5;   // мягко догоняем звук
                t = Date.now() - root.clock0;
            }
            root.now = t - root.offset;
            const c = root.chart;
            // «автопилот»: всё, что дошло до линии, — точно в такт
            if (root.now < root.autoUntil)
                for (let i = root.next; i < c.length && c[i].t <= root.now; i++)
                    if (!c[i].j) { const p = root.notePos(c[i]); root.judge(i, 300, p.x, p.y); root.sfx("pop"); }
            // промахи: прошли окно
            while (root.next < c.length && (c[root.next].j || c[root.next].t < root.now - root.win[2])) {
                if (!c[root.next].j) { const p = root.notePos(c[root.next]); root.judge(root.next, 0, p.x, p.y); if (root.screen !== "play") return; }
                root.next++;
            }
            if (root.next >= c.length && c.length && root.now > c[c.length - 1].t + 1500) root.finish();
            stage.requestPaint();
        }
    }

    Keys.onPressed: e => {
        if (e.isAutoRepeat) { e.accepted = true; return; }
        const L = K.letter(e);
        if (screen === "play") {
            if (e.key === Qt.Key_Escape) return;          // Esc — окно: назад к играм
            if (mode === "circles" && (L === "z" || L === "x")) tryHit(n => stage.over(n));
            else if (mode === "mania" && ["d", "f", "j", "k"].includes(L)) { const ln = ["d", "f", "j", "k"].indexOf(L); stage.press(ln, true); tryHit(n => n.lane === ln); }
            else if (mode === "taiko" && ["d", "f", "j", "k"].includes(L)) { const don = L === "f" || L === "j"; stage.drum(L); tryHit(n => n.k === (don ? "don" : "kat")); }
            else if (L === "r") start();
            else { feed(L); return; }
            e.accepted = true;
        } else if (screen === "result" && (e.key === Qt.Key_Return || e.key === Qt.Key_Space || L === "r")) { start(); e.accepted = true; }
    }
    Keys.onReleased: e => {
        const L = K.letter(e);
        if (mode === "mania" && ["d", "f", "j", "k"].includes(L)) stage.press(["d", "f", "j", "k"].indexOf(L), false);
    }

    // ================= выбор трека =================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20
        visible: root.screen === "select"

        // список треков
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 430
            spacing: 8
            StyledText { text: I18n.tr("Треки Cove"); font.bold: true; color: Theme.subtext0 }
            Repeater {
                model: root.builtin
                TrackRow {
                    required property var modelData
                    t: modelData
                    sub: modelData.style + " · " + modelData.bpm + " BPM · " + Math.floor(modelData.seconds / 60) + ":" + String(modelData.seconds % 60).padStart(2, "0")
                    note: modelData.ready ? "" : root.busy === modelData.id ? I18n.tr("сочиняю… ~30 с") : I18n.tr("ещё не сочинён")
                    onPicked: root.pickBuiltin(modelData)
                }
            }
            StyledText { Layout.topMargin: 8; text: I18n.tr("Свои треки"); font.bold: true; color: Theme.subtext0 }
            Repeater {
                model: root.custom
                TrackRow {
                    required property var modelData
                    t: modelData
                    sub: (modelData.artist ? modelData.artist + " · " : "") + modelData.bpm + " BPM · " + Math.floor(modelData.duration / 60000) + ":" + String(Math.floor(modelData.duration / 1000) % 60).padStart(2, "0")
                    removable: true
                    onPicked: root.loadMap(Quickshell.env("HOME") + "/.local/share/cove/rhythm/maps/" + modelData.id + ".json")
                    onRemoved: root.removeTrack(modelData.id)
                }
            }
            // добавить свой
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                SField {
                    id: addField
                    Layout.fillWidth: true
                    placeholderText: I18n.tr("Путь к файлу или ссылка (YouTube, SoundCloud…)")
                    onAccepted: { root.addTrack(text); text = ""; }
                }
                SButton { icon: "add"; text: root.busy === "add" ? I18n.tr("Анализ…") : I18n.tr("Добавить"); onClicked: { root.addTrack(addField.text); addField.text = ""; } }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.error || I18n.tr("Можно просто перетащить аудиофайл в окно")
                color: root.error ? Theme.red : Theme.overlay0
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
            Item { Layout.fillHeight: true }
        }

        // выбранная карта, режим, сложность
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 150
                radius: Theme.radius + 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.alpha(Theme.accent, 0.35) }
                    GradientStop { position: 1; color: Theme.alpha(Theme.accent2, 0.18) }
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 2
                    StyledText { text: root.map ? root.map.title : I18n.tr("Выбери трек слева"); font.pixelSize: 26; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    StyledText { text: root.map ? (root.map.artist || I18n.tr("неизвестный исполнитель")) + " · " + root.map.bpm + " BPM" : I18n.tr("Треки Cove сочиняются при первом выборе"); color: Theme.subtext0 }
                    Item { Layout.fillHeight: true }
                    StyledText {
                        visible: !!root.map
                        readonly property var b: root.map ? (Store.gameScores ?? {})[root.bestKey] : undefined
                        text: b !== undefined ? I18n.tr("Рекорд: ") + b : I18n.tr("Рекорда пока нет")
                        color: Theme.yellow
                    }
                }
            }
            StyledText { text: I18n.tr("Режим"); color: Theme.subtext0 }
            SSegment {
                options: [{ value: "circles", label: I18n.tr("Круги"), icon: "radio_button_checked" }, { value: "mania", label: I18n.tr("Дорожки"), icon: "view_week" }, { value: "taiko", label: I18n.tr("Барабан"), icon: "album" }]
                current: root.mode
                onPicked: v => { root.mode = v; root.remember(); }
            }
            StyledText {
                text: root.mode === "circles" ? I18n.tr("Мышь + Z / X или кнопки мыши — когда кольцо сожмётся до круга")
                    : root.mode === "mania" ? I18n.tr("D F J K — когда нота дойдёт до линии")
                    : I18n.tr("F / J — красные «дон», D / K — синие «кат»")
                color: Theme.overlay1
                font.pixelSize: Theme.fontSizeSmall
            }
            StyledText { text: I18n.tr("Сложность"); color: Theme.subtext0 }
            SSegment {
                options: ["easy", "normal", "hard", "insane"].map(d => ({ value: d, label: root.diffs[d].name }))
                current: root.diff
                onPicked: v => { root.diff = v; root.remember(); }
            }
            RowLayout {
                spacing: 10
                StyledText { text: I18n.tr("Сдвиг звука"); color: Theme.subtext0 }
                IconButton { size: 28; iconSize: 14; icon: "remove"; onClicked: { root.offset -= 5; root.remember(); } }
                StyledText { text: (root.offset > 0 ? "+" : "") + root.offset + I18n.tr(" мс"); Layout.preferredWidth: 60; horizontalAlignment: Text.AlignHCenter }
                IconButton { size: 28; iconSize: 14; icon: "add"; onClicked: { root.offset += 5; root.remember(); } }
                StyledText { text: I18n.tr("если ноты приходят раньше звука — плюс"); color: Theme.overlay0; font.pixelSize: Theme.fontSizeSmall }
            }
            Item { Layout.fillHeight: true }
            SButton {
                Layout.alignment: Qt.AlignRight
                primary: true
                icon: "play_arrow"
                text: I18n.tr("Играть")
                enabled_: !!root.map
                onClicked: root.start()
            }
        }
    }

    // перетащить файл в окно — добавить трек
    DropArea {
        anchors.fill: parent
        enabled: root.screen === "select"
        onDropped: d => { if (d.hasUrls) root.addTrack(String(d.urls[0])); }
    }

    component TrackRow: Rectangle {
        id: tr
        property var t: ({})
        property string sub: ""
        property string note: ""
        property bool removable: false
        signal picked()
        signal removed()
        readonly property bool on: root.map && root.map.id === t.id
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radius
        color: on ? Theme.alpha(Theme.accent, 0.18) : trm.containsMouse ? Theme.surface0 : Theme.mantle
        border.width: on ? 1 : 0
        border.color: Theme.accent
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10
            MIcon { icon: tr.t.builtin === false || tr.removable ? "audio_file" : "music_note"; color: tr.on ? Theme.accent : Theme.subtext1; size: 18 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { Layout.fillWidth: true; text: tr.t.title ?? ""; font.bold: true; elide: Text.ElideRight }
                StyledText { Layout.fillWidth: true; text: tr.note || tr.sub; color: tr.note ? Theme.yellow : Theme.overlay1; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideRight }
            }
            IconButton { visible: tr.removable && trm.containsMouse; size: 26; iconSize: 13; icon: "delete"; color: "transparent"; onClicked: tr.removed() }
        }
        MouseArea { id: trm; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tr.picked() }
    }

    // ================= игра =================
    Canvas {
        id: stage
        anchors.fill: parent
        visible: root.screen === "play"
        // круги: поле 512×384 по центру
        readonly property real sc: Math.min((width - 80) / 512, (height - 90) / 384)
        readonly property real ox: (width - 512 * sc) / 2
        readonly property real oy: (height - 384 * sc) / 2 + 20
        readonly property real cr: 34 * sc * (root.diff === "insane" ? 0.85 : root.diff === "easy" ? 1.2 : 1)
        // дорожки
        readonly property real laneW: 78
        readonly property real hitY: height - 90
        function laneX(l: int): real { return width / 2 - 2 * laneW + l * laneW; }
        property var held: [false, false, false, false]
        function press(l: int, v: bool): void { const h = held.slice(); h[l] = v; held = h; }
        // барабан
        readonly property real taikoHitX: 170
        property string lastDrum: ""
        property real drumAt: 0
        function drum(L: string): void { lastDrum = L; drumAt = Date.now(); }
        function over(n): bool {
            const mx = cursor.x, my = cursor.y;
            const dx = mx - (ox + n.x * sc), dy = my - (oy + n.y * sc);
            return dx * dx + dy * dy <= (cr * 1.15) * (cr * 1.15);
        }

        onPaint: {
            const g = getContext("2d");
            g.reset();
            const t = root.now, c = root.chart, A = root.dc.approach;
            if (root.mode === "circles") {
                // рамка поля
                g.strokeStyle = Theme.alpha(Theme.surface0, 0.7); g.lineWidth = 1;
                g.strokeRect(ox - 10, oy - 10, 512 * sc + 20, 384 * sc + 20);
                // видимые ноты: от будущих к ближайшим (ближайшая сверху)
                let last = root.next;
                while (last < c.length && c[last].t - t < A) last++;
                for (let i = last - 1; i >= root.next; i--) {
                    const n = c[i];
                    if (n.j) continue;
                    const k = 1 - (n.t - t) / A;                       // 0 → появилась, 1 → пора
                    const x = ox + n.x * sc, y = oy + n.y * sc;
                    const col = [Theme.accent, Theme.accent2, Theme.pink, Theme.teal][Math.floor(i / 8) % 4];
                    g.globalAlpha = Math.min(1, k * 3);
                    g.fillStyle = Theme.alpha(col, 0.85);
                    g.beginPath(); g.arc(x, y, cr, 0, Math.PI * 2); g.fill();
                    g.strokeStyle = "#ffffff"; g.lineWidth = 3;
                    g.beginPath(); g.arc(x, y, cr, 0, Math.PI * 2); g.stroke();
                    g.fillStyle = "#ffffff"; g.font = "bold " + Math.round(cr * 0.8) + "px sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
                    g.fillText(String(n.n), x, y + 1);
                    // кольцо приближения
                    g.strokeStyle = Theme.alpha(col, 0.95); g.lineWidth = 3;
                    g.beginPath(); g.arc(x, y, cr * (1 + 2.2 * (1 - Math.min(1, k))), 0, Math.PI * 2); g.stroke();
                }
                g.globalAlpha = 1;
            } else if (root.mode === "mania") {
                const W = laneW, S = root.dc.speed;
                for (let l = 0; l < 4; l++) {
                    g.fillStyle = Theme.alpha(held[l] ? Theme.accent : Theme.surface0, held[l] ? 0.25 : 0.35);
                    g.fillRect(laneX(l) + 2, 0, W - 4, height);
                }
                g.fillStyle = Theme.alpha(Theme.text, 0.8); g.fillRect(laneX(0), hitY, 4 * W, 3);
                for (let l = 0; l < 4; l++) {
                    g.fillStyle = held[l] ? Theme.accent : Theme.surface1;
                    g.beginPath(); g.roundedRect(laneX(l) + 8, hitY + 12, W - 16, 30, 8, 8); g.fill();
                    g.fillStyle = held[l] ? Theme.crust : Theme.subtext0; g.font = "bold 14px sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
                    g.fillText(["D", "F", "J", "K"][l], laneX(l) + W / 2, hitY + 27);
                }
                for (let i = root.next; i < c.length; i++) {
                    const n = c[i];
                    const y = hitY - (n.t - t) * S;
                    if (y < -30) break;
                    if (n.j) continue;
                    g.fillStyle = [Theme.accent2, Theme.accent, Theme.accent, Theme.accent2][n.lane];
                    g.beginPath(); g.roundedRect(laneX(n.lane) + 6, y - 11, W - 12, 22, 7, 7); g.fill();
                }
            } else {
                // барабан: лента справа налево, удар слева
                const S = root.dc.speed * 0.9, cy = height / 2;
                g.fillStyle = Theme.alpha(Theme.surface0, 0.5); g.fillRect(0, cy - 55, width, 110);
                const hot = Date.now() - drumAt < 90;
                g.strokeStyle = hot ? (lastDrum === "f" || lastDrum === "j" ? Theme.red : Theme.accent2) : Theme.overlay1; g.lineWidth = 4;
                g.beginPath(); g.arc(taikoHitX, cy, 40, 0, Math.PI * 2); g.stroke();
                for (let i = c.length - 1; i >= root.next; i--) {
                    const n = c[i];
                    const x = taikoHitX + (n.t - t) * S;
                    if (x > width + 60) continue;
                    if (n.j) continue;
                    const r = n.big ? 44 : 30;
                    g.fillStyle = n.k === "don" ? Theme.red : Theme.accent2;
                    g.beginPath(); g.arc(x, cy, r, 0, Math.PI * 2); g.fill();
                    g.strokeStyle = "#ffffff"; g.lineWidth = 3; g.stroke();
                }
                // барабан-подсказка
                g.fillStyle = Theme.overlay1; g.font = "13px sans-serif"; g.textAlign = "center";
                g.fillText(I18n.tr("D K — кат   ·   F J — дон"), taikoHitX, cy + 80);
            }
            // всплывающие оценки
            for (const p of root.pops) {
                const age = (t - p.t) / 500;
                if (age < 0 || age > 1) continue;
                g.globalAlpha = 1 - age;
                g.fillStyle = p.j === 300 ? Theme.accent : p.j === 100 ? Theme.green : p.j === 50 ? Theme.yellow : Theme.red;
                g.font = "bold 22px sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
                g.fillText(p.j ? String(p.j) : "✕", p.x, p.y - 30 - age * 20);
            }
            g.globalAlpha = 1;
            // отсчёт
            if (t < 0) {
                g.fillStyle = Theme.text; g.font = "bold 64px sans-serif"; g.textAlign = "center"; g.textBaseline = "middle";
                g.fillText(String(Math.ceil(-t / 1000 * 1.5)), width / 2, height / 2);
            }
        }

        // курсор и клики мыши (круги)
        Item { id: cursor; x: hover.mouseX; y: hover.mouseY }
        Rectangle {
            visible: root.mode === "circles"
            x: cursor.x - 9; y: cursor.y - 9
            width: 18; height: 18; radius: 9
            color: Theme.alpha(Theme.yellow, 0.85)
            border.width: 2
            border.color: "#ffffff"
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.mode === "circles" ? Qt.BlankCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: { root.forceActiveFocus(); if (root.mode === "circles") root.tryHit(n => stage.over(n)); }
        }
    }

    // шапка игры: HP, прогресс, комбо
    Item {
        anchors.fill: parent
        visible: root.screen === "play"
        Rectangle {
            x: 20; y: 14; width: parent.width * 0.4; height: 8; radius: 4
            color: Theme.surface0
            Rectangle { width: parent.width * root.hp; height: parent.height; radius: 4; color: root.hp > 0.3 ? Theme.green : Theme.red; Behavior on width { NumberAnimation { duration: 120 } } }
        }
        Rectangle {
            anchors.bottom: parent.bottom; width: parent.width * Math.max(0, Math.min(1, root.now / Math.max(1, root.map?.duration ?? 1))); height: 3
            color: Theme.accent
        }
        StyledText {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 18
            text: root.combo + "x"
            font.pixelSize: 40; font.bold: true
            color: Theme.text
            opacity: root.combo > 1 ? 1 : 0.3
        }
        StyledText {
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
            text: String(root.score).padStart(8, "0")
            font.pixelSize: 26; font.bold: true
        }
        StyledText {
            anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 48; anchors.rightMargin: 14
            text: root.acc.toFixed(2) + "%"
            color: Theme.subtext0
        }
    }

    // ================= результат =================
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.screen === "result"
        spacing: 14
        StyledText { Layout.alignment: Qt.AlignHCenter; text: root.failed ? I18n.tr("Провал") : root.map?.title ?? ""; font.pixelSize: 24; font.bold: true; color: root.failed ? Theme.red : Theme.text }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 40
            StyledText {
                text: root.failed ? "F" : root.grade
                font.pixelSize: 110; font.bold: true
                color: root.failed ? Theme.red : ({ SS: Theme.yellow, S: Theme.yellow, A: Theme.green, B: Theme.accent2, C: Theme.accent, D: Theme.red })[root.grade]
            }
            ColumnLayout {
                spacing: 4
                StyledText { text: String(root.score).padStart(8, "0"); font.pixelSize: 30; font.bold: true }
                StyledText { text: I18n.tr("Точность ") + root.acc.toFixed(2) + "%   ·   " + I18n.tr("макс. комбо ") + root.maxCombo + "x"; color: Theme.subtext0 }
                RowLayout {
                    spacing: 14
                    Repeater {
                        model: [["300", 3, Theme.accent], ["100", 2, Theme.green], ["50", 1, Theme.yellow], ["✕", 0, Theme.red]]
                        StyledText { required property var modelData; text: modelData[0] + " · " + root.counts[modelData[1]]; color: modelData[2]; font.bold: true }
                    }
                }
                StyledText { visible: root.counts[0] === 0 && !root.failed; text: I18n.tr("Без промахов!"); color: Theme.yellow; font.bold: true }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            SButton { icon: "list"; text: I18n.tr("К трекам"); onClicked: root.screen = "select" }
            SButton { primary: true; icon: "refresh"; text: I18n.tr("Ещё раз (Enter)"); onClicked: root.start() }
        }
    }
}
