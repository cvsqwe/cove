import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Заставка Cove: один раз за сессию при входе — знак прорисовывается, проявляется «cove» и приветствие.
// Флаг в $XDG_RUNTIME_DIR (очищается при выходе), поэтому перезапуск шелла её не показывает.
// qs ipc call splash play — показать ещё раз.
Scope {
    id: root

    property bool shown: false
    readonly property string flag: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/cove-splash"

    function greeting(): string {
        const h = new Date().getHours();
        if (h < 5) return I18n.tr("Доброй ночи");
        if (h < 12) return I18n.tr("Доброе утро");
        if (h < 18) return I18n.tr("Добрый день");
        return I18n.tr("Добрый вечер");
    }

    function show(): void {
        shown = true;
        seq.restart();
    }

    // при старте шелла: первый раз за сессию — показываем
    function boot(): void {
        if (!Settings.appearance.splash) return;
        check.running = true;
    }

    Process {
        id: check
        command: ["sh", "-c", 'test -e "$1" && exit 1; : > "$1"', "_", root.flag]
        onExited: code => { if (code === 0) root.show(); }
    }

    IpcHandler {
        target: "splash"
        function play(): void { root.show(); }
    }

    PanelWindow {
        id: win
        screen: Displays.primaryScreen
        visible: root.shown
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-splash"
        color: "transparent"

        property real bg: 0
        property real logo: 0
        property real word: 0
        property real fade: 1

        Rectangle {
            anchors.fill: parent
            color: Theme.crust
            opacity: win.bg * win.fade
        }

        MouseArea {
            anchors.fill: parent
            onClicked: { seq.stop(); out.start(); }
        }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            spacing: 0
            opacity: win.fade
            scale: 0.96 + 0.04 * win.fade

            CoveLogo {
                Layout.alignment: Qt.AlignHCenter
                size: 132
                color: Theme.accent
                color2: Theme.accent2
                waveColor: Theme.text
                progress: win.logo
                scale: 0.9 + 0.1 * win.logo
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 26
                text: "cove"
                font.pixelSize: 46
                font.weight: Font.Light
                font.letterSpacing: 4 + 18 * (1 - win.word)
                color: Theme.text
                opacity: win.word
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                text: `${root.greeting()}, ${Settings.displayName}`
                font.pixelSize: 15
                color: Theme.subtext0
                opacity: win.word * 0.9
            }
        }

        SequentialAnimation {
            id: seq
            ScriptAction { script: { win.bg = 0; win.logo = 0; win.word = 0; win.fade = 1; } }
            NumberAnimation { target: win; property: "bg"; to: 0.94; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: win; property: "logo"; to: 1; duration: 1000; easing.type: Easing.InOutCubic }
            NumberAnimation { target: win; property: "word"; to: 1; duration: 650; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 900 }
            ScriptAction { script: out.start() }
        }

        NumberAnimation {
            id: out
            target: win; property: "fade"; to: 0; duration: 520; easing.type: Easing.InCubic
            onFinished: root.shown = false
        }
    }
}
