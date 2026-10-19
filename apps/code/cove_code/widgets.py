"""Части окна в стиле шелла Cove: капсулы, остров, карточки, вкладки-капсулы, стартовый экран как лаунчер."""
from __future__ import annotations

from pathlib import Path
from typing import Iterable

from rich.style import Style
from rich.text import Text
from textual import events, on
from textual.app import ComposeResult
from textual.containers import Center, Horizontal, Vertical, VerticalScroll
from textual.message import Message
from textual.reactive import reactive
from textual.widgets import Button, DirectoryTree, Input, Label, OptionList, Static
from textual.widgets.option_list import Option

from . import icons
from .dialogs import IGNORED_DIRS, fuzzy, list_files


def pal(widget) -> dict:
    return widget.app.pal


def short_path(p: Path | str, width: int) -> str:
    """~ вместо домашней папки; длинное — с многоточием в начале, конец пути важнее."""
    s = str(p).replace(str(Path.home()), "~", 1)
    return s if len(s) <= width else "…" + s[-(width - 1):]


# ---------------------------------------------------------------- капсула
class Pill(Static):
    """Капсула как в панели шелла: полукруг, содержимое, полукруг. kind: accent | surface | soft."""

    DEFAULT_CSS = "Pill { width: auto; height: 1; }"
    hover = reactive(False)

    class Pressed(Message):
        def __init__(self, pill: "Pill", button: int, x: int):
            super().__init__()
            self.pill, self.button, self.x = pill, button, x

    def __init__(self, content: str | Text = "", kind: str = "surface", action: str = "", outside: str = "crust", **kw):
        super().__init__(**kw)
        self.content, self.kind, self.action, self.outside = content, kind, action, outside

    def set(self, content: str | Text, kind: str | None = None) -> None:
        self.content = content
        if kind:
            self.kind = kind
        self.refresh(layout=True)

    def colors(self) -> tuple[str, str]:
        p = pal(self)
        if self.kind == "accent":
            return p["accent"], p["crust"]
        if self.kind == "soft":
            return (p["surface1"] if self.hover and self.action else p["mantle"]), p["subtext1"]
        return (p["surface1"] if self.hover and self.action else p["surface0"]), p["text"]

    def render(self) -> Text:
        p = pal(self)
        bg, fg = self.colors()
        edge = Style(color=bg, bgcolor=p[self.outside])
        body = Style(color=fg, bgcolor=bg)
        content = self.content if isinstance(self.content, Text) else Text(self.content)
        t = Text(icons.PILL_L, style=edge)
        t.append(Text(" ", style=body))
        inner = content.copy()
        inner.stylize(body, 0, len(inner))      # фон под всем содержимым, свои цвета символов сохраняются
        for span in content.spans:
            inner.stylize(span.style, span.start, span.end)
        t.append_text(inner)
        t.append(Text(" ", style=body))
        t.append(icons.PILL_R, style=edge)
        return t

    def on_enter(self) -> None:
        self.hover = True

    def on_leave(self) -> None:
        self.hover = False

    def watch_hover(self) -> None:
        if self.action:
            self.refresh()

    def on_click(self, e: events.Click) -> None:
        e.stop()
        self.post_message(self.Pressed(self, e.button, e.x))


def colored(glyph: str, color: str, widget) -> Text:
    return Text(glyph, style=Style(color=pal(widget)[color]))


# ---------------------------------------------------------------- верхняя панель с островом
class TopBar(Horizontal):
    """Слева «◐ Cove» (меню), по центру остров с файлом и веткой, справа — быстрые действия."""

    def compose(self) -> ComposeResult:
        yield Pill(Text("◐ Cove"), kind="accent", action="menu", id="cove-pill")
        yield Static(id="top-spacer-l")
        yield Pill("", kind="surface", action="quick_open", id="island")
        yield Static(id="top-spacer-r")
        yield Pill(Text(f"{icons.SEARCH} Файл"), kind="soft", action="quick_open", id="act-open")
        yield Pill(Text(icons.CODE), kind="soft", action="find(False)", id="act-find")
        yield Pill(Text(icons.SIDEBAR), kind="soft", action="toggle_sidebar", id="act-side")
        yield Pill(Text(icons.MENU), kind="soft", action="menu", id="act-menu")

    def on_mount(self) -> None:
        self.query_one("#act-open").tooltip = "Найти файл в проекте (Ctrl+P)"
        self.query_one("#act-find").tooltip = "Поиск в файле (Ctrl+F)"
        self.query_one("#act-side").tooltip = "Боковая панель (Ctrl+B)"
        self.query_one("#act-menu").tooltip = "Меню (F10)"


# ---------------------------------------------------------------- вкладки-капсулы
class TabPill(Pill):
    """Вкладка: значок языка, имя, точка несохранённого и крестик. Средняя кнопка — закрыть."""

    def __init__(self, bid: str, **kw):
        super().__init__(kind="surface", outside="base", **kw)
        self.bid = bid
        self.title = ""
        self.path: Path | None = None
        self.dirty = False
        self.active = False

    def render(self) -> Text:
        glyph, color = icons.for_path(self.path)
        t = Text()
        t.append(glyph, style=Style(color=pal(self)["crust" if self.active else color]))
        t.append(" " + self.title, style=Style(bold=self.active))
        t.append(" " + (icons.DOT if self.dirty else icons.CLOSE),
                 style=Style(color=pal(self)["crust" if self.active else ("yellow" if self.dirty else "overlay1")]))
        self.content = t
        self.kind = "accent" if self.active else "surface"
        self.action = "tab"
        return super().render()


class TabStrip(Horizontal):
    class Select(Message):
        def __init__(self, bid: str, close: bool):
            super().__init__()
            self.bid, self.close = bid, close

    def sync(self, tabs: list[dict]) -> None:
        """tabs: [{id, title, path, dirty, active}] — добавляет недостающие, убирает лишние, порядок как в списке."""
        have = {w.bid: w for w in self.query(TabPill)}
        want = [t["id"] for t in tabs]
        for bid, w in have.items():
            if bid not in want:
                w.remove()
        for i, t in enumerate(tabs):
            w = have.get(t["id"])
            if w is None:
                w = TabPill(t["id"], id=f"tab-{t['id']}")
                self.mount(w)
            w.title, w.path, w.dirty, w.active = t["title"], t["path"], t["dirty"], t["active"]
            w.tooltip = str(t["path"]) if t["path"] else "Новый файл"
            w.refresh(layout=True)

    @on(Pill.Pressed)
    def pressed(self, e: Pill.Pressed) -> None:
        if isinstance(e.pill, TabPill):
            e.stop()
            close = e.button == 2 or e.x >= e.pill.size.width - 3
            self.post_message(self.Select(e.pill.bid, close))


# ---------------------------------------------------------------- дерево файлов
class Sidebar(DirectoryTree):
    """Дерево проекта: значки по типам, без линий, без .git и кэшей; скрытые — по переключателю."""

    ICON_NODE = ""
    ICON_NODE_EXPANDED = ""
    ICON_FILE = ""
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

    def render_label(self, node, base_style: Style, style: Style) -> Text:
        label = super().render_label(node, base_style, style)
        path = node.data.path if node.data else None
        if node.allow_expand:
            glyph, color = (icons.FOLDER_OPEN if node.is_expanded else icons.FOLDER), "accent"
        else:
            glyph, color = icons.for_path(Path(path) if path else None)
        icon = Text(glyph + " ", style=Style(color=pal(self)[color]))
        return icon + label

    async def _on_click(self, event: events.Click) -> None:
        # правый клик — контекстное меню; открываем по завершённому клику, а не по нажатию:
        # иначе отпускание кнопки достаётся уже меню и выбирает его первый пункт
        # (обычный клик Textual отдаёт Tree._on_click сам — обработчики вызываются по всей цепочке классов)
        if event.button != 3:
            return
        event.prevent_default()
        event.stop()
        node = self.get_node_at_line(event.y + int(self.scroll_y))
        if node is None or node.data is None:
            path = Path(self.path)
        else:
            self.move_cursor(node)
            path = Path(node.data.path)
        self.post_message(self.ContextMenu(path, event.screen_x, event.screen_y))


# ---------------------------------------------------------------- строка состояния: капсулы
class StatusBar(Horizontal):
    class Action(Message):
        def __init__(self, action: str):
            super().__init__()
            self.action = action

    def compose(self) -> ComposeResult:
        yield Label("", id="st-path")
        yield Static(id="st-spacer")
        yield Pill("", kind="soft", id="st-branch")
        yield Pill("", kind="soft", action="goto_line", id="st-pos")
        yield Pill("", kind="soft", action="toggle_indent", id="st-indent")
        yield Pill("", kind="soft", action="command_palette", id="st-lang")

    def set(self, path: str | Text = "", branch: str = "", pos: str = "", indent: str = "", lang: str | Text = "") -> None:
        self.query_one("#st-path", Label).update(path)
        for key, val in (("branch", branch), ("pos", pos), ("indent", indent), ("lang", lang)):
            w = self.query_one(f"#st-{key}", Pill)
            w.display = bool(val)
            if val:
                w.set(val)

    @on(Pill.Pressed)
    def pressed(self, e: Pill.Pressed) -> None:
        e.stop()
        if e.pill.action:
            self.post_message(self.Action(e.pill.action))


# ---------------------------------------------------------------- поиск и замена
class FindBar(Vertical):
    """Ctrl+F — найти, Ctrl+H — заменить. Enter — следующее, Shift+Enter — предыдущее, Esc — закрыть."""

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
            yield Label(icons.SEARCH, classes="find-icon")
            yield Input(placeholder="Найти в файле", id="find", compact=True)
            yield Label("", id="find-count")
            yield Button("", id="find-prev", classes="small", compact=True, tooltip="Предыдущее (Shift+Enter)")
            yield Button("", id="find-next", classes="small", compact=True, tooltip="Следующее (Enter)")
            yield Button(icons.CLOSE, id="find-close", classes="small", compact=True, tooltip="Закрыть (Esc)")
        with Horizontal(classes="find-row", id="replace-row"):
            yield Label("", classes="find-icon")
            yield Input(placeholder="Заменить на", id="replace", compact=True)
            yield Button("Заменить", id="replace-one", classes="small", compact=True)
            yield Button("Все", id="replace-all", classes="small", compact=True)

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


# ---------------------------------------------------------------- стартовый экран как лаунчер
LOGO = (
    "   ▄████▄   ▄█████▄  ██    ██  ▄█████▄\n"
    "  ██▀  ▀▀  ██▀   ▀██ ██    ██ ██▄▄▄▄██\n"
    "  ██▄  ▄▄  ██▄   ▄██  ██  ██  ██▀▀▀▀▀▀\n"
    "   ▀████▀   ▀█████▀    ▀██▀    ▀█████▀"
)


def greeting() -> str:
    import time
    h = time.localtime().tm_hour
    return "Доброй ночи" if h < 5 else "Доброе утро" if h < 12 else "Добрый день" if h < 18 else "Добрый вечер"


class Dashboard(VerticalScroll):
    """Когда нет открытых файлов: поле поиска файла (ищет при вводе), недавние, кнопки — как лаунчер шелла."""

    class Open(Message):
        def __init__(self, target: str):
            super().__init__()
            self.target = target

    def __init__(self, project: Path, recent: list[str], **kw):
        super().__init__(**kw)
        self.project, self.recent = project, recent
        self.files: list[str] | None = None

    def compose(self) -> ComposeResult:
        import os
        with Center():
            yield Static(Text(LOGO), id="logo")
        with Center():
            yield Label(Text.assemble((greeting() + ", ", ""), (os.environ.get("USER", ""), "bold")), id="dash-hello")
        with Center():
            yield Label(Text.assemble((icons.FOLDER + "  ", ""), (short_path(self.project, 60), "")), id="dash-project")
        with Center():
            with Vertical(id="dash-box"):
                yield Input(placeholder=f"{icons.SEARCH}  Найти файл в проекте…", id="dash-search", compact=True)
                yield OptionList(id="dash-list")
        with Center():
            with Horizontal(id="dash-buttons"):
                yield Pill(Text(f"{icons.PLUS} Новый файл"), kind="surface", action="dash-new", id="dash-new")
                yield Pill(Text(f"{icons.FOLDER_OPEN} Открыть папку"), kind="surface", action="dash-folder", id="dash-folder")
                yield Pill(Text(f"{icons.MENU} Все команды"), kind="surface", action="dash-commands", id="dash-commands")

    def on_mount(self) -> None:
        self.show_items("")

    def show_items(self, q: str) -> None:
        ol = self.query_one("#dash-list", OptionList)
        ol.clear_options()
        if q:
            if self.files is None:
                self.files = list_files(self.project)
            scored = sorted(((fuzzy(q, f), f) for f in self.files), key=lambda x: -x[0])
            paths = [str(self.project / f) for s, f in scored if s >= 0][:9]
        else:
            paths = self.recent[:9]
        for path in paths:
            p = Path(path)
            glyph, color = icons.for_path(p)
            t = Text()
            t.append(glyph + "  ", style=Style(color=pal(self)[color]))
            t.append(p.name, style="bold")
            t.append("   " + short_path(p.parent, 50), style=Style(color=pal(self)["overlay1"]))
            ol.add_option(Option(t, id=path))
        if not paths and not q:
            ol.add_option(Option(Text("Недавних файлов пока нет — начните поиск выше", style=Style(color=pal(self)["overlay1"])), disabled=True))
        if paths:
            ol.highlighted = 0

    @on(Input.Changed, "#dash-search")
    def search(self, e: Input.Changed) -> None:
        self.show_items(e.value.strip())

    @on(Input.Submitted, "#dash-search")
    def submit(self) -> None:
        ol = self.query_one("#dash-list", OptionList)
        if ol.highlighted is not None and ol.option_count and ol.get_option_at_index(ol.highlighted).id:
            self.post_message(self.Open(ol.get_option_at_index(ol.highlighted).id))

    def on_key(self, e: events.Key) -> None:
        if e.key in ("down", "up") and isinstance(self.app.focused, Input):
            ol = self.query_one("#dash-list", OptionList)
            if ol.option_count:
                ol.highlighted = max(0, min(ol.option_count - 1, (ol.highlighted or 0) + (1 if e.key == "down" else -1)))
            e.stop()

    @on(OptionList.OptionSelected, "#dash-list")
    def chosen(self, e: OptionList.OptionSelected) -> None:
        if e.option.id:
            self.post_message(self.Open(e.option.id))

    @on(Pill.Pressed)
    def pressed(self, e: Pill.Pressed) -> None:
        e.stop()
        self.post_message(self.Open(e.pill.action))
