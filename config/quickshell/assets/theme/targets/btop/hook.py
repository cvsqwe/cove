"""btop: выбрать тему cove (остальные настройки btop.conf не трогаем)."""


def apply(ctx, api):
    api.edit_ini("~/.config/btop/btop.conf", None, {"color_theme": '"cove"', "theme_background": "false"}, sep=" = ")
    return "ok"


def disable(api):
    api.edit_ini("~/.config/btop/btop.conf", None, {"color_theme": '"Default"', "theme_background": "true"}, sep=" = ")
