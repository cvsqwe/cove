pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.config

// Звуковые эффекты без EasyEffects: свой filter-chain PipeWire.
// Выход: предусиление → эквалайзер (биквады PipeWire) → бас → выравнивание громкости → лимитер (LSP).
// Микрофон: модуль echo-cancel с WebRTC (шумо- и эхоподавление, автогромкость, срез гула).
// Оба — «умные фильтры» WirePlumber (filter.smart): встают перед устройством по умолчанию сами,
// громкость и выбор выхода работают как без них. Живут отдельными юнитами systemd
// (cove-sound-out / cove-sound-mic), поэтому перезапуск шелла звук не прерывает.
// Ползунки меняют параметры на лету (pw-cli set-param), перезапуск — только когда меняется
// число или тип полос.
Singleton {
    id: root

    readonly property var s: Settings.sound
    readonly property string dir: Settings.home + "/.local/state/cove/sound"
    readonly property string outUnit: "cove-sound-out"
    readonly property string micUnit: "cove-sound-mic"

    // LSP (лимитер, выравнивание громкости) — пакет lsp-plugins-lv2, необязательный
    property bool lsp: false
    property bool checked: false
    // EasyEffects: запущен (мешает — сам перетаскивает потоки) и есть ли что импортировать
    property bool eeRunning: false
    property bool eeData: false

    readonly property real rate: 48000
    readonly property var freqs10: [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    function graphic(g): var { return freqs10.map((f, i) => ({ f: f, g: g[i], q: 1.41, type: "bell" })); }

    readonly property var builtin: [
        { id: "flat", label: I18n.tr("Ровно"), bands: graphic([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), bass: 0 },
        { id: "bass", label: I18n.tr("Бас"), bands: graphic([5, 5, 4, 2, 0, 0, 0, 0, 0, 0]), bass: 0 },
        { id: "warm", label: I18n.tr("Тепло"), bands: graphic([2, 3, 3, 1, 0, -1, -1, -2, -2, -3]), bass: 0 },
        { id: "vocal", label: I18n.tr("Голос"), bands: graphic([-3, -2, -1, 0, 2, 3, 3, 2, 0, -1]), bass: 0 },
        { id: "bright", label: I18n.tr("Ярко"), bands: graphic([0, 0, 0, 0, 0, 1, 2, 3, 4, 4]), bass: 0 },
        { id: "phones", label: I18n.tr("Наушники"), bands: graphic([3, 2, 1, 0, -1, 0, 1, 2, 3, 1]), bass: 0 },
        { id: "laptop", label: I18n.tr("Маленькие колонки"), bands: graphic([-6, -3, 2, 3, 2, 1, 1, 2, 2, 0]), bass: 0 }
    ]
    readonly property var types: [
        { value: "bell", label: I18n.tr("Колокол") },
        { value: "lowshelf", label: I18n.tr("Полка низких") },
        { value: "highshelf", label: I18n.tr("Полка высоких") },
        { value: "lowpass", label: I18n.tr("Срез высоких") },
        { value: "highpass", label: I18n.tr("Срез низких") },
        { value: "notch", label: I18n.tr("Вырез") }
    ]

    readonly property var bands: (s.bands ?? []).length ? s.bands : builtin[0].bands
    readonly property var customNames: Object.keys(s.presets ?? {}).sort()
    function presetLabel(id: string): string {
        const b = builtin.find(p => p.id === id);
        return b ? b.label : id;
    }
    function presetData(id: string): var { return builtin.find(p => p.id === id) ?? (s.presets ?? {})[id] ?? null; }
    // набор выбран, но полосы с тех пор двигали
    readonly property bool modified: {
        const p = presetData(s.preset);
        if (!p) return true;
        const same = (a, b) => Math.abs((a ?? 0) - (b ?? 0)) < 0.05;
        if (!same(p.preamp, s.preamp) || !same(p.bass, s.bass) || p.bands.length !== bands.length) return true;
        return p.bands.some((b, i) => !same(b.f, bands[i].f) || !same(b.g, bands[i].g) || !same(b.q, bands[i].q) || b.type !== bands[i].type);
    }

    // ---------- изменение состояния (из страниц) ----------
    function load(id: string): void {
        const p = presetData(id);
        if (!p) return;
        s.bands = Settings.copy(p.bands);
        s.preamp = p.preamp ?? 0;
        s.bass = p.bass ?? 0;
        s.preset = id;
        rememberDevice(id);
    }
    function save(name: string): void {
        name = name.trim();
        if (!name || builtin.some(p => p.label === name || p.id === name)) return;
        const all = Settings.copy(s.presets ?? {});
        all[name] = { bands: Settings.copy(bands), preamp: s.preamp, bass: s.bass };
        s.presets = all;
        s.preset = name;
        rememberDevice(name);
    }
    function remove(name: string): void {
        const all = Settings.copy(s.presets ?? {});
        delete all[name];
        s.presets = all;
        const d = Settings.copy(s.devices ?? {});
        for (const k of Object.keys(d)) if (d[k] === name) delete d[k];
        s.devices = d;
        if (s.preset === name) s.preset = "";
    }
    function setBand(i: int, patch): void {
        const b = Settings.copy(bands);
        if (!b[i]) return;
        Object.assign(b[i], patch);
        s.bands = b;
    }
    function addBand(f: real, g: real): int {
        const b = Settings.copy(bands);
        b.push({ f: Math.round(f), g: g ?? 0, q: 1.41, type: "bell" });
        b.sort((x, y) => x.f - y.f);
        s.bands = b;
        return b.findIndex(x => Math.round(f) === x.f);
    }
    function removeBand(i: int): void {
        const b = Settings.copy(bands);
        b.splice(i, 1);
        s.bands = b;
    }

    // набор запоминается за выходом: наушники — одно, колонки — другое
    readonly property string sinkName: Pipewire.defaultAudioSink?.name ?? ""
    function rememberDevice(id: string): void {
        if (!sinkName) return;
        const d = Settings.copy(s.devices ?? {});
        d[sinkName] = id;
        s.devices = d;
    }
    onSinkNameChanged: {
        const id = (s.devices ?? {})[sinkName];
        if (id && id !== s.preset && presetData(id)) load(id);
    }

    // ---------- АЧХ для графика (те же формулы RBJ, что у биквадов PipeWire) ----------
    function coeffs(type: string, f: real, q: real, g: real): var {
        const A = Math.pow(10, g / 40), w = 2 * Math.PI * Math.min(f, rate / 2 - 1) / rate;
        const c = Math.cos(w), al = Math.sin(w) / (2 * Math.max(0.05, q)), sa = 2 * Math.sqrt(A) * al;
        switch (type) {
        case "lowshelf": return [A * ((A + 1) - (A - 1) * c + sa), 2 * A * ((A - 1) - (A + 1) * c), A * ((A + 1) - (A - 1) * c - sa),
                                 (A + 1) + (A - 1) * c + sa, -2 * ((A - 1) + (A + 1) * c), (A + 1) + (A - 1) * c - sa];
        case "highshelf": return [A * ((A + 1) + (A - 1) * c + sa), -2 * A * ((A - 1) + (A + 1) * c), A * ((A + 1) + (A - 1) * c - sa),
                                  (A + 1) - (A - 1) * c + sa, 2 * ((A - 1) - (A + 1) * c), (A + 1) - (A - 1) * c - sa];
        case "lowpass": return [(1 - c) / 2, 1 - c, (1 - c) / 2, 1 + al, -2 * c, 1 - al];
        case "highpass": return [(1 + c) / 2, -(1 + c), (1 + c) / 2, 1 + al, -2 * c, 1 - al];
        case "notch": return [1, -2 * c, 1, 1 + al, -2 * c, 1 - al];
        default: return [1 + al * A, -2 * c, 1 - al * A, 1 + al / A, -2 * c, 1 - al / A];
        }
    }
    function magDb(k, f: real): real {
        const w = 2 * Math.PI * f / rate, c1 = Math.cos(w), s1 = Math.sin(w), c2 = Math.cos(2 * w), s2 = Math.sin(2 * w);
        const nr = k[0] + k[1] * c1 + k[2] * c2, ni = -(k[1] * s1 + k[2] * s2);
        const dr = k[3] + k[4] * c1 + k[5] * c2, di = -(k[4] * s1 + k[5] * s2);
        return 10 * Math.log10((nr * nr + ni * ni) / Math.max(1e-12, dr * dr + di * di));
    }
    // filters: [[коэффициенты], …] — считаются один раз на изменение полос
    function chainCoeffs(list, bass: real): var {
        const out = list.map(b => coeffs(b.type, b.f, b.q, b.g));
        if (Math.abs(bass) > 0.01) out.push(coeffs("lowshelf", 100, 0.707, bass));
        return out;
    }
    function response(ks, f: real, pre: real): real { return ks.reduce((a, k) => a + magDb(k, f), pre); }

    // ---------- конфиги ----------
    function num(v: real): string { return Number(v).toFixed(4); }
    function bq(type: string): string { return "bq_" + (type === "bell" ? "peaking" : type); }
    readonly property string outSig: "cove-sound 1 " + bands.map(b => b.type).join(",") + (lsp ? " lsp" : "")

    // все управляемые параметры выхода: [[имя, значение], …]
    function outParams(): var {
        const p = [];
        const pre = Math.pow(10, s.preamp / 20);
        for (const ch of ["l", "r"]) {
            p.push([`pre${ch}:Mult`, pre]);
            bands.forEach((b, i) => {
                p.push([`b${i}${ch}:Freq`, b.f], [`b${i}${ch}:Q`, b.q], [`b${i}${ch}:Gain`, b.g]);
            });
            p.push([`bass${ch}:Gain`, s.bass]);
        }
        if (lsp) {
            p.push(["agc:enabled", s.loudness ? 1 : 0], ["agc:level", s.loudnessLevel]);
            p.push(["lim:enabled", s.limiter ? 1 : 0]);
        }
        return p;
    }

    function outConf(): string {
        const vals = outParams().reduce((o, [k, v]) => { o[k] = v; return o; }, {});
        const nodes = [], links = [];
        for (const ch of ["l", "r"]) {
            const chain = [`pre${ch}`];
            nodes.push(`{ type = builtin name = pre${ch} label = linear control = { Mult = ${num(vals[`pre${ch}:Mult`])} Add = 0.0 } }`);
            bands.forEach((b, i) => {
                const n = `b${i}${ch}`;
                nodes.push(`{ type = builtin name = ${n} label = ${bq(b.type)} control = { Freq = ${num(b.f)} Q = ${num(b.q)} Gain = ${num(b.g)} } }`);
                chain.push(n);
            });
            nodes.push(`{ type = builtin name = bass${ch} label = bq_lowshelf control = { Freq = 100.0 Q = 0.7070 Gain = ${num(s.bass)} } }`);
            chain.push(`bass${ch}`);
            for (let i = 1; i < chain.length; i++)
                links.push(`{ output = "${chain[i - 1]}:Out" input = "${chain[i]}:In" }`);
        }
        let outputs = `"bassl:Out" "bassr:Out"`;
        if (lsp) {
            const lv = "http://lsp-plug.in/plugins/lv2/";
            nodes.push(`{ type = lv2 name = agc plugin = "${lv}autogain_stereo" control = { enabled = ${s.loudness ? 1 : 0} level = ${num(s.loudnessLevel)} } }`);
            nodes.push(`{ type = lv2 name = lim plugin = "${lv}limiter_stereo" control = { enabled = ${s.limiter ? 1 : 0} th = 0.8913 } }`);
            links.push(`{ output = "bassl:Out" input = "agc:in_l" }`, `{ output = "bassr:Out" input = "agc:in_r" }`,
                       `{ output = "agc:out_l" input = "lim:in_l" }`, `{ output = "agc:out_r" input = "lim:in_r" }`);
            outputs = `"lim:out_l" "lim:out_r"`;
        }
        const desc = I18n.tr("Эффекты Cove");
        return [
            "# " + outSig,
            "# Сгенерировано Cove (services/SoundFx.qml), меняется в Настройки → Звук",
            "context.properties = { log.level = 0 }",
            "context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }",
            "context.modules = [",
            "  { name = libpipewire-module-rt args = { nice.level = -11 } flags = [ ifexists nofail ] }",
            "  { name = libpipewire-module-protocol-native }",
            "  { name = libpipewire-module-client-node }",
            "  { name = libpipewire-module-adapter }",
            "  { name = libpipewire-module-filter-chain",
            "    args = {",
            `      node.description = "${desc}"`,
            `      media.name = "${desc}"`,
            "      audio.channels = 2",
            "      audio.position = [ FL FR ]",
            "      filter.graph = {",
            "        nodes = [",
            ...nodes.map(n => "          " + n),
            "        ]",
            "        links = [",
            ...links.map(l => "          " + l),
            "        ]",
            `        inputs = [ "prel:In" "prer:In" ]`,
            `        outputs = [ ${outputs} ]`,
            "      }",
            `      capture.props = { node.name = "cove_fx_sink" media.class = Audio/Sink filter.smart = true filter.smart.name = "cove-fx-output" }`,
            `      playback.props = { node.name = "cove_fx_out" node.passive = true stream.dont-remix = true }`,
            "    }",
            "  }",
            "]",
            ""
        ].join("\n");
    }

    readonly property string micSig: `cove-mic 1 ns=${s.micNoise} agc=${s.micGain} hp=${s.micHighpass}`
    function micConf(): string {
        return [
            "# " + micSig,
            "# Сгенерировано Cove (services/SoundFx.qml), меняется в Настройки → Звук",
            "context.properties = { log.level = 0 }",
            "context.spa-libs = { audio.convert.* = audioconvert/libspa-audioconvert support.* = support/libspa-support }",
            "context.modules = [",
            "  { name = libpipewire-module-rt args = { nice.level = -11 } flags = [ ifexists nofail ] }",
            "  { name = libpipewire-module-protocol-native }",
            "  { name = libpipewire-module-client-node }",
            "  { name = libpipewire-module-adapter }",
            "  { name = libpipewire-module-echo-cancel",
            "    args = {",
            "      library.name = aec/libspa-aec-webrtc",
            "      monitor.mode = true",
            "      audio.channels = 1",
            "      audio.position = [ MONO ]",
            `      aec.args = { webrtc.noise_suppression = ${s.micNoise} webrtc.gain_control = ${s.micGain} webrtc.high_pass_filter = ${s.micHighpass} webrtc.extended_filter = true webrtc.delay_agnostic = true }`,
            `      capture.props = { node.name = "cove_mic_capture" node.passive = true }`,
            `      sink.props = { node.name = "cove_mic_ref" }`,
            `      source.props = { node.name = "cove_mic" node.description = "${I18n.tr("Микрофон Cove")}" filter.smart = true filter.smart.name = "cove-fx-mic" }`,
            "    }",
            "  }",
            "]",
            ""
        ].join("\n");
    }

    // ---------- юниты ----------
    // start: пишет конфиг и (пере)запускает юнит; ensure: запускает, только если юнит не тот
    function unitCmd(unit: string, path: string, conf: string, sig: string, force: bool): var {
        return ["sh", "-c", `mkdir -p "$(dirname "$2")"
            if [ "$5" != 1 ] && systemctl --user is-active --quiet "$1" && grep -qxF "# $4" "$2" 2>/dev/null; then exit 3; fi
            printf '%s' "$3" > "$2"
            systemctl --user stop "$1" 2>/dev/null; systemctl --user reset-failed "$1" 2>/dev/null
            exec systemd-run --user --quiet --collect --unit="$1" -p Restart=on-failure -p RestartSec=2 pipewire -c "$2"`,
            "_", unit, path, conf, sig, force ? "1" : "0"];
    }
    function stopCmd(unit: string): var { return ["sh", "-c", `systemctl --user stop "$1" 2>/dev/null; systemctl --user reset-failed "$1" 2>/dev/null; true`, "_", unit]; }

    property string runningOutSig: ""
    property string runningMicSig: ""

    Process {
        id: outProc
        property bool pushAfter: false
        onExited: code => {
            // 3 — юнит уже работает с этой структурой: значит, параметры надо догнать на лету
            if (code === 3 || pushAfter) push.restart();
            pushAfter = false;
        }
    }
    Process { id: micProc }

    function applyOut(force: bool): void {
        if (!checked) return;
        if (!s.enabled) {
            if (runningOutSig !== "off") { runningOutSig = "off"; outProc.command = stopCmd(outUnit); outProc.running = true; }
            return;
        }
        if (outProc.running) { outRetry.restart(); return; }
        if (force || runningOutSig !== outSig) {
            const first = runningOutSig === "";
            runningOutSig = outSig;
            // первый раз после старта шелла: юнит мог пережить перезапуск — не трогаем, если он тот же
            outProc.command = unitCmd(outUnit, dir + "/output.conf", outConf(), outSig, !first);
            outProc.running = true;
        } else {
            push.restart();
        }
    }
    function applyMic(): void {
        if (!checked) return;
        if (!s.mic) {
            if (runningMicSig !== "off") { runningMicSig = "off"; micProc.command = stopCmd(micUnit); micProc.running = true; }
            return;
        }
        if (micProc.running) { micRetry.restart(); return; }
        if (runningMicSig === micSig) return;
        const first = runningMicSig === "";
        runningMicSig = micSig;
        micProc.command = unitCmd(micUnit, dir + "/mic.conf", micConf(), micSig, !first);
        micProc.running = true;
    }
    Timer { id: outRetry; interval: 150; onTriggered: root.applyOut(false) }
    Timer { id: micRetry; interval: 150; onTriggered: root.applyMic() }

    // живые параметры: пачкой не чаще ~25 раз в секунду
    readonly property var fxNode: Pipewire.nodes.values.find(n => n.name === "cove_fx_sink") ?? null
    Timer {
        id: push
        interval: 40
        onTriggered: {
            if (!root.fxNode) return;
            if (setter.running) { restart(); return; }
            const body = root.outParams().map(([k, v]) => `"${k}" ${root.num(v)}`).join(" ");
            setter.command = ["pw-cli", "set-param", String(root.fxNode.id), "Props", `{ params = [ ${body} ] }`];
            setter.running = true;
        }
    }
    Process { id: setter }

    readonly property string outState: JSON.stringify([s.enabled, bands, s.preamp, s.bass, s.loudness, s.loudnessLevel, s.limiter, lsp])
    readonly property string micState: JSON.stringify([s.mic, micSig])
    onOutStateChanged: debounceOut.restart()
    onMicStateChanged: debounceMic.restart()
    Timer { id: debounceOut; interval: 30; onTriggered: root.applyOut(false) }
    Timer { id: debounceMic; interval: 200; onTriggered: root.applyMic() }

    // ---------- проверка окружения ----------
    Process {
        id: probe
        command: ["sh", "-c", `for d in /usr/lib/lv2 /usr/local/lib/lv2 "$HOME/.lv2" /usr/lib64/lv2; do
                [ -f "$d/lsp-plugins.lv2/limiter_stereo.ttl" ] && [ -f "$d/lsp-plugins.lv2/autogain_stereo.ttl" ] && { echo lsp; break; }; done
            pgrep -x easyeffects >/dev/null && echo ee-running
            [ -f "$HOME/.config/easyeffects/db/equalizerrc" ] || ls "$HOME"/.local/share/easyeffects/output/*.json >/dev/null 2>&1 \
                || ls "$HOME"/.config/easyeffects/output/*.json >/dev/null 2>&1 && echo ee-data
            true`]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.split("\n");
                root.lsp = t.includes("lsp");
                root.eeRunning = t.includes("ee-running");
                root.eeData = t.includes("ee-data");
                if (!root.checked) {
                    root.checked = true;
                    root.applyOut(false);
                    root.applyMic();
                }
            }
        }
    }
    function init(): void { probe.running = true; }
    function recheck(): void { probe.running = true; }

    // EasyEffects перетаскивает все потоки на свой синк — с ним фильтры Cove не работают
    function quitEasyEffects(): void {
        Quickshell.execDetached(["sh", "-c", "easyeffects -q 2>/dev/null; sleep 1; pkill -x easyeffects; true"]);
        eeRunning = false;
        recheckLater.restart();
    }
    Timer { id: recheckLater; interval: 2500; onTriggered: root.recheck() }

    // ---------- импорт из EasyEffects ----------
    property var imported: []   // [{ name, bands, preamp, skipped: [названия эффектов, которых нет в Cove] }]
    property bool importing: false
    property bool importAndTake: false
    Process {
        id: importer
        command: ["python3", Quickshell.shellPath("assets/sound/ee-import.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.importing = false;
                try { root.imported = JSON.parse(text); } catch (e) { root.imported = []; }
                if (root.importAndTake && root.imported.length) root.takeImported(root.imported[0]);
                root.importAndTake = false;
            }
        }
    }
    function scanEasyEffects(): void { importing = true; importer.running = true; }
    function takeImported(p): void {
        const all = Settings.copy(s.presets ?? {});
        let name = p.name, n = 2;
        while (builtin.some(b => b.label === name) || (all[name] && JSON.stringify(all[name].bands) !== JSON.stringify(p.bands))) name = `${p.name} ${n++}`;
        all[name] = { bands: p.bands, preamp: p.preamp ?? 0, bass: 0 };
        s.presets = all;
        load(name);
    }

    IpcHandler {
        target: "sound"
        function status(): string {
            return JSON.stringify({ enabled: root.s.enabled, preset: root.s.preset, modified: root.modified, bands: root.bands.length,
                lsp: root.lsp, node: root.fxNode?.id ?? -1, sig: root.runningOutSig, mic: root.s.mic, micSig: root.runningMicSig });
        }
        function toggle(): void { root.s.enabled = !root.s.enabled; }
        function preset(id: string): void { root.load(id); }
        function mic(): void { root.s.mic = !root.s.mic; }
        // взять текущий эквалайзер EasyEffects как набор (без окна настроек)
        function importEasyEffects(): void { root.importAndTake = true; root.scanEasyEffects(); }
        function restart(): void { root.applyOut(true); root.runningMicSig = ""; root.applyMic(); }
    }
}
