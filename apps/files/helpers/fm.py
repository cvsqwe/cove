#!/usr/bin/env python3
"""Быстрые запросы Cove Files. Каждый печатает JSON в stdout.

    apps <mime>                       приложения для типа файла (+ какое по умолчанию)
    launch <desktop-id> <файл>...     открыть файлы приложением
    setdefault <desktop-id> <mime>    сделать приложение основным для типа
    devices                           съёмные и неподключённые разделы
    trash                             содержимое корзины
    restore <имя в корзине>...        вернуть из корзины
    empty                             очистить корзину
    search <папка> <запрос> [hidden]  поиск по именам (fd)
    du <путь>...                      размер и число объектов
    df <путь>                         свободное место
    stat <путь>                       права, владелец, даты, тип
"""

import configparser
import glob
import json
import os
import pwd
import grp
import shutil
import stat as st
import subprocess
import sys
import time
from urllib.parse import unquote

HOME = os.path.expanduser("~")
DATA_HOME = os.environ.get("XDG_DATA_HOME", HOME + "/.local/share")
DATA_DIRS = [DATA_HOME] + os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
TRASH = DATA_HOME + "/Trash"


def out(x):
    print(json.dumps(x, ensure_ascii=False))


def run(*cmd, **kw):
    return subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True, **kw)


# ---------- приложения ----------

def desktop_files():
    seen = {}
    for d in DATA_DIRS:
        for p in glob.glob(d + "/applications/**/*.desktop", recursive=True):
            did = os.path.relpath(p, d + "/applications").replace("/", "-")
            seen.setdefault(did, p)  # первые каталоги главнее
    return seen


def read_entry(path):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(path, encoding="utf-8")
        e = cp["Desktop Entry"]
    except Exception:
        return None
    if e.get("NoDisplay") == "true" or e.get("Hidden") == "true" or e.get("Type", "Application") != "Application":
        return None
    lang = (os.environ.get("LANG") or "").split(".")[0]
    name = e.get(f"Name[{lang}]") or e.get(f"Name[{lang.split('_')[0]}]") or e.get("Name", "")
    return {"name": name, "icon": e.get("Icon", ""), "mimes": [m for m in e.get("MimeType", "").split(";") if m]}


def parents(mime):
    """Тип и его «родители»: text/x-python → text/plain → application/octet-stream."""
    out_ = [mime]
    sub = {}
    for d in DATA_DIRS:
        try:
            for ln in open(d + "/mime/subclasses"):
                a, b = ln.split()
                sub.setdefault(a, []).append(b)
        except OSError:
            pass
    i = 0
    while i < len(out_):
        for p in sub.get(out_[i], []):
            if p not in out_:
                out_.append(p)
        i += 1
    if mime.startswith("text/") and "text/plain" not in out_:
        out_.append("text/plain")
    return out_


def cmd_apps(mime):
    files = desktop_files()
    default = run("xdg-mime", "query", "default", mime).stdout.strip()
    chain = parents(mime)
    res = []
    for did, path in files.items():
        e = read_entry(path)
        if not e:
            continue
        rank = next((i for i, m in enumerate(chain) if m in e["mimes"]), None)
        if rank is None and did != default:
            continue
        res.append({"id": did, "name": e["name"], "icon": e["icon"], "default": did == default,
                    "rank": rank if rank is not None else 0})
    res.sort(key=lambda a: (not a["default"], a["rank"], a["name"].lower()))
    out(res)


def cmd_launch(did, *paths):
    path = desktop_files().get(did)
    if not path:
        out({"error": "нет такого приложения"})
        return
    subprocess.Popen(["gio", "launch", path, *paths], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    out({"ok": True})


def cmd_setdefault(did, mime):
    run("xdg-mime", "default", did, mime)
    out({"ok": True})


# ---------- устройства ----------

def cmd_devices():
    r = run("lsblk", "-J", "-b", "-o", "NAME,LABEL,SIZE,MOUNTPOINT,HOTPLUG,TYPE,RM,FSTYPE,PATH,MODEL")
    try:
        tree = json.loads(r.stdout)["blockdevices"]
    except Exception:
        out([])
        return
    res = []

    def walk(devs, disk):
        for d in devs:
            if d["type"] == "disk":
                disk = d
            kids = d.get("children") or []
            removable = bool(d.get("hotplug") or d.get("rm") or (disk and (disk.get("hotplug") or disk.get("rm"))))
            fs = d.get("fstype")
            mp = d.get("mountpoint")
            if d["type"] in ("part", "disk") and fs and fs not in ("swap", "crypto_LUKS", "LVM2_member") and not kids:
                system = mp in ("/", "/boot", "/home", "/efi", "/boot/efi") or (mp or "").startswith(("/var", "/usr", "/nix"))
                if removable or (not system and (not mp or mp.startswith(("/run/media", "/media", "/mnt")))):
                    res.append({"path": d["path"], "label": d.get("label") or (disk or d).get("model") or d["name"],
                                "size": int(d.get("size") or 0), "mount": mp or "", "fs": fs,
                                "removable": removable, "disk": (disk or d)["path"]})
            walk(kids, disk)
    walk(tree, None)
    out(res)


# ---------- корзина ----------

def cmd_trash():
    res = []
    for info in glob.glob(TRASH + "/info/*.trashinfo"):
        name = os.path.basename(info)[:-10]
        f = TRASH + "/files/" + name
        if not os.path.lexists(f):
            continue
        orig, date = "", ""
        for ln in open(info, encoding="utf-8", errors="replace"):
            if ln.startswith("Path="):
                orig = unquote(ln[5:].strip())
            elif ln.startswith("DeletionDate="):
                date = ln[13:].strip()
        try:
            s = os.lstat(f)
        except OSError:
            continue
        try:
            t = time.mktime(time.strptime(date, "%Y-%m-%dT%H:%M:%S")) * 1000
        except ValueError:
            t = s.st_mtime * 1000
        res.append({"name": os.path.basename(orig) or name, "path": f, "trashName": name, "orig": orig,
                    "dir": st.S_ISDIR(s.st_mode), "size": s.st_size, "mtime": t})
    res.sort(key=lambda x: -x["mtime"])
    out(res)


def free_name(path):
    if not os.path.lexists(path):
        return path
    base, ext = os.path.splitext(path)
    if os.path.isdir(path):
        base, ext = path, ""
    i = 2
    while os.path.lexists(f"{base} ({i}){ext}"):
        i += 1
    return f"{base} ({i}){ext}"


def cmd_restore(*names):
    done, errors = [], []
    for name in names:
        info = f"{TRASH}/info/{name}.trashinfo"
        orig = ""
        try:
            for ln in open(info, encoding="utf-8"):
                if ln.startswith("Path="):
                    orig = unquote(ln[5:].strip())
            if not orig.startswith("/"):
                orig = os.path.join(TRASH, "..", "..", "..", orig)
            os.makedirs(os.path.dirname(orig), exist_ok=True)
            dst = free_name(orig)
            shutil.move(f"{TRASH}/files/{name}", dst)
            os.remove(info)
            done.append(dst)
        except Exception as e:
            errors.append(f"{name}: {e}")
    out({"restored": done, "errors": errors})


def cmd_empty():
    run("gio", "trash", "--empty")
    out({"ok": True})


# ---------- поиск, размеры ----------

def entry(p):
    try:
        s = os.lstat(p)
        isdir = st.S_ISDIR(s.st_mode) or (st.S_ISLNK(s.st_mode) and os.path.isdir(p))
    except OSError:
        return None
    return {"name": os.path.basename(p), "path": p, "dir": isdir, "size": s.st_size, "mtime": s.st_mtime * 1000}


def cmd_search(root, query, hidden=""):
    cmd = ["fd", "-i", "--absolute-path", "--max-results", "3000", "--color", "never"]
    if hidden:
        cmd += ["-H", "--no-ignore"]
    cmd += ["--", query, root]
    r = run(*cmd, timeout=30)
    res = [e for e in (entry(p.rstrip("/")) for p in r.stdout.splitlines()) if e]
    out(res)


def cmd_du(*paths):
    total, count = 0, 0
    for p in paths:
        if os.path.isdir(p) and not os.path.islink(p):
            for root, dirs, files in os.walk(p):
                count += len(dirs) + len(files)
                for f in files:
                    try:
                        total += os.lstat(os.path.join(root, f)).st_size
                    except OSError:
                        pass
        else:
            try:
                total += os.lstat(p).st_size
                count += 1
            except OSError:
                pass
    out({"size": total, "count": count})


def cmd_df(path):
    try:
        u = shutil.disk_usage(path)
        out({"free": u.free, "total": u.total})
    except OSError:
        out({})


def cmd_stat(path):
    try:
        s = os.lstat(path)
    except OSError as e:
        out({"error": str(e)})
        return
    mime = run("file", "-b", "-L", "--mime-type", path).stdout.strip()
    try:
        owner = pwd.getpwuid(s.st_uid).pw_name
    except KeyError:
        owner = str(s.st_uid)
    try:
        group = grp.getgrgid(s.st_gid).gr_name
    except KeyError:
        group = str(s.st_gid)
    out({"mode": st.filemode(s.st_mode), "octal": oct(s.st_mode & 0o777)[2:], "owner": owner, "group": group,
         "mtime": s.st_mtime * 1000, "atime": s.st_atime * 1000, "ctime": s.st_ctime * 1000,
         "link": os.readlink(path) if st.S_ISLNK(s.st_mode) else "", "mime": mime,
         "writable": os.access(path, os.W_OK), "exec": os.access(path, os.X_OK) and not st.S_ISDIR(s.st_mode)})


def main(a):
    if not a:
        print(__doc__)
        return 2
    cmd = {"apps": cmd_apps, "launch": cmd_launch, "setdefault": cmd_setdefault, "devices": cmd_devices,
           "trash": cmd_trash, "restore": cmd_restore, "empty": cmd_empty, "search": cmd_search,
           "du": cmd_du, "df": cmd_df, "stat": cmd_stat}.get(a[0])
    if not cmd:
        print(__doc__)
        return 2
    cmd(*a[1:])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
