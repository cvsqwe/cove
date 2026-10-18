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
    property alias launcher: data.launcher
    property alias firefox: data.firefox
    property alias terminal: data.terminal
    property alias windows: data.windows
    property alias input: data.input
    property alias notifications: data.notifications
    property alias wallpaper: data.wallpaper
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

    FileView {
        id: file
        path: Quickshell.shellPath("settings.json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // до первой загрузки не пишем: иначе при старте умолчания затирают файл
        onAdapterUpdated: if (loaded) writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); root.ready = true; }

        JsonAdapter {
            id: data

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
            }

            property JsonObject appearance: JsonObject {
                property string palette: "wallpaper" // wallpaper | catppuccin | custom
                property string customAccent: "#cba6f7"
                property bool coverAccent: false     // перекрашивать систему в цвет обложки трека
                property bool light: false
                property real saturation: 1.0
                property real tint: 1.0              // насколько поверхности окрашены в акцент
                property real panelOpacity: 1.0
                property string font: "Adwaita Sans"   // интерфейс; иконки Nerd Font подхватываются фолбэком
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
                property var right: ["tray", "updates", "sysmon", "weather", "layout", "network", "bluetooth", "volume", "notifs"]
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
                property bool privacyToast: true       // тост, когда приложение включает микрофон/камеру/экран
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

            property JsonObject idle: JsonObject {
                property int lockMinutes: 10
                property int dpmsMinutes: 15
                property int suspendMinutes: 0
            }

            property JsonObject nightLight: JsonObject {
                property int temperature: 4300
                property bool schedule: false
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
