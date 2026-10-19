#!/usr/bin/env python3
"""Долгие операции Cove Files с прогрессом (JSON-строки в stdout).

    ops.py check <куда> <что>...                         какие имена уже заняты → ["имя", ...]
    ops.py copy|move <политика> <куда> <что>...          политика: replace | skip | rename
    ops.py trash <что>...
    ops.py delete <что>...                               насовсем
    ops.py extract <куда> <архив>...                     каждый архив — в свою папку
    ops.py compress <архив.zip|.tar.gz|.7z> <что>...

Строки: {"t":"progress","done":байты,"total":байты,"file":имя}, в конце {"t":"done","created":[...],"errors":[...]}.
SIGTERM — отмена: недописанный файл удаляется.
"""

import json
import os
import shutil
import signal
import stat as st
import subprocess
import sys
import time

cancelled = False
partial = None


def on_term(*_):
    global cancelled
    cancelled = True


signal.signal(signal.SIGTERM, on_term)
signal.signal(signal.SIGINT, on_term)


def emit(**kw):
    sys.stdout.write(json.dumps(kw, ensure_ascii=False) + "\n")
    sys.stdout.flush()


class Progress:
    def __init__(self, total):
        self.total, self.done, self.last, self.file = total, 0, 0, ""

    def add(self, n, file=None):
        self.done += n
        if file:
            self.file = file
        now = time.monotonic()
        if now - self.last > 0.12:
            self.last = now
            emit(t="progress", done=self.done, total=self.total, file=self.file)


def size_of(p):
    try:
        s = os.lstat(p)
    except OSError:
        return 0
    if st.S_ISDIR(s.st_mode):
        total = 0
        for root, dirs, files in os.walk(p):
            for f in files:
                try:
                    total += os.lstat(os.path.join(root, f)).st_size
                except OSError:
                    pass
            total += 1  # папки тоже двигают прогресс
        return total
    return max(1, s.st_size)


def free_name(path):
    if not os.path.lexists(path):
        return path
    base, ext = (path, "") if os.path.isdir(path) else os.path.splitext(path)
    if base.endswith(".tar"):  # архив.tar.gz → архив (2).tar.gz
        base, ext = base[:-4], ".tar" + ext
    i = 2
    while os.path.lexists(f"{base} ({i}){ext}"):
        i += 1
    return f"{base} ({i}){ext}"


def copy_file(src, dst, prog):
    global partial
    if os.path.islink(src):
        os.symlink(os.readlink(src), dst)
        prog.add(1, os.path.basename(src))
        return
    partial = dst
    with open(src, "rb") as fi, open(dst, "wb") as fo:
        while True:
            if cancelled:
                raise KeyboardInterrupt
            b = fi.read(1 << 20)
            if not b:
                break
            fo.write(b)
            prog.add(len(b), os.path.basename(src))
    partial = None
    shutil.copystat(src, dst, follow_symlinks=False)
    if os.path.getsize(dst) == 0:
        prog.add(1)


def copy_tree(src, dst, prog):
    if os.path.isdir(src) and not os.path.islink(src):
        os.makedirs(dst, exist_ok=True)
        prog.add(1, os.path.basename(src))
        for name in sorted(os.listdir(src)):
            if cancelled:
                raise KeyboardInterrupt
            copy_tree(os.path.join(src, name), os.path.join(dst, name), prog)
        try:
            shutil.copystat(src, dst)
        except OSError:
            pass
    else:
        copy_file(src, dst, prog)


def remove(p):
    if os.path.isdir(p) and not os.path.islink(p):
        shutil.rmtree(p)
    elif os.path.lexists(p):
        os.remove(p)


def cmd_check(dest, *srcs):
    print(json.dumps([os.path.basename(s.rstrip("/")) for s in srcs
                      if os.path.lexists(os.path.join(dest, os.path.basename(s.rstrip("/"))))
                      and os.path.abspath(os.path.dirname(s.rstrip("/"))) != os.path.abspath(dest)], ensure_ascii=False))


def cmd_transfer(mode, policy, dest, *srcs):
    created, errors = [], []
    srcs = [s.rstrip("/") for s in srcs]
    prog = Progress(sum(size_of(s) for s in srcs) if mode == "copy" else 0)
    emit(t="progress", done=0, total=prog.total, file="")
    for src in srcs:
        if cancelled:
            break
        name = os.path.basename(src)
        dst = os.path.join(dest, name)
        try:
            if os.path.abspath(dest + "/").startswith(os.path.abspath(src) + "/"):
                raise OSError("нельзя положить папку саму в себя")
            same = os.path.abspath(os.path.dirname(src)) == os.path.abspath(dest)
            if same and mode == "move":
                continue
            if os.path.lexists(dst):
                if same or policy == "rename":
                    dst = free_name(dst)
                elif policy == "skip":
                    continue
                elif policy == "replace":
                    remove(dst)
            if mode == "move":
                try:
                    os.rename(src, dst)  # тот же диск — мгновенно
                except OSError:
                    prog.total += size_of(src)
                    copy_tree(src, dst, prog)
                    remove(src)
            else:
                copy_tree(src, dst, prog)
            created.append(dst)
        except KeyboardInterrupt:
            break
        except Exception as e:
            errors.append(f"{name}: {e}")
    if cancelled and partial:
        try:
            os.remove(partial)
        except OSError:
            pass
    emit(t="done", created=created, errors=errors, cancelled=cancelled)


def cmd_trash(*paths):
    errors, unsupported = [], []
    for i, p in enumerate(paths):
        r = subprocess.run(["gio", "trash", "--", p], stdin=subprocess.DEVNULL, capture_output=True, text=True)
        if r.returncode:
            err = r.stderr.strip()
            # у этого диска нет корзины (tmpfs, системные разделы) — интерфейс предложит удалить насовсем
            if "not supported" in err or "Unable to find or create trash" in err:
                unsupported.append(p)
            else:
                errors.append(f"{os.path.basename(p)}: {err.split(': ')[-1] or 'не удалось'}")
        emit(t="progress", done=i + 1, total=len(paths), file=os.path.basename(p))
    emit(t="done", created=[], errors=errors, unsupported=unsupported, cancelled=False)


def cmd_delete(*paths):
    errors = []
    for i, p in enumerate(paths):
        if cancelled:
            break
        try:
            remove(p)
        except Exception as e:
            errors.append(f"{os.path.basename(p)}: {e}")
        emit(t="progress", done=i + 1, total=len(paths), file=os.path.basename(p))
    emit(t="done", created=[], errors=errors, cancelled=cancelled)


def archive_stem(name):
    for ext in (".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2", ".tgz", ".tar", ".zip", ".7z", ".rar", ".gz", ".xz", ".zst"):
        if name.lower().endswith(ext):
            return name[: -len(ext)]
    return os.path.splitext(name)[0]


def cmd_extract(dest, *archives):
    created, errors = [], []
    for i, a in enumerate(archives):
        out = free_name(os.path.join(dest, archive_stem(os.path.basename(a))))
        os.makedirs(out)
        emit(t="progress", done=i, total=len(archives), file=os.path.basename(a))
        r = subprocess.run(["bsdtar", "-xf", a, "-C", out], stdin=subprocess.DEVNULL, capture_output=True, text=True)
        if r.returncode:
            errors.append(f"{os.path.basename(a)}: {r.stderr.strip()[:200]}")
            shutil.rmtree(out, ignore_errors=True)
            continue
        # в архиве одна папка — не делаем «папку в папке»
        inner = os.listdir(out)
        if len(inner) == 1 and os.path.isdir(os.path.join(out, inner[0])):
            target = free_name(os.path.join(dest, inner[0]))
            tmp = out + ".cove-tmp"
            os.rename(out, tmp)
            os.rename(os.path.join(tmp, inner[0]), target)
            os.rmdir(tmp)
            out = target
        created.append(out)
    emit(t="done", created=created, errors=errors, cancelled=False)


def cmd_compress(archive, *paths):
    archive = free_name(archive)
    base = os.path.dirname(paths[0])
    names = [os.path.relpath(p, base) for p in paths]
    emit(t="progress", done=0, total=1, file=os.path.basename(archive))
    r = subprocess.run(["bsdtar", "-a", "-cf", archive, "-C", base, "--", *names],
                       stdin=subprocess.DEVNULL, capture_output=True, text=True)
    errors = [r.stderr.strip()[:200]] if r.returncode else []
    emit(t="done", created=[] if errors else [archive], errors=errors, cancelled=False)


def main(a):
    if not a:
        print(__doc__)
        return 2
    c, rest = a[0], a[1:]
    if c == "check":
        cmd_check(*rest)
    elif c in ("copy", "move"):
        cmd_transfer(c, *rest)
    elif c == "trash":
        cmd_trash(*rest)
    elif c == "delete":
        cmd_delete(*rest)
    elif c == "extract":
        cmd_extract(*rest)
    elif c == "compress":
        cmd_compress(*rest)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
