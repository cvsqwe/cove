"""Диалоги и всплывающие меню: всё можно сделать мышью, клавиши — для скорости."""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

from rich.text import Text
from textual import on
from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.screen import ModalScreen
from textual.widgets import Button, Input, Label, OptionList
from textual.widgets.option_list import Option

IGNORED_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv", "target", "build", "dist", ".cache", ".mypy_cache", ".pytest_cache"}


# ---------------------------------------------------------------- всплывающее меню
class MenuItem:
    def __init__(self, label: str, action: str | None, key: str = "", enabled: bool = True, danger: bool = False):
        self.label, self.action, self.key, self.enabled, self.danger = label, action, key, enabled, danger


SEPARATOR = MenuItem("", None)


class PopupMenu(ModalScreen[str | None]):
    """Меню у точки (x, y): строка меню сверху или правый клик. Клик мимо или Esc — закрыть."""

    BINDINGS = [Binding("escape", "dismiss(None)", show=False)]

    def __init__(self, items: list[MenuItem], x: int, y: int):
        super().__init__(classes="popup-screen")
        self.items, self.x, self.y = items, x, y

    def compose(self) -> ComposeResult:
        width = max((len(i.label) + len(i.key) + 6 for i in self.items), default=20)
        options = []
        for i, it in enumerate(self.items):
            if it.action is None:
                options.append(None)   # разделитель
                continue
            t = Text(it.label, style="bold red" if it.danger else "")
            if it.key:
                t.append(" " * max(2, width - len(it.label) - len(it.key) - 4))
                t.append(it.key, style="dim")
            options.append(Option(t, id=str(i), disabled=not it.enabled))
        menu = OptionList(*options, id="popup")
        menu.styles.width = width
        menu.styles.offset = (self.x, self.y)
        yield menu

    def on_mount(self) -> None:
        menu = self.query_one(OptionList)
        menu.focus()
        # не вылезаем за край экрана
        h = len(self.items) + 2
        x = min(self.x, max(0, self.size.width - menu.styles.width.value - 1))
        y = min(self.y, max(0, self.size.height - h))
        menu.styles.offset = (x, y)

    @on(OptionList.OptionSelected)
    def chosen(self, e: OptionList.OptionSelected) -> None:
        self.dismiss(self.items[int(e.option.id)].action)

    def on_click(self, e) -> None:
        if e.widget is self:
            self.dismiss(None)


# ---------------------------------------------------------------- быстрое открытие
def list_files(root: Path, limit: int = 20000) -> list[str]:
    """Файлы проекта относительно root: fd/rg учитывают .gitignore, иначе — свой обход."""
    for cmd in (["fd", "--type", "f", "--hidden", "--exclude", ".git", "--color", "never"],
                ["rg", "--files", "--hidden", "--glob", "!.git"]):
        if shutil.which(cmd[0]):
            try:
                r = subprocess.run(cmd, cwd=root, capture_output=True, timeout=5)
                if r.returncode in (0, 1):
                    return r.stdout.decode("utf-8", "replace").splitlines()[:limit]
            except (OSError, subprocess.SubprocessError):
                pass
    out = []
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x not in IGNORED_DIRS]
        for f in files:
            out.append(os.path.relpath(os.path.join(d, f), root))
            if len(out) >= limit:
                return out
    return out


def fuzzy(query: str, path: str) -> int:
    """Очки совпадения: буквы запроса по порядку; бонус за имя файла и подряд идущие буквы. -1 — нет."""
    q, p = query.lower(), path.lower()
    name_start = p.rfind("/") + 1
    score, i, prev = 0, 0, -2
    for j, ch in enumerate(p):
        if i < len(q) and ch == q[i]:
            score += 3 if j == prev + 1 else 1
            if j >= name_start:
                score += 2
            prev = j
            i += 1
    if i < len(q):
        return -1
    if q in p[name_start:]:
        score += 20
    return score - len(p) // 20


class QuickOpen(ModalScreen[str | None]):
    """Ctrl+P: найти файл проекта по кусочкам имени."""

    BINDINGS = [Binding("escape", "dismiss(None)", show=False),
                Binding("down", "move(1)", show=False), Binding("up", "move(-1)", show=False)]

    def __init__(self, root: Path, recent: list[str]):
        super().__init__(classes="dialog-screen")
        self.root, self.recent = root, recent
        self.files: list[str] = []

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog quick"):
            yield Label("Открыть файл", classes="dialog-title")
            yield Input(placeholder="Имя файла… (Enter — открыть, Esc — закрыть)", id="q")
            yield OptionList(id="results")

    def on_mount(self) -> None:
        self.files = list_files(self.root)
        self.refresh_results("")
        self.query_one(Input).focus()

    def refresh_results(self, q: str) -> None:
        ol = self.query_one(OptionList)
        ol.clear_options()
        if q:
            scored = sorted(((fuzzy(q, f), f) for f in self.files), key=lambda x: -x[0])
            items = [f for s, f in scored if s >= 0][:60]
        else:
            rec = [r for r in self.recent if r in set(self.files)]
            items = (rec + [f for f in self.files if f not in rec])[:60]
        for f in items:
            name = f.rsplit("/", 1)[-1]
            t = Text(name, style="bold")
            if "/" in f:
                t.append("   " + f.rsplit("/", 1)[0], style="dim")
            ol.add_option(Option(t, id=f))
        if items:
            ol.highlighted = 0

    @on(Input.Changed, "#q")
    def changed(self, e: Input.Changed) -> None:
        self.refresh_results(e.value.strip())

    @on(Input.Submitted, "#q")
    def submitted(self) -> None:
        ol = self.query_one(OptionList)
        if ol.highlighted is not None and ol.option_count:
            self.dismiss(ol.get_option_at_index(ol.highlighted).id)

    @on(OptionList.OptionSelected)
    def chosen(self, e: OptionList.OptionSelected) -> None:
        self.dismiss(e.option.id)

    def action_move(self, d: int) -> None:
        ol = self.query_one(OptionList)
        if ol.option_count:
            ol.highlighted = max(0, min(ol.option_count - 1, (ol.highlighted or 0) + d))


# ---------------------------------------------------------------- ввод строки
class Prompt(ModalScreen[str | None]):
    BINDINGS = [Binding("escape", "dismiss(None)", show=False)]

    def __init__(self, title: str, value: str = "", placeholder: str = "", ok: str = "Готово"):
        super().__init__(classes="dialog-screen")
        self.title_text, self.value, self.placeholder, self.ok = title, value, placeholder, ok

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog"):
            yield Label(self.title_text, classes="dialog-title")
            yield Input(self.value, placeholder=self.placeholder, id="value")
            with Horizontal(classes="buttons"):
                yield Button("Отмена", id="cancel")
                yield Button(self.ok, id="ok", variant="primary")

    def on_mount(self) -> None:
        self.query_one(Input).focus()

    @on(Input.Submitted)
    @on(Button.Pressed, "#ok")
    def submit(self) -> None:
        v = self.query_one(Input).value.strip()
        self.dismiss(v or None)

    @on(Button.Pressed, "#cancel")
    def cancel(self) -> None:
        self.dismiss(None)


# ---------------------------------------------------------------- вопрос с кнопками
class Ask(ModalScreen[str | None]):
    """Вопрос: buttons — [(id, текст, вид)], вид: primary | error | default. Esc — None."""

    BINDINGS = [Binding("escape", "dismiss(None)", show=False)]

    def __init__(self, title: str, text: str, buttons: list[tuple[str, str, str]]):
        super().__init__(classes="dialog-screen")
        self.title_text, self.text, self.buttons = title, text, buttons

    def compose(self) -> ComposeResult:
        with Vertical(classes="dialog"):
            yield Label(self.title_text, classes="dialog-title")
            yield Label(self.text, classes="dialog-text")
            with Horizontal(classes="buttons"):
                for bid, label, variant in self.buttons:
                    yield Button(label, id=bid, variant=variant)

    def on_mount(self) -> None:
        self.query(Button).last().focus()

    @on(Button.Pressed)
    def pressed(self, e: Button.Pressed) -> None:
        self.dismiss(e.button.id)
