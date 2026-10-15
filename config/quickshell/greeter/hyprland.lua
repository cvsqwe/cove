-- Минимальный Hyprland для экрана входа: только Quickshell-гритер, после входа — выход.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_options = "grp:alt_shift_toggle",
    },
    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
    },
    animations = { enabled = false },
})

hl.on("hyprland.start", function ()
    hl.exec_cmd("sh -c 'qs -p /etc/greetd/qs-greeter; hyprctl dispatch \"hl.dsp.exit()\"'")
end)
