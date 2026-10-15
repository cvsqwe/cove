pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Обёртка над Hyprland: диспатчи (Lua-конфиг и классический) и раскладка клавиатуры.
Singleton {
    id: root

    property string layout: "EN"

    function focusWorkspace(id: int): void {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(String(id))} })`);
        else
            Hyprland.dispatch(`workspace ${id}`);
    }

    // перенести окно на воркспейс, не переключаясь на него
    function moveWindow(address: string, ws: int): void {
        const a = address.startsWith("0x") ? address : "0x" + address;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.window.move({ workspace = "${ws}", window = "address:${a}", follow = false })`);
        else
            Hyprland.dispatch(`movetoworkspacesilent ${ws},address:${a}`);
    }

    function focusWindow(address: string): void {
        const a = address.startsWith("0x") ? address : "0x" + address;
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${a}" })`);
        else
            Hyprland.dispatch(`focuswindow address:${a}`);
    }

    function exit(): void {
        Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit");
    }

    function nextLayout(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    function shortLayout(name: string): string {
        if (name.startsWith("Russian")) return "RU";
        if (name.startsWith("English")) return "EN";
        return name.slice(0, 2).toUpperCase();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout") {
                const parts = event.data.split(",");
                root.layout = root.shortLayout(parts[parts.length - 1]);
            }
        }
    }

    // начальное значение раскладки
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards;
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    if (kb) root.layout = root.shortLayout(kb.active_keymap);
                } catch (e) {}
            }
        }
    }
}
