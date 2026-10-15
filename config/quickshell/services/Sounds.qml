pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Звуки интерфейса (assets/sounds/*.wav). Выключаются в settings.json: "sounds": false.
Singleton {
    property real lastTick: 0

    function play(name: string): void {
        if (!Settings.general.sounds) return;
        Quickshell.execDetached(["pw-play", "--volume", String(Settings.general.soundVolume), Quickshell.shellPath(`assets/sounds/${name}.wav`)]);
    }

    // для частых событий (громкость) — не чаще раза в 90 мс
    function tick(): void {
        const now = Date.now();
        if (now - lastTick < 90) return;
        lastTick = now;
        play("tick");
    }
}
