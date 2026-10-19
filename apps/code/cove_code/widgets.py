"""Части окна: строка меню, дерево файлов, строка состояния, поиск, стартовый экран."""
from __future__ import annotations

from pathlib import Path
from typing import Iterable

from rich.text import Text
from textual import events, on
from textual.app import ComposeResult
from textual.containers import Center, Horizontal, Vertical, VerticalScroll
from textual.message import Message
from textual.widget import Widget
from textual.widgets import Button, DirectoryTree, Input, Label, Static

from .dialogs import IGNORED_DIRS


# ---------------------------------------------------------------- строка меню
class MenuBar(Horizontal):
    """Пункты меню сверху; клик открывает выпадающее меню (App.open_menu)."""

    MENUS = [("file", "Файл"), ("edit", "Правка"), ("view", "Вид"), ("go", "Перейти")]

    class Opened(Message):
        def __init__(self, menu: str, x: int, y: int):
            super().__init__()
            self.menu, self.x, self.y = menu, x, y

    def compose(self) -> ComposeResult:
        yield Label(" ◐ Cove Code ", id="brand")
        for mid, label in self.MENUS:
            yield Label(f" {label} ", id=f"menu-{mid}", classes="menu-item")
        yield Label("", id="menu-spacer")
        yield Label("", id="project")

    def on_click(self, e: events.Click) -> None:
        w = e.widget
        if w is not None and w.id and w.id.startswith("menu-") and w.id != "menu-spacer":
            r = w.region
            self.post_message(self.Opened(w.id[5:], r.x, r.y + 1))
        elif w is not None and w.id == "brand":
            self.post_message(self.Opened("cove", w.region.x, w.region.y + 1))


# ---------------------------------------------------------------- дерево файлов
class Sidebar(DirectoryTree):
    """Дерево проекта: без .git, кэшей и сборок; скрытые файлы — по переключателю."""

    show_hidden = False

    class ContextMenu(Message):
        def __init__(self, path: Path, x: int, y: int):
            super().__init__()
            self.path, self.x, self.y = path, x, y

    def filter_paths(self, paths: Iterable[Path]) -> Iterable[Path]:
        for p in paths:
            if p.name in IGNORED_DIRS:
                continue
            if not self.show_hidden and p.name.startswith(".") and p.name not in (".config", ".github"):
                continue
            yield p

    def on_mouse_down(self, e: events.MouseDown) -> None:
        if e.button != 3:
            return
        line = e.y + int(self.scroll_y)
        node = self.get_node_at_line(line)
        if node is None or node.data is None:
            path = self.path if isinstance(self.path, Path) else Path(self.path)
        else:
            self.move_cursor(node)
            path = node.data.path
        e.stop()
        self.post_message(self.ContextMenu(Path(path), e.screen_x, e.screen_y))


# ---------------------------------------------------------------- строка состояния
class StatusBar(Horizontal):
    """Путь, ветка, позиция курсора, язык и отступы; клик по полю — действие."""

    class Action(Message):
        def __init__(self, action: str):
            super().__init__()
            self.action = action

    def compose(self) -> ComposeResult:
        yield Label("", id="st-path")
        yield Label("", id="st-spacer")
        yield Label("", id="st-branch", classes="st-item")
        yield Label("", id="st-pos", classes="st-item")
        yield Label("", id="st-indent", classes="st-item")
        yield Label("", id="st-lang", classes="st-item")

    def set(self, **kw: str) -> None:
        for k, v in kw.items():
            w = self.query_one(f"#st-{k}", Label)
            w.update(v)
            w.display = bool(v)

    def on_click(self, e: events.Click) -> None:
        actions = {"st-pos": "goto_line", "st-indent": "toggle_indent", "st-lang": "command_palette"}
        if e.widget is not None and e.widget.id in actions:
            self.post_message(self.Action(actions[e.widget.id]))


# ---------------------------------------------------------------- поиск и замена
class FindBar(Vertical):
    """Ctrl+F — найти, Ctrl+H — заменить. Enter — следующее, Shift+Enter — предыдущее."""

    class Find(Message):
        def __init__(self, query: str, forward: bool = True, live: bool = False):
            super().__init__()
            self.query, self.forward, self.live = query, forward, live

    class Replace(Message):
        def __init__(self, query: str, replacement: str, all: bool):
            super().__init__()
            self.query, self.replacement, self.all = query, replacement, all

    class Closed(Message):
        pass

    def compose(self) -> ComposeResult:
        with Horizontal(classes="find-row"):
            yield Input(placeholder="Найти", id="find")
            yield Label("", id="find-count")
            yield Button("↑", id="find-prev", classes="small")
            yield Button("↓", id="find-next", classes="small")
            yield Button("✕", id="find-close", classes="small")
        with Horizontal(classes="find-row", id="replace-row"):
            yield Input(placeholder="Заменить на", id="replace")
            yield Button("Заменить", id="replace-one", classes="small")
            yield Button("Все", id="replace-all", classes="small")

    def show(self, replace: bool, text: str = "") -> None:
        self.display = True
        self.query_one("#replace-row").display = replace
        f = self.query_one("#find", Input)
        if text:
            f.value = text
        f.focus()
        f.select_all()

    @property
    def query_text(self) -> str:
        return self.query_one("#find", Input).value

    def set_count(self, text: str) -> None:
        self.query_one("#find-count", Label).update(text)

    @on(Input.Changed, "#find")
    def live(self, e: Input.Changed) -> None:
        self.post_message(self.Find(e.value, live=True))

    @on(Input.Submitted, "#find")
    def submit(self) -> None:
        self.post_message(self.Find(self.query_text))

    @on(Input.Submitted, "#replace")
    def submit_replace(self) -> None:
        self.post_message(self.Replace(self.query_text, self.query_one("#replace", Input).value, False))

    @on(Button.Pressed)
    def buttons(self, e: Button.Pressed) -> None:
        bid = e.button.id
        if bid == "find-next":
            self.post_message(self.Find(self.query_text))
        elif bid == "find-prev":
            self.post_message(self.Find(self.query_text, forward=False))
        elif bid == "find-close":
            self.post_message(self.Closed())
        elif bid in ("replace-one", "replace-all"):
            self.post_message(self.Replace(self.query_text, self.query_one("#replace", Input).value, bid == "replace-all"))

    def on_key(self, e: events.Key) -> None:
        if e.key == "escape":
            e.stop()
            self.post_message(self.Closed())
        elif e.key == "shift+enter":
            e.stop()
            self.post_message(self.Find(self.query_text, forward=False))


# ---------------------------------------------------------------- стартовый экран
LOGO = r"""
   ▄████▄   ▄█████▄  ██    ██  ▄█████▄
  ██▀  ▀▀  ██▀   ▀██ ██    ██ ██▄▄▄▄██
  ██▄  ▄▄  ██▄   ▄██  ██  ██  ██▀▀▀▀▀▀
   ▀████▀   ▀█████▀    ▀██▀    ▀█████▀
""".strip("\n")


def short_path(p: Path | str, width: int) -> str:
    """~ вместо домашней папки; длинное — с многоточием в начале, конец пути важнее."""
    s = str(p).replace(str(Path.home()), "~", 1)
    return s if len(s) <= width else "…" + s[-(width - 1):]


class Dashboard(VerticalScroll):
    """Когда нет открытых файлов: логотип, кнопки и недавние файлы."""

    class Open(Message):
        def __init__(self, target: str):
            super().__init__()
            self.target = target

    def __init__(self, project: Path, recent: list[str], **kw):
        super().__init__(**kw)
        self.project, self.recent = project, recent

    def compose(self) -> ComposeResult:
        with Center():
            yield Static(Text(LOGO), id="logo")
        with Center():
            yield Label(Text.assemble(("Code", "bold"), ("  ·  ", "dim"), (short_path(self.project, 60), "")), id="dash-project")
        with Center():
            with Horizontal(id="dash-buttons"):
                yield Button("Открыть файл  Ctrl+P", id="dash-quick", variant="primary")
                yield Button("Новый файл  Ctrl+N", id="dash-new")
                yield Button("Открыть папку", id="dash-folder")
        if self.recent:
            with Center():
                yield Label("Недавние", id="dash-recent-title")
            with Center():
                with Vertical(id="dash-recent"):
                    for i, r in enumerate(self.recent[:8]):
                        p = Path(r)
                        b = Button(Text.assemble((p.name, "bold"), "   ", (short_path(p.parent, 64 - len(p.name)), "dim")), id=f"recent-{i}", classes="recent")
                        b.tooltip = r
                        yield b

    @on(Button.Pressed)
    def pressed(self, e: Button.Pressed) -> None:
        bid = e.button.id or ""
        if bid.startswith("recent-"):
            self.post_message(self.Open(self.recent[int(bid[7:])]))
        else:
            self.post_message(self.Open(bid))
