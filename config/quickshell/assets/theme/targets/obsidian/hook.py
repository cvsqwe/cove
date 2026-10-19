"""Obsidian: сниппет cove.css в каждом хранилище + светлая/тёмная тема по режиму Cove."""
import os

SNIPPET = "cove"


def vaults(api):
    data = api.load_json(os.path.expanduser("~/.config/obsidian/obsidian.json"), {})
    return [v["path"] for v in data.get("vaults", {}).values() if os.path.isdir(v.get("path", ""))]


def apply(ctx, api):
    css = ctx.render(open(os.path.join(os.path.dirname(__file__), "cove.css")).read())
    vs = vaults(api)
    for v in vs:
        api.write(os.path.join(v, ".obsidian", "snippets", SNIPPET + ".css"), css)

        def on(d):
            s = d.setdefault("enabledCssSnippets", [])
            if SNIPPET not in s:
                s.append(SNIPPET)
            d["theme"] = "moonstone" if ctx.light else "obsidian"
        api.edit_json(os.path.join(v, ".obsidian", "appearance.json"), on)
    return "ok" if vs else "ok: хранилищ пока нет"


def disable(api):
    for v in vaults(api):
        api.restore(os.path.join(v, ".obsidian", "snippets", SNIPPET + ".css"))
        api.edit_json(os.path.join(v, ".obsidian", "appearance.json"),
                      lambda d: d.__setitem__("enabledCssSnippets", [x for x in d.get("enabledCssSnippets", []) if x != SNIPPET]))
