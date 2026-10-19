"""GTK: светлая/тёмная тема, шрифт и значки через gsettings + settings.ini для приложений без dconf."""
import os


def apply(ctx, api):
    dark = not ctx.light
    theme = "adw-gtk3-dark" if dark else "adw-gtk3"
    font = f"{ctx.look['font']} {round(float(ctx.look['fontSize']) * 0.75)}"
    s = "org.gnome.desktop.interface"
    # смена gtk-theme заставляет открытые GTK3-окна перечитать gtk.css
    api.run("gsettings", "set", s, "gtk-theme", "Adwaita")
    api.run("gsettings", "set", s, "gtk-theme", theme)
    api.run("gsettings", "set", s, "color-scheme", "prefer-dark" if dark else "prefer-light")
    api.run("gsettings", "set", s, "font-name", font)
    if ctx.look.get("iconTheme"):
        api.run("gsettings", "set", s, "icon-theme", ctx.look["iconTheme"])
    for v in ("gtk-3.0", "gtk-4.0"):
        vals = {"gtk-theme-name": theme, "gtk-font-name": font,
                "gtk-application-prefer-dark-theme": "1" if dark else "0"}
        if ctx.look.get("iconTheme"):
            vals["gtk-icon-theme-name"] = ctx.look["iconTheme"]
        api.edit_ini(f"~/.config/{v}/settings.ini", "Settings", vals)
    return "ok"
