"""Vesktop: включает тему cove.theme.css в настройках Vencord (сами настройки не трогаем)."""
PATH = "~/.config/vesktop/settings/settings.json"
NAME = "cove.theme.css"


def apply(ctx, api):
    def on(d):
        t = d.setdefault("enabledThemes", [])
        if NAME not in t:
            t.append(NAME)
    api.edit_json(PATH, on)
    return "ok"


def disable(api):
    def off(d):
        d["enabledThemes"] = [x for x in d.get("enabledThemes", []) if x != NAME]
    api.edit_json(PATH, off)
