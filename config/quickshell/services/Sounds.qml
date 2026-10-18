pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Звуки интерфейса. Наборы — папки в assets/sounds (cove — файлы в самой assets/sounds).
// Выключаются в settings.json: "sounds": false (будильник звонит всё равно — services/Timers.qml).
Singleton {
    property real lastTick: 0

    readonly property var sets: [
        { value: "cove", label: "Cove" },
        { value: "soft", label: I18n.tr("Мягкий") },
        { value: "glass", label: I18n.tr("Стекло") },
        { value: "retro", label: I18n.tr("Ретро") }
    ]

    // файл звука из выбранного набора; если в наборе его нет — из основного
    function path(name: string, set: string): string {
        const s = set || Settings.general.soundSet || "cove";
        return Quickshell.shellPath(s === "cove" ? `assets/sounds/${name}.wav` : `assets/sounds/${s}/${name}.wav`);
    }

    function play(name: string): void {
        if (!Settings.general.sounds) return;
        Quickshell.execDetached(["pw-play", "--volume", String(Settings.general.soundVolume), path(name)]);
    }

    // прослушать набор в настройках (даже если звуки выключены)
    function preview(set: string): void {
        Quickshell.execDetached(["pw-play", "--volume", String(Math.max(0.4, Settings.general.soundVolume)), path("notify", set)]);
    }

    // для частых событий (громкость) — не чаще раза в 90 мс
    function tick(): void {
        const now = Date.now();
        if (now - lastTick < 90) return;
        lastTick = now;
        play("tick");
    }
}
