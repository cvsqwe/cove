//@ pragma IconTheme breeze-dark

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Greetd

// Экран входа (greetd). Ставится в /etc/greetd/qs-greeter скриптом install.sh.
// @USER@, @ACCENT@ и прочие плейсхолдеры подставляет install.sh.
ShellRoot {
    id: root

    readonly property string user: "@USER@"
    readonly property color accent: "@ACCENT@"
    readonly property color base: "@BASE@"
    readonly property color text: "@TEXT@"
    readonly property color dim: "@DIM@"
    readonly property color red: "#f38ba8"
    readonly property string font: "Adwaita Sans"

    property string password: ""
    property bool busy: false
    property bool failed: false
    property bool launching: false

    function login(): void {
        if (busy || password === "") return;
        busy = true;
        failed = false;
        Greetd.createSession(user);
    }

    Connections {
        target: Greetd
        function onAuthMessage(message: string, error: bool, responseRequired: bool, echoResponse: bool): void {
            if (responseRequired) Greetd.respond(root.password);
        }
        function onAuthFailure(message: string): void {
            root.busy = false;
            root.failed = true;
            root.password = "";
            Greetd.cancelSession();
        }
        function onReadyToLaunch(): void {
            root.launching = true;
            Greetd.launch(["start-hyprland"], [], true);
        }
        function onError(error: string): void {
            root.busy = false;
            root.failed = true;
            root.password = "";
        }
    }

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "black"

        SystemClock { id: clock; precision: SystemClock.Seconds }

        Image {
            id: wall
            anchors.fill: parent
            source: "file:///etc/greetd/qs-greeter/wallpaper"
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(1280, 720)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            brightness: -0.3
        }

        ColumnLayout {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -40
            spacing: 6
            opacity: root.launching ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 300 } }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: root.text
                font.family: root.font
                font.pixelSize: 110
                font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    const s = Qt.locale("ru_RU").toString(clock.date, "dddd, d MMMM");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                color: root.dim
                font.family: root.font
                font.pixelSize: 20
            }

            Item { implicitHeight: 36 }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 76
                implicitHeight: 76
                radius: 38
                color: root.accent
                // знак Cove (как components/CoveLogo.qml; гритер — отдельный шелл без модулей qs.*)
                Shape {
                    id: mark
                    anchors.centerIn: parent
                    width: 44; height: 44
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real k: width / 64
                    ShapePath {
                        strokeWidth: 7 * mark.k; strokeColor: root.base; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        startX: 48.06 * mark.k; startY: 14.17 * mark.k
                        PathArc { x: 48.06 * mark.k; y: 49.83 * mark.k; radiusX: 24 * mark.k; radiusY: 24 * mark.k; useLargeArc: true; direction: PathArc.Counterclockwise }
                    }
                    ShapePath {
                        strokeWidth: 4.5 * mark.k; strokeColor: root.base; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        startX: 21 * mark.k; startY: 30 * mark.k
                        PathQuad { x: 32 * mark.k; y: 30 * mark.k; controlX: 26.5 * mark.k; controlY: 24 * mark.k }
                        PathQuad { x: 43 * mark.k; y: 30 * mark.k; controlX: 37.5 * mark.k; controlY: 36 * mark.k }
                    }
                    ShapePath {
                        strokeWidth: 4 * mark.k; strokeColor: Qt.alpha(root.base, 0.5); fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        startX: 26 * mark.k; startY: 41 * mark.k
                        PathQuad { x: 37 * mark.k; y: 41 * mark.k; controlX: 31.5 * mark.k; controlY: 35.5 * mark.k }
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 10
                text: root.user
                color: root.text
                font.family: root.font
                font.pixelSize: 18
                font.bold: true
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 340
                implicitHeight: 54
                radius: 27
                color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.8)
                border.width: 2
                border.color: root.failed ? root.red : root.accent

                TextInput {
                    id: input
                    anchors.fill: parent
                    focus: true
                    opacity: 0
                    echoMode: TextInput.Password
                    text: root.password
                    onTextChanged: { root.password = text; if (text !== "") root.failed = false; }
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.password.length > 0
                    Repeater {
                        model: Math.min(root.password.length, 24)
                        Rectangle { width: 10; height: 10; radius: 5; color: root.accent }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.password.length === 0
                    text: root.busy ? "Вход…" : root.failed ? "Неверный пароль" : "Пароль"
                    color: root.failed ? root.red : root.dim
                    font.family: root.font
                    font.pixelSize: 14
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 30
            spacing: 12
            Repeater {
                model: [
                    { icon: "󰜉", cmd: ["systemctl", "reboot"] },
                    { icon: "󰐥", cmd: ["systemctl", "poweroff"] }
                ]
                Rectangle {
                    required property var modelData
                    width: 40; height: 40; radius: 20
                    color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.8)
                    Text { anchors.centerIn: parent; text: modelData.icon; color: root.text; font.family: root.font; font.pixelSize: 18 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(modelData.cmd) }
                }
            }
        }
    }
}
