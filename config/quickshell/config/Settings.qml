pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Все настройки окружения: ~/.config/quickshell/settings.json.
// Меняются из окна «Настройки» (Super+,), файл можно править и руками — изменения подхватываются сразу.
Singleton {
    id: root

    // файл читается асинхронно: до ready свойства содержат умолчания (см. shell.qml)
    property bool ready: false
    property alias general: data.general
    property alias appearance: data.appearance
    property alias bar: data.bar
    property alias island: data.island
    property alias displays: data.displays
    property alias launcher: data.launcher
    property alias assistant: data.assistant
    property alias firefox: data.firefox
    property alias terminal: data.terminal
    property alias apps: data.apps
    property alias windows: data.windows
    property alias input: data.input
    property alias notifications: data.notifications
    property alias wallpaper: data.wallpaper
    property alias sound: data.sound
    property alias power: data.power
    property alias vpn: data.vpn
    property alias idle: data.idle
    property alias nightLight: data.nightLight
    property alias focus: data.focus
    property alias desktop: data.desktop
    property alias dotfiles: data.dotfiles
    property alias binds: data.binds
    property alias rules: data.rules
    property alias autostart: data.autostart
    property alias profiles: data.profiles

    readonly property string home: Quickshell.env("HOME")
    function expand(p: string): string { return (p ?? "").replace(/^~/, home); }
    readonly property string displayName: general.name !== "" ? general.name : Quickshell.env("USER")

    // для массивов/объектов: присваиваем копию, чтобы сработали уведомления об изменении
    function copy(v): var { return JSON.parse(JSON.stringify(v)); }

    Timer {
        id: saveDelay
        interval: 100
        onTriggered: file.writeAdapter()
    }

    // Версия схемы settings.json. Переименовали настройку или поменяли её смысл — поднимите
    // schemaVersion и добавьте шаг в migrations. Шаг получает сырой JSON из файла (старые ключи
    // ещё в нём: адаптер неизвестные ключи отбрасывает) и сам Settings, куда пишет новые значения.
    // Пример: 2: (raw, s) => { if (raw.bar?.oldName !== undefined) s.bar.newName = raw.bar.oldName; }
    readonly property int schemaVersion: 1
    readonly property var migrations: ({})
    function migrate(): void {
        if (data.schema >= schemaVersion) return;
        let raw = {};
        try { raw = JSON.parse(file.text()); } catch (e) {}
        for (let v = data.schema + 1; v <= schemaVersion; v++) {
            // не вызывать migrations[v] опционально прямо по ключу: такой вызов роняет движок QML (Qt 6.12)
            try { const step = migrations[v]; if (step) step(raw, root); } catch (e) { console.warn("Settings: миграция", v, "не удалась:", e); }
        }
        data.schema = schemaVersion;
        saveDelay.restart();   // изменение внутри onLoaded само запись не запускает
    }

    FileView {
        id: file
        path: Quickshell.shellPath("settings.json")
        blockLoading: true
        watchChanges: true
        // пока своя запись в очереди, файл не перечитываем: иначе он откатит ещё не записанные поля
        onFileChanged: if (!saveDelay.running) reload()
        // до первой загрузки не пишем: иначе при старте умолчания затирают файл.
        // Пачка изменений подряд (город + широта + долгота) пишется одним разом: раньше каждое поле
        // писало файл, слежение перечитывало промежуточную версию и откатывало соседние поля.
        onAdapterUpdated: if (loaded) saveDelay.restart()
        onLoaded: { root.migrate(); root.ready = true; }
        // нового файла нет — пишем умолчания сразу с текущей версией схемы
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) { data.schema = root.schemaVersion; writeAdapter(); } root.ready = true; }

        JsonAdapter {
            id: data

            // версия схемы; у старых файлов без неё — 0 (см. migrate)
            property int schema: 0

            property JsonObject general: JsonObject {
                property string language: "auto"     // ru | en | auto (по $LANG)
                property string name: ""
                property string avatar: ""
                property string city: "Москва"
                property real latitude: 55.7558
                property real longitude: 37.6173
                property string terminal: "kitty"
                property string browser: "firefox"
                property string fileManager: "kitty -e yazi"
                property string editor: "code"
                property bool sounds: true
                property real soundVolume: 0.6
                property string soundSet: "cove"     // cove | soft | glass | retro (assets/sounds)
                property bool weather: true
                property var calendars: []           // ICS-подписки: ссылки или пути к .ics
                property int calendarRemind: 10      // напоминание за N минут (0 — не напоминать)
                property int clipClearSeconds: 30    // очищать скопированный пароль через N секунд (0 — нет)
                property string polkitStyle: "center" // center | island — где появляется запрос прав
                property bool polkit: true           // свой агент polkit (запрос прав root); выкл — hyprpolkitagent
                property bool screenTime: true       // экранное время: сколько времени в каких приложениях (services/ScreenTime.qml)
            }

            property JsonObject appearance: JsonObject {
                property string palette: "wallpaper" // wallpaper | custom | ключ из config/Palettes.qml (catppuccin, gruvbox, nord…)
                property string scheme: "tonal"      // для обоев/своего цвета: tonal | vibrant | muted | neutral | contrast | expressive
                property bool harmonize: false       // смысловые цвета (красный, зелёный…) чуть сдвинуты к оттенку акцента
                property var overrides: ({})          // свои цвета поверх палитры: { accent: "#…", base: "#…", … }
                property string customAccent: "#cba6f7"
                property bool coverAccent: false     // перекрашивать систему в цвет обложки трека
                property bool light: false
                property string themeMode: "manual"   // manual | sun (светлая от восхода до заката) | schedule
                property string lightFrom: "07:00"    // для schedule: светлая с … до …
                property string lightTo: "20:00"
                property real saturation: 1.0
                property real tint: 1.0              // насколько поверхности окрашены в акцент
                property real panelOpacity: 1.0
                property string material: "solid"    // solid | glass | frosted | acrylic — фон панелей, острова, ящиков
                property int borderWidth: 1          // обводка панелей и карточек: 0 | 1 | 2
                property real shadow: 1.0            // сила теней: 0 — без теней
                property string font: "Adwaita Sans"   // интерфейс; иконки Nerd Font подхватываются фолбэком
                property string fontHeading: ""      // крупный текст (заголовки, часы, числа от 20 px); пусто — как интерфейс
                property string density: "normal"    // compact | normal | comfy — высота строк, плиток и капсул
                property string iconStyle: "rounded" // rounded | outlined | sharp — набор Material Symbols
                property bool iconFill: false        // все значки залитые
                property int iconWeight: 400         // толщина линий значков: 200…700
                // компоненты (Оформление → Компоненты)
                property string tileStyle: "tiles"   // Центр управления: tiles | round | list
                property string tileOn: "fill"       // включённая плитка: fill | tint | outline
                property string osdStyle: "slider"   // громкость/яркость: slider | ring | minimal
                property string notifStyle: "normal" // уведомление в острове: compact | normal | rich
                property string lockStyle: "center"  // экран блокировки: center | side | minimal | poster
                property int fontSize: 13
                property int radius: 14
                property int frameRadius: 18
                property int barHeight: 36
                property bool frame: true            // вогнутые углы-рамка у краёв экрана
                property bool animations: true
                property bool splash: true           // заставка Cove при входе в систему
                property real animSpeed: 1.0
                property real springiness: 0.32      // демпфирование острова: меньше — пружинистее
                property string iconTheme: "breeze-dark"
                property string cursorTheme: "Adwaita"
                property int cursorSize: 24
            }

            property JsonObject bar: JsonObject {
                property var left: ["launcher", "workspaces", "window"]
                property var right: ["tray", "updates", "sysmon", "weather", "layout", "network", "bluetooth", "volume", "battery", "vpn", "notifs"]
                property int workspaces: 5
                property string workspaceStyle: "pills" // pills | dots | lines | squares | numbers | kanji | roman | icons
                property bool workspaceOccupiedOnly: false
                property string workspaceActive: "accent"  // accent | text
                property bool visualizerStrip: true
                property string style: "floating"  // docked — сросшаяся с краем | floating — плавающая полоса
                // стиль (пресеты — services/BarStyles.qml); цвета и размеры всегда из темы
                property string capsules: "groups"    // none | groups | each
                property string capsuleFill: "dark"   // dark | light | outline
                property string shape: "round"        // round | soft
                property real bodyOpacity: 1.0        // фон панели; 0 — без полосы, только капсулы
                property string iconColors: "mono"    // mono | accent | colorful
                property bool separators: false       // точки между модулями (без капсул)
                property string labels: "hover"      // hover | always — по умолчанию только значки, подпись при наведении
                property string launcherStyle: "icon"     // icon | text | both
                property string launcherText: "Cove"
                property string launcherColor: "accent"   // accent | mono
                property string launcherAction: "launcher" // launcher | control | overview
                property string launcherIcon: "cove"
            }

            // вид лаунчера (пресеты — services/LauncherStyles.qml)
            property JsonObject launcher: JsonObject {
                property string position: "left"   // left | right | center
                property string layout: "list"     // list | grid — для приложений
                property string density: "normal"  // normal | compact
                property int iconSize: 32
                property bool descriptions: true
                property bool greeting: true
                property int width: 560
                property int height: 540
                // оформление
                property string background: "solid"  // solid | glass | wallpaper
                property string searchPos: "top"     // top | bottom
                property string searchStyle: "filled" // filled | line | bare
                property string placeholder: ""      // пусто — подсказка по умолчанию
                property string highlight: "bar"     // bar | fill | outline | zoom
                property string header: "greeting"   // greeting | clock | weather | none
                property string anim: "slide"        // slide | grow | fade
                property bool dim: false             // затемнять экран вокруг
                property bool hints: true            // подсказка префиксов
                // содержимое и поведение
                property bool favorites: true        // строка закреплённых сверху
                property var pinned: []              // id закреплённых приложений
                property var hidden: []              // id скрытых приложений
                property string sort: "frequent"     // frequent | alpha | recent
                property bool fuzzy: true            // «ffx» найдёт Firefox
                property var bangs: [
                    { key: "yt", name: "YouTube", url: "https://www.youtube.com/results?search_query=%s" },
                    { key: "g", name: "Google", url: "https://www.google.com/search?q=%s" },
                    { key: "d", name: "DuckDuckGo", url: "https://duckduckgo.com/?q=%s" },
                    { key: "w", name: "Википедия", url: "https://ru.wikipedia.org/w/index.php?search=%s" },
                    { key: "gh", name: "GitHub", url: "https://github.com/search?q=%s" },
                    { key: "aur", name: "AUR", url: "https://aur.archlinux.org/packages?K=%s" },
                    { key: "aw", name: "ArchWiki", url: "https://wiki.archlinux.org/index.php?search=%s" },
                    { key: "tr", name: "Переводчик", url: "https://translate.google.com/?sl=auto&tl=ru&text=%s" }
                ]
            }

            // ассистент в лаунчере (префикс *): assets/assistant.py; ключ API — отдельным файлом, не здесь
            property JsonObject assistant: JsonObject {
                property string provider: "claude"   // claude (Claude Code) | anthropic | openai | ollama | off
                property string model: ""            // пусто — модель провайдера по умолчанию
                property string baseUrl: ""          // для openai-совместимых и Ollama; пусто — стандартный адрес
            }

            // вид Firefox в стиле шелла (services/FirefoxLook.qml, assets/firefox/)
            property JsonObject firefox: JsonObject {
                property string layout: "floating"   // floating | oneline | island | vertical | classic
                property bool menus: true            // меню и панели в стиле шелла
                property bool cleanNewtab: true      // новая вкладка без рекламы, виджетов и рекомендаций
                property bool startpage: true        // своя стартовая страница как домашняя
                property string engine: "https://www.google.com/search?q=%s"
                property var links: [
                    { name: "YouTube", url: "https://www.youtube.com" },
                    { name: "GitHub", url: "https://github.com" },
                    { name: "ВКонтакте", url: "https://vk.com" },
                    { name: "Telegram", url: "https://web.telegram.org" },
                    { name: "Википедия", url: "https://ru.wikipedia.org" },
                    { name: "Reddit", url: "https://www.reddit.com" }
                ]
            }

            // Перекраска сторонних приложений движком тем (assets/theme/cove-theme.py)
            property JsonObject apps: JsonObject {
                property var off: []                  // id целей, которые не трогаем (gtk, qt, telegram…)
            }
            property JsonObject terminal: JsonObject {
                property string font: "JetBrainsMono Nerd Font"
                property real fontSize: 11.5
                property int padding: 10
                property real opacity: 0.94
                property string cursor: "beam"       // beam | block | underline
                property bool cursorBlink: true
                property string tabs: "powerline"    // powerline | slant | separator | fade | hidden
                property bool greeting: true         // fastfetch в первом окне за сессию
            }

            property JsonObject island: JsonObject {
                property string idle: "clock"        // clock | weather | greeting
                property string clockFormat: "HH:mm"
                property string dateFormat: "ddd, d MMMM"
                property bool showDate: true
                property bool visualizer: true
                property bool osd: true
                property int notifTimeout: 6
                property bool workspaceToast: true
                property bool layoutToast: true
                property bool capsToast: true
                property bool screenshotPreview: true
                property bool screenshotEditor: true   // сразу открывать satty после снимка
                property bool peek: true               // раскрываться при наведении: плеер и быстрые действия
                property bool greeting: true
                property bool agenda: true             // ближайшее событие календаря в капсуле
                property bool media: true              // плеер (трек, обложка) в капсуле — выключить, например, для записи экрана
                property bool lyrics: true             // текст песни в капсуле вместо названия (LRCLIB)
                property bool privacyToast: true       // тост, когда приложение включает микрофон/камеру/экран
                property bool shelf: true              // полка: бросить файл на капсулу, потом утащить куда нужно
                property bool shelfRemove: true        // убирать с полки то, что утащили (иначе — только при «Переместить»)
                property int shelfMax: 30
            }

            property JsonObject displays: JsonObject {
                // свои настройки мониторов; пусто — как решит Hyprland (и ~/.config/hypr/monitors.lua)
                // [{ key: "desc:…" | имя выхода, name, enabled, mode: "1920x1080@144", x, y, scale, transform, vrr, mirror }]
                property var monitors: []
                property string primary: ""          // имя выхода: виджеты рабочего стола, заставка; пусто — первый
                property string bars: "all"          // all | primary — где панель и остров
            }

            property JsonObject windows: JsonObject {
                property int gapsIn: 5
                property int gapsOut: 10
                property int borderSize: 2
                property bool borderGradient: true
                property int rounding: 12
                property bool blur: true
                property int blurSize: 6
                property int blurPasses: 3
                property bool shadow: true
                property int shadowRange: 18
                property real activeOpacity: 1.0
                property real inactiveOpacity: 1.0
                property bool dimInactive: false
                property real dimStrength: 0.15
                property bool glow: false
                property string layout: "dwindle"     // dwindle | master | scrolling
                property string animation: "popin"    // popin | slide | gnomed | fade
                property bool gameMode: true          // авто-режим для полноэкранных игр
            }

            property JsonObject input: JsonObject {
                property var layouts: ["us", "ru"]
                property string switchKey: "grp:alt_shift_toggle"
                property int repeatDelay: 600
                property int repeatRate: 25
                property real sensitivity: 0
                property string accel: "adaptive"     // adaptive | flat
                property bool naturalScroll: false
                property int followMouse: 1
                // тачпад (ноутбук)
                property bool tapToClick: true
                property bool tpNatural: true         // естественная прокрутка на тачпаде (отдельно от мыши)
                property bool tpTyping: true          // выключать тачпад, пока печатаете
                property bool tpClickfinger: true     // правый клик — двумя пальцами, а не углом
                property real tpScroll: 1.0           // скорость прокрутки
                property bool gestures: true          // три пальца влево-вправо — воркспейсы
            }

            property JsonObject notifications: JsonObject {
                property var dndAllow: []            // кого пропускать в «Не беспокоить» (заголовок или приложение)
                property var muted: []                // приложения без всплывашек
                property bool dndSchedule: false
                property string dndFrom: "23:00"
                property string dndTo: "08:00"
            }

            property JsonObject wallpaper: JsonObject {
                property string dir: "~/Wallpapers"
                property string mode: "fixed"         // fixed | time | workspace | slideshow
                property string day: ""
                property string night: ""
                property string dayStart: "08:00"
                property string nightStart: "20:00"
                property var perWorkspace: ({})
                property int slideshowMinutes: 30
                property string transition: "grow"    // grow | fade | wipe | outer | wave | random
                property bool blurWindows: false      // размывать обои, когда на воркспейсе есть окна
                property bool liveSound: false        // звук у видеообоев
            }

            // звуковые эффекты (services/SoundFx.qml): свой filter-chain PipeWire вместо EasyEffects
            property JsonObject sound: JsonObject {
                property bool enabled: false          // эффекты на выходе
                property var bands: []                // [{ f, g, q, type: bell|lowshelf|highshelf|lowpass|highpass|notch }]; пусто — 10 полос по нулям
                property real preamp: 0               // дБ перед эквалайзером
                property real bass: 0                 // подъём баса, дБ (полка 100 Гц)
                property bool loudness: false         // выравнивание громкости (LSP autogain)
                property real loudnessLevel: -18      // целевая громкость, LUFS
                property bool limiter: true           // защита от перегруза (LSP limiter, −1 дБ)
                property string preset: "flat"        // выбранный набор: id встроенного или имя своего
                property var presets: ({})            // свои наборы: имя → { bands, preamp, bass }
                property var devices: ({})            // выход (node.name) → набор, который на нём выбирали
                property bool mic: false              // обработка микрофона (WebRTC)
                property bool micNoise: true          // шумоподавление
                property bool micGain: false          // автогромкость
                property bool micHighpass: true       // срез гула и низких
            }

            // свой VPN на ядре Mihomo (services/Vpn.qml, assets/vpn/vpn.py)
            property JsonObject vpn: JsonObject {
                property var sources: []              // [{ name, url } | { name, path }, enabled]
                property string route: "ru"           // ru — российские сайты напрямую | all — всё через VPN
                property var direct: []               // свои домены «всегда напрямую»
                property bool autoConnect: false      // подключаться при входе
            }

            // питание (services/Power.qml)
            property JsonObject power: JsonObject {
                property int saverAt: 20              // от батареи на N % и ниже — режим экономии (0 — не включать)
            }

            property JsonObject idle: JsonObject {
                property int lockMinutes: 10
                property int dpmsMinutes: 15
                property int suspendMinutes: 0
            }

            property JsonObject nightLight: JsonObject {
                property string antiFlash: "off"      // защита от вспышки: off | weak | strong (assets/shaders, screen_shader)
                property int temperature: 4300
                property bool schedule: false
                property bool bySun: false            // расписание — от заката до восхода (services/Sun.qml)
                property string from: "21:00"
                property string to: "07:00"
            }

            property JsonObject focus: JsonObject {
                property int work: 25
                property int shortBreak: 5
                property bool dnd: true
            }

            property JsonObject desktop: JsonObject {
                property bool enabled: true
                property bool snap: true             // привязка к сетке в редакторе
                property var widgets: [
                    { "type": "clock", "x": 80, "y": 120, "enabled": true },
                    { "type": "sysmon", "x": 80, "y": 330, "enabled": false },
                    { "type": "media", "x": 80, "y": 520, "enabled": false },
                    { "type": "notes", "x": 1480, "y": 120, "enabled": false }
                ]
            }

            property JsonObject dotfiles: JsonObject {
                property string repo: "~/Dotfiles"
                property string remote: ""
            }

            property var binds: []      // заполняются стандартными при первом запуске (services/Binds.qml)
            property var rules: []
            property var autostart: []
            property var profiles: ({})
        }
    }
}
