import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Лаунчер: ящик слева/справа или карточка по центру — вид в Settings.launcher (Настройки → Лаунчер).
// Префиксы:
//   =  калькулятор     /  файлы в ~     >  команда в терминале
//   ?  поиск в сети    :  история буфера обмена   #  действия
//   !  быстрые поиски (!yt котики)     @  открытые окна
//   *  ассистент (провайдер — Настройки → Лаунчер → Ассистент)
Drawer {
    id: root
    screen: Panels.screen   // монитор с фокусом в момент открытия

    readonly property var look: Settings.launcher
    side: look.position
    drawerWidth: look.width
    drawerHeight: look.height
    centerOffset: Math.round((screen?.height ?? 1080) * 0.12)
    grabKeyboard: true
    anim: look.anim
    background: look.background
    layerName: "qs-launcher"
    open: Panels.launcher
    onCloseRequested: Panels.launcher = false

    onOpenChanged: if (open) {
        search.text = Panels.launcherQuery;
        Panels.launcherQuery = "";
        list.currentIndex = 0;
        grid.currentIndex = 0;
        search.forceActiveFocus();
        clipProc.running = true;
    }

    Connections {
        target: Panels
        function onLauncherTyped(text: string): void { search.text = text; search.cursorPosition = text.length; }
        function onLauncherRun(): void { root.activate(root.current); }
    }

    readonly property string query: search.text
    readonly property string prefix: "=/>?:#!@;+<*".includes(query.charAt(0)) ? query.charAt(0) : ""
    readonly property string term: (prefix ? query.slice(1) : query).trim()
    // сетка — только для приложений; калькулятор, файлы и прочее всегда списком
    readonly property bool gridMode: look.layout === "grid" && prefix === ""
    readonly property int current: gridMode ? grid.currentIndex : list.currentIndex
    readonly property bool compact: look.density === "compact"

    property var files: []
    property var clips: []

    function greeting(): string {
        const h = new Date().getHours();
        if (h < 5) return I18n.tr("Доброй ночи");
        if (h < 12) return I18n.tr("Доброе утро");
        if (h < 18) return I18n.tr("Добрый день");
        return I18n.tr("Добрый вечер");
    }

    // ---- источники результатов ----
    function score(e, q: string): int {
        const name = (e.name ?? "").toLowerCase();
        if (name.startsWith(q)) return 100;
        if (name.split(/[\s\-_.]/).some(w => w.startsWith(q))) return 80;
        if (name.includes(q)) return 60;
        const extra = [e.genericName, e.comment, ...(e.keywords ?? []), e.id].join(" ").toLowerCase();
        if (extra.includes(q)) return 30;
        return look.fuzzy && subseq(q, name) ? 20 : 0;   // «ffx» → Firefox
    }

    // все буквы запроса встречаются в имени по порядку
    function subseq(q: string, s: string): bool {
        let i = 0;
        for (const ch of s) { if (ch === q[i]) i++; if (i === q.length) return true; }
        return q.length === 0;
    }

    function launch(e): void {
        const c = Object.assign({}, Store.launches ?? {});
        c[e.id] = (c[e.id] ?? 0) + 1;
        Store.launches = c;
        const t = Object.assign({}, Store.launchedAt ?? {});
        t[e.id] = Date.now();
        Store.launchedAt = t;
        e.execute();
    }

    function appItem(e): var {
        return {
            icon: Quickshell.iconPath(e.icon, "application-x-executable"),
            title: e.name,
            subtitle: e.comment || e.genericName || "",
            app: e.id,
            run: () => launch(e)
        };
    }

    function apps(q: string): var {
        const counts = Store.launches ?? {}, when = Store.launchedAt ?? {}, hidden = look.hidden ?? [];
        // порядок при равной релевантности: частые / по алфавиту / недавние
        const order = (a, b) => look.sort === "alpha" ? a.e.name.localeCompare(b.e.name)
            : look.sort === "recent" ? ((when[b.e.id] ?? 0) - (when[a.e.id] ?? 0)) || a.e.name.localeCompare(b.e.name)
            : (Math.min(b.c, 40) - Math.min(a.c, 40)) || a.e.name.localeCompare(b.e.name);
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && !hidden.includes(e.id))
            .map(e => ({ e, s: q === "" ? 1 : score(e, q), c: counts[e.id] ?? 0 }))
            .filter(x => x.s > 0)
            .sort((a, b) => (b.s - a.s) || order(a, b))
            .map(x => appItem(x.e));
    }

    // закреплённые (строка сверху при пустом поиске)
    readonly property var favApps: {
        const all = DesktopEntries.applications.values;
        return (look.pinned ?? []).map(id => all.find(e => e.id === id)).filter(e => !!e);
    }
    function togglePin(id: string): void {
        const p = look.pinned ?? [];
        look.pinned = p.includes(id) ? p.filter(x => x !== id) : [...p, id];
    }
    function hideApp(id: string): void {
        look.hidden = [...(look.hidden ?? []), id];
        look.pinned = (look.pinned ?? []).filter(x => x !== id);
    }

    // !yt котики → поиск на YouTube; !y — подсказки по ключам
    function bangResults(t: string): var {
        const parts = t.split(/\s+/);
        const key = (parts.shift() ?? "").toLowerCase(), q = parts.join(" ");
        const list = look.bangs ?? [];
        const exact = list.find(b => b.key === key);
        if (exact && (q || t.endsWith(" ")))
            return [{ glyph: "travel_explore", title: q || exact.name, subtitle: q ? I18n.tr("Искать в ") + exact.name : I18n.tr("Введите запрос"),
                run: () => { if (q) Qt.openUrlExternally(exact.url.replace("%s", encodeURIComponent(q))); } }];
        const found = list.filter(b => key === "" || b.key.startsWith(key) || b.name.toLowerCase().includes(key));
        if (found.length === 0) return [{ glyph: "travel_explore", title: I18n.tr("Нет такого поиска: !") + key, subtitle: I18n.tr("Свои поиски — Настройки → Лаунчер") }];
        return found.map(b => ({ glyph: "travel_explore", title: "!" + b.key + "   " + b.name, subtitle: I18n.tr("Быстрый поиск"), keep: true,
            run: () => { search.text = "!" + b.key + " "; } }));
    }

    // @ — переключиться на открытое окно
    function windowResults(t: string): var {
        const q = t.toLowerCase();
        return Hyprland.toplevels.values
            .filter(w => (w.title ?? "").toLowerCase().includes(q) || (w.lastIpcObject?.class ?? "").toLowerCase().includes(q))
            .map(w => {
                const app = w.wayland?.appId || w.lastIpcObject?.class || "";
                const e = app ? DesktopEntries.heuristicLookup(app) : null;
                return {
                    icon: Quickshell.iconPath(e?.icon ?? app, "application-x-executable"),
                    title: w.title || app,
                    subtitle: (e?.name ?? app) + (w.workspace ? I18n.tr(" · воркспейс ") + w.workspace.id : ""),
                    run: () => Hypr.focusWindow(w.address)
                };
            });
    }

    function calc(q: string): var {
        if (q === "") return [{ glyph: "calculate", title: I18n.tr("Калькулятор и конвертер"), subtitle: I18n.tr("Например: =2^10, =15%*3400, =100 usd в руб, =5 km в mi, =30 c в f") }];
        const conv = Convert.convert(q);
        if (conv) return [{ glyph: "currency_exchange", title: conv.text, subtitle: (conv.note ? conv.note + " · " : "") + I18n.tr("Enter — скопировать"),
            run: () => { if (isFinite(conv.value)) Quickshell.execDetached(["wl-copy", String(Math.round(conv.value * 1e6) / 1e6)]); } }];
        const allowed = /^[0-9+\-*/().,%^\s]*(?:(?:sqrt|sin|cos|tan|log|ln|abs|round|floor|ceil|pi|e)[0-9+\-*/().,%^\s]*)*$/i;
        if (!allowed.test(q)) return [{ glyph: "󰃬", title: I18n.tr("Не понимаю выражение"), subtitle: q }];
        try {
            const js = q.replace(/,/g, ".").replace(/\^/g, "**").replace(/(\d+(?:\.\d+)?)%/g, "($1/100)")
                .replace(/\bln\b/gi, "Math.log").replace(/\blog\b/gi, "Math.log10")
                .replace(/\b(sqrt|sin|cos|tan|abs|round|floor|ceil)\b/gi, m => "Math." + m.toLowerCase())
                .replace(/\bpi\b/gi, "Math.PI").replace(/\be\b/gi, "Math.E");
            const v = Function(`"use strict"; return (${js});`)();
            if (typeof v !== "number" || !isFinite(v)) throw 0;
            const s = String(Math.round(v * 1e10) / 1e10);
            return [{ glyph: "󰃬", title: s, subtitle: I18n.tr("Enter — скопировать"), run: () => Quickshell.execDetached(["wl-copy", s]) }];
        } catch (e) {
            return [{ glyph: "󰃬", title: "…", subtitle: q }];
        }
    }

    // командная палитра: действия шелла, разделы настроек, профили
    function palette(q: string): var {
        const out = [];
        for (const a of Actions.list) {
            if (a.arg && !["special"].includes(a.arg)) continue;
            out.push({ glyph: a.icon, title: a.label, subtitle: a.group, key: a.label + " " + a.group, run: () => Actions.run(a.id, "") });
        }
        const pages = [["appearance", I18n.tr("Оформление")], ["profiles", I18n.tr("Профили")], ["bar", I18n.tr("Панель")], ["island", I18n.tr("Остров")], ["launcher", I18n.tr("Лаунчер")], ["firefox", "Firefox"], ["windows", I18n.tr("Окна")],
            ["binds", I18n.tr("Хоткеи")], ["rules", I18n.tr("Правила окон")], ["input", I18n.tr("Ввод")], ["notifications", I18n.tr("Уведомления")], ["wallpaper", I18n.tr("Обои")],
            ["desktop", I18n.tr("Рабочий стол")], ["system", I18n.tr("Система")], ["autostart", I18n.tr("Автозапуск")], ["dotfiles", I18n.tr("Дотфайлы")], ["about", I18n.tr("О системе")]];
        for (const [id, label] of pages)
            out.push({ glyph: "󰒓", title: I18n.tr("Настройки: ") + label, subtitle: I18n.tr("Открыть раздел"), key: I18n.tr("настройки ") + label, run: () => Panels.openSettings(id) });
        for (const name of [...Object.keys(Profiles.presets), ...Object.keys(Settings.profiles ?? {})])
            out.push({ glyph: "󰏘", title: I18n.tr("Профиль: ") + name, subtitle: I18n.tr("Применить стиль"), key: I18n.tr("профиль тема стиль ") + name, run: () => Profiles.applyNamed(name) });
        out.push({ glyph: "󰒭", title: I18n.tr("Следующие обои"), subtitle: I18n.tr("Случайные из папки"), key: I18n.tr("обои следующие"), run: () => Wallpapers.next() });
        const f = q.toLowerCase();
        return f === "" ? out : out.filter(x => x.key.toLowerCase().includes(f) || x.title.toLowerCase().includes(f));
    }

    function command(q: string): var {
        return [{
            glyph: "", title: q === "" ? I18n.tr("Команда в терминале") : q,
            subtitle: q === "" ? I18n.tr("Например: >htop") : I18n.tr("Выполнить в {0}", Settings.general.terminal),
            run: () => { if (q) Quickshell.execDetached([Settings.general.terminal, "--hold", "sh", "-c", q]); }
        }];
    }

    function web(q: string): var {
        return [{
            glyph: "󰖟", title: q === "" ? I18n.tr("Поиск в интернете") : q, subtitle: "DuckDuckGo",
            run: () => { if (q) Qt.openUrlExternally("https://duckduckgo.com/?q=" + encodeURIComponent(q)); }
        }];
    }

    function fileResults(): var {
        if (term === "") return [{ glyph: "󰈞", title: I18n.tr("Поиск файлов и папок в домашней папке"), subtitle: I18n.tr("Например: /отчёт · ПКМ — открыть папку с файлом") }];
        return files.map(f => {
            const dir = f.endsWith("/"), path = dir ? f.slice(0, -1) : f;   // fd помечает папки косой чертой
            const parent = path.slice(0, path.lastIndexOf("/")) || "/";
            return {
                glyph: dir ? "folder" : "draft",
                title: path.split("/").pop(),
                subtitle: parent.replace(Settings.home, "~"),
                run: () => Qt.openUrlExternally("file://" + path),
                alt: () => { Qt.openUrlExternally("file://" + parent); Panels.launcher = false; }
            };
        });
    }

    function clipResults(): var {
        const q = term.toLowerCase();
        const pins = Store.pinnedClips ?? [];
        const pinned = pins.filter(t => t.toLowerCase().includes(q)).map(t => ({
            glyph: "󰐃", title: t.replace(/\s+/g, " ").slice(0, 120), subtitle: I18n.tr("Закреплено · ПКМ — открепить"),
            run: () => Quickshell.execDetached(["wl-copy", t]),
            alt: () => { Store.pinnedClips = pins.filter(x => x !== t); }
        }));
        const items = clips.filter(c => c.type === "img" ? q === "" || I18n.tr("картинка изображение image").includes(q) : c.text.toLowerCase().includes(q))
            .filter(c => !pins.includes(c.text))
            .slice(0, 80).map(c => c.type === "img" ? {
                image: "file://" + c.text, title: I18n.tr("Изображение ") + (c.size || ""), subtitle: I18n.tr("Enter — в буфер · Delete — удалить"),
                run: () => Quickshell.execDetached(["sh", "-c", `cliphist decode ${c.id} | wl-copy`]),
                del: () => root.clipDelete(c.id)
            } : {
                glyph: "󰅌", title: c.text.trim().slice(0, 400), lines: 3,
                subtitle: I18n.tr("Enter — в буфер · ПКМ — закрепить · Delete — удалить"),
                run: () => Quickshell.execDetached(["sh", "-c", `cliphist decode ${c.id} | wl-copy`]),
                alt: () => { Store.pinnedClips = [c.text, ...pins].slice(0, 30); },
                del: () => root.clipDelete(c.id)
            });
        return [...pinned, ...items];
    }

    // убрать запись из истории буфера (Delete) / всю историю (Shift+Delete); закреплённое остаётся
    function clipDelete(id: string): void {
        clips = clips.filter(c => c.id !== id);
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "_", id]);
    }
    function clipWipe(): void {
        clips = [];
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf "${XDG_RUNTIME_DIR:-/tmp}/qs-clip"']);
    }

    // ; — эмодзи (assets/emoji.json: символ, английское имя, русские слова)
    property var emoji: []
    function emojiResults(q: string): var {
        if (!emoji.length) emojiFile.reload();
        const f = q.toLowerCase();
        const list = f === "" ? emoji.slice(0, 60)
            : emoji.filter(e => e[1].includes(f) || e[2].includes(f)).slice(0, 60);
        return list.map(e => ({ glyph: e[0], title: e[2] ? e[2].split(" ")[0] : e[1], subtitle: e[1] + I18n.tr(" · Enter — скопировать"),
            run: () => Quickshell.execDetached(["wl-copy", e[0]]) }));
    }
    FileView {
        id: emojiFile
        path: Quickshell.shellPath("assets/emoji.json")
        onLoaded: { try { root.emoji = JSON.parse(text()); } catch (e) {} }
    }

    // + — таймер: «+5m чай», «+1:30», «+25»
    function timerResults(q: string): var {
        const c = Timers.parseCommand(q);
        const out = [];
        if (c.seconds > 0)
            out.push({ glyph: "timer", title: I18n.tr("Таймер на {0}", Timers.human(c.seconds)) + (c.label ? " · " + c.label : ""),
                subtitle: I18n.tr("Enter — запустить"), run: () => Timers.start(c.seconds, c.label) });
        else
            out.push({ glyph: "timer", title: I18n.tr("Таймер"), subtitle: I18n.tr("Например: +5m чай, +1h30m, +25:00, +10") });
        for (const t of Timers.timers)
            out.push({ glyph: t.left !== undefined ? "pause_circle" : "hourglass_top", title: (t.label || I18n.tr("Таймер")) + " · " + Timers.format(Timers.remaining(t)),
                subtitle: I18n.tr("Enter — пауза · ПКМ — отменить"), keep: true, run: () => Timers.togglePause(t.id), alt: () => Timers.cancel(t.id) });
        return out;
    }

    // < — история и закладки Firefox
    property var history: []
    function historyResults(): var {
        if (term === "") return [{ glyph: "history", title: I18n.tr("История Firefox"), subtitle: I18n.tr("Например: <github") }];
        return history.map(h => ({ glyph: h.bookmark ? "bookmark" : "history", title: h.title || h.url, subtitle: h.url.replace(/^https?:\/\//, ""),
            run: () => Qt.openUrlExternally(h.url) }));
    }
    Timer {
        id: historyDebounce
        interval: 150
        onTriggered: if (root.prefix === "<" && root.term !== "") historyProc.running = true
    }
    // places.sqlite открыт Firefox'ом — читаем в режиме immutable, без блокировок
    Process {
        id: historyProc
        command: ["sh", "-c", 'db=$(ls -t "$HOME"/.config/mozilla/firefox/*/places.sqlite "$HOME"/.mozilla/firefox/*/places.sqlite 2>/dev/null | head -1)
            [ -n "$db" ] || exit 0
            q=$(printf %s "$1" | sed "s/\x27/\x27\x27/g")
            sqlite3 -separator "\t" "file:$db?immutable=1" "SELECT p.url, replace(coalesce(p.title, \x27\x27), char(9), \x27 \x27), (SELECT count(*) FROM moz_bookmarks b WHERE b.fk = p.id) FROM moz_places p WHERE p.hidden = 0 AND (p.title LIKE \x27%$q%\x27 OR p.url LIKE \x27%$q%\x27) ORDER BY p.frecency DESC LIMIT 40"',
            "_", root.term]
        stdout: StdioCollector {
            onStreamFinished: root.history = text.split("\n").filter(s => s).map(l => {
                const [url, title, bm] = l.split("\t");
                return { url, title, bookmark: Number(bm) > 0 };
            }).filter(h => /^https?:/.test(h.url))
        }
    }

    readonly property var results: {
        switch (prefix) {
        case "=": return calc(term);
        case ">": return command(term);
        case "?": return web(term);
        case "/": return fileResults();
        case ":": return clipResults();
        case "#": return palette(term);
        case "!": return bangResults(query.slice(1));
        case "@": return windowResults(term);
        case ";": return emojiResults(term);
        case "+": return timerResults(term);
        case "<": return historyResults();
        case "*": return [];   // свой вид — AssistantView
        default: return apps(term.toLowerCase());
        }
    }

    function activate(i: int): void {
        if (prefix === "*") {
            if (term !== "" && !Assistant.busy) { Assistant.ask(term); search.text = "*"; }
            return;
        }
        const r = results[i];
        if (!r || !r.run) return;
        r.run();
        if (!r.keep) Panels.launcher = false;
    }

    // поиск файлов с задержкой, чтобы не дёргать fd на каждую букву
    Timer {
        id: fileDebounce
        interval: 180
        onTriggered: if (root.prefix === "/" && root.term !== "") fileProc.running = true
    }
    onTermChanged: {
        if (prefix === "/") fileDebounce.restart();
        if (prefix === "<") historyDebounce.restart();
    }

    Process {
        id: fileProc
        command: ["fd", "-i", "-t", "f", "-t", "d", "--max-results", "50", "--exclude", ".git", "--exclude", "node_modules", root.term, Settings.home]
        stdout: StdioCollector { onStreamFinished: root.files = text.split("\n").filter(s => s !== "") }
    }

    Process {
        id: clipProc
        command: [Quickshell.shellPath("assets/clip-list.sh")]
        stdout: StdioCollector {
            onStreamFinished: root.clips = text.split("\n").filter(s => s !== "").map(l => {
                const [id, type, value, size] = l.split("\t");
                return { id, type, text: value ?? "", size: size ?? "" };
            })
        }
    }

    // ---- вид ----
    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 12
        spacing: 12

        // шапка: приветствие / часы / погода + подсказка префиксов
        RowLayout {
            Layout.fillWidth: true
            visible: root.look.header !== "none" || root.look.hints
            SystemClock { id: clock; precision: SystemClock.Minutes }
            StyledText {
                visible: root.look.header === "greeting"
                text: `${root.greeting()}, ${Settings.displayName}`
                font.pixelSize: Theme.fontSizeLarge + 2
                font.bold: true
            }
            RowLayout {
                visible: root.look.header === "clock"
                spacing: 10
                StyledText { text: Qt.formatDateTime(clock.date, "HH:mm"); font.pixelSize: Theme.fontSizeLarge + 6; font.bold: true }
                StyledText { text: I18n.locale.toString(clock.date, "dddd, d MMMM"); color: Theme.subtext0 }
            }
            RowLayout {
                visible: root.look.header === "weather"
                spacing: 8
                MIcon { icon: Weather.icon; color: Theme.accent; size: Theme.iconSize + 4 }
                StyledText { text: Weather.ready ? Math.round(Weather.temp) + "°" : "—"; font.pixelSize: Theme.fontSizeLarge + 2; font.bold: true }
                StyledText { text: Weather.ready ? Weather.description : ""; color: Theme.subtext0 }
            }
            Item { Layout.fillWidth: true }
            StyledText {
                visible: root.look.hints
                text: "= / > ? : # ! @ ; + < *"
                color: Theme.overlay0
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // место для поиска сверху (или снизу — bottomSlot в конце)
        Item {
            id: topSlot
            Layout.fillWidth: true
            implicitHeight: root.look.searchPos === "bottom" ? 0 : 46
            visible: implicitHeight > 0
        }

        Rectangle {
            id: searchBox
            parent: root.look.searchPos === "bottom" ? bottomSlot : topSlot
            anchors.fill: parent
            readonly property string st: root.look.searchStyle
            radius: Theme.radius
            color: st === "filled" ? Theme.mantle : "transparent"
            border.color: Theme.accent
            border.width: st === "filled" ? 1 : 0

            // стиль «линия»: только черта под полем
            Rectangle {
                visible: searchBox.st === "line"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                radius: 1
                color: search.activeFocus ? Theme.accent : Theme.surface1
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: searchBox.st === "filled" ? 14 : 4
                anchors.rightMargin: 14
                spacing: 10

                MIcon {
                    icon: ({ "=": "calculate", "/": "folder_open", ">": "terminal", "?": "language", ":": "content_paste",
                             "#": "bolt", "!": "travel_explore", "@": "select_window", ";": "mood", "+": "timer", "<": "history", "*": "auto_awesome" })[root.prefix] ?? "search"
                    color: Theme.accent
                    size: 18
                }

                TextField {
                    id: search
                    Layout.fillWidth: true
                    placeholderText: root.look.placeholder || I18n.tr("Приложения, =расчёт, /файлы, >команда, !поиск, @окна, :буфер, ;эмодзи, +таймер, <история, *ассистент")
                    placeholderTextColor: Theme.overlay0
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    background: null
                    onTextChanged: { list.currentIndex = 0; grid.currentIndex = 0; }

                    Keys.onEscapePressed: Panels.launcher = false
                    Keys.onDownPressed: root.gridMode ? grid.moveCurrentIndexDown() : list.incrementCurrentIndex()
                    Keys.onUpPressed: root.gridMode ? grid.moveCurrentIndexUp() : list.decrementCurrentIndex()
                    Keys.onTabPressed: root.gridMode ? grid.moveCurrentIndexRight() : list.incrementCurrentIndex()
                    Keys.onBacktabPressed: root.gridMode ? grid.moveCurrentIndexLeft() : list.decrementCurrentIndex()
                    // в сетке ←/→ листают, когда курсор в конце строки
                    Keys.onRightPressed: e => { if (root.gridMode && cursorPosition === text.length) grid.moveCurrentIndexRight(); else e.accepted = false; }
                    Keys.onLeftPressed: e => { if (root.gridMode && cursorPosition === text.length) grid.moveCurrentIndexLeft(); else e.accepted = false; }
                    // буфер: Delete в конце строки — убрать запись, Shift+Delete — очистить историю
                    Keys.onDeletePressed: e => {
                        if (root.prefix !== ":" || cursorPosition !== text.length) { e.accepted = false; return; }
                        if (e.modifiers & Qt.ShiftModifier) root.clipWipe();
                        else root.results[list.currentIndex]?.del?.();
                    }
                    Keys.onReturnPressed: root.activate(root.current)
                    Keys.onEnterPressed: root.activate(root.current)
                }
            }
        }

        // избранное: закреплённые приложения крупно, при пустом поиске
        Flow {
            Layout.fillWidth: true
            visible: root.look.favorites && root.query === "" && root.favApps.length > 0
            spacing: 6
            Repeater {
                model: root.favApps
                Rectangle {
                    id: fav
                    required property var modelData
                    width: 76
                    height: 74
                    radius: Theme.radius
                    color: favMouse.containsMouse ? Theme.surface0 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        implicitSize: 36
                        source: Quickshell.iconPath(fav.modelData.icon, "application-x-executable")
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 50
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: fav.modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: favMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: m => {
                            if (m.button === Qt.RightButton) root.showMenu(fav.modelData.id, mapToItem(col, m.x, m.y));
                            else { root.launch(fav.modelData); Panels.launcher = false; }
                        }
                    }
                }
            }
        }

        AssistantView {
            visible: root.prefix === "*"
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        ListView {
            id: list
            visible: !root.gridMode && root.prefix !== "*"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            // выделение: bar — заливка и полоса акцента, fill — заливка, outline — рамка, zoom — заливка + крупнее значок
            highlight: Rectangle {
                radius: Theme.radiusSmall
                color: root.look.highlight === "outline" ? "transparent" : Theme.surface0
                border.width: root.look.highlight === "outline" ? 1 : 0
                border.color: Theme.accent
                Rectangle {
                    visible: root.look.highlight === "bar"
                    width: 3
                    height: parent.height - 16
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 2
                    color: Theme.accent
                }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                // картинки из буфера — крупным превью, длинный текст — до трёх строк
                height: row.modelData.image ? 108
                    : Math.max(root.compact ? Math.max(36, root.look.iconSize + 8) : Math.max(50, root.look.iconSize + 18), texts.implicitHeight + 16)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        visible: !!row.modelData.image
                        implicitWidth: 160
                        implicitHeight: 92
                        radius: Theme.radiusSmall
                        color: Theme.crust
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: row.modelData.image ?? ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(320, 184)
                        }
                    }
                    Item {
                        visible: !row.modelData.image
                        implicitWidth: row.modelData.icon?.startsWith?.("file://") ? root.look.iconSize * 2 : root.look.iconSize
                        scale: root.look.highlight === "zoom" && row.ListView.isCurrentItem ? 1.18 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                        implicitHeight: root.look.iconSize
                        IconImage {
                            anchors.fill: parent
                            visible: !!row.modelData.icon
                            source: row.modelData.icon ?? ""
                        }
                        MIcon {
                            anchors.centerIn: parent
                            visible: !row.modelData.icon
                            icon: row.modelData.glyph ?? ""
                            color: Theme.accent
                            size: Math.round(root.look.iconSize * 0.62)
                        }
                    }

                    ColumnLayout {
                        id: texts
                        Layout.fillWidth: true
                        spacing: 1
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            color: row.ListView.isCurrentItem ? Theme.accent : Theme.text
                            elide: Text.ElideRight
                            wrapMode: row.modelData.lines ? Text.Wrap : Text.NoWrap
                            maximumLineCount: row.modelData.lines ?? 1
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text !== "" && root.look.descriptions && !root.compact
                            text: row.modelData.subtitle ?? ""
                            color: Theme.overlay1
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideMiddle
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: list.currentIndex = row.index
                    onClicked: m => {
                        if (m.button === Qt.RightButton) {
                            if (row.modelData.app) root.showMenu(row.modelData.app, mapToItem(col, m.x, m.y));
                            else { row.modelData.alt?.(); clipProc.running = true; }
                        }
                        else root.activate(row.index);
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: I18n.tr("Ничего не найдено")
                color: Theme.overlay0
            }
        }

        GridView {
            id: grid
            visible: root.gridMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.gridMode ? root.results : []
            readonly property int cols: Math.max(3, Math.floor(width / (root.look.iconSize * 1.6 + 56)))
            cellWidth: Math.floor(width / cols)
            cellHeight: root.look.iconSize * 1.3 + (root.compact ? 34 : 50)
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 120
            highlight: Rectangle {
                radius: Theme.radius
                color: root.look.highlight === "outline" ? "transparent" : Theme.surface0
                border.width: root.look.highlight === "fill" ? 0 : 1
                border.color: Theme.alpha(Theme.accent, 0.6)
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    spacing: 6
                    IconImage {
                        Layout.alignment: Qt.AlignHCenter
                        scale: root.look.highlight === "zoom" && cell.GridView.isCurrentItem ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutBack } }
                        implicitSize: Math.round(root.look.iconSize * 1.3)
                        source: cell.modelData.icon ?? ""
                    }
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.title
                        color: cell.GridView.isCurrentItem ? Theme.accent : Theme.text
                        font.pixelSize: Theme.fontSizeSmall + 1
                        elide: Text.ElideRight
                        maximumLineCount: root.compact ? 1 : 2
                        wrapMode: Text.Wrap
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: grid.currentIndex = cell.index
                    onClicked: m => {
                        if (m.button === Qt.RightButton && cell.modelData.app) root.showMenu(cell.modelData.app, mapToItem(col, m.x, m.y));
                        else root.activate(cell.index);
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: I18n.tr("Ничего не найдено")
                color: Theme.overlay0
            }
        }

        // место для поиска снизу
        Item {
            id: bottomSlot
            Layout.fillWidth: true
            implicitHeight: root.look.searchPos === "bottom" ? 46 : 0
            visible: implicitHeight > 0
        }
    }

    // ---- правый клик по приложению: закрепить / скрыть ----
    property string menuApp: ""
    function showMenu(id: string, pos): void {
        menuApp = id;
        appMenu.x = Math.min(pos.x, col.width - appMenu.width);
        appMenu.y = Math.min(pos.y, col.height - appMenu.implicitHeight);
        appMenu.open();
    }

    Popup {
        id: appMenu
        parent: col
        width: 220
        padding: 6
        background: Rectangle {
            radius: Theme.radius
            color: Theme.mantle
            border.width: 1
            border.color: Theme.surface1
        }
        readonly property bool pinned: (root.look.pinned ?? []).includes(root.menuApp)
        contentItem: Column {
            spacing: 2
            Repeater {
                model: [
                    { icon: appMenu.pinned ? "keep_off" : "keep", label: appMenu.pinned ? I18n.tr("Открепить") : I18n.tr("Закрепить сверху"), act: () => root.togglePin(root.menuApp) },
                    { icon: "open_in_new", label: I18n.tr("Запустить"), act: () => {
                        const e = DesktopEntries.applications.values.find(x => x.id === root.menuApp);
                        if (e) { root.launch(e); Panels.launcher = false; } } },
                    { icon: "visibility_off", label: I18n.tr("Скрыть из списка"), act: () => root.hideApp(root.menuApp) }
                ]
                Rectangle {
                    id: mi
                    required property var modelData
                    width: 208
                    height: 34
                    radius: Theme.radiusSmall
                    color: miMouse.containsMouse ? Theme.surface0 : "transparent"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        spacing: 10
                        MIcon { icon: mi.modelData.icon; color: Theme.accent; size: 16; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: mi.modelData.label; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: miMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { appMenu.close(); mi.modelData.act(); }
                    }
                }
            }
        }
    }
}
