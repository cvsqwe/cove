import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.components
import qs.services

// Динамический остров: капсула в центре панели, которая перетекает между состояниями
// и выпадает из панели вниз.
// Приоритет тела: дашборд > уведомление > скриншот > пипетка > громкость > ничего.
// Капсула сама показывает тосты (воркспейс, раскладка, Caps, приветствие), плеер или часы.
PanelWindow {
    id: win

    anchors.top: true
    implicitWidth: 1240
    implicitHeight: 620
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: island }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-island"
    WlrLayershell.keyboardFocus: Panels.dashboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool osdVisible: false
    property bool shotVisible: false
    property bool pickerVisible: false
    property bool armed: false
    property var toast: null

    // раскрытие при наведении: с задержкой, чтобы не срабатывать от пролетающей мыши
    property bool peekOpen: false
    property bool peekSuppressed: false   // после действия из «peek» не раскрываться снова сразу
    readonly property bool peekWanted: Settings.island.peek && hovering && !peekSuppressed && !Panels.dashboard
    onPeekWantedChanged: {
        if (peekWanted) { peekClose.stop(); peekOpenTimer.restart(); }
        else { peekOpenTimer.stop(); peekClose.restart(); }
    }
    Timer { id: peekOpenTimer; interval: 260; onTriggered: win.peekOpen = true }
    Timer { id: peekClose; interval: 320; onTriggered: if (!win.peekWanted) win.peekOpen = false }
    Timer { id: unsuppress; interval: 1500; onTriggered: win.peekSuppressed = false }
    function closePeek(): void { peekOpen = false; peekSuppressed = true; unsuppress.restart(); }
    // «курсор над островом»: HoverHandler не узнаёт об уходе курсора, если остров сжался под
    // неподвижной мышью (закрыли дашборд) — сверяем последнюю точку с текущими границами
    readonly property bool hovering: hover.hovered
        && hover.point.position.x >= 0 && hover.point.position.x <= island.width
        && hover.point.position.y >= 0 && hover.point.position.y <= island.height

    readonly property string mode: Panels.dashboard ? "dashboard"
        : Notifs.current ? "notif"
        : shotVisible ? "shot"
        : pickerVisible ? "picker"
        : osdVisible ? "osd"
        : peekOpen ? "peek"
        : "idle"

    readonly property real bodyWidth: mode === "dashboard" ? dashboard.implicitWidth + 32
        : mode === "notif" ? 460
        : mode === "shot" ? shot.implicitWidth + 36
        : mode === "picker" ? picker.implicitWidth + 36
        : mode === "osd" ? 360
        : mode === "peek" ? peek.implicitWidth + 40
        : 0
    readonly property real bodyHeight: mode === "dashboard" ? dashboard.implicitHeight + 28
        : mode === "notif" ? notif.implicitHeight + 26
        : mode === "shot" ? shot.implicitHeight + 28
        : mode === "picker" ? picker.implicitHeight + 28
        : mode === "osd" ? 46
        : mode === "peek" ? peek.implicitHeight + 24
        : 0

    // ---- тосты в капсуле ----
    function showToast(icon: string, text: string, color: color, ms: int): void {
        if (!armed || GameMode.active) return;
        toast = { icon, text, color };
        toastTimer.interval = ms || 1300;
        toastTimer.restart();
    }
    Timer { id: toastTimer; onTriggered: win.toast = null }

    Timer {
        interval: 2000
        running: true
        onTriggered: {
            win.armed = true;
            if (Settings.island.greeting) {
                const h = new Date().getHours();
                const g = h < 5 ? I18n.tr("Доброй ночи") : h < 12 ? I18n.tr("Доброе утро") : h < 18 ? I18n.tr("Добрый день") : I18n.tr("Добрый вечер");
                win.showToast("󰣐", `${g}, ${Settings.displayName}`, Theme.accent, 3200);
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged(): void {
            if (Settings.island.workspaceToast && Hyprland.focusedWorkspace)
                win.showToast("󰍹", I18n.tr("Воркспейс ") + Hyprland.focusedWorkspace.id, Theme.accent, 900);
        }
    }
    Connections {
        target: Hypr
        function onLayoutChanged(): void {
            if (!Settings.island.layoutToast) return;
            const flags = { RU: "🇷🇺", EN: "🇺🇸", UA: "🇺🇦", BY: "🇧🇾", DE: "🇩🇪", FR: "🇫🇷", KZ: "🇰🇿" };
            win.showToast(flags[Hypr.layout] ?? "󰌌", Hypr.layout === "RU" ? I18n.tr("Русский") : Hypr.layout === "EN" ? "English" : Hypr.layout, Theme.lavender, 900);
        }
    }
    Connections {
        target: Keyboard
        function onCapsChanged(): void {
            if (Settings.island.capsToast)
                win.showToast(Keyboard.caps ? "󰪛" : "󰬶", Keyboard.caps ? "CAPS LOCK" : "caps lock", Keyboard.caps ? Theme.peach : Theme.overlay1, 1100);
        }
    }

    // ---- громкость ----
    Timer { id: osdTimer; interval: 1600; onTriggered: win.osdVisible = false }
    Connections {
        target: Audio
        function onVolumeChanged(): void { win.pingOsd(); }
        function onMutedChanged(): void { win.pingOsd(); }
    }
    function pingOsd(): void {
        if (!armed || !Settings.island.osd) return;
        osdVisible = true;
        osdTimer.restart();
        Sounds.tick();
    }

    // ---- скриншот и пипетка ----
    Timer { id: shotTimer; interval: 6000; running: win.shotVisible && !win.hovering; onTriggered: win.shotVisible = false }
    Connections {
        target: Screenshot
        function onSerialChanged(): void { if (Settings.island.screenshotPreview) { win.shotVisible = true; shotTimer.restart(); } }
    }
    Timer { id: pickerTimer; interval: 7000; running: win.pickerVisible && !win.hovering; onTriggered: win.pickerVisible = false }
    Connections {
        target: Picker
        function onSerialChanged(): void { win.pickerVisible = true; pickerTimer.restart(); }
    }

    // ---- уведомление висит N секунд, наведение ставит на паузу ----
    Timer {
        id: notifTimer
        interval: (Notifs.current?.urgency === 2 ? 2 : 1) * Settings.island.notifTimeout * 1000
        running: win.mode === "notif" && !win.hovering
        onTriggered: Notifs.next()
    }
    Connections {
        target: Notifs
        function onCurrentChanged(): void { notifTimer.restart(); }
    }

    Binding { target: Panels; property: "islandWidth"; value: island.open ? Panels.islandWidth : island.width }

    HyprlandFocusGrab {
        windows: [win]
        active: Panels.dashboard
        onCleared: Panels.dashboard = false
    }

    // ---- форма ----
    // мягкая тень под чёлкой: отделяет её от окон и обоев
    RectangularShadow {
        anchors.fill: island
        visible: Theme.barNotch || (island.morph && win.bodyHeight > 0)
        radius: island.bottomLeftRadius
        offset.y: 4
        blur: 20
        color: Qt.rgba(0, 0, 0, 0.38)
    }

    Rectangle {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        // Три способа раскрытия:
        //  • morph (плавающие стили) — остров и есть капсула в баре; раскрываясь, вырастает
        //    из неё в отдельную скруглённую карточку с тенью, без наплывов;
        //  • hanging («Чёлка», «Капли») — свисает с края экрана, растёт вниз;
        //  • docked («Классика») — выпадает из сплошной панели через наплывы.
        readonly property bool morph: Theme.barFloating && !Theme.islandHanging
        readonly property bool open: win.bodyHeight > 0
        readonly property int inset: 0
        y: morph ? Theme.barTop + (Theme.barHeight - Theme.capsuleHeight) / 2 : Theme.barTop
        width: morph ? Math.max(header.implicitWidth + 16, win.bodyWidth)
                     : Math.max(header.implicitWidth + 24, win.bodyWidth, Theme.barNotch ? 240 : 0)
        height: (morph ? Theme.capsuleHeight : Theme.islandHanging ? Theme.dropHeight : Theme.barHeight) + win.bodyHeight
        color: morph ? (open ? Theme.panel : Theme.capsule)
             : open || Theme.islandHanging ? Theme.islandColor : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        border.width: morph ? 1 : 0
        border.color: Theme.capsuleBorder
        readonly property real openRadius: Theme.radius + 6
        bottomLeftRadius: morph ? (open ? openRadius : Theme.capsuleRadius)
                        : open ? openRadius : Theme.islandHanging ? Theme.capsuleRadius + 2 : 0
        bottomRightRadius: bottomLeftRadius
        topLeftRadius: morph ? (open ? openRadius : Theme.capsuleRadius) : 0
        topRightRadius: topLeftRadius
        Behavior on topLeftRadius { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
        clip: true

        Behavior on width { SpringAnimation { spring: Theme.springSpring; damping: Theme.springDamping; epsilon: 0.5 } }
        Behavior on height { SpringAnimation { spring: Theme.springSpring; damping: Theme.springDamping; epsilon: 0.5 } }

        HoverHandler { id: hover }

        // капсула внутри панели
        Rectangle {
            id: capsule
            anchors.horizontalCenter: parent.horizontalCenter
            y: island.morph ? 0 : Theme.islandHanging ? (Theme.dropHeight - height) / 2 : 4
            width: header.implicitWidth + 16
            height: Theme.capsuleHeight
            radius: Theme.capsuleRadius
            color: Theme.islandHanging || island.morph ? "transparent" : Theme.capsule
            border.width: Theme.islandHanging || island.morph ? 0 : 1
            // состояние (запись, тост, музыка) показывает «губа» снизу — рамка всегда нейтральная
            border.color: Theme.islandHanging ? "transparent" : Theme.capsuleBorder
            Behavior on width { SpringAnimation { spring: Theme.springSpring; damping: Theme.springDamping; epsilon: 0.5 } }
            Behavior on border.color { ColorAnimation { duration: Theme.anim } }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: m => {
                    if (m.button === Qt.MiddleButton) Media.player?.togglePlaying();
                    else if (m.button === Qt.RightButton) Media.player?.next();
                    else Panels.toggle("dashboard");
                }
                onWheel: w => Audio.step(w.angleDelta.y > 0 ? 0.05 : -0.05)
            }

            Header {
                id: header
                z: 1
                anchors.centerIn: parent
                toast: win.toast
            }
        }

        // «губа» чёлки: светящаяся полоска по нижнему краю вместо рамки — запись, тост, музыка
        Rectangle {
            id: lip
            readonly property color tone: Recorder.recording ? Theme.red
                : win.toast ? win.toast.color
                : Media.playing ? Media.accent : "transparent"
            visible: win.bodyHeight === 0
            anchors.horizontalCenter: parent.horizontalCenter
            // у висящего острова — по нижнему краю, у острова в панели — по низу капсулы
            y: Theme.islandHanging ? parent.height - height - 3 : capsule.y + capsule.height - height - 2
            width: Math.min(parent.width * 0.42, 120)
            height: 2
            radius: 1
            color: tone
            opacity: tone.a > 0 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim } }
            Behavior on color { ColorAnimation { duration: Theme.anim } }
            RectangularShadow {
                z: -1
                anchors.fill: parent
                radius: 1
                blur: 10
                spread: 1
                color: Theme.alpha(lip.tone, 0.8)
            }
        }

        // тело: выпадающая часть
        Item {
            id: bodyArea
            anchors.top: capsule.bottom
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: island.width - 32

            OsdBody {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                shown: win.mode === "osd"
            }
            NotifBody {
                id: notif
                width: parent.width
                shown: win.mode === "notif"
            }
            ShotBody {
                id: shot
                anchors.horizontalCenter: parent.horizontalCenter
                shown: win.mode === "shot"
                onDone: win.shotVisible = false
            }
            PickerBody {
                id: picker
                anchors.horizontalCenter: parent.horizontalCenter
                shown: win.mode === "picker"
            }
            PeekBody {
                id: peek
                anchors.horizontalCenter: parent.horizontalCenter
                shown: win.mode === "peek"
                onDone: win.closePeek()
            }
            Dashboard {
                id: dashboard
                anchors.horizontalCenter: parent.horizontalCenter
                shown: win.mode === "dashboard"
            }
        }

        Keys.onEscapePressed: Panels.dashboard = false
        focus: Panels.dashboard
    }

    // вогнутые «наплывы» там, где остров выходит из панели
    InvertedCorner {
        readonly property real r: Theme.islandHanging ? (Theme.barNotch ? Theme.notchRadius : Theme.dropRadius) : Math.min(Theme.frameRadius || 14, Math.max(0, island.height - Theme.barHeight))
        visible: r > 0.5 && !island.morph
        x: island.x - r
        y: Theme.islandHanging ? 0 : Theme.barBottom
        radius: r
        corner: "topRight"
        color: Theme.islandColor
    }
    InvertedCorner {
        readonly property real r: Theme.islandHanging ? (Theme.barNotch ? Theme.notchRadius : Theme.dropRadius) : Math.min(Theme.frameRadius || 14, Math.max(0, island.height - Theme.barHeight))
        visible: r > 0.5 && !island.morph
        x: island.x + island.width
        y: Theme.islandHanging ? 0 : Theme.barBottom
        radius: r
        corner: "topLeft"
        color: Theme.islandColor
    }
}
