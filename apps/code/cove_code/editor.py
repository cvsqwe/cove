"""Поле редактирования: TextArea с привычными клавишами, системным буфером обмена и файлом за спиной."""
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from textual.binding import Binding
from textual.widgets import TextArea

# расширение / имя файла → язык подсветки (tree-sitter из textual[syntax])
LANGUAGES = {
    ".py": "python", ".pyi": "python",
    ".js": "javascript", ".mjs": "javascript", ".cjs": "javascript", ".jsx": "javascript",
    ".ts": "javascript", ".tsx": "javascript", ".qml": "javascript",
    ".json": "json", ".jsonc": "json",
    ".md": "markdown", ".markdown": "markdown",
    ".toml": "toml", ".yaml": "yaml", ".yml": "yaml",
    ".html": "html", ".htm": "html", ".xml": "xml", ".svg": "xml",
    ".css": "css", ".tcss": "css", ".scss": "css",
    ".sh": "bash", ".bash": "bash", ".zsh": "bash",
    ".rs": "rust", ".go": "go", ".java": "java", ".sql": "sql",
}
NAMES = {"PKGBUILD": "bash", ".bashrc": "bash", ".profile": "bash", "Cargo.lock": "toml"}

# комментарий строки по языку (Ctrl+/); для языков без подсветки — по расширению
LINE_COMMENT = {
    "python": "#", "bash": "#", "toml": "#", "yaml": "#",
    "javascript": "//", "rust": "//", "go": "//", "java": "//", "css": None, "sql": "--",
}
EXT_COMMENT = {".lua": "--", ".fish": "#", ".conf": "#", ".ini": ";", ".c": "//", ".h": "//", ".cpp": "//", ".hpp": "//"}

LANGUAGE_LABEL = {
    "python": "Python", "javascript": "JavaScript", "json": "JSON", "markdown": "Markdown", "toml": "TOML",
    "yaml": "YAML", "html": "HTML", "xml": "XML", "css": "CSS", "bash": "Shell", "rust": "Rust", "go": "Go",
    "java": "Java", "sql": "SQL",
}


def detect_language(path: Path | None) -> str | None:
    if path is None:
        return None
    return NAMES.get(path.name) or LANGUAGES.get(path.suffix.lower())


def detect_indent(text: str) -> tuple[str, int]:
    """Табы или пробелы и ширина — по первым строкам файла."""
    tabs = spaces = 0
    widths: dict[int, int] = {}
    for line in text.splitlines()[:400]:
        if line.startswith("\t"):
            tabs += 1
        elif line.startswith(" "):
            n = len(line) - len(line.lstrip(" "))
            if n in (2, 4, 8):
                spaces += 1
                widths[n] = widths.get(n, 0) + 1
    if tabs > spaces:
        return "tabs", 4
    if not widths:
        return "spaces", 4
    # самая маленькая ширина, которая встречается заметно часто
    return "spaces", min(w for w, c in widths.items() if c >= max(widths.values()) * 0.25)


def clipboard_copy(text: str) -> bool:
    if not shutil.which("wl-copy"):
        return False
    try:
        subprocess.run(["wl-copy"], input=text.encode(), timeout=2, check=False)
        return True
    except (OSError, subprocess.SubprocessError):
        return False


def clipboard_paste() -> str | None:
    if not shutil.which("wl-paste"):
        return None
    try:
        r = subprocess.run(["wl-paste", "--no-newline", "--type", "text"], capture_output=True, timeout=2)
        return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


class CoveTextArea(TextArea):
    """TextArea с клавишами обычных редакторов (без режимов) и системным буфером обмена."""

    BINDINGS = [
        Binding("ctrl+a", "select_all", "Выделить всё", show=False),
        Binding("ctrl+shift+z", "redo", "Повторить", show=False),
        Binding("ctrl+d", "duplicate_line", "Дублировать строку", show=False),
        Binding("ctrl+slash,ctrl+underscore", "toggle_comment", "Закомментировать", show=False),
        Binding("alt+up", "move_line(-1)", "Строку вверх", show=False),
        Binding("alt+down", "move_line(1)", "Строку вниз", show=False),
        Binding("home", "smart_home", "В начало строки", show=False),
    ]

    comment: str | None = None   # знак комментария строки для этого файла

    # ---- буфер обмена: системный (wl-copy/wl-paste), запасной — свой Textual ----
    def action_copy(self) -> None:
        text = self.selected_text or (self.document.get_line(self.cursor_location[0]) + "\n")
        if not clipboard_copy(text):
            self.app.copy_to_clipboard(text)

    def action_cut(self) -> None:
        if self.read_only:
            return
        start, end = self.selection
        if start == end:
            row = start[0]
            text = self.document.get_line(row) + "\n"
            clipboard_copy(text) or self.app.copy_to_clipboard(text)
            self.action_delete_line()
            return
        text = self.selected_text
        clipboard_copy(text) or self.app.copy_to_clipboard(text)
        self.delete(start, end)

    def action_paste(self) -> None:
        if self.read_only:
            return
        text = clipboard_paste()
        if text is None:
            text = self.app.clipboard
        if text:
            result = self.replace(text, *self.selection)
            self.move_cursor(result.end_location)

    # ---- правка строк ----
    def action_duplicate_line(self) -> None:
        row, col = self.cursor_location
        line = self.document.get_line(row)
        self.insert(line + "\n", (row, 0))
        self.move_cursor((row + 1, col))

    def action_move_line(self, d: int) -> None:
        row, col = self.cursor_location
        target = row + d
        if target < 0 or target >= self.document.line_count:
            return
        a, b = sorted((row, target))
        lines = [self.document.get_line(a), self.document.get_line(b)]
        end = (b, len(lines[1]))
        self.replace(lines[1] + "\n" + lines[0], (a, 0), end)
        self.move_cursor((target, col))

    def action_smart_home(self) -> None:
        """Home: сначала к первому символу строки, второй раз — в самое начало."""
        row, col = self.cursor_location
        line = self.document.get_line(row)
        first = len(line) - len(line.lstrip())
        self.move_cursor((row, 0 if col == first else first))

    def action_toggle_comment(self) -> None:
        mark = self.comment
        if not mark or self.read_only:
            return
        start, end = sorted(self.selection)
        first, last = start[0], end[0]
        if last > first and end[1] == 0:
            last -= 1   # выделение до начала следующей строки — её не трогаем
        rows = range(first, last + 1)
        lines = [self.document.get_line(r) for r in rows]
        code = [l for l in lines if l.strip()]
        uncomment = bool(code) and all(l.lstrip().startswith(mark) for l in code)
        indent = min((len(l) - len(l.lstrip()) for l in code), default=0)
        out = []
        for l in lines:
            if not l.strip():
                out.append(l)
            elif uncomment:
                i = l.index(mark)
                rest = l[i + len(mark):]
                out.append(l[:i] + (rest[1:] if rest.startswith(" ") else rest))
            else:
                out.append(l[:indent] + mark + " " + l[indent:])
        self.replace("\n".join(out), (first, 0), (last, len(lines[-1])))
        self.selection = type(self.selection)((first, 0), (last, len(out[-1])))


class Buffer:
    """Открытый файл: путь, текст на диске и вид поля."""

    counter = 0

    def __init__(self, path: Path | None, text: str = ""):
        Buffer.counter += 1
        self.id = f"buf{Buffer.counter}"
        self.path = path
        self.saved_text = text
        self.disk_mtime = path.stat().st_mtime if path and path.exists() else 0.0

    @property
    def title(self) -> str:
        return self.path.name if self.path else "Без имени"


def read_file(path: Path) -> str:
    data = path.read_bytes()
    if b"\0" in data[:8192]:
        raise ValueError("binary")
    return data.decode("utf-8", errors="replace")


def make_editor(buf: Buffer, text: str, theme: str) -> CoveTextArea:
    language = detect_language(buf.path)
    ta = CoveTextArea.code_editor(text, language=language, theme="css", id=buf.id, soft_wrap=False)   # тему ставит App после register_theme
    ta.indent_type, ta.indent_width = detect_indent(text)
    ta.comment = LINE_COMMENT.get(language or "") or (EXT_COMMENT.get(buf.path.suffix.lower()) if buf.path else None)
    if buf.path and buf.path.suffix.lower() in (".md", ".txt", ".markdown"):
        ta.soft_wrap = True
    return ta
