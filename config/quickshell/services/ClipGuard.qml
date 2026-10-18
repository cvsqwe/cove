pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Пароли в буфере обмена: менеджеры паролей (KeePassXC, Bitwarden, 1Password…) помечают копию как
// секретную, wl-paste сообщает это как CLIPBOARD_STATE=sensitive. cliphist такие копии в историю не пишет,
// а мы очищаем буфер через Settings.general.clipClearSeconds секунд, если в нём всё ещё пароль.
Singleton {
    id: root

    property bool sensitive: false
    readonly property int seconds: Settings.general.clipClearSeconds ?? 30

    Process {
        running: root.seconds > 0
        command: ["wl-paste", "--watch", "sh", "-c", 'echo "${CLIPBOARD_STATE:-data}"']
        stdout: SplitParser {
            onRead: line => {
                root.sensitive = line.trim() === "sensitive";
                if (root.sensitive) clearTimer.restart();
                else clearTimer.stop();
            }
        }
    }

    Timer {
        id: clearTimer
        interval: root.seconds * 1000
        onTriggered: if (root.sensitive) {
            Quickshell.execDetached(["wl-copy", "--clear"]);
            root.sensitive = false;
        }
    }
}
