import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services

// Экран блокировки на Quickshell. `qs ipc call lock lock` (Super+L, hypridle).
// Пароль проверяется через assets/pam/lock (только pam_unix — без faillock).
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property bool failed: false
    property bool unlocking: false

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
