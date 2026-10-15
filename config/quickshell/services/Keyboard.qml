pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock: читаем светодиод из /sys/class/leds (дёшево, без процессов).
Singleton {
    id: root

    property bool caps: false
    property string ledPath: ""

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/leds/*capslock* 2>/dev/null | head -1"]
        stdout: StdioCollector { onStreamFinished: root.ledPath = text.trim() ? text.trim() + "/brightness" : "" }
    }

    Timer {
        interval: 300
        running: root.ledPath !== ""
        repeat: true
        onTriggered: led.reload()
    }

    FileView {
        id: led
        path: root.ledPath
        onLoaded: root.caps = text().trim() !== "0"
    }
}
