"""Cove Code — терминальный редактор Cove: без режимов, всё мышью и привычными клавишами, цвета шелла."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from textual import on, work
from textual.app import App, ComposeResult, SystemCommand
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from rich.style import Style
from rich.text import Text
from textual.widgets import ContentSwitcher, TextArea

from . import palette
from .dialogs import SEPARATOR, Ask, MenuItem, PopupMenu, Prompt, QuickOpen
from .editor import LANGUAGE_LABEL, Buffer, CoveTextArea, make_editor, read_file
from . import icons
from .widgets import Dashboard, FindBar, Pill, Sidebar, StatusBar, TabStrip, TopBar, short_path

# COVE_CODE_STATE / COVE_CODE_STATUS — для тестов, чтобы не трогать настоящие недавние файлы и панель
STATE = Path(os.environ.get("COVE_CODE_STATE") or Path.home() / ".local/state/cove/code.json")
STATUS = Path(os.environ.get("COVE_CODE_STATUS") or Path.home() / ".cache/cove/status.json")


def home_short(p: Path | str) -> str:
    s = str(p)
    h = str(Path.home())
    return "~" + s[len(h):] if s.startswith(h) else s


def git_root(start: Path) -> Path | None:
    for d in [start, *start.parents]:
        if (d / ".git").exists():
            return d
    return None


def git_branch(root: Path) -> str:
    g = git_root(root)
    if not g:
        return ""
    head = g / ".git" / "HEAD"
    try:
        s = head.read_text().strip()
    except OSError:
        return ""
    return s[16:] if s.startswith("ref: refs/heads/") else s[:7]


class CoveCode(App):
    CSS_PATH = "app.tcss"
    TITLE = "Cove Code"
    COMMAND_PALETTE_BINDING = "f1"
    ENABLE_COMMAND_PALETTE = True

    BINDINGS = [
        Binding("ctrl+s", "save", "Сохранить", priority=True),
        Binding("ctrl+n", "new_file", "Новый", priority=True),
        Binding("ctrl+p,ctrl+o", "quick_open", "Открыть", priority=True),
        Binding("ctrl+w", "close_tab", "Закрыть", priority=True),
        Binding("ctrl+q", "quit_app", "Выход", priority=True),
        Binding("ctrl+f", "find(False)", "Найти", priority=True),
        Binding("ctrl+h,ctrl+r", "find(True)", "Заменить", priority=True),
        Binding("f3", "find_next(True)", show=False, priority=True),
        Binding("shift+f3", "find_next(False)", show=False, priority=True),
        Binding("ctrl+g", "goto_line", "К строке", priority=True),
        Binding("ctrl+b", "toggle_sidebar", "Панель", priority=True),
        Binding("alt+z", "toggle_wrap", "Перенос", priority=True),
        Binding("ctrl+pagedown,ctrl+tab", "next_tab(1)", show=False, priority=True),
        Binding("ctrl+pageup,ctrl+shift+tab", "next_tab(-1)", show=False, priority=True),
        Binding("f1,ctrl+shift+p", "command_palette", show=False, priority=True),
        Binding("f10", "menu", show=False, priority=True),
    ] + [Binding(f"alt+{i}", f"tab_index({i})", show=False, priority=True) for i in range(1, 10)]

    def __init__(self, target: Path | None = None):
        super().__init__()
        target = (target or Path.cwd()).expanduser().resolve()
        if target.is_dir():
            self.root, self.open_first = target, None
        else:
            self.root = git_root(target.parent) or target.parent
            self.open_first = target
        self.buffers: dict[str, Buffer] = {}
        self.order: list[str] = []          # порядок вкладок (id буферов)
        self.active: str | None = None
        self.pal = palette.load()
        self.state = self.load_state()
        self.theme_serial = 0
        self.palette_mtime = 0.0
        self.find_query = ""
        self.branch = ""
        self.status_pending = False

    # ---------------------------------------------------------------- состояние между запусками
    def load_state(self) -> dict:
        try:
            return json.loads(STATE.read_text())
        except (OSError, ValueError):
            return {}

    def save_state(self) -> None:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(self.state, ensure_ascii=False, indent=1))

    def remember(self, path: Path) -> None:
        rec = [str(path)] + [r for r in self.state.get("recent", []) if r != str(path)]
        self.state["recent"] = rec[:30]
        self.save_state()

    # ---------------------------------------------------------------- окно
    def compose(self) -> ComposeResult:
        yield TopBar(id="topbar")
        with Horizontal(id="body"):
            yield Sidebar(self.root, id="sidebar")
            with ContentSwitcher(initial="dashboard", id="switcher"):
                yield Dashboard(self.root, self.state.get("recent", []), id="dashboard")
                with Vertical(id="editor-card"):
                    yield TabStrip(id="tabstrip")
                    yield FindBar(id="findbar")
                    yield ContentSwitcher(id="editors")
        yield StatusBar(id="statusbar")

    def on_mount(self) -> None:
        self.apply_palette(force=True)
        self.set_interval(0.5, self.apply_palette)   # дёшево: только mtime файла
        self.set_interval(2.0, self.check_disk)
        self.set_interval(5.0, self.update_branch)
        self.query_one(FindBar).display = False
        self.query_one(Sidebar).display = self.state.get("sidebar", True)
        self.update_branch()
        self.query_one(Sidebar).show_root = False
        self.update_titles()
        if self.open_first:
            self.open_path(self.open_first)
        else:
            self.query_one(Sidebar).focus()
        self.refresh_status()

    # ---------------------------------------------------------------- палитра шелла
    def get_theme_variable_defaults(self) -> dict[str, str]:
        # стили разбираются до регистрации темы — переменные Cove нужны сразу
        return {**super().get_theme_variable_defaults(), **palette.app_theme(palette.load(), "cove-0").variables}

    def apply_palette(self, force: bool = False) -> None:
        m = palette.mtime()
        if not force and m == self.palette_mtime:
            return
        self.palette_mtime = m
        p = palette.load()
        # новое имя темы при каждой смене: Textual перерисовывает только при смене имени
        self.theme_serial += 1
        name = f"cove-{self.theme_serial}"
        self.register_theme(palette.app_theme(p, name))
        self.theme = name
        self.pal = p
        self.editor_theme = palette.editor_theme(p, name)
        for ta in self.query(CoveTextArea):
            ta.register_theme(self.editor_theme)
            ta.theme = name
        # капсулы и значки рисуются цветами палитры напрямую — перерисовать
        for w in self.query(Pill):
            w.refresh()
        self.query_one(Sidebar).refresh()
        if not force:
            self.query_one(Dashboard).show_items(self.query_one("#dash-search").value.strip())

    # ---------------------------------------------------------------- буферы и вкладки
    def current(self) -> tuple[Buffer, CoveTextArea] | None:
        bid = self.active
        buf = self.buffers.get(bid or "")
        if not buf:
            return None
        try:
            return buf, self.query_one(f"#{bid}", CoveTextArea)
        except Exception:
            return None

    def activate(self, bid: str) -> None:
        if bid not in self.buffers:
            return
        self.active = bid
        self.query_one("#switcher", ContentSwitcher).current = "editor-card"
        self.query_one("#editors", ContentSwitcher).current = bid
        self.sync_tabs()
        self.refresh_status()
        self.call_after_refresh(self.focus_editor)

    def find_buffer(self, path: Path) -> Buffer | None:
        return next((b for b in self.buffers.values() if b.path == path), None)

    def open_path(self, path: Path, line: int | None = None) -> None:
        path = path.expanduser().resolve()
        existing = self.find_buffer(path)
        if existing:
            self.activate(existing.id)
            return
        if path.is_dir():
            self.set_root(path)
            return
        text = ""
        if path.exists():
            try:
                text = read_file(path)
            except ValueError:
                self.notify(f"{path.name}: это не текстовый файл", severity="warning")
                return
            except OSError as e:
                self.notify(f"Не открылся {path.name}: {e.strerror}", severity="error")
                return
        buf = Buffer(path, text)
        self.add_buffer(buf, text)
        self.remember(path)
        if line:
            self.call_after_refresh(lambda: self.query_one(f"#{buf.id}", CoveTextArea).move_cursor((line - 1, 0), center=True))

    def add_buffer(self, buf: Buffer, text: str) -> None:
        self.buffers[buf.id] = buf
        # новая вкладка — справа от текущей
        i = self.order.index(self.active) + 1 if self.active in self.order else len(self.order)
        self.order.insert(i, buf.id)
        ta = make_editor(buf, text, self.editor_theme.name)
        ta.register_theme(self.editor_theme)
        ta.theme = self.editor_theme.name
        self.query_one("#editors", ContentSwitcher).mount(ta)
        self.call_after_refresh(lambda: self.activate(buf.id))

    def sync_tabs(self) -> None:
        self.query_one(TabStrip).sync([
            {"id": bid, "title": self.buffers[bid].title, "path": self.buffers[bid].path,
             "dirty": self.is_dirty(self.buffers[bid]), "active": bid == self.active}
            for bid in self.order if bid in self.buffers
        ])
        self.update_titles()

    def update_tab(self, buf: Buffer) -> None:
        self.sync_tabs()

    def update_titles(self) -> None:
        """Заголовки карточек: проект над деревом, путь-«хлебные крошки» над редактором."""
        self.query_one(Sidebar).border_title = f"{icons.FOLDER} {self.root.name}"
        cur = self.current()
        card = self.query_one("#editor-card")
        if cur and cur[0].path:
            try:
                parts = cur[0].path.relative_to(self.root).parts
            except ValueError:
                parts = (home_short(cur[0].path),)
            card.border_title = " › ".join(parts)
        else:
            card.border_title = "Новый файл" if cur else ""

    def is_dirty(self, buf: Buffer) -> bool:
        try:
            return self.query_one(f"#{buf.id}", CoveTextArea).text != buf.saved_text
        except Exception:
            return False

    def close_buffer(self, bid: str, force: bool = False) -> None:
        buf = self.buffers.get(bid)
        if not buf:
            return
        if not force and self.is_dirty(buf):
            def answer(a: str | None) -> None:
                if a == "save":
                    if self.save_buffer(buf):
                        self.close_buffer(bid, force=True)
                elif a == "discard":
                    self.close_buffer(bid, force=True)
            self.push_screen(Ask("Сохранить изменения?", f"В «{buf.title}» есть несохранённые правки.",
                                 [("cancel", "Отмена", "default"), ("discard", "Не сохранять", "error"), ("save", "Сохранить", "primary")]), answer)
            return
        i = self.order.index(bid)
        self.order.remove(bid)
        del self.buffers[bid]
        self.query_one(f"#{bid}", CoveTextArea).remove()
        if not self.order:
            self.active = None
            self.sync_tabs()
            self.show_dashboard()
        elif self.active == bid:
            self.activate(self.order[min(i, len(self.order) - 1)])
        else:
            self.sync_tabs()
        self.call_after_refresh(self.refresh_status)

    def show_dashboard(self) -> None:
        dash = self.query_one(Dashboard)
        dash.project, dash.recent = self.root, self.state.get("recent", [])
        dash.files = None
        dash.refresh(recompose=True)   # свежие «недавние» и папка проекта
        self.query_one("#switcher", ContentSwitcher).current = "dashboard"
        self.query_one(Sidebar).focus()

    # ---------------------------------------------------------------- сохранение
    def save_buffer(self, buf: Buffer) -> bool:
        if buf.path is None:
            self.action_save_as()
            return False
        ta = self.query_one(f"#{buf.id}", CoveTextArea)
        text = ta.text
        try:
            buf.path.parent.mkdir(parents=True, exist_ok=True)
            tmp = buf.path.with_name(f".{buf.path.name}.cove-tmp")
            tmp.write_text(text, encoding="utf-8")
            if buf.path.exists():
                os.chmod(tmp, buf.path.stat().st_mode)
            os.replace(tmp, buf.path)   # атомарно: при сбое старый файл цел
        except OSError as e:
            self.notify(f"Не сохранилось: {e.strerror}", severity="error")
            return False
        buf.saved_text = text
        buf.disk_mtime = buf.path.stat().st_mtime
        self.update_tab(buf)
        self.refresh_status()
        self.query_one(Sidebar).reload() if buf.path.parent == self.root else None
        return True

    def action_save(self) -> None:
        cur = self.current()
        if cur:
            buf, _ = cur
            if self.save_buffer(buf):
                self.notify(f"Сохранено: {buf.title}", timeout=1.5)

    def action_save_all(self) -> None:
        n = sum(1 for b in list(self.buffers.values()) if self.is_dirty(b) and b.path and self.save_buffer(b))
        self.notify(f"Сохранено файлов: {n}", timeout=1.5)

    def action_save_as(self) -> None:
        cur = self.current()
        if not cur:
            return
        buf, ta = cur
        start = home_short(buf.path) if buf.path else home_short(self.root) + "/"

        def done(v: str | None) -> None:
            if not v:
                return
            p = Path(v).expanduser()
            p = (self.root / p) if not p.is_absolute() else p
            buf.path = p.resolve()
            ta.language = None
            from .editor import detect_language
            ta.language = detect_language(buf.path)
            if self.save_buffer(buf):
                self.remember(buf.path)
                self.notify(f"Сохранено: {buf.title}", timeout=1.5)
        self.push_screen(Prompt("Сохранить как", start, "Путь к файлу", "Сохранить"), done)

    # ---------------------------------------------------------------- действия
    def action_new_file(self) -> None:
        self.add_buffer(Buffer(None), "")

    def action_quick_open(self) -> None:
        rec = []
        for r in self.state.get("recent", []):
            try:
                rec.append(str(Path(r).relative_to(self.root)))
            except ValueError:
                pass

        def done(rel: str | None) -> None:
            if rel:
                self.open_path(self.root / rel)
        self.push_screen(QuickOpen(self.root, rec), done)

    def action_open_folder(self) -> None:
        def done(v: str | None) -> None:
            if v:
                p = Path(v).expanduser()
                if p.is_dir():
                    self.set_root(p.resolve())
                else:
                    self.notify("Нет такой папки", severity="warning")
        self.push_screen(Prompt("Открыть папку", home_short(self.root), "Путь к папке", "Открыть"), done)

    def set_root(self, path: Path) -> None:
        self.root = path
        self.query_one(Sidebar).path = path
        self.update_titles()
        self.update_branch()
        if not self.buffers:
            self.show_dashboard()
        self.refresh_status()

    def action_close_tab(self) -> None:
        cur = self.current()
        if cur:
            self.close_buffer(cur[0].id)

    def action_next_tab(self, d: int) -> None:
        if len(self.order) < 2:
            return
        i = self.order.index(self.active) if self.active in self.order else 0
        self.activate(self.order[(i + d) % len(self.order)])

    def action_tab_index(self, n: int) -> None:
        if n - 1 < len(self.order):
            self.activate(self.order[n - 1])

    def focus_editor(self) -> None:
        cur = self.current()
        if cur:
            cur[1].focus()

    def action_quit_app(self) -> None:
        dirty = [b for b in self.buffers.values() if self.is_dirty(b)]
        if not dirty:
            self.exit()
            return

        def answer(a: str | None) -> None:
            if a == "save":
                if all(self.save_buffer(b) for b in dirty):
                    self.exit()
            elif a == "discard":
                self.exit()
        names = ", ".join(b.title for b in dirty[:4]) + ("…" if len(dirty) > 4 else "")
        self.push_screen(Ask("Выйти из Cove Code?", f"Не сохранено: {names}",
                             [("cancel", "Отмена", "default"), ("discard", "Выйти без сохранения", "error"), ("save", "Сохранить и выйти", "primary")]), answer)

    def action_toggle_sidebar(self) -> None:
        sb = self.query_one(Sidebar)
        sb.display = not sb.display
        self.state["sidebar"] = sb.display
        self.save_state()
        if sb.display:
            sb.focus()
        else:
            self.focus_editor()

    def action_toggle_hidden(self) -> None:
        sb = self.query_one(Sidebar)
        sb.show_hidden = not sb.show_hidden
        sb.reload()

    def action_toggle_wrap(self) -> None:
        cur = self.current()
        if cur:
            cur[1].soft_wrap = not cur[1].soft_wrap

    def action_toggle_numbers(self) -> None:
        cur = self.current()
        if cur:
            cur[1].show_line_numbers = not cur[1].show_line_numbers

    def action_toggle_indent(self) -> None:
        cur = self.current()
        if not cur:
            return
        ta = cur[1]
        # пробелы 4 → пробелы 2 → табы → пробелы 4
        if ta.indent_type == "tabs":
            ta.indent_type, ta.indent_width = "spaces", 4
        elif ta.indent_width == 4:
            ta.indent_width = 2
        else:
            ta.indent_type, ta.indent_width = "tabs", 4
        self.refresh_status()

    def action_goto_line(self) -> None:
        cur = self.current()
        if not cur:
            return
        ta = cur[1]

        def done(v: str | None) -> None:
            if not v:
                return
            parts = v.replace(",", ":").split(":")
            try:
                row = max(1, min(int(parts[0]), ta.document.line_count))
                col = max(1, int(parts[1])) if len(parts) > 1 and parts[1] else 1
            except ValueError:
                return
            ta.move_cursor((row - 1, col - 1), center=True)
            ta.focus()
        self.push_screen(Prompt("Перейти к строке", "", f"Строка (1–{ta.document.line_count}), можно строка:столбец", "Перейти"), done)

    def run_editor_action(self, name: str) -> None:
        cur = self.current()
        if cur:
            cur[1].focus()
            self.call_after_refresh(lambda: cur[1].run_action(name))

    # ---------------------------------------------------------------- поиск
    def action_find(self, replace: bool) -> None:
        cur = self.current()
        if not cur:
            return
        sel = cur[1].selected_text
        self.query_one(FindBar).show(replace, sel if sel and "\n" not in sel else "")

    @on(FindBar.Closed)
    def find_closed(self) -> None:
        self.query_one(FindBar).display = False
        self.focus_editor()

    @on(FindBar.Find)
    def find(self, e: FindBar.Find) -> None:
        self.find_query = e.query
        self.find_in_editor(e.query, e.forward, from_start_of_selection=e.live)

    def action_find_next(self, forward: bool) -> None:
        q = self.find_query or self.query_one(FindBar).query_text
        if q:
            self.find_in_editor(q, forward)

    def find_in_editor(self, q: str, forward: bool = True, from_start_of_selection: bool = False) -> bool:
        cur = self.current()
        fb = self.query_one(FindBar)
        if not cur or not q:
            fb.set_count("")
            return False
        ta = cur[1]
        doc = ta.document
        text = ta.text
        sensitive = q != q.lower()   # «умный» регистр: есть заглавные — учитываем регистр
        hay, needle = (text, q) if sensitive else (text.lower(), q.lower())
        count = hay.count(needle)
        start, end = sorted(ta.selection)
        if forward:
            pos = doc.get_index_from_location(start if from_start_of_selection else end)
            i = hay.find(needle, pos)
            if i < 0:
                i = hay.find(needle)
        else:
            pos = doc.get_index_from_location(start)
            i = hay.rfind(needle, 0, pos)
            if i < 0:
                i = hay.rfind(needle)
        if i < 0:
            fb.set_count("нет")
            return False
        before = hay.count(needle, 0, i) + 1
        fb.set_count(f"{before} из {count}")
        a, b = doc.get_location_from_index(i), doc.get_location_from_index(i + len(q))
        ta.selection = type(ta.selection)(a, b)
        ta.scroll_cursor_visible(center=True)
        return True

    @on(FindBar.Replace)
    def replace(self, e: FindBar.Replace) -> None:
        cur = self.current()
        if not cur or not e.query:
            return
        ta = cur[1]
        sensitive = e.query != e.query.lower()
        if e.all:
            import re
            flags = 0 if sensitive else re.IGNORECASE
            new, n = re.subn(re.escape(e.query), lambda _: e.replacement, ta.text, flags=flags)
            if n:
                loc = ta.cursor_location
                ta.replace(new, (0, 0), ta.document.end)   # одной правкой: Ctrl+Z отменит всё сразу
                ta.move_cursor((min(loc[0], ta.document.line_count - 1), 0))
            self.query_one(FindBar).set_count(f"заменено: {n}")
            return
        sel = ta.selected_text
        if sel and (sel == e.query if sensitive else sel.lower() == e.query.lower()):
            r = ta.replace(e.replacement, *ta.selection)
            ta.move_cursor(r.end_location)
        self.find_in_editor(e.query)

    # ---------------------------------------------------------------- меню
    def menu_items(self, menu: str) -> list[MenuItem]:
        cur = self.current()
        has = cur is not None
        if menu == "file":
            return [MenuItem("Новый файл", "new_file", "Ctrl+N"), MenuItem("Открыть файл…", "quick_open", "Ctrl+P"),
                    MenuItem("Открыть папку…", "open_folder"), SEPARATOR,
                    MenuItem("Сохранить", "save", "Ctrl+S", has), MenuItem("Сохранить как…", "save_as", "", has),
                    MenuItem("Сохранить все", "save_all", "", has), SEPARATOR,
                    MenuItem("Закрыть вкладку", "close_tab", "Ctrl+W", has), MenuItem("Выход", "quit_app", "Ctrl+Q")]
        if menu == "edit":
            return [MenuItem("Отменить", "editor:undo", "Ctrl+Z", has), MenuItem("Повторить", "editor:redo", "Ctrl+Y", has), SEPARATOR,
                    MenuItem("Вырезать", "editor:cut", "Ctrl+X", has), MenuItem("Копировать", "editor:copy", "Ctrl+C", has),
                    MenuItem("Вставить", "editor:paste", "Ctrl+V", has), MenuItem("Выделить всё", "editor:select_all", "Ctrl+A", has), SEPARATOR,
                    MenuItem("Найти", "find(False)", "Ctrl+F", has), MenuItem("Заменить", "find(True)", "Ctrl+H", has), SEPARATOR,
                    MenuItem("Закомментировать", "editor:toggle_comment", "Ctrl+/", has and bool(cur[1].comment)),
                    MenuItem("Дублировать строку", "editor:duplicate_line", "Ctrl+D", has),
                    MenuItem("Строку вверх", "editor:move_line(-1)", "Alt+↑", has), MenuItem("Строку вниз", "editor:move_line(1)", "Alt+↓", has)]
        if menu == "view":
            sb = self.query_one(Sidebar)
            mark = lambda on_: "✓ " if on_ else "   "
            return [MenuItem(mark(sb.display) + "Боковая панель", "toggle_sidebar", "Ctrl+B"),
                    MenuItem(mark(sb.show_hidden) + "Скрытые файлы", "toggle_hidden"),
                    MenuItem(mark(has and cur[1].soft_wrap) + "Перенос строк", "toggle_wrap", "Alt+Z", has),
                    MenuItem(mark(has and cur[1].show_line_numbers) + "Номера строк", "toggle_numbers", "", has), SEPARATOR,
                    MenuItem("Все команды", "command_palette", "F1")]
        if menu == "go":
            return [MenuItem("К строке…", "goto_line", "Ctrl+G", has), MenuItem("Быстро открыть файл…", "quick_open", "Ctrl+P"), SEPARATOR,
                    MenuItem("Следующая вкладка", "next_tab(1)", "Ctrl+PgDn", has), MenuItem("Предыдущая вкладка", "next_tab(-1)", "Ctrl+PgUp", has)]
        if menu == "cove":
            return [MenuItem("Все команды", "command_palette", "F1"),
                    MenuItem("Папка проекта в Cove Files", "reveal:" + str(self.root), "", bool(shutil.which("cove-files"))),
                    MenuItem("Терминал в папке проекта", "terminal:" + str(self.root)), SEPARATOR,
                    MenuItem("Выход", "quit_app", "Ctrl+Q")]
        return []

    def action_menu(self, x: int = 1, y: int = 1) -> None:
        items = [MenuItem("Файл", "submenu:file", "›"), MenuItem("Правка", "submenu:edit", "›"),
                 MenuItem("Вид", "submenu:view", "›"), MenuItem("Перейти", "submenu:go", "›"), SEPARATOR,
                 *self.menu_items("cove")]
        self.menu_pos = (x, y)
        self.push_screen(PopupMenu(items, x, y), self.run_menu_action)

    @on(Pill.Pressed)
    def pill_pressed(self, e: Pill.Pressed) -> None:
        act = e.pill.action
        if act == "menu":
            r = e.pill.region
            self.action_menu(r.x if r.x < self.size.width // 2 else max(0, r.x + r.width - 30), r.y + 1)
        elif act:
            self.run_action(act)

    @on(TabStrip.Select)
    def tab_selected(self, e: TabStrip.Select) -> None:
        if e.close:
            self.close_buffer(e.bid)
        else:
            self.activate(e.bid)

    def run_menu_action(self, action: str | None) -> None:
        if not action:
            return
        if action.startswith("submenu:"):
            x, y = getattr(self, "menu_pos", (1, 1))
            self.push_screen(PopupMenu(self.menu_items(action[8:]), x, y), self.run_menu_action)
        elif action.startswith("editor:"):
            self.run_editor_action(action[7:])
        elif action.startswith("reveal:"):
            subprocess.Popen(["cove-files", action[7:]], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif action.startswith("terminal:"):
            term = os.environ.get("TERMINAL") or ("kitty" if shutil.which("kitty") else "xterm")
            subprocess.Popen([term, "--directory", action[9:]] if term == "kitty" else [term], cwd=action[9:],
                             start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif action.startswith("tree:"):
            self.tree_action(action[5:])
        else:
            self.run_action(action)

    # ---------------------------------------------------------------- дерево: открыть, контекстное меню
    @on(Sidebar.FileSelected)
    def file_selected(self, e: Sidebar.FileSelected) -> None:
        self.open_path(Path(e.path))

    @on(Sidebar.ContextMenu)
    def tree_menu(self, e: Sidebar.ContextMenu) -> None:
        self.tree_target = e.path
        is_dir = e.path.is_dir()
        items = [MenuItem("Открыть", "tree:open", "", not is_dir),
                 MenuItem("Новый файл…", "tree:new_file"), MenuItem("Новая папка…", "tree:new_dir"), SEPARATOR,
                 MenuItem("Переименовать…", "tree:rename", "", e.path != self.root),
                 MenuItem("Копировать путь", "tree:copy_path"), SEPARATOR,
                 MenuItem("Показать в Cove Files", "reveal:" + str(e.path if is_dir else e.path.parent), "", bool(shutil.which("cove-files"))),
                 MenuItem("Терминал здесь", "terminal:" + str(e.path if is_dir else e.path.parent)), SEPARATOR,
                 MenuItem("В корзину", "tree:trash", "", e.path != self.root, danger=True)]
        self.push_screen(PopupMenu(items, e.x, e.y), self.run_menu_action)

    def tree_action(self, act: str) -> None:
        p: Path = self.tree_target
        folder = p if p.is_dir() else p.parent
        sb = self.query_one(Sidebar)
        if act == "open":
            self.open_path(p)
        elif act in ("new_file", "new_dir"):
            def done(name: str | None) -> None:
                if not name:
                    return
                target = folder / name
                try:
                    if act == "new_dir":
                        target.mkdir(parents=True)
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.touch(exist_ok=False)
                except OSError as e:
                    self.notify(f"Не получилось: {e.strerror}", severity="error")
                    return
                sb.reload()
                if act == "new_file":
                    self.open_path(target)
            self.push_screen(Prompt("Новая папка" if act == "new_dir" else "Новый файл", "", f"в {home_short(folder)}", "Создать"), done)
        elif act == "rename":
            def done(name: str | None) -> None:
                if not name or name == p.name:
                    return
                target = p.parent / name
                if target.exists():
                    self.notify("Такое имя уже есть", severity="warning")
                    return
                p.rename(target)
                for b in self.buffers.values():
                    if b.path and (b.path == p or p in b.path.parents):
                        b.path = target / b.path.relative_to(p) if b.path != p else target
                        self.update_tab(b)
                sb.reload()
                self.refresh_status()
            self.push_screen(Prompt("Переименовать", p.name, "", "Переименовать"), done)
        elif act == "copy_path":
            from .editor import clipboard_copy
            clipboard_copy(str(p)) or self.copy_to_clipboard(str(p))
            self.notify("Путь скопирован", timeout=1.5)
        elif act == "trash":
            def answer(a: str | None) -> None:
                if a != "trash":
                    return
                ok = shutil.which("gio") and subprocess.run(["gio", "trash", str(p)], capture_output=True).returncode == 0
                if not ok:
                    self.notify("Не получилось убрать в корзину", severity="error")
                    return
                for b in list(self.buffers.values()):
                    if b.path and (b.path == p or p in b.path.parents):
                        self.close_buffer(b.id, force=True)
                sb.reload()
            self.push_screen(Ask("В корзину?", f"«{p.name}» уйдёт в корзину, вернуть можно из Cove Files.",
                                 [("cancel", "Отмена", "default"), ("trash", "В корзину", "error")]), answer)

    # ---------------------------------------------------------------- стартовый экран
    @on(Dashboard.Open)
    def dash_open(self, e: Dashboard.Open) -> None:
        if e.target == "dash-quick":
            self.action_quick_open()
        elif e.target == "dash-new":
            self.action_new_file()
        elif e.target == "dash-folder":
            self.action_open_folder()
        elif e.target == "dash-commands":
            self.action_command_palette()
        else:
            self.open_path(Path(e.target))

    # ---------------------------------------------------------------- строка состояния и связь с шеллом
    @on(StatusBar.Action)
    def status_action(self, e: StatusBar.Action) -> None:
        self.run_action(e.action)

    @on(TextArea.Changed)
    def text_changed(self, e: TextArea.Changed) -> None:
        buf = self.buffers.get(e.text_area.id or "")
        if buf:
            self.update_tab(buf)
            self.refresh_status()

    @on(TextArea.SelectionChanged)
    def selection_changed(self, e: TextArea.SelectionChanged) -> None:
        self.refresh_status(shell=False)

    def update_branch(self) -> None:
        b = git_branch(self.root)
        if b != self.branch:
            self.branch = b
            self.refresh_status()

    def refresh_status(self, shell: bool = True) -> None:
        sb = self.query_one(StatusBar)
        island = self.query_one("#island", Pill)
        p = self.pal
        cur = self.current()
        branch = Text.assemble((icons.BRANCH + " ", Style(color=p["accent2"])), self.branch) if self.branch else ""
        dirty_n = sum(1 for b in self.buffers.values() if self.is_dirty(b))
        if not cur:
            sb.set(path=Text(home_short(self.root), style=Style(color=p["overlay1"])), branch=branch)
            island.set(Text.assemble((icons.FOLDER + "  ", Style(color=p["accent"])), (self.root.name, Style(bold=True)),
                                     *((("   " + icons.BRANCH + " ", Style(color=p["accent2"])), self.branch) if self.branch else ())))
        else:
            buf, ta = cur
            row, col = ta.cursor_location
            sel = ta.selected_text
            pos = f"{row + 1}:{col + 1}" + (f"  \u00b7 {len(sel)} выд." if sel else "")
            glyph, color = icons.for_path(buf.path)
            dirty = ta.text != buf.saved_text
            if buf.path:
                try:
                    shown = str(buf.path.relative_to(self.root))
                except ValueError:
                    shown = home_short(buf.path)
            else:
                shown = "Новый файл"
            sb.set(path=Text(shown, style=Style(color=p["overlay1"])), branch=branch, pos=pos,
                   indent="Табы" if ta.indent_type == "tabs" else f"Пробелы: {ta.indent_width}",
                   lang=Text.assemble((glyph + " ", Style(color=p[color])), LANGUAGE_LABEL.get(ta.language or "", "Текст")))
            # остров: файл, проект, ветка, несохранённое — как остров шелла
            parts: list = [(glyph + "  ", Style(color=p[color])), (buf.title, Style(bold=True))]
            if dirty:
                parts.append(("  " + icons.DOT, Style(color=p["yellow"])))
            parts.append(("   " + self.root.name, Style(color=p["overlay1"])))
            if self.branch:
                parts += [("  " + icons.BRANCH + " ", Style(color=p["accent2"])), (self.branch, Style(color=p["subtext0"]))]
            if dirty_n > (1 if dirty else 0):
                parts.append((f"   {icons.SAVE} {dirty_n}", Style(color=p["yellow"])))
            island.set(Text.assemble(*parts))
        if shell and not self.status_pending:
            self.status_pending = True
            self.set_timer(0.3, self.write_shell_status)

    def write_shell_status(self) -> None:
        """~/.cache/cove/status.json для панели шелла (services/CoveCode.qml) и заголовок терминала."""
        self.status_pending = False
        cur = self.current()
        buf = cur[0] if cur else None
        data = {
            "pid": os.getpid(),
            "project": self.root.name,
            "cwd": str(self.root),
            "file": buf.title if buf else "",
            "path": (str(buf.path.relative_to(self.root)) if buf and buf.path and self.root in buf.path.parents else (home_short(buf.path) if buf and buf.path else "")),
            "branch": self.branch,
            "modified": sum(1 for b in self.buffers.values() if self.is_dirty(b)),
            "errors": 0,
            "warnings": 0,
            "time": int(time.time()),
        }
        try:
            STATUS.parent.mkdir(parents=True, exist_ok=True)
            tmp = STATUS.with_suffix(".tmp")
            tmp.write_text(json.dumps(data, ensure_ascii=False))
            os.replace(tmp, STATUS)
        except OSError:
            pass
        title = f"{buf.title} — {self.root.name} — Cove Code" if buf else f"{self.root.name} — Cove Code"
        try:
            with open("/dev/tty", "w") as tty:
                tty.write(f"\x1b]2;{title}\x07")
        except OSError:
            pass

    def on_unmount(self) -> None:
        try:
            if json.loads(STATUS.read_text()).get("pid") == os.getpid():
                STATUS.unlink()
        except (OSError, ValueError):
            pass

    # ---------------------------------------------------------------- файл изменился на диске
    def check_disk(self) -> None:
        cur = self.current()
        if not cur:
            return
        buf, ta = cur
        if not buf.path or not buf.path.exists():
            return
        m = buf.path.stat().st_mtime
        if m == buf.disk_mtime:
            return
        buf.disk_mtime = m
        if ta.text != buf.saved_text:
            self.notify(f"«{buf.title}» изменён на диске, а у вас есть правки — сохранение перезапишет его", severity="warning", timeout=6)
            return
        try:
            text = read_file(buf.path)
        except (OSError, ValueError):
            return
        loc = ta.cursor_location
        ta.load_text(text)
        buf.saved_text = text
        ta.move_cursor((min(loc[0], ta.document.line_count - 1), loc[1]))
        self.notify(f"«{buf.title}» обновлён с диска", timeout=2)

    # ---------------------------------------------------------------- палитра команд (F1)
    def get_system_commands(self, screen):
        cmds = [
            ("Новый файл", "Ctrl+N", self.action_new_file), ("Открыть файл", "Ctrl+P", self.action_quick_open),
            ("Открыть папку", "", self.action_open_folder), ("Сохранить", "Ctrl+S", self.action_save),
            ("Сохранить как", "", self.action_save_as), ("Сохранить все", "", self.action_save_all),
            ("Закрыть вкладку", "Ctrl+W", self.action_close_tab), ("Найти", "Ctrl+F", lambda: self.action_find(False)),
            ("Заменить", "Ctrl+H", lambda: self.action_find(True)), ("Перейти к строке", "Ctrl+G", self.action_goto_line),
            ("Боковая панель", "Ctrl+B", self.action_toggle_sidebar), ("Скрытые файлы", "", self.action_toggle_hidden),
            ("Перенос строк", "Alt+Z", self.action_toggle_wrap), ("Номера строк", "", self.action_toggle_numbers),
            ("Отступы: пробелы / табы", "", self.action_toggle_indent), ("Выход", "Ctrl+Q", self.action_quit_app),
        ]
        for title, key, cb in cmds:
            yield SystemCommand(title, key, cb)
