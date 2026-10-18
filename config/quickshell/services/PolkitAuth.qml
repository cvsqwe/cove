pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.config

// Агент polkit: запросы прав root (GParted, монтирование, принтеры) показывает окно шелла
// (session/PolkitPrompt.qml). Агент в сессии может быть только один: если свой выключен
// в настройках или не смог зарегистрироваться — поднимаем запасной hyprpolkitagent.
Singleton {
    id: root

    readonly property bool enabled: Settings.ready && Settings.general.polkit
    readonly property var agent: loader.item
    readonly property bool registered: agent?.isRegistered ?? false
    readonly property AuthFlow flow: agent?.flow ?? null
    readonly property bool active: flow !== null
    property bool fallback: false      // работает hyprpolkitagent

    signal failed()

    onEnabledChanged: apply()
    Component.onCompleted: apply()

    function apply(): void {
        if (!Settings.ready) return;
        if (enabled) {
            // сначала гасим запасной агент, иначе polkitd откажет в регистрации
            loader.active = false;
            fallback = false;
            killFallback.running = true;
        } else {
            loader.active = false;
            startFallback();
        }
    }

    function startFallback(): void {
        fallback = true;
        Quickshell.execDetached(["sh", "-c", "pgrep -x hyprpolkitagent >/dev/null || exec /usr/lib/hyprpolkitagent/hyprpolkitagent </dev/null >/dev/null 2>&1"]);
    }

    function submit(password: string): void {
        if (flow && flow.isResponseRequired) flow.submit(password);
    }
    function cancel(): void {
        if (flow) flow.cancelAuthenticationRequest();
    }

    Process {
        id: killFallback
        command: ["pkill", "-x", "hyprpolkitagent"]
        // polkitd замечает уход прежнего агента не сразу
        onExited: registerDelay.restart()
    }
    Timer {
        id: registerDelay
        interval: 400
        onTriggered: if (root.enabled) { loader.active = true; registerCheck.restart(); }
    }
    Timer {
        id: registerCheck
        interval: 3000
        onTriggered: if (root.enabled && !root.registered) {
            console.warn("polkit: свой агент не зарегистрировался, запускаю hyprpolkitagent");
            loader.active = false;
            root.startFallback();
        }
    }

    LazyLoader {
        id: loader
        active: false
        PolkitAgent {
            onAuthenticationRequestStarted: Sounds.play("notify")
        }
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed(): void { root.failed(); }
    }

    IpcHandler {
        target: "polkit"
        function status(): string {
            return root.registered ? "shell" : root.fallback ? "hyprpolkitagent" : "none";
        }
        function cancel(): void { root.cancel(); }
    }
}
