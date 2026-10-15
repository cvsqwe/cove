-- Окружение на Quickshell: автозапуск, хоткеи, правила окон.
-- Подключается из hyprland.lua через require("shell").

local mainMod = "SUPER"

---- АВТОЗАПУСК ----
hl.on("hyprland.start", function ()
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

---- ПЕРЕМЕННЫЕ ----
hl.env("GTK_THEME", "adw-gtk3-dark")

---- ХОТКЕИ ----
-- Хоткеи, вид окон, ввод, правила и автозапуск генерирует Quickshell из Настроек:
-- см. generated.lua (подключается в конце этого файла).

---- ПРАВИЛА ОКОН ----
hl.window_rule({
    name  = "floating-terminal",
    match = { class = "floating" },
    float = true,
    size  = "900 600",
    center = true,
})

hl.window_rule({
    name  = "pip",
    match = { title = "Picture-in-Picture|Картинка в картинке" },
    float = true,
    pin   = true,
})

---- РАЗНОЕ ----
hl.config({
    misc = {
        -- если экран блокировки Quickshell упадёт, его можно перезапустить (или запустить hyprlock)
        allow_session_lock_restore = true,
    },
})

-- размытие под полупрозрачным обзором
hl.layer_rule({ name = "qs-overview-blur", match = { namespace = "^qs-overview$" }, blur = true })

-- Сгенерированное из Настроек — последним, чтобы перекрывать значения выше
local ok, err = pcall(require, "generated")
if not ok then hl.notification.create({ text = "generated.lua: " .. tostring(err), timeout = 8000 }) end
