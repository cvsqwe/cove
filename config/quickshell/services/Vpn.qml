pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Свой VPN на ядре Mihomo (Clash Meta), без сторонних программ.
// Конфиг пишет assets/vpn/vpn.py (подписки → proxy-providers, TUN, DNS, правила),
// ядро — системная служба cove-vpn@<пользователь> (system/vpn/install.sh: ставится один раз через polkit,
// дальше включается без пароля). Управление — Clash API на 127.0.0.1:9097 с секретом.
Singleton {
    id: root

    readonly property var s: Settings.vpn
    readonly property string user: Quickshell.env("USER")
    readonly property string unit: `cove-vpn@${user}.service`
    readonly property string api: "http://127.0.0.1:9097"
    readonly property string group: "VPN"
    readonly property string auto: "Авто"
    readonly property string testUrl: "https://www.gstatic.com/generate_204"
    readonly property string dir: Settings.home + "/.local/state/cove/vpn"

    // ---- установка ----
    property bool probed: false
    property bool hasCore: false       // /usr/bin/mihomo (AUR: mihomo-bin)
    property bool hasUnit: false       // служба и правило polkit
    readonly property bool ready: hasCore && hasUnit
    property bool prizrak: false       // запущен Prizrak-Box — два TUN мешают друг другу
    property bool installing: false

    // ---- состояние ----
    property string state: "off"       // off | starting | on | stopping | error
    property string error: ""
    readonly property bool on: state === "on"
    readonly property bool busy: state === "starting" || state === "stopping"
    property string secret: ""

    property var servers: []           // имена в группе VPN (первым — «Авто»)
    readonly property bool noServers: on && refreshed && servers.filter(n => n !== auto).length === 0
    property bool refreshed: false
    property bool updating: false      // подписки перекачиваются
    property string now: ""            // выбранный в группе VPN
    property string autoNow: ""        // кого сейчас выбрал «Авто»
    property var delays: ({})          // имя → мс (0 — не ответил)
    property bool testing: false
    readonly property string current: now === auto ? autoNow : now
    property real up: 0                // байт/с
    property real down: 0
    property var where: null           // { ip, country, code, flag }

    readonly property bool hasSources: (s.sources ?? []).some(x => x.enabled !== false)

    function fmtSpeed(b: real): string {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + I18n.tr(" МБ/с");
        if (b >= 1024) return Math.round(b / 1024) + I18n.tr(" КБ/с");
        return Math.round(b) + I18n.tr(" Б/с");
    }

    // ---------------- проверка установки ----------------
    function probe(): void { probeProc.running = true; }
    Process {
        id: probeProc
        command: ["sh", "-c", `bash "$(realpath "$1")/../../system/vpn/install.sh" status "$2"; pgrep -x px >/dev/null && echo prizrak=yes; systemctl is-active --quiet "$3" && echo active=yes; true`,
            "_", Quickshell.shellPath("."), root.user, root.unit]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1); }
                root.hasCore = !!kv.mihomo;
                root.hasUnit = kv.unit === "yes" && kv.rule === "yes";
                root.prizrak = kv.prizrak === "yes";
                const wasProbed = root.probed;
                root.probed = true;
                // служба уже работает (шелл перезапустили) — подхватываем
                if (kv.active === "yes" && root.state === "off") { root.state = "starting"; root.attach(); }
                else if (!wasProbed && root.s.autoConnect && root.ready && kv.active !== "yes") root.connect();
            }
        }
    }

    // ядро — из AUR в терминале (yay/paru спросят пароль сами); служба — через окно polkit Cove
    function installCore(): void {
        Quickshell.execDetached([Settings.general.terminal, "-e", "sh", Quickshell.shellPath("assets/vpn/install-core.sh")]);
        recheck.left = 0;
        recheck.restart();
    }
    function installService(): void {
        installing = true;
        installProc.running = true;
    }
    Process {
        id: installProc
        command: ["sh", "-c", `pkexec bash "$(realpath "$1")/../../system/vpn/install.sh" install "$2"`, "_", Quickshell.shellPath("."), root.user]
        stderr: StdioCollector { id: installErr }
        onExited: code => {
            root.installing = false;
            if (code !== 0 && code !== 126) root.error = installErr.text.trim() || I18n.tr("Не удалось поставить службу");
            root.probe();
        }
    }
    Timer { id: recheck; interval: 15000; repeat: true; running: false; property int left: 0
        onTriggered: { root.probe(); if (root.hasCore || ++left > 40) stop(); } }

    // ---------------- подключение ----------------
    function toggle(): void { on || state === "starting" ? disconnect() : connect(); }

    function connect(): void {
        if (busy) return;
        error = "";
        if (!ready) { error = I18n.tr("VPN ещё не установлен: Настройки → VPN"); state = "error"; return; }
        if (!hasSources) { error = I18n.tr("Добавьте подписку: Настройки → VPN"); state = "error"; return; }
        state = "starting";
        genThen(() => systemctl("start"));
    }
    function disconnect(): void {
        if (state === "off") return;
        state = "stopping";
        systemctl("stop");
    }

    // конфиг из настроек; then — что делать после удачной записи
    property var afterGen: null
    function genThen(then): void {
        afterGen = then;
        genProc.running = false;
        genProc.running = true;
    }
    Process {
        id: genProc
        command: ["sh", "-c", 'printf %s "$1" | python3 "$2" gen', "_",
            JSON.stringify({ sources: root.s.sources ?? [], route: root.s.route, direct: root.s.direct ?? [] }),
            Quickshell.shellPath("assets/vpn/vpn.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = {};
                try { d = JSON.parse(text); } catch (e) { d = { ok: false, error: text.trim() }; }
                if (!d.ok) {
                    root.error = I18n.tr("Не удалось собрать конфиг: ") + (d.error ?? "");
                    if (root.state === "starting") root.state = "error";
                    return;
                }
                root.secret = d.secret;
                const f = root.afterGen;
                root.afterGen = null;
                f?.();
            }
        }
    }

    function systemctl(verb: string): void {
        ctlProc.verb = verb;
        ctlProc.command = ["systemctl", verb, root.unit];
        ctlProc.running = true;
    }
    Process {
        id: ctlProc
        property string verb: ""
        stderr: StdioCollector { id: ctlErr }
        onExited: code => {
            if (verb === "stop") { root.reset(); root.state = "off"; return; }
            if (code !== 0) {
                root.error = ctlErr.text.trim() || I18n.tr("Служба не запустилась");
                root.state = "error";
                return;
            }
            root.attach();
        }
    }

    // ждём, пока ядро поднимет API (до ~20 с), потом — серверы, трафик, где мы
    property int attempts: 0
    function attach(): void {
        if (!secret) { secretFile.reload(); }
        attempts = 0;
        waitApi.restart();
    }
    Timer {
        id: waitApi
        interval: 700
        repeat: true
        onTriggered: {
            if (++root.attempts > 30) {
                stop();
                root.error = I18n.tr("Ядро не отвечает. Журнал: journalctl -u ") + root.unit;
                root.state = "error";
                journal.running = true;
                return;
            }
            root.call("GET", "/version", null, (d, code) => {
                if (code !== 200 || !waitApi.running) return;
                waitApi.stop();
                root.state = "on";
                root.refresh();
                root.locate();
            });
        }
    }
    Process {
        id: journal
        command: ["journalctl", "-u", root.unit, "-n", "4", "-o", "cat", "--no-pager"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.error += "\n" + text.trim().split("\n").slice(-3).join("\n") }
    }
    FileView {
        id: secretFile
        path: root.dir + "/secret"
        printErrors: false
        onLoaded: root.secret = text().trim()
    }

    function reset(): void {
        servers = []; refreshed = false; now = ""; autoNow = ""; delays = ({}); up = 0; down = 0; where = null;
    }

    // служба упала сама (или её остановили снаружи)
    Timer {
        interval: 5000
        repeat: true
        running: root.on
        onTriggered: aliveProc.running = true
    }
    Process {
        id: aliveProc
        command: ["systemctl", "is-active", "--quiet", root.unit]
        onExited: code => { if (code !== 0 && root.on) { root.reset(); root.state = "error"; root.error = I18n.tr("VPN остановился"); journal.running = true; } }
    }

    // ---------------- Clash API ----------------
    // очередь запросов: один curl за раз
    property var queue: []
    function call(method: string, path: string, body, cb): void {
        queue = [...queue, { method, path, body, cb }];
        if (!apiProc.running) pump();
    }
    function pump(): void {
        if (!queue.length) return;
        const r = queue[0];
        queue = queue.slice(1);
        apiProc.cb = r.cb;
        const args = ["curl", "-s", "-m", r.path.includes("/delay") ? "12" : "5", "-X", r.method,
            "-H", "Authorization: Bearer " + secret, "-w", "\n%{http_code}"];
        if (r.body !== null && r.body !== undefined) args.push("-H", "Content-Type: application/json", "--data", JSON.stringify(r.body));
        args.push(api + r.path);
        apiProc.command = args;
        apiProc.running = true;
    }
    Process {
        id: apiProc
        property var cb: null
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text, i = t.lastIndexOf("\n");
                const code = Number(t.slice(i + 1)) || 0;
                let d = null;
                try { d = JSON.parse(t.slice(0, i)); } catch (e) {}
                const cb = apiProc.cb;
                apiProc.cb = null;
                cb?.(d, code);
                Qt.callLater(root.pump);
            }
        }
    }

    function refresh(): void {
        call("GET", "/proxies", null, d => {
            const ps = d?.proxies ?? {};
            const g = ps[group];
            if (!g) return;
            servers = (g.all ?? []).filter(n => n !== "DIRECT" && n !== "REJECT");
            now = g.now ?? "";
            autoNow = ps[auto]?.now ?? "";
            const del = {};
            for (const n of servers) {
                const h = ps[n]?.history ?? [];
                if (h.length) del[n] = h[h.length - 1].delay ?? 0;
            }
            if (Object.keys(del).length) delays = Object.assign({}, delays, del);
            refreshed = true;
        });
    }
    // перекачать все подписки (провайдеры) и перечитать список серверов
    function updateSources(): void {
        if (!on || updating) return;
        updating = true;
        call("GET", "/providers/proxies", null, d => {
            const names = Object.keys(d?.providers ?? {}).filter(n => d.providers[n].vehicleType === "HTTP");
            if (!names.length) { updating = false; refresh(); return; }
            let left = names.length;
            for (const n of names)
                call("PUT", "/providers/proxies/" + encodeURIComponent(n), null, () => {
                    if (--left > 0) return;
                    updating = false;
                    refresh();
                });
        });
    }
    function select(name: string): void {
        call("PUT", "/proxies/" + encodeURIComponent(group), { name }, (d, code) => {
            if (code === 204 || code === 200) { now = name; locateLater.restart(); }
        });
    }
    function test(): void {
        if (!on || testing) return;
        testing = true;
        call("GET", `/group/${encodeURIComponent(group)}/delay?timeout=4000&url=${encodeURIComponent(testUrl)}`, null, d => {
            testing = false;
            const del = Object.assign({}, delays);
            for (const n of servers) if (n !== auto) del[n] = d?.[n] ?? 0;
            delays = del;
            refresh();
        });
    }
    // настройки поменялись при включённом VPN — перечитать конфиг без переподключения
    function reload(): void {
        if (!on) return;
        genThen(() => call("PUT", "/configs?force=true", { path: dir + "/config.yaml" }, () => { refresh(); locateLater.restart(); }));
    }
    readonly property string settingsKey: JSON.stringify([s.sources, s.route, s.direct])
    onSettingsKeyChanged: reloadLater.restart()
    Timer { id: reloadLater; interval: 800; onTriggered: root.reload() }

    // трафик: поток JSON-строк { up, down } раз в секунду
    Process {
        running: root.on && root.secret !== ""
        command: ["curl", "-sN", "-H", "Authorization: Bearer " + root.secret, root.api + "/traffic"]
        stdout: SplitParser {
            onRead: line => { try { const t = JSON.parse(line); root.up = t.up; root.down = t.down; } catch (e) {} }
        }
        onRunningChanged: if (!running) { root.up = 0; root.down = 0; }
    }

    // где мы для внешнего мира: IP и страна (идёт через VPN — значит, это адрес сервера)
    function locate(): void { if (on) whereProc.running = true; }
    Timer { id: locateLater; interval: 1500; onTriggered: root.locate() }
    Process {
        id: whereProc
        command: ["curl", "-s", "-m", "8", "https://ipwho.is/?fields=ip,country,country_code,flag,success"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.success !== false) root.where = { ip: d.ip ?? "", country: d.country ?? "", code: d.country_code ?? "", flag: d.flag?.emoji ?? "" };
                } catch (e) {}
            }
        }
    }

    // ---------------- импорт из Prizrak-Box ----------------
    property var found: []
    function scanPrizrak(): void { scanProc.running = true; }
    Process {
        id: scanProc
        command: ["python3", Quickshell.shellPath("assets/vpn/vpn.py"), "scan-prizrak"]
        stdout: StdioCollector { onStreamFinished: { try { root.found = JSON.parse(text); } catch (e) { root.found = []; } } }
    }
    function addSource(src): void {
        const list = Settings.copy(s.sources ?? []);
        if (list.some(x => (src.url && x.url === src.url) || (src.path && x.path === src.path))) return;
        list.push(Object.assign({ enabled: true }, src));
        s.sources = list;
    }
    function removeSource(i: int): void {
        const list = Settings.copy(s.sources ?? []);
        list.splice(i, 1);
        s.sources = list;
    }
    function setSource(i: int, patch): void {
        const list = Settings.copy(s.sources ?? []);
        Object.assign(list[i], patch);
        s.sources = list;
    }

    function init(): void { probe(); }

    IpcHandler {
        target: "vpn"
        function toggle(): void { root.toggle(); }
        function connect(): void { root.connect(); }
        function disconnect(): void { root.disconnect(); }
        function status(): string {
            return JSON.stringify({ state: root.state, error: root.error, ready: root.ready, core: root.hasCore, unit: root.hasUnit,
                prizrak: root.prizrak, server: root.current, servers: root.servers.length, where: root.where });
        }
    }
}
