import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services
import qs.components

// Экран блокировки на Quickshell. `qs ipc call lock lock` (Super+L, hypridle).
// Пароль проверяется через assets/pam/lock (только pam_unix — без faillock).
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    property bool unlocking: false
    // для остального шелла (экранное время не считает, пока заблокировано)
    Binding { target: Panels; property: "locked"; value: sessionLock.locked }

    function lock(): void {
        password = "";
        failed = false;
        unlocking = false;
        sessionLock.locked = true;
    }

    function tryUnlock(): void {
        if (busy || password === "") return;
        busy = true;
        failed = false;
        pam.start();
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return sessionLock.locked; }
        function preview(): void { root.previewing = !root.previewing; }
    }

    // ---- предпросмотр: тот же экран обычным окном поверх всего, без блокировки и пароля ----
    property bool previewing: false
    QtObject {
        id: fakeLock
        readonly property bool preview: true   // кнопки питания в предпросмотре ничего не делают
        property string password: ""
        property bool busy: false
        property bool failed: false
        property bool unlocking: false
        function tryUnlock(): void { password = ""; root.previewing = false; }
    }
    Timer { running: root.previewing; interval: 15000; onTriggered: root.previewing = false }
    PanelWindow {
        visible: root.previewing
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-lock-preview"
        color: Theme.crust
        LockSurface {
            anchors.fill: parent
            lock: fakeLock
            focus: true
            Keys.onEscapePressed: root.previewing = false
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            width: hint.implicitWidth + 28
            height: 30
            radius: 15
            color: Theme.alpha(Theme.base, 0.7)
            StyledText { id: hint; anchors.centerIn: parent; text: I18n.tr("Предпросмотр — Esc или клик, чтобы закрыть"); color: Theme.subtext0; font.pixelSize: Theme.fontSizeSmall }
        }
        MouseArea { anchors.fill: parent; z: -1; onClicked: root.previewing = false }
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("assets/pam")
        config: "lock"

        onPamMessage: {
            if (responseRequired) respond(root.password);
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.unlocking = true;
                Sounds.play("unlock");
                unlockDelay.start();
            } else {
                root.password = "";
                root.failed = true;
            }
        }
        onError: {
            root.busy = false;
            root.password = "";
            root.failed = true;
        }
    }

    // даём анимации растворения доиграть
    Timer {
        id: unlockDelay
        interval: 420
        onTriggered: {
            sessionLock.locked = false;
            root.password = "";
            root.unlocking = false;
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: Theme.crust

            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }
}
