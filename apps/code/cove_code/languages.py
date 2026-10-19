"""Языки сверх встроенных в Textual: грамматики tree-sitter из pip (tree-sitter-cpp и т. п.).

Правила подсветки (queries/highlights.scm) берутся из самих пакетов. Некоторые из них — только добавки
к базовому языку (C++ к C, TypeScript к JavaScript), поэтому склеиваются: сначала база, потом своё.
Ставит их install.sh editor; чего нет — просто остаётся без подсветки.
"""
from __future__ import annotations

import importlib
from functools import lru_cache
from pathlib import Path

# имя → (модуль, функция языка, [(модуль с queries, файл)…])
EXTRA: dict[str, tuple[str, str, list[tuple[str, str]]]] = {
    "c": ("tree_sitter_c", "language", [("tree_sitter_c", "highlights.scm")]),
    "cpp": ("tree_sitter_cpp", "language", [("tree_sitter_c", "highlights.scm"), ("tree_sitter_cpp", "highlights.scm")]),
    "lua": ("tree_sitter_lua", "language", [("tree_sitter_lua", "highlights.scm")]),
    "typescript": ("tree_sitter_typescript", "language_typescript",
                   [("tree_sitter_javascript", "highlights.scm"), ("tree_sitter_typescript", "highlights.scm")]),
    "tsx": ("tree_sitter_typescript", "language_tsx",
            [("tree_sitter_javascript", "highlights.scm"), ("tree_sitter_javascript", "highlights-jsx.scm"),
             ("tree_sitter_typescript", "highlights.scm")]),
    "qml": ("tree_sitter_qmljs", "language",
            [("tree_sitter_javascript", "highlights.scm"), ("tree_sitter_typescript", "highlights.scm"),
             ("tree_sitter_qmljs", "highlights.scm")]),
    "csharp": ("tree_sitter_c_sharp", "language", [("tree_sitter_c_sharp", "highlights.scm")]),
    "php": ("tree_sitter_php", "language_php", [("tree_sitter_php", "highlights.scm")]),
    "ruby": ("tree_sitter_ruby", "language", [("tree_sitter_ruby", "highlights.scm")]),
    "make": ("tree_sitter_make", "language", [("tree_sitter_make", "highlights.scm")]),
    "cmake": ("tree_sitter_cmake", "language", [("tree_sitter_cmake", "highlights.scm")]),
    "glsl": ("tree_sitter_glsl", "language", [("tree_sitter_c", "highlights.scm"), ("tree_sitter_glsl", "highlights.scm")]),
    "nix": ("tree_sitter_nix", "language", [("tree_sitter_nix", "highlights.scm")]),
    "zig": ("tree_sitter_zig", "language", [("tree_sitter_zig", "highlights.scm")]),
    "swift": ("tree_sitter_swift", "language", [("tree_sitter_swift", "highlights.scm")]),
    "dockerfile": ("tree_sitter_dockerfile", "language", [("tree_sitter_dockerfile", "highlights.scm")]),
}

LABELS = {
    "c": "C", "cpp": "C++", "lua": "Lua", "typescript": "TypeScript", "tsx": "TSX", "qml": "QML", "csharp": "C#",
    "php": "PHP", "ruby": "Ruby", "make": "Makefile", "cmake": "CMake", "glsl": "GLSL", "nix": "Nix", "zig": "Zig",
    "swift": "Swift", "dockerfile": "Dockerfile",
}


def _query_file(module: str, name: str) -> str:
    try:
        m = importlib.import_module(module)
    except ImportError:
        return ""
    here = Path(m.__file__).parent
    # некоторые пакеты кладут queries рядом, в папку с дефисом (tree_sitter_c-sharp)
    alt = here.parent / ("tree_sitter_" + module.removeprefix("tree_sitter_").replace("_", "-"))
    for d in (here, alt):
        try:
            return (d / "queries" / name).read_text()
        except OSError:
            continue
    return ""


@lru_cache(maxsize=None)
def load(name: str):
    """(Language, query) или None, если грамматики нет или правила не собираются."""
    spec = EXTRA.get(name)
    if not spec:
        return None
    try:
        from tree_sitter import Language, Query
        lang = Language(getattr(importlib.import_module(spec[0]), spec[1])())
    except Exception:
        return None
    parts = [_query_file(m, f) for m, f in spec[2]]
    # собираем по кусочкам: если чужая добавка не компилируется с этой грамматикой — пропускаем её
    good: list[str] = []
    for part in parts:
        if not part:
            continue
        try:
            Query(lang, "\n".join(good + [part]))
            good.append(part)
        except Exception:
            continue
    if not good:
        return None
    return lang, "\n".join(good)


def register_all(text_area) -> None:
    for name in EXTRA:
        loaded = load(name)
        if loaded:
            text_area.register_language(name, *loaded)
