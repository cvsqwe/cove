pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Агент сопряжения Bluetooth: держит bluetoothctl как агента по умолчанию,
// показывает код подтверждения и сам подтверждает сопряжение, начатое из шелла.
Singleton {
    id: root

    property string passkey: ""       // код, который нужно сверить с устройством
    property string pendingName: ""
    property bool expectPairing: false
    property string buffer: ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: adapter?.devices.values ?? []
    readonly property var connected: devices.filter(d => d.connected)
    readonly property var paired: devices.filter(d => d.paired || d.bonded).sort((a, b) => b.connected - a.connected)
    readonly property var found: devices.filter(d => !d.paired && !d.bonded && (d.name ?? "") !== "")

    function pair(dev): void {
        if (!dev) return;
        expectPairing = true;
        pendingName = dev.name;
        dev.pair();
        // после сопряжения — доверие и подключение
        afterPair.dev = dev;
        afterPair.restart();
    }

    function toggle(dev): void {
        if (!dev) return;
        if (dev.connected) dev.disconnect();
        else dev.connect();
    }

    function forget(dev): void { dev?.forget(); }

    function scan(on: bool): void { if (adapter) adapter.discovering = on; }

    Timer {
        id: afterPair
        property var dev: null
        interval: 1500
        repeat: true
        property int tries: 0
        onTriggered: {
            tries++;
            if (dev && (dev.paired || dev.bonded)) {
                dev.trusted = true;
                dev.connect();
                root.expectPairing = false;
                root.passkey = "";
                stop();
                tries = 0;
            } else if (tries > 20) {
                root.expectPairing = false;
                root.passkey = "";
                stop();
                tries = 0;
            }
        }
    }

    Process {
        id: agent
        running: Bluetooth.defaultAdapter !== null
        command: ["bluetoothctl"]
        stdinEnabled: true
        onStarted: write("agent KeyboardDisplay\ndefault-agent\n")
        stdout: SplitParser {
            splitMarker: ""
            onRead: chunk => {
                root.buffer = (root.buffer + chunk).slice(-2000);
                const b = root.buffer;
                let m = b.match(/Confirm passkey (\d+)[^\n]*\(yes\/no\):\s*$/);
                if (m) {
                    root.passkey = m[1];
                    agent.write("yes\n");
                    root.buffer = "";
                    return;
                }
                if (/(Authorize service|Accept pairing|Request authorization)[^\n]*\(yes\/no\):\s*$/.test(b)) {
                    agent.write("yes\n");
                    root.buffer = "";
                    return;
                }
                m = b.match(/Passkey: (\d+)/);
                if (m) root.passkey = m[1];
            }
        }
    }
}
