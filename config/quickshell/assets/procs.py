#!/usr/bin/env python3
"""Процессы для диспетчера задач (tasks/TasksPanel.qml).

Раз в N секунд (аргумент, по умолчанию 2) печатает строку JSON:
{ "procs": [{pid, ppid, name, exe, cmd, uid, cpu, mem, threads}], "ncpu": …, "memTotal": … }
cpu — доля всей машины (0..1) за последний интервал, mem — RSS в байтах.
Потоки ядра (без exe и cmdline) пропускаются.
"""
import json
import os
import re
import sys
import time

PAGE = os.sysconf("SC_PAGE_SIZE")
TICKS = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count() or 1


def mem_total():
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                return int(line.split()[1]) * 1024
    return 0


def read(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            st = f.read()
        # comm в скобках может содержать пробелы и скобки — режем по последней «)»
        rp = st.rfind(")")
        comm = st[st.find("(") + 1:rp]
        f = st[rp + 2:].split()
        ppid, utime, stime, threads, rss = int(f[1]), int(f[11]), int(f[12]), int(f[17]), int(f[21])
        with open(f"/proc/{pid}/cmdline", "rb") as fh:
            argv = fh.read().split(b"\0")
        cmd = " ".join(a.decode("utf-8", "replace") for a in argv if a)
        if not cmd:
            return None   # поток ядра
        try:
            exe = os.path.basename(os.readlink(f"/proc/{pid}/exe"))
        except OSError:
            exe = os.path.basename(argv[0].decode("utf-8", "replace")) if argv and argv[0] else comm
        exe = exe.replace(" (deleted)", "")
        # Electron-приложения (Vesktop, Obsidian…) все называются electron — имя берём из пути к app.asar
        if exe.startswith("electron"):
            names = [n for n in re.findall(r"/(?:usr|opt)/(?:lib|share)/([^/\s]+)/", cmd) if not n.startswith("electron")]
            if names:
                exe = names[0]
        uid = os.stat(f"/proc/{pid}").st_uid
        return {"pid": pid, "ppid": ppid, "name": comm, "exe": exe, "cmd": cmd[:300], "uid": uid,
                "ticks": utime + stime, "mem": rss * PAGE, "threads": threads}
    except (OSError, ValueError, IndexError):
        return None


def snapshot():
    out = {}
    for d in os.listdir("/proc"):
        if d.isdigit():
            p = read(int(d))
            if p:
                out[p["pid"]] = p
    # дочерние процессы Electron (/proc/self/exe --type=renderer) — под именем предка-приложения
    for p in out.values():
        if p["exe"].startswith("electron") or p["exe"] == "exe":
            q, seen = out.get(p["ppid"]), 0
            while q and seen < 8 and (q["exe"].startswith("electron") or q["exe"] == "exe"):
                q, seen = out.get(q["ppid"]), seen + 1
            if q and q["exe"] not in ("init", "systemd", "Hyprland", "sh", "bash", "fish", "kitty", "qs", "quickshell"):
                p["exe"] = q["exe"]
            else:
                # осиротевший помощник: имя из --user-data-dir=~/.config/<Приложение>
                m = re.search(r"--user-data-dir=\S*/([^/\s]+)", p["cmd"])
                if m:
                    p["exe"] = m.group(1).lower()
    return out


def main():
    interval = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
    total = mem_total()
    prev, prev_t = snapshot(), time.monotonic()
    time.sleep(min(1.0, interval))
    while True:
        cur, now = snapshot(), time.monotonic()
        dt = max(0.001, now - prev_t)
        procs = []
        for pid, p in cur.items():
            was = prev.get(pid)
            d = p["ticks"] - was["ticks"] if was and was["ticks"] <= p["ticks"] else 0
            q = {k: v for k, v in p.items() if k != "ticks"}
            q["cpu"] = round(d / TICKS / dt / NCPU, 4)
            procs.append(q)
        print(json.dumps({"procs": procs, "ncpu": NCPU, "memTotal": total, "self": os.getpid(), "me": os.getuid()}, ensure_ascii=False), flush=True)
        prev, prev_t = cur, now
        time.sleep(interval)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
