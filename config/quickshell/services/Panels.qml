pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Какие панели/ящики открыты. Одновременно открыт максимум один.
// Снаружи: `qs ipc call <имя> toggle`.
Singleton {
    id: root

    property real islandWidth: 200   // ширина свёрнутого острова — заголовок окна в баре не залезает под него
    property bool launcher: false
    property bool control: false
    property bool overview: false
    property bool wallpaper: false
    property bool session: false
    property bool dashboard: false
    property bool notes: false
    property bool cheatsheet: false
    property string launcherQuery: "" // текст, с которым откроется лаунчер (например ":" — буфер)

    // переключение окон в обзоре (Super+Tab): первое нажатие открывает, следующие двигают выделение
    property bool overviewSwitch: false
    signal overviewStep(int d)
    function overviewNext(d: int): void {
        if (overview) { overviewStep(d); return; }
        closeAll();
        overviewSwitch = true;
        overview = true;
    }

    property string controlPage: "" // подстраница центра управления: bluetooth | wifi | audio
    function openControl(page: string): void { const was = control && controlPage === page; closeAll(); controlPage = page; control = !was; }

    signal settingsRequested(string page)
    // ввод в уже открытый лаунчер из скриптов: qs ipc call launcher type "=2+2"; launcher run — как Enter
    signal launcherTyped(string text)
    signal launcherRun()
    function openSettings(page: string): void { closeAll(); settingsRequested(page); }

    readonly property var names: ["launcher", "control", "overview", "wallpaper", "session", "dashboard", "notes", "cheatsheet"]

    function closeAll(): void {
        for (const n of names) root[n] = false;
    }

    function toggle(name: string): void {
        const v = !root[name];
        closeAll();
        root[name] = v;
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle("launcher"); }
        function clipboard(): void { root.launcherQuery = ":"; root.toggle("launcher"); }
        function palette(): void { root.launcherQuery = "#"; root.toggle("launcher"); }
        function assistant(): void { root.launcherQuery = "*"; root.toggle("launcher"); }
        function type(text: string): void { if (root.launcher) root.launcherTyped(text); }
        function run(): void { if (root.launcher) root.launcherRun(); }
        function search(q: string): void { root.launcherQuery = q; root.launcher = false; root.toggle("launcher"); }   // qs ipc call launcher search "!yt "
    }
    IpcHandler {
        target: "control"
        function toggle(): void { root.toggle("control"); }
        function open(page: string): void { root.openControl(page); }
    }
    IpcHandler {
        target: "overview"
        function toggle(): void { root.overviewSwitch = false; root.toggle("overview"); }
        function next(): void { root.overviewNext(1); }
        function prev(): void { root.overviewNext(-1); }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle("wallpaper"); }
        function set(path: string): void { Wallpapers.set(path); }   // qs ipc call wallpaper set ~/Wallpapers/…
        function next(): void { Wallpapers.next(); }
        function current(): string { return Store.wallpaper; }
    }
    IpcHandler { target: "session";   function toggle(): void { root.toggle("session"); } }
    IpcHandler { target: "dashboard"; function toggle(): void { root.toggle("dashboard"); } }
    IpcHandler { target: "notes"; function toggle(): void { root.toggle("notes"); } }
    IpcHandler { target: "cheatsheet"; function toggle(): void { root.toggle("cheatsheet"); } }
}
