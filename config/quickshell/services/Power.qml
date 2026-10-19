pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// Питание: батарея (UPower), режимы power-profiles-daemon, яркость экрана.
// Яркость — подсветка ноутбука (/sys/class/backlight, brightnessctl) или, на обычных мониторах,
// DDC/CI через ddcutil, если он стоит. Низкий заряд: тост и уведомление на 20/10/5 %,
// на N % сам включает экономию и возвращает прежний режим на зарядке.
Singleton {
    id: root

    // ---------- батарея ----------
    // demo: { level, charging } — показать интерфейс на компьютере без батареи (`qs ipc call power demo 40 0`)
    property var demo: null
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: demo !== null || ((dev?.isLaptopBattery ?? false) && (dev?.isPresent ?? false))
    readonly property real level: demo ? demo.level : (dev?.percentage ?? 0)
    readonly property int state: dev?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: demo ? demo.charging : (state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge)
    readonly property bool full: !demo && state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: hasBattery && !charging && !full && (demo ? true : UPower.onBattery)
    readonly property int percent: Math.round(level * 100)
    readonly property bool low: onBattery && percent <= 15

    function duration(sec: real): string {
        if (!(sec > 0)) return "";
        const h = Math.floor(sec / 3600), m = Math.round(sec % 3600 / 60);
        return h > 0 ? I18n.tr("{0} ч {1} мин", h, m) : I18n.tr("{0} мин", m);
    }
    readonly property string timeText: demo ? "" : charging ? duration(dev?.timeToFull ?? 0) : onBattery ? duration(dev?.timeToEmpty ?? 0) : ""
    readonly property string statusText: !hasBattery ? ""
        : full ? I18n.tr("Заряжена")
        : charging ? I18n.tr("Заряжается") + (timeText ? I18n.tr(" · до полной {0}", timeText) : "")
        : timeText ? I18n.tr("Хватит на {0}", timeText) : I18n.tr("От батареи")

    function icon(): string {
        if (charging || full) return percent >= 95 ? "battery_charging_full" : "battery_charging_" + [20, 20, 30, 50, 60, 80, 90, 90][Math.min(7, Math.floor(percent / 14))];
        if (percent >= 95) return "battery_full";
        if (percent <= 5) return "battery_alert";
        return "battery_" + Math.max(0, Math.min(6, Math.round(level * 6))) + "_bar";
    }
    function tint(): color { return charging || full ? Theme.green : percent <= 10 ? Theme.red : percent <= 20 ? Theme.peach : Theme.text; }

    // ---------- режимы питания ----------
    property bool hasProfiles: false   // power-profiles-daemon на шине
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile
    readonly property var profiles: [
        { value: PowerProfile.PowerSaver, icon: "energy_savings_leaf", label: I18n.tr("Экономия") },
        { value: PowerProfile.Balanced, icon: "balance", label: I18n.tr("Баланс") },
        { value: PowerProfile.Performance, icon: "bolt", label: I18n.tr("Мощность") }
    ].filter(p => p.value !== PowerProfile.Performance || hasPerformance)
    function profileInfo(p: int): var { return profiles.find(x => x.value === p) ?? profiles[0]; }
    function setProfile(p: int): void { if (hasProfiles) PowerProfiles.profile = p; }
    function cycleProfile(): void {
        const i = profiles.findIndex(x => x.value === profile);
        setProfile(profiles[(i + 1) % profiles.length].value);
    }

    Process {
        id: ppd
        running: true
        command: ["sh", "-c", `for n in org.freedesktop.UPower.PowerProfiles net.hadess.PowerProfiles; do
            busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s $n 2>/dev/null | grep -q true && { echo yes; exit; }
            busctl --system call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasActivatableName s $n 2>/dev/null | grep -q true && { echo yes; exit; }
        done; echo no`]
        stdout: StdioCollector { onStreamFinished: root.hasProfiles = text.trim() === "yes" }
    }

    // ---------- низкий заряд ----------
    property int warned: 100            // последний порог, о котором уже сказали
    signal alert(string icon, string text, color tint)

    // UPower отдаёт поля по одному (и сперва нули): решаем, когда состояние устоялось
    readonly property bool trusted: demo !== null || ((dev?.ready ?? false) && percent > 0)
    onPercentChanged: settle.restart()
    onOnBatteryChanged: settle.restart()
    Timer { id: settle; interval: 1500; onTriggered: if (root.trusted || !root.onBattery) root.react() }
    Component.onCompleted: settle.start()   // после перезапуска шелла — вернуть режим, если зарядку уже подключили
    property bool lastOnBattery: false
    function react(): void {
        if (onBattery) { lastOnBattery = true; checkLevel(); return; }
        // не от батареи: вернуть режим до автоэкономии (он в state.json — переживает перезапуск шелла)
        if (Store.savedProfile >= 0) { setProfile(Store.savedProfile); Store.savedProfile = -1; }
        if (lastOnBattery) {
            warned = 100;
            if (hasBattery && charging) alert(icon(), I18n.tr("Заряжается · {0}%", percent), Theme.green);
        }
        lastOnBattery = false;
    }
    function checkLevel(): void {
        if (!onBattery) return;
        const saverAt = Settings.power.saverAt;
        if (saverAt > 0 && percent <= saverAt && hasProfiles && profile !== PowerProfile.PowerSaver && Store.savedProfile < 0) {
            Store.savedProfile = profile;
            setProfile(PowerProfile.PowerSaver);
        }
        for (const t of [5, 10, 20]) {
            if (percent <= t && warned > t) {
                warned = t;
                const crit = t <= 10;
                Quickshell.execDetached(["notify-send", "-a", I18n.tr("Питание"), "-u", crit ? "critical" : "normal", "-i", "battery-caution",
                    I18n.tr("Батарея {0}%", percent),
                    crit ? I18n.tr("Подключите зарядку, скоро ноутбук уснёт.") : I18n.tr("Включена экономия энергии.")]);
                break;
            }
        }
    }

    // ---------- яркость ----------
    // kind: "backlight" (ноутбук) | "ddc" (монитор по DDC/CI) | "" (нечем управлять)
    property string kind: ""
    property string backlight: ""     // /sys/class/backlight/<устройство>
    property real maxRaw: 0
    property real brightness: 0       // 0..1
    readonly property bool hasBrightness: kind !== ""
    signal brightnessShown()          // для OSD острова: менялась через шелл

    Process {
        id: probe
        running: true
        command: ["sh", "-c", `b=$(ls -d /sys/class/backlight/* 2>/dev/null | head -1)
            if [ -n "$b" ]; then echo "backlight $b $(cat $b/max_brightness)"; exit; fi
            command -v ddcutil >/dev/null || exit 0
            v=$(timeout 6 ddcutil getvcp 10 --brief 2>/dev/null | head -1) && echo "ddc $v"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim().split(/\s+/);
                if (t[0] === "backlight") {
                    root.backlight = t[1]; root.maxRaw = Number(t[2]) || 0; root.kind = "backlight"; rawFile.reload();
                } else if (t[0] === "ddc" && t[1] === "VCP") {
                    // VCP 10 C <текущее> <максимум>
                    root.maxRaw = Number(t[5]) || 100; root.brightness = (Number(t[4]) || 0) / root.maxRaw; root.kind = "ddc";
                }
            }
        }
    }
    FileView {
        id: rawFile
        path: root.backlight ? root.backlight + "/brightness" : ""
        printErrors: false
        onLoaded: if (root.maxRaw > 0 && !setter.running && !pending.running) root.brightness = Number(text().trim()) / root.maxRaw
    }
    // подсветку могут менять и мимо шелла (Fn-клавиши, другие программы)
    Timer { interval: 2000; running: root.kind === "backlight"; repeat: true; onTriggered: rawFile.reload() }

    property real target: -1
    function setBrightness(v: real): void {
        if (!hasBrightness) return;
        brightness = Math.max(0.01, Math.min(1, v));
        target = brightness;
        pending.restart();
        brightnessShown();
    }
    function step(d: real): void { setBrightness(brightness + d); }
    // ddcutil медленный (~100 мс на команду), поэтому только последнее значение и не чаще 5 раз в секунду
    Timer {
        id: pending
        interval: root.kind === "ddc" ? 200 : 16
        onTriggered: {
            if (setter.running) { restart(); return; }
            const v = Math.round(root.target * root.maxRaw);
            setter.command = root.kind === "ddc"
                ? ["ddcutil", "setvcp", "10", String(v), "--noverify"]
                : ["brightnessctl", "-q", "-d", root.backlight.split("/").pop(), "set", String(Math.max(1, v))];
            setter.running = true;
        }
    }
    Process { id: setter }

    IpcHandler {
        target: "power"
        function status(): string {
            return JSON.stringify({ battery: root.hasBattery, percent: root.percent, charging: root.charging, onBattery: root.onBattery,
                time: root.timeText, profiles: root.hasProfiles, profile: root.profileInfo(root.profile).label,
                brightness: root.kind ? Math.round(root.brightness * 100) : -1, kind: root.kind });
        }
        function demo(level: int, charging: int): void { root.demo = level < 0 ? null : { level: level / 100, charging: charging > 0 }; }
        function profile(): void { root.cycleProfile(); }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { root.step(0.05); }
        function down(): void { root.step(-0.05); }
        function set(percent: int): void { root.setBrightness(percent / 100); }
    }
}
