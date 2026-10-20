pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Состояние, которое переживает перезапуск: обои, режим палитры, переключатели.
Singleton {
    id: root
    // файл читается асинхронно: до ready свойства содержат умолчания —
    // одноразовые действия при старте должны ждать (см. shell.qml)
    property bool ready: false
    property alias wallpaper: data.wallpaper
    property alias dnd: data.dnd
    property alias nightLight: data.nightLight
    property alias caffeine: data.caffeine
    property alias gameMode: data.gameMode
    property alias seenApps: data.seenApps // приложения, присылавшие уведомления (для настроек)
    property alias colors: data.colors     // история пипетки
    property alias pinnedClips: data.pinnedClips // закреплённое в буфере обмена
    property alias launches: data.launches
    property alias launchedAt: data.launchedAt // счётчик запусков приложений для сортировки
    property alias bindsAdded: data.bindsAdded // новые хоткеи по умолчанию, уже добавленные к своим (services/Binds.qml)
    property alias alarms: data.alarms         // будильники [{ time: "07:30", label, days: [1..7], on }]
    property alias welcomed: data.welcomed     // Cove Welcome уже показан (session/Welcome.qml)
    property alias savedProfile: data.savedProfile // режим питания до автоэкономии (services/Power.qml), -1 — нет
    property alias shelf: data.shelf           // полка острова [{ path, name, mime } | { text, name }] (services/Shelf.qml)
    property alias gameScores: data.gameScores // рекорды игр { ключ: число } (games/GamesWindow.qml)
    property alias gameSound: data.gameSound   // звуки в играх

    // Живые обои: видео показывает слой wallpaper/LiveWallpaper.qml, а всё, что берёт обои как картинку
    // (палитра, экран блокировки, превью), — кадр-постер из кэша (его готовит services/Wallpapers.qml).
    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/quickshell/wallpapers"
    function isVideo(p: string): bool { return /\.(mp4|webm|mkv|mov|m4v)$/i.test(p ?? ""); }
    function hash(s: string): string {
        let h = 5381;
        for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
        return (h >>> 0).toString(16);
    }
    function posterOf(p: string): string { return `${cacheDir}/poster-${hash(p)}.jpg`; }
    readonly property string still: isVideo(wallpaper) ? posterOf(wallpaper) : wallpaper

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/quickshell/state.json"
        blockLoading: true
        // до первой загрузки не пишем: иначе при старте умолчания затирают файл
        onAdapterUpdated: if (loaded) writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); root.ready = true; }

        JsonAdapter {
            id: data
            property string wallpaper: Quickshell.shellPath("assets/wallpapers/cove-dark.png")
            property bool dnd: false
            property bool nightLight: false
            property bool caffeine: false
            property bool gameMode: false
            property var seenApps: []
            property var colors: []
            property var pinnedClips: []
            property var launches: ({})
            property var launchedAt: ({})   // id приложения → время последнего запуска (сортировка «недавние»)
            property var alarms: []
            property var bindsAdded: []
            property var shelf: []
            property var gameScores: ({})
            property bool gameSound: true
            property bool welcomed: false
            property int savedProfile: -1
        }
    }
}
