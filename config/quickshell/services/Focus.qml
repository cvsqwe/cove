pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Фокус-таймер (помодоро): работа → перерыв → работа… Во время работы — «Не беспокоить».
Singleton {
    id: root

    property string phase: "idle" // idle | work | break
    property int remaining: 0
    property int total: 1
    property int rounds: 0
    property bool paused: false
    property bool prevDnd: false

    readonly property bool active: phase !== "idle"
    readonly property real progress: total > 0 ? 1 - remaining / total : 0
    readonly property string timeText: `${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, "0")}`

    function startWork(): void {
        if (phase === "idle") prevDnd = Store.dnd;
        phase = "work";
        total = remaining = Settings.focus.work * 60;
        paused = false;
        if (Settings.focus.dnd) Store.dnd = true;
    }
    function startBreak(): void {
        phase = "break";
        total = remaining = Settings.focus.shortBreak * 60;
        if (Settings.focus.dnd) Store.dnd = prevDnd;
    }
    function stop(): void {
        if (phase === "work" && Settings.focus.dnd) Store.dnd = prevDnd;
        phase = "idle";
        remaining = 0;
        paused = false;
    }
    function toggle(): void { active ? stop() : startWork(); }
    function skip(): void { phase === "work" ? finish() : startWork(); }
    function finish(): void {
        Sounds.play("unlock");
        if (phase === "work") {
            rounds++;
            Quickshell.execDetached(["notify-send", "-a", I18n.tr("Фокус"), I18n.tr("Перерыв!"), I18n.tr("Отличная работа — {0}-й подход. Отдохните {1} мин.", rounds, Settings.focus.shortBreak)]);
            startBreak();
        } else {
            Quickshell.execDetached(["notify-send", "-a", I18n.tr("Фокус"), I18n.tr("Перерыв окончен"), I18n.tr("Возвращаемся к делу.")]);
            startWork();
        }
    }

    Timer {
        running: root.active && !root.paused
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0) root.finish();
        }
    }

    IpcHandler {
        target: "focus"
        function toggle(): void { root.toggle(); }
        function skip(): void { root.skip(); }
        function pause(): void { root.paused = !root.paused; }
    }
}
