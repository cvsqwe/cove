import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Выбор обоев — ящик, поднимающийся от нижнего края. Super+W.
// ←/→ — выбор, Enter — применить, Esc — закрыть. Палитра перестраивается сама.
PanelWindow {
    id: win
    screen: Panels.screen   // монитор с фокусом в момент открытия

    readonly property bool open: Panels.wallpaper
    readonly property int drawerHeight: 250

    // вкладки по подпапкам ~/Wallpapers; "" — все
    property string folder: ""
    readonly property string root: Settings.expand(Settings.wallpaper.dir).replace(/\/$/, "") + "/"
    function folderOf(f: string): string { const r = f.startsWith(root) ? f.slice(root.length) : f; const i = r.indexOf("/"); return i > 0 ? r.slice(0, i) : ""; }
    readonly property var folders: [...new Set(Wallpapers.files.map(f => folderOf(f)).filter(s => s !== ""))].sort()
    readonly property var shown: folder === "" ? Wallpapers.files : Wallpapers.files.filter(f => folderOf(f) === folder)
    function cycleFolder(d: int): void {
        const all = ["", ...folders];
        folder = all[(all.indexOf(folder) + d + all.length) % all.length];
        list.currentIndex = Math.max(0, shown.indexOf(Store.wallpaper));
    }

    anchors.bottom: true
    implicitWidth: 1240 + Theme.frameRadius * 2
    implicitHeight: drawerHeight + 4
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || drawer.height > 0.5
    mask: Region { item: drawer }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onOpenChanged: if (open) {
        Wallpapers.refresh();
        list.currentIndex = Math.max(0, win.shown.indexOf(Store.wallpaper));
        list.forceActiveFocus();
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: Panels.wallpaper = false
    }

    Rectangle {
        id: drawer
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - Theme.frameRadius * 2
        height: win.open ? win.drawerHeight : 0
        color: Theme.panel
        topLeftRadius: Theme.radius + 6
        topRightRadius: Theme.radius + 6
        clip: true
        Behavior on height { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutExpo } }

        StyledText {
            x: 20
            y: 14
            text: I18n.tr("Обои")
            font.bold: true
        }
        StyledText {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 14
            text: win.shown.length + I18n.tr(" шт. · ↑↓ — папки")
            color: Theme.overlay1
            font.pixelSize: Theme.fontSizeSmall
        }

        // вкладки папок: по центру, а если не влезают между заголовком и счётчиком — листаются колесом
        Flickable {
            id: tabsView
            x: Math.max(90, (parent.width - width) / 2)
            y: 10
            width: Math.min(tabsRow.implicitWidth, parent.width - 90 - 190)
            height: 26
            contentWidth: tabsRow.implicitWidth
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                onWheel: e => tabsView.contentX = Math.max(0, Math.min(tabsView.contentWidth - tabsView.width, tabsView.contentX - (e.angleDelta.y || e.angleDelta.x)))
            }
        Row {
            id: tabsRow
            spacing: 4
            Repeater {
                model: ["", ...win.folders]
                Rectangle {
                    id: tab
                    required property string modelData
                    readonly property bool active: win.folder === modelData
                    width: tabText.implicitWidth + 22
                    height: 26
                    radius: 13
                    color: active ? Theme.accent : tabMouse.containsMouse ? Theme.surface0 : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    StyledText {
                        id: tabText
                        anchors.centerIn: parent
                        text: tab.modelData === "" ? I18n.tr("Все") : tab.modelData
                        color: tab.active ? Theme.onAccent : Theme.subtext0
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: tab.active
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.folder = tab.modelData; list.currentIndex = Math.max(0, win.shown.indexOf(Store.wallpaper)); list.forceActiveFocus(); }
                    }
                }
            }
        }
        }

        ListView {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            height: 180
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            model: win.shown
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: width / 2 - 150
            preferredHighlightEnd: width / 2 + 150
            highlightMoveDuration: 220

            Keys.onEscapePressed: Panels.wallpaper = false
            Keys.onReturnPressed: Wallpapers.set(win.shown[currentIndex])
            Keys.onEnterPressed: Wallpapers.set(win.shown[currentIndex])
            Keys.onUpPressed: win.cycleFolder(-1)
            Keys.onDownPressed: win.cycleFolder(1)

            delegate: Rectangle {
                id: thumb
                required property string modelData
                required property int index
                readonly property bool current: Store.wallpaper === modelData
                readonly property bool selected: ListView.isCurrentItem

                width: 300
                height: 170
                anchors.verticalCenter: parent?.verticalCenter
                radius: Theme.radius
                color: Theme.surface0
                scale: selected ? 1.0 : 0.92
                Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

                Image {
                    anchors.fill: parent
                    anchors.margins: 3
                    source: "file://" + Wallpapers.thumbOf(thumb.modelData)
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: thumb.selected ? 3 : thumb.current ? 2 : 0
                    border.color: thumb.selected ? Theme.accent : Theme.surface2
                }

                // видеообои — значок «живые»
                Rectangle {
                    visible: Store.isVideo(thumb.modelData)
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    width: liveRow.implicitWidth + 14
                    height: 24
                    radius: 12
                    color: Theme.alpha(Theme.crust, 0.75)
                    Row {
                        id: liveRow
                        anchors.centerIn: parent
                        spacing: 4
                        MIcon { anchors.verticalCenter: parent.verticalCenter; icon: "play_circle"; fill: true; size: 13; color: Theme.accent }
                        StyledText { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("живые"); font.pixelSize: Theme.fontSizeSmall }
                    }
                }

                Rectangle {
                    visible: thumb.current
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    width: 26
                    height: 26
                    radius: 13
                    color: Theme.accent
                    MIcon { anchors.centerIn: parent; icon: "󰄬"; color: Theme.crust }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = thumb.index
                    onClicked: Wallpapers.set(thumb.modelData)
                }
            }
        }
    }

    InvertedCorner {
        anchors.bottom: parent.bottom
        x: drawer.x - radius
        radius: Math.min(Theme.frameRadius, drawer.height)
        visible: drawer.height > 0.5
        corner: "bottomRight"
        color: Theme.panel
    }
    InvertedCorner {
        anchors.bottom: parent.bottom
        x: drawer.x + drawer.width
        radius: Math.min(Theme.frameRadius, drawer.height)
        visible: drawer.height > 0.5
        corner: "bottomLeft"
        color: Theme.panel
    }
}
