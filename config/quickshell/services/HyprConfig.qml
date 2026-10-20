pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Генерирует ~/.config/hypr/generated.lua (хоткеи, вид окон, ввод, мониторы, правила, автозапуск)
// и ~/.config/hypr/hypridle.conf из Settings, затем перезагружает Hyprland.
// Если после перезагрузки Hyprland сообщает об ошибках — возвращает прошлую рабочую версию.
Singleton {
    id: root

    readonly property string hyprDir: Settings.home + "/.config/hypr"
    property string lastError: ""
    property string lastGood: ""

    function q(s): string { return JSON.stringify(String(s ?? "")); }
    function hex(c: color): string { return String(c).slice(1, 7); }

    function generate(): string {
        const w = Settings.windows, i = Settings.input, a = Settings.appearance;
        const L = [];
        L.push(I18n.tr("-- Сгенерировано Quickshell (services/HyprConfig.qml). Не редактировать — меняйте в Настройках (Super+,)."));
        L.push("");

        // ---- вид окон ----
        const ac = hex(Theme.accent), ac2 = hex(Theme.accent2), in0 = hex(Theme.surface0);
        const border = w.borderGradient
            ? `{ colors = {"rgba(${ac}ff)", "rgba(${ac2}ff)"}, angle = 45 }`
            : `"rgba(${ac}ff)"`;
        L.push("hl.config({");
        L.push("    general = {");
        L.push(`        gaps_in = ${w.gapsIn}, gaps_out = ${w.gapsOut}, border_size = ${w.borderSize},`);
        L.push(`        layout = ${q(w.layout)},`);
        L.push(`        col = { active_border = ${border}, inactive_border = "rgba(${in0}ff)" },`);
        L.push("    },");
        L.push("    decoration = {");
        L.push(`        rounding = ${w.rounding},`);
        // защита от вспышки: шейдер смотрит на весь экран — перерисовывать монитор целиком
        const af = Settings.nightLight.antiFlash;
        if (af === "weak" || af === "strong") L.push(`        screen_shader = ${q(Quickshell.shellPath(`assets/shaders/anti-flash-${af}.glsl`))},`);
        L.push(`        active_opacity = ${w.activeOpacity}, inactive_opacity = ${w.inactiveOpacity},`);
        L.push(`        dim_inactive = ${w.dimInactive}, dim_strength = ${w.dimStrength},`);
        L.push(`        blur = { enabled = ${w.blur}, size = ${w.blurSize}, passes = ${w.blurPasses} },`);
        L.push(`        shadow = { enabled = ${w.shadow}, range = ${w.shadowRange} },`);
        L.push(`        glow = { enabled = ${w.glow} },`);
        L.push("    },");
        L.push(`    animations = { enabled = ${a.animations} },`);
        // только xcursor: hyprcursor-тема + setcursor на xcursor роняют Hyprland 0.56 (см. ниже про курсор)
        L.push("    cursor = { enable_hyprcursor = false },");
        if (af === "weak" || af === "strong") L.push("    debug = { damage_tracking = 1 },");
        L.push("    input = {");
        L.push(`        kb_layout = ${q((i.layouts ?? ["us"]).join(","))}, kb_options = ${q(i.switchKey)},`);
        L.push(`        repeat_delay = ${i.repeatDelay}, repeat_rate = ${i.repeatRate},`);
        L.push(`        sensitivity = ${i.sensitivity}, accel_profile = ${q(i.accel)},`);
        L.push(`        natural_scroll = ${i.naturalScroll}, follow_mouse = ${i.followMouse},`);
        L.push(`        touchpad = { tap_to_click = ${i.tapToClick}, natural_scroll = ${i.tpNatural}, disable_while_typing = ${i.tpTyping},`);
        L.push(`                     clickfinger_behavior = ${i.tpClickfinger}, scroll_factor = ${Number(i.tpScroll).toFixed(2)} },`);
        L.push("    },");
        L.push("})");
        L.push("");
        if (i.gestures) L.push(`hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })`, "");

        const style = { popin: "popin 87%", slide: "slide", gnomed: "gnomed", fade: "popin 100%" }[w.animation] ?? "popin 87%";
        const sp = Math.max(0.1, a.animSpeed);
        L.push(`hl.animation({ leaf = "windowsIn", enabled = true, speed = ${(4.1 / sp).toFixed(2)}, spring = "easy", style = ${q(style)} })`);
        L.push(`hl.animation({ leaf = "windowsOut", enabled = true, speed = ${(1.49 / sp).toFixed(2)}, bezier = "linear", style = ${q(style)} })`);
        L.push(`hl.animation({ leaf = "windows", enabled = true, speed = ${(4.79 / sp).toFixed(2)}, spring = "easy" })`);
        L.push("");

        // ---- мониторы (Настройки → Мониторы) ----
        const mons = Settings.displays.monitors ?? [];
        if (mons.length) {
            L.push(I18n.tr("-- Мониторы"));
            for (const c of mons) L.push(Displays.lua(c));
            L.push("");
        }

        // ---- окружение ----
        L.push(`hl.env("XCURSOR_THEME", ${q(a.cursorTheme)})`);
        L.push(`hl.env("XCURSOR_SIZE", ${q(a.cursorSize)})`);
        L.push(`hl.env("HYPRCURSOR_SIZE", ${q(a.cursorSize)})`);
        L.push(`hl.env("QS_ICON_THEME", ${q(a.iconTheme)})`);
        // Qt-приложения берут палитру Cove из qt6ct (services/AppThemes.qml)
        if (AppThemes.active("qt")) L.push(`hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")`);
        L.push("");

        // ---- хоткеи ----
        L.push(I18n.tr("-- Хоткеи"));
        for (const b of Settings.binds ?? []) {
            if (b.enabled === false) continue;
            const act = Actions.get(b.action);
            if (!act || !b.key) continue;
            const flags = [];
            if (b.locked) flags.push("locked = true");
            if (b.repeating) flags.push("repeating = true");
            if (act.mouse) flags.push("mouse = true");
            const opts = flags.length ? `, { ${flags.join(", ")} }` : "";
            L.push(`hl.bind(${q(Binds.combo(b))}, ${act.lua(b.arg ?? "")}${opts})`);
        }
        L.push("");

        // ---- правила окон ----
        L.push(I18n.tr("-- Правила окон"));
        (Settings.rules ?? []).forEach((r, n) => {
            if (r.enabled === false || !r.value) return;
            const f = [];
            const field = r.matchBy === "title" ? "title" : "class";
            f.push(`name = "qs-rule-${n}"`);
            f.push(`match = { ${field} = ${q(r.exact ? "^(" + r.value + ")$" : r.value)} }`);
            if (r.workspace) f.push(`workspace = ${q(r.workspace + (r.silent ? " silent" : ""))}`);
            if (r.float) f.push("float = true");
            if (r.float && r.size) f.push(`size = ${q(r.size)}`);
            if (r.center) f.push("center = true");
            if (r.pin) f.push("pin = true");
            if (r.fullscreen) f.push("fullscreen = true");
            if (r.maximize) f.push("maximize = true");
            if (r.opacity && r.opacity < 1) f.push(`opacity = ${q(r.opacity)}`);
            if (r.noBlur) f.push("no_blur = true");
            if (r.noAnim) f.push("no_anim = true");
            if (r.idleInhibit) f.push(`idle_inhibit = "fullscreen"`);
            L.push(`hl.window_rule({ ${f.join(", ")} })`);
        });
        // окно настроек шелла
        L.push(`hl.window_rule({ name = "qs-satty", match = { class = "^(com.gabm.satty)$" }, float = true, size = "1400 860", center = true })`);
        // стеклянный лаунчер; сплошной фон непрозрачен — размытие под ним не видно
        L.push(`hl.layer_rule({ name = "qs-launcher-blur", match = { namespace = "^qs-launcher$" }, blur = true, ignore_alpha = 0.3 })`);
        // стеклянные виджеты рабочего стола; тени и затемнение редактора (альфа < 0.4) не размываем
        L.push(`hl.layer_rule({ name = "qs-desktop-blur", match = { namespace = "^qs-desktop$" }, blur = true, ignore_alpha = 0.4 })`);
        // материал «стекло/матовое/акрил»: размытие под ящиками, островом и меню шелла.
        // ignore_alpha ниже альфы фона, но выше альфы теней (0.38 × сила) — тени не размываются
        if (Theme.glassy) {
            const ia = Math.max(0.1, Math.min(0.42, Theme.panelAlpha - 0.08)).toFixed(2);
            L.push(`hl.layer_rule({ name = "qs-material-blur", match = { namespace = "^qs-(drawer|island|session|overview|cheatsheet|polkit|welcome|translate)$" }, blur = true, ignore_alpha = ${ia} })`);
        }
        // размытие обоев под полупрозрачной панелью; ignore_alpha — чтобы не размывать тени
        if (Settings.bar.bodyOpacity < 0.98 || Settings.bar.style === "notch" || Settings.bar.style === "islands" || Theme.glassy)
            L.push(`hl.layer_rule({ name = "qs-bar-blur", match = { namespace = "^qs-bar$" }, blur = true, ignore_alpha = ${Settings.bar.style === "notch" ? "0.3" : Settings.bar.bodyOpacity > 0.02 ? Math.min(0.3, Settings.bar.bodyOpacity * 0.5).toFixed(2) : "0.4"} })`);
        L.push('hl.window_rule({ name = "qs-settings", match = { title = "^(Настройки Quickshell|Quickshell Settings)$" }, float = true, size = "1180 760", center = true })');
        L.push("");

        // ---- автозапуск ----
        const auto = (Settings.autostart ?? []).filter(x => x.enabled !== false && x.command);
        if (auto.length) {
            L.push("hl.on(\"hyprland.start\", function ()");
            for (const x of auto) L.push(`    hl.exec_cmd(${q(x.command)})`);
            L.push("end)");
        }
        return L.join("\n") + "\n";
    }

    function generateIdle(): string {
        const d = Settings.idle;
        const L = [
            I18n.tr("# Сгенерировано Quickshell — меняйте в Настройках → Система"),
            "general {",
            "    lock_cmd = qs ipc call lock lock || (pidof hyprlock || hyprlock)",
            "    before_sleep_cmd = loginctl lock-session",
            `    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'`,
            "}", ""
        ];
        if (d.lockMinutes > 0) L.push("listener {", `    timeout = ${d.lockMinutes * 60}`, "    on-timeout = loginctl lock-session", "}", "");
        if (d.dpmsMinutes > 0) L.push("listener {", `    timeout = ${d.dpmsMinutes * 60}`,
            `    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'`,
            `    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'`, "}", "");
        if (d.suspendMinutes > 0) L.push("listener {", `    timeout = ${d.suspendMinutes * 60}`, "    on-timeout = systemctl suspend", "}", "");
        return L.join("\n");
    }

    function apply(): void {
        if (!(Settings.binds ?? []).length) { Binds.ensureDefaults(); return; } // после сброса настроек
        const text = generate();
        if (text === genFile.text()) return;
        genFile.setText(text);
        reloadProc.running = true;
    }

    function applyIdle(): void {
        const text = generateIdle();
        if (text === idleFile.text()) return;
        idleFile.setText(text);
        Quickshell.execDetached(["sh", "-c", "pkill -x hypridle; sleep 0.3; setsid hypridle >/dev/null 2>&1 &"]);
    }

    function init(): void {
        Binds.ensureDefaults();
        root.lastGood = genFile.text();
        root.appliedCursor = JSON.stringify(root.cursor);
        debounce.restart();
        idleDebounce.restart();
    }

    Timer { id: debounce; interval: 500; onTriggered: root.apply() }

    IpcHandler {
        target: "hyprconfig"
        // qs ipc call hyprconfig status — последняя ошибка и совпадает ли файл с тем, что сгенерировал бы шелл
        function status(): string { return JSON.stringify({ error: root.lastError, upToDate: root.generate() === genFile.text(), material: Theme.material }); }
        function apply(): void { root.apply(); }
    }

    // курсор: env в generated.lua видят только новые процессы — применяем сразу
    // самому Hyprland (setcursor) и GTK-приложениям (gsettings)
    // при старте не трогаем: тему уже задал env.
    // hyprcursor выключен в generated.lua (cursor.enable_hyprcursor = false): иначе при пустом
    // HYPRCURSOR_THEME Hyprland 0.56 сам берёт первую найденную hyprcursor-тему, и setcursor
    // на xcursor-тему во время её анимации роняет его (tickAnimatedCursor, bad_variant_access).
    // Сами hyprcursor-темы на всякий случай вынесены в ~/.local/share/hyprcursor-disabled.
    readonly property var cursor: [Settings.appearance.cursorTheme, Settings.appearance.cursorSize]
    property string appliedCursor: ""
    onCursorChanged: {
        if (root.appliedCursor === "" || root.appliedCursor === JSON.stringify(root.cursor)) return;
        root.appliedCursor = JSON.stringify(root.cursor);
        cursorDebounce.restart();
    }
    Timer {
        id: cursorDebounce
        interval: 250
        onTriggered: Quickshell.execDetached(["sh", "-c",
            'hyprctl setcursor "$1" "$2"; gsettings set org.gnome.desktop.interface cursor-theme "$1"; gsettings set org.gnome.desktop.interface cursor-size "$2"',
            "_", Settings.appearance.cursorTheme, String(Settings.appearance.cursorSize)])
    }
    Timer { id: idleDebounce; interval: 800; onTriggered: root.applyIdle() }

    // любые изменения нужных разделов и цвета — перегенерация
    property var watch: [
        JSON.stringify(Settings.binds), JSON.stringify(Settings.rules), JSON.stringify(Settings.autostart),
        Settings.windows.gapsIn, Settings.windows.gapsOut, Settings.windows.borderSize, Settings.windows.borderGradient,
        Settings.windows.rounding, Settings.windows.blur, Settings.windows.blurSize, Settings.windows.blurPasses,
        Settings.windows.shadow, Settings.windows.shadowRange, Settings.windows.activeOpacity, Settings.windows.inactiveOpacity,
        Settings.windows.dimInactive, Settings.windows.dimStrength, Settings.windows.glow, Settings.windows.layout, Settings.windows.animation,
        JSON.stringify(Settings.input.layouts), Settings.input.switchKey, Settings.input.repeatDelay, Settings.input.repeatRate,
        Settings.input.sensitivity, Settings.input.accel, Settings.input.naturalScroll, Settings.input.followMouse,
        Settings.input.tapToClick, Settings.input.tpNatural, Settings.input.tpTyping, Settings.input.tpClickfinger, Settings.input.tpScroll, Settings.input.gestures,
        Settings.nightLight.antiFlash,
        Settings.appearance.animations, Settings.appearance.animSpeed, Settings.appearance.cursorTheme, Settings.appearance.cursorSize, Settings.appearance.iconTheme,
        Settings.bar.bodyOpacity, Settings.bar.style, JSON.stringify(Settings.displays.monitors), Theme.material, Theme.panelAlpha,
        Settings.general.terminal, Settings.general.browser, Settings.general.fileManager, Settings.general.editor,
        Theme.accent, Theme.accent2, Theme.surface0, AppThemes.active("qt")
    ]
    onWatchChanged: debounce.restart()
    property var watchIdle: [Settings.idle.lockMinutes, Settings.idle.dpmsMinutes, Settings.idle.suspendMinutes]
    onWatchIdleChanged: idleDebounce.restart()

    FileView { id: genFile; path: root.hyprDir + "/generated.lua"; blockLoading: true }
    FileView { id: idleFile; path: root.hyprDir + "/hypridle.conf"; blockLoading: true }

    Process {
        id: reloadProc
        command: [Quickshell.shellPath("assets/hypr-reload.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err === "") {
                    root.lastError = "";
                    root.lastGood = genFile.text();
                } else {
                    root.lastError = err;
                    console.warn("Hyprland config error:", err);
                    if (root.lastGood !== "") {
                        genFile.setText(root.lastGood);
                        Quickshell.execDetached([Quickshell.shellPath("assets/hypr-reload.sh")]);
                    }
                    Quickshell.execDetached(["notify-send", "-a", I18n.tr("Настройки"), "-u", "critical",
                        I18n.tr("Ошибка в конфиге Hyprland"), I18n.tr("Изменение отменено:\n") + err.slice(0, 300)]);
                }
            }
        }
    }
}
