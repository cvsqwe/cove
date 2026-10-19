pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Каталог действий для хоткеев и командной палитры.
// Каждое действие умеет превращаться в Lua-диспатчер Hyprland (lua(arg)) и выполняться сразу (run(arg)).
Singleton {
    id: root

    function q(s): string { return JSON.stringify(String(s ?? "")); }
    function exec(cmd: string): string { return `hl.dsp.exec_cmd(${q(cmd)})`; }
    function ipc(target: string, fn: string): string { return exec(`qs ipc call ${target} ${fn}`); }

    readonly property var dirs: [
        { value: "left", label: I18n.tr("влево") }, { value: "right", label: I18n.tr("вправо") },
        { value: "up", label: I18n.tr("вверх") }, { value: "down", label: I18n.tr("вниз") }
    ]
    function dirLabel(d: string): string { return dirs.find(x => x.value === d)?.label ?? d; }
    function resizeDelta(d: string): string {
        return d === "left" ? "x = -40, y = 0" : d === "right" ? "x = 40, y = 0" : d === "up" ? "x = 0, y = -40" : "x = 0, y = 40";
    }

    // arg: "" | "dir" | "ws" | "text" | "app" | "special"
    readonly property var list: [
        // ---- шелл ----
        { id: "shell.launcher", group: I18n.tr("Шелл"), icon: "󰍉", label: I18n.tr("Лаунчер"), lua: () => ipc("launcher", "toggle") },
        { id: "shell.clipboard", group: I18n.tr("Шелл"), icon: "󰅌", label: I18n.tr("История буфера обмена"), lua: () => ipc("launcher", "clipboard") },
        { id: "shell.palette", group: I18n.tr("Шелл"), icon: "󰘳", label: I18n.tr("Командная палитра"), lua: () => ipc("launcher", "palette") },
        { id: "shell.desktopEdit", group: I18n.tr("Шелл"), icon: "󰖲", label: I18n.tr("Редактор виджетов"), lua: () => ipc("desktop", "edit") },
        { id: "shell.control", group: I18n.tr("Шелл"), icon: "󰒓", label: I18n.tr("Центр управления"), lua: () => ipc("control", "toggle") },
        { id: "shell.dashboard", group: I18n.tr("Шелл"), icon: "󰕮", label: I18n.tr("Дашборд острова"), lua: () => ipc("dashboard", "toggle") },
        { id: "shell.overview", group: I18n.tr("Шелл"), icon: "󰕰", label: I18n.tr("Обзор воркспейсов"), lua: () => ipc("overview", "toggle") },
        { id: "shell.wallpaper", group: I18n.tr("Шелл"), icon: "󰸉", label: I18n.tr("Выбор обоев"), lua: () => ipc("wallpaper", "toggle") },
        { id: "shell.session", group: I18n.tr("Шелл"), icon: "󰐥", label: I18n.tr("Меню питания"), lua: () => ipc("session", "toggle") },
        { id: "shell.settings", group: I18n.tr("Шелл"), icon: "󰒓", label: I18n.tr("Настройки"), lua: () => ipc("settings", "toggle") },
        { id: "shell.cheatsheet", group: I18n.tr("Шелл"), icon: "󰌌", label: I18n.tr("Шпаргалка хоткеев"), lua: () => ipc("cheatsheet", "toggle") },
        { id: "shell.notes", group: I18n.tr("Шелл"), icon: "󰎞", label: I18n.tr("Заметки"), lua: () => ipc("notes", "toggle") },
        { id: "shell.focus", group: I18n.tr("Шелл"), icon: "󰔟", label: I18n.tr("Фокус-таймер (старт/стоп)"), lua: () => ipc("focus", "toggle") },
        { id: "shell.record", group: I18n.tr("Шелл"), icon: "󰑋", label: I18n.tr("Запись экрана (старт/стоп)"), lua: () => ipc("record", "toggle") },
        { id: "shell.recordRegion", group: I18n.tr("Шелл"), icon: "󰩬", label: I18n.tr("Запись области"), lua: () => ipc("record", "region") },
        { id: "shell.ocr", group: I18n.tr("Шелл"), icon: "document_scanner", label: I18n.tr("Текст с экрана"), lua: () => ipc("lens", "text") },
        { id: "shell.qr", group: I18n.tr("Шелл"), icon: "qr_code_scanner", label: I18n.tr("QR-код с экрана"), lua: () => ipc("lens", "qr") },
        { id: "shell.assistant", group: I18n.tr("Шелл"), icon: "auto_awesome", label: I18n.tr("Ассистент"), lua: () => ipc("launcher", "assistant") },
        { id: "shell.picker", group: I18n.tr("Шелл"), icon: "󰈊", label: I18n.tr("Пипетка цвета"), lua: () => ipc("picker", "pick") },
        { id: "shell.shotArea", group: I18n.tr("Шелл"), icon: "󰩭", label: I18n.tr("Скриншот области"), lua: () => ipc("screenshot", "area") },
        { id: "shell.shotScreen", group: I18n.tr("Шелл"), icon: "󰹑", label: I18n.tr("Скриншот экрана"), lua: () => ipc("screenshot", "screen") },
        { id: "shell.shotWindow", group: I18n.tr("Шелл"), icon: "󰖯", label: I18n.tr("Скриншот окна"), lua: () => ipc("screenshot", "window") },
        { id: "shell.widgets", group: I18n.tr("Шелл"), icon: "󰖲", label: I18n.tr("Редактировать виджеты"), lua: () => ipc("desktop", "edit") },
        { id: "shell.restart", group: I18n.tr("Шелл"), icon: "󰜉", label: I18n.tr("Перезапустить шелл"), lua: () => exec("pkill -x qs; qs") },

        // ---- переключатели ----
        { id: "toggle.dnd", group: I18n.tr("Переключатели"), icon: "󰂛", label: I18n.tr("Не беспокоить"), lua: () => ipc("toggles", "dnd") },
        { id: "toggle.night", group: I18n.tr("Переключатели"), icon: "󰖔", label: I18n.tr("Ночной свет"), lua: () => ipc("toggles", "nightLight") },
        { id: "toggle.caffeine", group: I18n.tr("Переключатели"), icon: "󰅶", label: I18n.tr("Не засыпать"), lua: () => ipc("toggles", "caffeine") },
        { id: "toggle.game", group: I18n.tr("Переключатели"), icon: "󰊴", label: I18n.tr("Игровой режим"), lua: () => ipc("toggles", "gameMode") },
        { id: "toggle.theme", group: I18n.tr("Переключатели"), icon: "󰔎", label: I18n.tr("Светлая / тёмная тема"), lua: () => ipc("toggles", "light") },

        // ---- приложения ----
        { id: "app.terminal", group: I18n.tr("Приложения"), icon: "", label: I18n.tr("Терминал"), lua: () => exec(Settings.general.terminal) },
        { id: "app.browser", group: I18n.tr("Приложения"), icon: "󰖟", label: I18n.tr("Браузер"), lua: () => exec(Settings.general.browser) },
        { id: "app.files", group: I18n.tr("Приложения"), icon: "󰉋", label: I18n.tr("Файловый менеджер"), lua: () => exec(Settings.general.fileManager) },
        { id: "app.editor", group: I18n.tr("Приложения"), icon: "󰨞", label: I18n.tr("Редактор"), lua: () => exec(Settings.general.editor) },
        { id: "app.launch", group: I18n.tr("Приложения"), icon: "󰀻", label: I18n.tr("Запустить приложение"), arg: "app",
          lua: a => exec(`gtk-launch ${String(a).replace(/\.desktop$/, "")}`) },
        { id: "exec", group: I18n.tr("Приложения"), icon: "", label: I18n.tr("Своя команда"), arg: "text", lua: a => exec(a) },

        // ---- окна ----
        { id: "win.close", group: I18n.tr("Окна"), icon: "󰅖", label: I18n.tr("Закрыть окно"), lua: () => "hl.dsp.window.close()" },
        { id: "win.kill", group: I18n.tr("Окна"), icon: "󰚌", label: I18n.tr("Убить окно"), lua: () => "hl.dsp.window.kill()" },
        { id: "win.float", group: I18n.tr("Окна"), icon: "󰖲", label: I18n.tr("Плавающее / плитка"), lua: () => `hl.dsp.window.float({ action = "toggle" })` },
        { id: "win.fullscreen", group: I18n.tr("Окна"), icon: "󰊓", label: I18n.tr("Во весь экран"), lua: () => "hl.dsp.window.fullscreen()" },
        { id: "win.maximize", group: I18n.tr("Окна"), icon: "󰁌", label: I18n.tr("Развернуть"), lua: () => `hl.dsp.window.fullscreen({ mode = "maximized" })` },
        { id: "win.pin", group: I18n.tr("Окна"), icon: "󰐃", label: I18n.tr("Закрепить поверх"), lua: () => "hl.dsp.window.pin()" },
        { id: "win.pseudo", group: I18n.tr("Окна"), icon: "󰘖", label: I18n.tr("Псевдо-плитка"), lua: () => "hl.dsp.window.pseudo()" },
        { id: "win.center", group: I18n.tr("Окна"), icon: "󰘞", label: I18n.tr("По центру"), lua: () => "hl.dsp.window.center()" },
        { id: "win.split", group: I18n.tr("Окна"), icon: "󰯌", label: I18n.tr("Сменить разделение"), lua: () => `hl.dsp.layout("togglesplit")` },
        { id: "win.group", group: I18n.tr("Окна"), icon: "󰓩", label: I18n.tr("Группа вкладок"), lua: () => "hl.dsp.group.toggle()" },
        { id: "win.cycle", group: I18n.tr("Окна"), icon: "󰒭", label: I18n.tr("Следующее окно"), lua: () => "hl.dsp.window.cycle_next()" },
        { id: "win.focus", group: I18n.tr("Окна"), icon: "󰁔", label: I18n.tr("Фокус"), arg: "dir", lua: a => `hl.dsp.focus({ direction = ${q(a)} })` },
        { id: "win.move", group: I18n.tr("Окна"), icon: "󰁁", label: I18n.tr("Переместить окно"), arg: "dir", lua: a => `hl.dsp.window.move({ direction = ${q(a)} })` },
        { id: "win.swap", group: I18n.tr("Окна"), icon: "󰓡", label: I18n.tr("Поменять местами"), arg: "dir", lua: a => `hl.dsp.window.swap({ direction = ${q(a)} })` },
        { id: "win.resize", group: I18n.tr("Окна"), icon: "󰩨", label: I18n.tr("Изменить размер"), arg: "dir", lua: a => `hl.dsp.window.resize({ ${resizeDelta(a)}, relative = true })` },
        { id: "win.drag", group: I18n.tr("Окна"), icon: "󰆾", label: I18n.tr("Перетаскивать мышью"), mouse: true, lua: () => "hl.dsp.window.drag()" },
        { id: "win.resizeMouse", group: I18n.tr("Окна"), icon: "󰩨", label: I18n.tr("Тянуть размер мышью"), mouse: true, lua: () => "hl.dsp.window.resize()" },

        // ---- воркспейсы ----
        { id: "ws.focus", group: I18n.tr("Воркспейсы"), icon: "󰍹", label: I18n.tr("Перейти на воркспейс"), arg: "ws", lua: a => `hl.dsp.focus({ workspace = ${q(a)} })` },
        { id: "ws.move", group: I18n.tr("Воркспейсы"), icon: "󰍺", label: I18n.tr("Перенести окно на воркспейс"), arg: "ws", lua: a => `hl.dsp.window.move({ workspace = ${q(a)} })` },
        { id: "ws.moveSilent", group: I18n.tr("Воркспейсы"), icon: "󰍺", label: I18n.tr("Перенести окно (не переходя)"), arg: "ws", lua: a => `hl.dsp.window.move({ workspace = ${q(a)}, follow = false })` },
        { id: "ws.next", group: I18n.tr("Воркспейсы"), icon: "󰒭", label: I18n.tr("Следующий воркспейс"), lua: () => `hl.dsp.focus({ workspace = "e+1" })` },
        { id: "ws.prev", group: I18n.tr("Воркспейсы"), icon: "󰒮", label: I18n.tr("Предыдущий воркспейс"), lua: () => `hl.dsp.focus({ workspace = "e-1" })` },
        { id: "ws.previous", group: I18n.tr("Воркспейсы"), icon: "󰕍", label: I18n.tr("Вернуться на прошлый"), lua: () => `hl.dsp.focus({ workspace = "previous" })` },
        { id: "ws.special", group: I18n.tr("Воркспейсы"), icon: "󰆍", label: I18n.tr("Скрытый воркспейс"), arg: "special", lua: a => `hl.dsp.workspace.toggle_special(${q(a || "magic")})` },
        { id: "ws.toSpecial", group: I18n.tr("Воркспейсы"), icon: "󰆍", label: I18n.tr("Окно в скрытый воркспейс"), arg: "special", lua: a => `hl.dsp.window.move({ workspace = ${q("special:" + (a || "magic"))} })` },

        // ---- медиа ----
        { id: "media.volUp", group: I18n.tr("Медиа"), icon: "󰝝", label: I18n.tr("Громче"), lua: () => exec("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+") },
        { id: "media.volDown", group: I18n.tr("Медиа"), icon: "󰝞", label: I18n.tr("Тише"), lua: () => exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
        { id: "media.mute", group: I18n.tr("Медиа"), icon: "󰝟", label: I18n.tr("Без звука"), lua: () => exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
        { id: "media.micMute", group: I18n.tr("Медиа"), icon: "󰍭", label: I18n.tr("Выключить микрофон"), lua: () => exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") },
        { id: "media.play", group: I18n.tr("Медиа"), icon: "󰐎", label: I18n.tr("Пауза / играть"), lua: () => exec("playerctl play-pause") },
        { id: "media.next", group: I18n.tr("Медиа"), icon: "󰒭", label: I18n.tr("Следующий трек"), lua: () => exec("playerctl next") },
        { id: "media.prev", group: I18n.tr("Медиа"), icon: "󰒮", label: I18n.tr("Предыдущий трек"), lua: () => exec("playerctl previous") },
        { id: "media.brightUp", group: I18n.tr("Медиа"), icon: "󰃠", label: I18n.tr("Ярче"), lua: () => exec("brightnessctl -e4 -n2 set 5%+") },
        { id: "media.brightDown", group: I18n.tr("Медиа"), icon: "󰃞", label: I18n.tr("Темнее"), lua: () => exec("brightnessctl -e4 -n2 set 5%-") },

        // ---- система ----
        { id: "sys.dpms", group: I18n.tr("Система"), icon: "󰶐", label: I18n.tr("Выключить экран"), lua: () => `hl.dsp.dpms({ action = "toggle" })` },
        { id: "sys.exit", group: I18n.tr("Система"), icon: "󰍃", label: I18n.tr("Выйти из Hyprland"), lua: () => "hl.dsp.exit()" },
        { id: "sys.suspend", group: I18n.tr("Система"), icon: "󰤄", label: I18n.tr("Сон"), lua: () => exec("systemctl suspend") },
        { id: "sys.reboot", group: I18n.tr("Система"), icon: "󰜉", label: I18n.tr("Перезагрузка"), lua: () => exec("systemctl reboot") },
        { id: "sys.poweroff", group: I18n.tr("Система"), icon: "󰐥", label: I18n.tr("Выключение"), lua: () => exec("systemctl poweroff") }
    ]

    readonly property var groups: [...new Set(list.map(x => x.group))]

    function get(id: string): var { return list.find(x => x.id === id) ?? null; }

    function describe(bind): string {
        const a = get(bind.action);
        if (!a) return bind.action;
        if (bind.label) return bind.label;
        switch (a.arg) {
        case "dir": return `${a.label} ${dirLabel(bind.arg)}`;
        case "ws": return `${a.label} ${bind.arg}`;
        case "text": return bind.arg || a.label;
        case "app": {
            const e = DesktopEntries.byId(String(bind.arg ?? "").replace(/\.desktop$/, ""));
            return e ? I18n.tr("Запустить {0}", e.name) : a.label;
        }
        default: return a.label;
        }
    }

    function lua(action: string, arg): string {
        const a = get(action);
        return a ? a.lua(arg ?? "") : "";
    }

    // выполнить действие прямо сейчас (из командной палитры)
    function run(action: string, arg): void {
        const l = lua(action, arg);
        if (l !== "") Hyprland.dispatch(l);
    }
}
