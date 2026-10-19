"""Цвета Cove Code из палитры шелла (~/.cache/cove/palette.json, пишет services/Recolor.qml).

Палитра меняется вместе с обоями — приложение перечитывает файл и перекрашивается на лету.
"""
import json
from pathlib import Path

from rich.style import Style
from textual.theme import Theme
from textual.widgets.text_area import TextAreaTheme

PALETTE = Path.home() / ".cache/cove/palette.json"

# запасные цвета (Catppuccin Mocha) — если шелл ещё не писал палитру
DEFAULT = {
    "light": False,
    "crust": "#11111b", "mantle": "#181825", "base": "#1e1e2e",
    "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
    "overlay0": "#6c7086", "overlay1": "#7f849c",
    "subtext0": "#a6adc8", "subtext1": "#bac2de", "text": "#cdd6f4",
    "accent": "#cba6f7", "accent2": "#f5c2e7",
    "red": "#f38ba8", "peach": "#fab387", "yellow": "#f9e2af", "green": "#a6e3a1",
    "teal": "#94e2d5", "lavender": "#b4befe", "pink": "#f5c2e7",
}


def load() -> dict:
    p = dict(DEFAULT)
    try:
        p.update(json.loads(PALETTE.read_text()))
    except (OSError, ValueError):
        pass
    return p


def mtime() -> float:
    try:
        return PALETTE.stat().st_mtime
    except OSError:
        return 0.0


def app_theme(p: dict, name: str) -> Theme:
    return Theme(
        name=name,
        primary=p["accent"],
        secondary=p["accent2"],
        accent=p["accent"],
        foreground=p["text"],
        background=p["base"],
        surface=p["mantle"],
        panel=p["surface0"],
        success=p["green"],
        warning=p["yellow"],
        error=p["red"],
        dark=not p.get("light", False),
        variables={
            "cove-crust": p["crust"],
            "cove-mantle": p["mantle"],
            "cove-surface0": p["surface0"],
            "cove-surface1": p["surface1"],
            "cove-surface2": p["surface2"],
            "cove-overlay0": p["overlay0"],
            "cove-overlay1": p["overlay1"],
            "cove-subtext0": p["subtext0"],
            "cove-accent2": p["accent2"],
            "footer-key-foreground": p["accent"],
            "block-cursor-background": p["accent"],
            "block-cursor-foreground": p["crust"],
            "scrollbar": p["surface1"],
            "scrollbar-hover": p["surface2"],
            "scrollbar-active": p["accent"],
            "scrollbar-background": p["base"],
            "scrollbar-background-hover": p["base"],
            "scrollbar-background-active": p["base"],
        },
    )


def editor_theme(p: dict, name: str) -> TextAreaTheme:
    def s(color: str, **kw) -> Style:
        return Style(color=p[color], **kw)

    keyword = s("accent", bold=True)
    return TextAreaTheme(
        name=name,
        base_style=Style(color=p["text"], bgcolor=p["base"]),
        gutter_style=Style(color=p["overlay0"], bgcolor=p["base"]),
        cursor_style=Style(color=p["crust"], bgcolor=p["accent"]),
        cursor_line_style=Style(bgcolor=p["mantle"]),
        cursor_line_gutter_style=Style(color=p["accent"], bgcolor=p["mantle"], bold=True),
        bracket_matching_style=Style(bgcolor=p["surface1"], bold=True),
        selection_style=Style(bgcolor=p["surface1"]),
        syntax_styles={
            "comment": s("overlay1", italic=True),
            "string": s("green"),
            "string.documentation": s("overlay1", italic=True),
            "keyword": keyword,
            "keyword.function": keyword,
            "keyword.return": keyword,
            "keyword.operator": keyword,
            "conditional": keyword,
            "repeat": keyword,
            "exception": keyword,
            "include": keyword,
            "operator": s("teal"),
            "number": s("peach"),
            "float": s("peach"),
            "boolean": s("peach"),
            "constant.builtin": s("peach"),
            "json.null": s("peach"),
            "function": s("lavender"),
            "function.call": s("lavender"),
            "method": s("lavender"),
            "method.call": s("lavender"),
            "class": s("yellow"),
            "type": s("yellow"),
            "type.class": s("yellow"),
            "type.builtin": s("yellow"),
            "variable.builtin": s("pink"),
            "tag": s("accent2"),
            "heading": s("accent", bold=True),
            "heading.marker": s("overlay1"),
            "bold": Style(bold=True),
            "italic": Style(italic=True),
            "strikethrough": Style(strike=True),
            "link.label": s("accent2"),
            "link.uri": s("teal", underline=True),
            "list.marker": s("accent"),
            "inline_code": s("green"),
            "json.label": s("accent2"),
            "yaml.field": s("accent2"),
            "toml.type": s("accent2"),
            "toml.datetime": s("peach"),
            "css.property": s("accent2"),
            "html.end_tag_error": s("red", underline=True),
            "regex.punctuation.bracket": s("pink"),
            "regex.operator": s("pink"),
        },
    )
