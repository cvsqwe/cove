"""Qt: qt6ct.conf со своей палитрой, стилем Fusion, шрифтом и значками (остальные ключи пользователя не трогаем)."""


def apply(ctx, api):
    pt = round(float(ctx.look["fontSize"]) * 0.75)
    vals = {
        "color_scheme_path": ctx.home + "/.config/qt6ct/colors/cove.conf",
        "custom_palette": "true",
        "style": "Fusion",
    }
    if ctx.look.get("iconTheme"):
        vals["icon_theme"] = ctx.look["iconTheme"]
    api.edit_ini("~/.config/qt6ct/qt6ct.conf", "Appearance", vals)
    api.edit_ini("~/.config/qt6ct/qt6ct.conf", "Fonts", {
        "general": f'"{ctx.look["font"]},{pt},-1,5,400,0,0,0,0,0,0,0,0,0,0,1"',
        "fixed": f'"{ctx.look["mono"]},{pt},-1,5,400,0,0,0,0,0,0,0,0,0,0,1"',
    })
    return "ok"


def disable(api):
    api.edit_ini("~/.config/qt6ct/qt6ct.conf", "Appearance", {"custom_palette": "false"})
