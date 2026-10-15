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
        }
    }
}
