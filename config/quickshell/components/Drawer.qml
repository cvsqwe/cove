import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.config

// Ящик, выезжающий из панели. Прижат к левому/правому краю экрана или по центру,
// с вогнутыми «наплывами» в местах стыка с панелью и краем экрана.
PanelWindow {
    id: win

    property bool open: false
    property string side: "left" // left | right | center (карточка по центру, как Spotlight)
    property int centerOffset: 0  // для center: отступ сверху от панели
    property int drawerWidth: 400
    property int drawerHeight: 400
    property bool grabKeyboard: false
    // появление: slide — выезжает (растёт высота), grow — вырастает из центра, fade — проявляется
    property string anim: "slide"
    // фон: solid — сплошной, glass — полупрозрачный с размытием обоев, wallpaper — размытая обоина
    property string background: "solid"
    property string layerName: "qs-drawer"
    default property alias content: body.data
    readonly property real progress: anim === "slide" ? drawer.height / Math.max(1, drawerHeight) : drawer.opacity

    signal closeRequested()

    anchors {
        top: true
        left: side === "left"
        right: side === "right"
    }
    // card — отдельная карточка (плавающая панель или центр), иначе ящик, сросшийся с панелью
    readonly property bool center: side === "center"
    readonly property bool card: Theme.barCards || center
    // edge — отступ от края экрана, pad — место с другой стороны (наплыв или тень)
    readonly property int edge: center ? 24 : Theme.cardMargin
    readonly property int pad: card ? 24 : Theme.frameRadius
    readonly property int top: center ? Theme.barBottom + centerOffset
        : Theme.barCards ? Theme.barBottom + Theme.cardMargin : Theme.barHeight
    implicitWidth: edge + drawerWidth + pad
    implicitHeight: top + drawerHeight + pad
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open || (anim === "slide" ? drawer.height > 0.5 : drawer.opacity > 0.01)
    WlrLayershell.namespace: layerName
    mask: Region { item: drawer }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [win]
        active: win.open
        onCleared: win.closeRequested()
    }

    RectangularShadow {
        anchors.fill: drawer
        visible: win.card && drawer.height > 1
        radius: Math.min(Theme.radius + 6, drawer.height / 2)
        offset.y: 3
        blur: 20
        color: Qt.rgba(0, 0, 0, 0.38 * Math.min(1, win.progress * 2))
    }

    Rectangle {
        id: drawer
        readonly property int r: Theme.radius + 6
        x: win.side === "left" ? win.edge : win.pad
        y: win.top
        width: win.drawerWidth
        height: win.anim === "slide" ? (win.open ? win.drawerHeight : 0) : win.drawerHeight
        opacity: win.anim === "slide" ? 1 : (win.open ? 1 : 0)
        scale: win.anim === "grow" ? (win.open ? 1 : 0.9) : 1
        transformOrigin: win.center ? Item.Center : Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        color: win.background === "solid" ? Theme.panel : Theme.alpha(Theme.base, win.background === "glass" ? 0.72 : 0.55)
        clip: true
        border.width: win.card ? 1 : 0
        border.color: Theme.surface0
        topLeftRadius: win.card ? r : 0
        topRightRadius: win.card ? r : 0
        bottomRightRadius: win.card || win.side === "left" ? r : 0
        bottomLeftRadius: win.card || win.side === "right" ? r : 0

        Behavior on height { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutExpo } }

        // фон «обои»: текущая обоина, сильно размытая и притемнённая
        ClippingRectangle {
            anchors.fill: parent
            visible: win.background === "wallpaper"
            z: -1
            color: "transparent"
            topLeftRadius: drawer.topLeftRadius
            topRightRadius: drawer.topRightRadius
            bottomLeftRadius: drawer.bottomLeftRadius
            bottomRightRadius: drawer.bottomRightRadius
            Image {
                anchors.fill: parent
                anchors.margins: -24
                source: parent.visible && Store.still ? "file://" + Store.still : ""
                sourceSize: Qt.size(480, 270)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                layer.enabled: parent.visible
                layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; brightness: -0.25; saturation: 0.1 }
            }
        }

        Item {
            id: body
            width: win.drawerWidth
            height: win.drawerHeight
            anchors.bottom: parent.bottom
            opacity: Math.min(1, win.progress * 1.5)
        }
    }

    readonly property real r: card ? 0 : Math.min(Theme.frameRadius, drawer.height)

    // стык с панелью
    InvertedCorner {
        visible: win.r > 0.5
        radius: win.r
        y: win.top
        x: win.side === "left" ? drawer.width : drawer.x - radius
        corner: win.side === "left" ? "topLeft" : "topRight"
        color: Theme.panel
    }
    // стык с краем экрана
    InvertedCorner {
        visible: win.r > 0.5
        radius: win.r
        y: drawer.y + drawer.height
        x: win.side === "left" ? 0 : win.width - radius
        corner: win.side === "left" ? "topLeft" : "topRight"
        color: Theme.panel
    }
}
