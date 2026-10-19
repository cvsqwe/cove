#!/usr/bin/env python3
"""Движок тем Cove: палитра шелла -> шаблоны -> конфиги приложений.

Каждая цель — папка в targets/<id>/ с target.json, шаблонами и (по желанию) hook.py.

    cove-theme.py status                 список целей в JSON (установлено ли приложение)
    cove-theme.py apply [id ...]          применить (без id — все установленные)
    cove-theme.py disable <id>            убрать тему Cove и вернуть прежний конфиг

Данные: палитра ~/.cache/cove/palette.json (пишет services/Recolor.qml),
вид ~/.cache/cove/look.json (шрифт, скругления, значки, обои).
Переопределить можно через --palette '<json>' и --look '<json>'.

Синтаксис шаблонов: {{ имя | фильтр:арг | ... }}
    имена   — ключи палитры (accent, base, text...), а также mode, font, fontSize, radius, iconTheme, wallpaper
    фильтры — strip (без #), rgb («r, g, b»), rgba:0.5, alpha:0.5 (#rrggbbaa), argb (#aarrggbb),
              mix:другой:0.3, lighten:0.1, darken:0.1, pt (px -> pt), int
    {{ light ? светлое : тёмное }} — выбор по режиму
Чужие файлы не затираются молча: перед первой записью делается копия <файл>.cove-bak,
disable возвращает её на место.
"""

import importlib.util
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TARGETS = os.path.join(HERE, "targets")
HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", HOME + "/.cache"), "cove")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME", HOME + "/.local/state"), "cove")
OWNED = os.path.join(STATE, "theme-owned.json")
MARK = "Cove"  # подпись в сгенерированных файлах


# ---------- цвета ----------

class Color:
    def __init__(self, h):
        h = h.lstrip("#")
        if len(h) == 3:
            h = "".join(ch * 2 for ch in h)
        self.r, self.g, self.b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
        self.a = int(h[6:8], 16) / 255 if len(h) >= 8 else 1.0

    @staticmethod
    def of(r, g, b, a=1.0):
        c = Color("000000")
        c.r, c.g, c.b = (max(0, min(255, round(v))) for v in (r, g, b))
        c.a = a
        return c

    def mix(self, other, t):
        t = float(t)
        return Color.of(self.r + (other.r - self.r) * t, self.g + (other.g - self.g) * t,
                        self.b + (other.b - self.b) * t, self.a)

    def lighten(self, t): return self.mix(Color("ffffff"), t)
    def darken(self, t): return self.mix(Color("000000"), t)

    def hex(self): return "#%02x%02x%02x" % (self.r, self.g, self.b)
    def strip(self): return self.hex()[1:]
    def rgb(self): return f"{self.r}, {self.g}, {self.b}"
    def alpha_hex(self, a): return self.hex() + "%02x" % round(float(a) * 255)
    def argb(self): return "#%02x" % round(self.a * 255) + self.strip()
    def luminance(self): return (0.2126 * self.r + 0.7152 * self.g + 0.0722 * self.b) / 255
    def __str__(self): return self.hex()


# ---------- контекст ----------

def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


class Ctx:
    def __init__(self, palette, look):
        self.light = bool(palette.get("light", False))
        self.colors = {k: Color(v) for k, v in palette.items() if isinstance(v, str) and v.startswith("#")}
        self.look = {"font": "Adwaita Sans", "fontSize": 13, "radius": 14, "iconTheme": "Adwaita",
                     "mono": "JetBrainsMono Nerd Font", "wallpaper": ""}
        self.look.update(look or {})
        self.mode = "light" if self.light else "dark"
        self.home = HOME

    def __getitem__(self, k): return self.colors[k]

    def value(self, name):
        if name in self.colors:
            return self.colors[name]
        if name == "mode":
            return self.mode
        if name in self.look:
            return self.look[name]
        raise KeyError(name)

    def render(self, text):
        def expr(m):
            body = m.group(1).strip()
            cond = re.fullmatch(r"light\s*\?\s*(.*?)\s*:\s*(.*)", body, re.S)
            if cond:
                return cond.group(1) if self.light else cond.group(2)
            parts = [p.strip() for p in body.split("|")]
            v = self.value(parts[0])
            for f in parts[1:]:
                name, *args = f.split(":")
                if name == "strip": v = v.strip()
                elif name == "rgb": v = v.rgb()
                elif name == "rgba": v = f"rgba({v.rgb()}, {args[0]})"
                elif name == "alpha": v = v.alpha_hex(args[0])
                elif name == "argb": v = v.argb()
                elif name == "mix": v = v.mix(self.value(args[0]), args[1])
                elif name == "lighten": v = v.lighten(args[0])
                elif name == "darken": v = v.darken(args[0])
                elif name == "pt": v = round(float(v) * 0.75)
                elif name == "int": v = int(float(v))
                else: raise ValueError(f"неизвестный фильтр {name}")
            return str(v)
        return re.sub(r"\{\{(.*?)\}\}", expr, text, flags=re.S)


# ---------- запись файлов ----------

def owned():
    return set(load_json(OWNED, []))


def save_owned(s):
    os.makedirs(STATE, exist_ok=True)
    with open(OWNED, "w") as f:
        json.dump(sorted(s), f, indent=1)


def write(path, data, mode=None):
    """Пишет файл темы. Если там лежал чужой файл — один раз сохраняет его как .cove-bak."""
    path = os.path.expanduser(path)
    own = owned()
    if os.path.exists(path) and path not in own and not os.path.exists(path + ".cove-bak"):
        shutil.copy2(path, path + ".cove-bak")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".cove-tmp"
    with open(tmp, "wb") as f:
        f.write(data.encode() if isinstance(data, str) else data)
    if mode is not None:
        os.chmod(tmp, mode)
    os.replace(tmp, path)
    if path not in own:
        own.add(path)
        save_owned(own)


def restore(path):
    path = os.path.expanduser(path)
    own = owned()
    if os.path.exists(path + ".cove-bak"):
        os.replace(path + ".cove-bak", path)
    elif path in own and os.path.exists(path):
        os.remove(path)
    own.discard(path)
    save_owned(own)


def edit_json(path, fn):
    """Правит чужой JSON-конфиг на месте (не берёт его во владение)."""
    path = os.path.expanduser(path)
    data = load_json(path, {})
    fn(data)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".cove-tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)


def edit_ini(path, section, values, sep="="):
    """Ставит ключи в INI-подобном файле, не трогая остальное."""
    path = os.path.expanduser(path)
    try:
        lines = open(path).read().splitlines()
    except OSError:
        lines = []
    cur, done, out = None, set(), []
    for ln in lines:
        s = ln.strip()
        if s.startswith("[") and s.endswith("]"):
            if cur == section:
                out += [f"{k}{sep}{v}" for k, v in values.items() if k not in done]
                done.update(values)
            cur = s[1:-1]
        elif section is None or cur == section:
            k = s.split(sep, 1)[0].strip()
            if k in values:
                out.append(f"{k}{sep}{values[k]}")
                done.add(k)
                continue
        out.append(ln)
    rest = {k: v for k, v in values.items() if k not in done}
    if rest:
        if section is not None and cur != section:
            out += ["", f"[{section}]"]
        out += [f"{k}{sep}{v}" for k, v in rest.items()]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")


# ---------- цели ----------

def targets():
    out = []
    for d in sorted(os.listdir(TARGETS)):
        meta = load_json(os.path.join(TARGETS, d, "target.json"), None)
        if meta is not None:
            meta["id"] = d
            meta["dir"] = os.path.join(TARGETS, d)
            out.append(meta)
    return sorted(out, key=lambda t: (t.get("order", 99), t["id"]))


def installed(t):
    det = t.get("detect", {})
    if any(shutil.which(b) for b in det.get("bin", [])):
        return True
    return any(os.path.exists(os.path.expanduser(p)) for p in det.get("path", []))


def hook(t):
    p = os.path.join(t["dir"], "hook.py")
    if not os.path.exists(p):
        return None
    spec = importlib.util.spec_from_file_location("cove_hook_" + t["id"], p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Api:
    """То, что видит hook.py."""
    write = staticmethod(write)
    restore = staticmethod(restore)
    edit_json = staticmethod(edit_json)
    edit_ini = staticmethod(edit_ini)
    load_json = staticmethod(load_json)
    Color = Color

    @staticmethod
    def run(*cmd):
        import subprocess
        try:
            subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=10)
        except (OSError, subprocess.TimeoutExpired):
            pass


def apply(t, ctx):
    for f in t.get("files", []):
        src = open(os.path.join(t["dir"], f["template"])).read()
        write(f["output"], ctx.render(src))
    h = hook(t)
    if h and hasattr(h, "apply"):
        return h.apply(ctx, Api) or "ok"
    return "ok"


def disable(t):
    h = hook(t)
    if h and hasattr(h, "disable"):
        h.disable(Api)
    for f in t.get("files", []):
        restore(f["output"])


def main(argv):
    args, opts = [], {}
    it = iter(argv)
    for a in it:
        if a.startswith("--"):
            opts[a[2:]] = next(it, "")
        else:
            args.append(a)
    cmd = args[0] if args else "status"
    ids = set(args[1:])
    ts = targets()

    if cmd == "status":
        print(json.dumps([{"id": t["id"], "name": t.get("name", t["id"]), "icon": t.get("icon", "palette"),
                           "hint": t.get("hint", ""), "action": t.get("action", ""), "package": t.get("package", ""),
                           "installed": installed(t)} for t in ts], ensure_ascii=False))
        return 0

    if cmd == "apply":
        palette = json.loads(opts["palette"]) if opts.get("palette") else load_json(CACHE + "/palette.json", None)
        look = json.loads(opts["look"]) if opts.get("look") else load_json(CACHE + "/look.json", {})
        if not palette:
            print(json.dumps({"error": "нет палитры"}))
            return 1
        ctx = Ctx(palette, look)
        res = {}
        for t in ts:
            if (ids and t["id"] not in ids) or not installed(t):
                continue
            try:
                res[t["id"]] = apply(t, ctx)
            except Exception as e:  # одна сломанная цель не мешает остальным
                res[t["id"]] = f"error: {e}"
        print(json.dumps(res, ensure_ascii=False))
        return 0

    if cmd == "disable":
        for t in ts:
            if t["id"] in ids:
                disable(t)
        return 0

    if cmd == "action":
        # особое действие цели (например, «открыть тему в Telegram»)
        for t in ts:
            if t["id"] in ids:
                h = hook(t)
                if h and hasattr(h, "action"):
                    h.action(Api)
        return 0

    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
