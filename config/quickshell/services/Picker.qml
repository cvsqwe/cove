pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Пипетка: hyprpicker → цвет в буфер и всплывашка в острове с HEX / RGB / HSL.
Singleton {
    id: root

    property color color: "transparent"
    property bool hasColor: false
    property int serial: 0
    property var history: [] // последние 8 цветов (hex)

    readonly property string hex: String(color).toUpperCase()
    readonly property string rgb: `rgb(${Math.round(color.r * 255)}, ${Math.round(color.g * 255)}, ${Math.round(color.b * 255)})`
    readonly property string hsl: `hsl(${Math.round(Math.max(0, color.hslHue) * 360)}, ${Math.round(color.hslSaturation * 100)}%, ${Math.round(color.hslLightness * 100)}%)`

    function pick(): void { proc.running = true; }
    function copy(s: string): void { Quickshell.execDetached(["wl-copy", s]); }

    Process {
        id: proc
        command: ["hyprpicker", "-f", "hex", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim();
                if (!/^#[0-9a-fA-F]{6}$/.test(v)) return;
                root.color = v;
                root.hasColor = true;
                root.serial++;
                root.copy(v.toUpperCase());
                root.history = [v.toUpperCase(), ...root.history.filter(h => h !== v.toUpperCase())].slice(0, 8);
            }
        }
    }

    IpcHandler {
        target: "picker"
        function pick(): void { root.pick(); }
    }
}
