"""Значки файлов (Nerd Font) и их цвета из палитры. Коды — через \\u: символы из частной области Юникода
теряются при копировании, а так их видно и можно проверить."""
from __future__ import annotations

from pathlib import Path

# (значок, цвет палитры)
BY_EXT: dict[str, tuple[str, str]] = {
    ".py": ("", "yellow"), ".pyi": ("", "yellow"),
    ".js": ("", "yellow"), ".mjs": ("", "yellow"), ".cjs": ("", "yellow"), ".jsx": ("", "teal"),
    ".ts": ("", "lavender"), ".tsx": ("", "teal"), ".mts": ("", "lavender"),
    ".json": ("", "yellow"), ".jsonc": ("", "yellow"),
    ".md": ("", "subtext1"), ".markdown": ("", "subtext1"),
    ".rs": ("", "peach"), ".go": ("", "teal"),
    ".c": ("", "lavender"), ".h": ("", "accent2"), ".hpp": ("", "accent2"), ".hh": ("", "accent2"),
    ".cpp": ("", "accent"), ".cc": ("", "accent"), ".cxx": ("", "accent"), ".ino": ("", "teal"),
    ".lua": ("", "lavender"), ".sh": ("", "green"), ".bash": ("", "green"), ".zsh": ("", "green"),
    ".fish": ("", "green"),
    ".html": ("", "peach"), ".htm": ("", "peach"), ".css": ("", "accent"), ".scss": ("", "pink"),
    ".tcss": ("", "accent"),
    ".toml": ("", "subtext0"), ".yaml": ("", "red"), ".yml": ("", "red"), ".ini": ("", "subtext0"),
    ".conf": ("", "subtext0"), ".cfg": ("", "subtext0"),
    ".qml": ("", "green"), ".nix": ("", "lavender"), ".zig": ("", "peach"), ".swift": ("", "peach"),
    ".rb": ("", "red"), ".php": ("", "lavender"), ".cs": ("\U000f031b", "accent2"), ".java": ("", "peach"),
    ".sql": ("", "subtext1"), ".xml": ("\U000f05c0", "peach"), ".svg": ("\U000f0721", "yellow"),
    ".glsl": ("", "teal"), ".vert": ("", "teal"), ".frag": ("", "teal"),
    ".png": ("", "accent2"), ".jpg": ("", "accent2"), ".jpeg": ("", "accent2"), ".gif": ("", "accent2"),
    ".webp": ("", "accent2"), ".ico": ("", "accent2"),
    ".txt": ("", "subtext0"), ".log": ("", "overlay1"), ".lock": ("", "overlay1"),
    ".cmake": ("", "teal"), ".mk": ("", "subtext0"),
}
BY_NAME: dict[str, tuple[str, str]] = {
    "Makefile": ("", "subtext0"), "makefile": ("", "subtext0"), "CMakeLists.txt": ("", "teal"),
    "Dockerfile": ("", "accent"), "Containerfile": ("", "accent"),
    ".gitignore": ("", "peach"), ".gitmodules": ("", "peach"), ".gitattributes": ("", "peach"),
    "LICENSE": ("", "yellow"), "PKGBUILD": ("", "accent"),
}
FILE = ("", "overlay1")
FOLDER = ""
FOLDER_OPEN = ""

# элементы интерфейса
PILL_L = ""      # левый полукруг капсулы
PILL_R = ""      # правый полукруг
BRANCH = ""
SEARCH = ""
MENU = ""
CLOSE = ""
DOT = "●"
SAVE = ""
CODE = ""
TERMINAL = ""
PLUS = ""
SIDEBAR = ""
COVE = "◐"


def for_path(path: Path | None) -> tuple[str, str]:
    if path is None:
        return FILE
    return BY_NAME.get(path.name) or BY_EXT.get(path.suffix.lower()) or FILE
