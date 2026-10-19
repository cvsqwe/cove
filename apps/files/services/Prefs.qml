pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.kit

// Настройки Cove Files (~/.local/state/cove/files.json): вид, сортировка, скрытые файлы.
Singleton {
    id: root
    property bool ready: false
    property alias view: data.view               // grid | list
    property alias iconSize: data.iconSize       // размер значков в сетке
    property alias showHidden: data.showHidden
    property alias sortBy: data.sortBy           // name | mtime | size | type
    property alias sortDesc: data.sortDesc
    property alias foldersFirst: data.foldersFirst
    property alias sidebarWidth: data.sidebarWidth
    property alias info: data.info               // панель сведений справа
    property alias perFolder: data.perFolder     // путь → {view, sortBy, sortDesc}
    property alias winW: data.winW
    property alias winH: data.winH

    FileView {
        path: Cove.stateDir + "/files.json"
        blockLoading: true
        onAdapterUpdated: if (loaded) writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); root.ready = true; }
        JsonAdapter {
            id: data
            property string view: "grid"
            property int iconSize: 96
            property bool showHidden: false
            property string sortBy: "name"
            property bool sortDesc: false
            property bool foldersFirst: true
            property int sidebarWidth: 210
            property bool info: false
            property var perFolder: ({})
            property int winW: 1100
            property int winH: 680
        }
    }
}
