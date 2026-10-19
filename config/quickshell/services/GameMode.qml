pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Игровой режим: без анимаций, блюра, теней и шейдера экрана, «Не беспокоить», спектр выключен.
// Включается вручную (Super+G) или сам — когда на весь экран открыта игра.
Singleton {
    id: root

    readonly property var win: Hyprland.activeToplevel
    // у закрывающегося окна lastIpcObject бывает пустым — приводим типы явно
    readonly property string cls: String(win?.lastIpcObject?.class ?? "")
    readonly property bool fullscreen: Number(win?.lastIpcObject?.fullscreen ?? 0) > 0
    readonly property bool isGame: /^(steam_app_\d+|gamescope|.*\.exe|minecraft.*|Minecraft.*|osu!|cs2|dota2)$/i.test(cls)
    readonly property bool auto: Settings.windows.gameMode && fullscreen && isGame
    readonly property bool active: Store.gameMode || auto

    property bool applied: false
    property bool prevDnd: false

    onActiveChanged: active ? enable() : disable()

    function enable(): void {
        if (applied) return;
        applied = true;
        prevDnd = Store.dnd;
        Store.dnd = true;
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false }, glow = { enabled = false }, screen_shader = \"\" } })"]);
    }

    function disable(): void {
        if (!applied) return;
        applied = false;
        Store.dnd = prevDnd;
        Quickshell.execDetached([Quickshell.shellPath("assets/hypr-reload.sh")]); // вернуть значения из generated.lua
    }

    // lastIpcObject обновляется не по событиям — освежаем при смене окна/полноэкранного режима
    Connections {
        target: Hyprland
        function onRawEvent(e: HyprlandEvent): void {
            if (e.name === "fullscreen" || e.name === "activewindowv2") Hyprland.refreshToplevels();
        }
    }
}
