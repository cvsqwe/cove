#!/usr/bin/env python3
# Собирает конфиги fastfetch Cove: полный (`ff`, ru и en) и компактный для приветствия fish.
# Значки Nerd Font заданы кодами: глифы из личной области Unicode теряются при копировании.
# Цвета только ANSI (magenta — акцент, blue — второй цвет), поэтому всё следует палитре из обоев.
# Запуск: python3 build.py
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOGO = "~/.config/cove/branding/logo.txt"
LOGO_SMALL = "~/.config/cove/branding/logo-small.txt"
SCHEMA = "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json"
DOT = chr(0x25CF)

ICON = {k: chr(v) for k, v in dict(
    os=0xF08C7, kernel=0xF013, uptime=0xF0150, pkgs=0xF03D6, wm=0xF2D2, shell=0xF120, term=0xF489,
    font=0xF031, cpu=0xF4BC, gpu=0xF08AE, mem=0xF035B, disk=0xF02CA, display=0xF0379,
).items()}

TEXT = {
    "ru": dict(sys="система", env="окружение", hw="железо", os="ос", kernel="ядро", uptime="в сети",
               pkgs="пакеты", wm="оконный", shell="оболочка", term="терминал", font="шрифт", cpu="процессор",
               gpu="видео", mem="память", disk="диск", display="экран",
               up="{?days}{days} д {?}{?hours}{hours} ч {?}{minutes} мин", of="из", hz="Гц", threads="потоков"),
    "en": dict(sys="system", env="desktop", hw="hardware", os="os", kernel="kernel", uptime="uptime",
               pkgs="packages", wm="wm", shell="shell", term="terminal", font="font", cpu="cpu",
               gpu="gpu", mem="memory", disk="disk", display="display",
               up="{?days}{days}d {?}{?hours}{hours}h {?}{minutes}m", of="of", hz="Hz", threads="threads"),
}

DISPLAY = {
    "separator": " ",
    "color": {"output": "default"},
    "bar": {"char": {"elapsed": "━", "total": "─"}, "border": None, "width": 12, "color": {"total": "90"}},
    "percent": {"type": ["bar"], "color": {"green": "magenta", "yellow": "yellow", "red": "red"}},
}

PALETTE = {"type": "custom", "format": "".join("{#%d}%s " % (c, DOT) for c in (35, 34, 36, 32, 33, 31)) + "{#90}" + DOT + "{#}"}


def title() -> dict:
    return {"type": "title", "format": "{#1;magenta}{user-name}{#} {#90}·{#} {#blue}{host-name}{#}"}


def full(lang: str) -> dict:
    t = TEXT[lang]

    def key(name: str) -> str:
        return "{#90}│{#} {#blue}" + ICON[name] + "{#}  {#magenta}" + t[name].ljust(10) + "{#}"

    def section(edge: str, name: str) -> dict:
        return {"type": "custom", "format": "{#90}" + edge + "─{#} {#1;magenta}" + t[name] + "{#}"}

    def mod(kind: str, name: str, **opts) -> dict:
        return {"type": kind, "key": key(name), **opts}

    return {
        "$schema": SCHEMA,
        "logo": {"type": "file", "source": LOGO, "color": {"1": "magenta", "2": "blue"},
                 "padding": {"top": 4, "left": 2, "right": 4}},
        "display": DISPLAY,
        "modules": [
            "break",
            title(),
            "break",
            section("╭", "sys"),
            mod("os", "os", format="Cove · {name}"),
            mod("kernel", "kernel", format="{release}"),
            mod("uptime", "uptime", format=t["up"]),
            mod("packages", "pkgs", format="{all}"),
            section("├", "env"),
            mod("wm", "wm", format="{pretty-name} {version}"),
            mod("shell", "shell", format="{pretty-name} {version}"),
            mod("terminal", "term", format="{pretty-name} {version}"),
            mod("terminalfont", "font", format="{name} {size}"),
            section("├", "hw"),
            mod("cpu", "cpu", format="{name} · {cores-logical} " + t["threads"]),
            mod("gpu", "gpu", format="{name}"),
            mod("memory", "mem", format="{percentage-bar} {used} " + t["of"] + " {total}"),
            mod("disk", "disk", folders="/", format="{size-percentage-bar} {size-used} " + t["of"] + " {size-total}"),
            mod("display", "display", format="{width}×{height} · {refresh-rate} " + t["hz"]),
            {"type": "custom", "format": "{#90}╰─{#}"},
            "break",
            {**PALETTE, "format": "   " + PALETTE["format"]},
        ],
    }


def compact() -> dict:
    t = TEXT["ru"]

    def key(edge: str, name: str) -> str:
        return "{#90}" + edge + "{#} {#blue}" + ICON[name] + "{#}"

    return {
        "$schema": SCHEMA,
        "logo": {"type": "file", "source": LOGO_SMALL, "color": {"1": "magenta", "2": "blue"},
                 "padding": {"top": 1, "left": 1, "right": 3}},
        "display": DISPLAY,
        "modules": [
            "break",
            title(),
            {"type": "os", "key": key("╭", "os"), "format": "Cove · {name}"},
            {"type": "wm", "key": key("│", "wm"), "format": "{pretty-name} {version}"},
            {"type": "uptime", "key": key("│", "uptime"), "format": t["up"]},
            {"type": "memory", "key": key("│", "mem"), "format": "{percentage-bar} {used} " + t["of"] + " {total}"},
            {**PALETTE, "format": "{#90}╰{#} " + PALETTE["format"]},
        ],
    }


def write(path: Path, note: str, conf: dict) -> None:
    path.write_text(f"// {note}. Собран tools/fastfetch/build.py, правки вносить туда\n"
                    + json.dumps(conf, indent=2, ensure_ascii=False) + "\n")
    print("→", path.relative_to(ROOT))


if __name__ == "__main__":
    for lang in TEXT:
        write(ROOT / f"config/fastfetch/config.{lang}.jsonc", f"Полный fastfetch Cove ({lang}), команда ff", full(lang))
    write(ROOT / "config/fish/fastfetch.jsonc", "Компактный fastfetch Cove для приветствия fish", compact())
