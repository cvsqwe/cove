#!/usr/bin/env python3
"""Свой трек для «Ритма»: файл или ссылка (YouTube, SoundCloud… через yt-dlp) → библиотека + карта нот.

    python3 add.py <файл-или-ссылка>   — печатает JSON {"ok": true, "map": путь} или {"ok": false, "error": …}
    python3 add.py --list              — карты в библиотеке (JSON)
    python3 add.py --remove <id>       — удалить трек и карту

Библиотека: ~/.local/share/cove/rhythm/{tracks,maps}. Анализ без numpy:
ffmpeg → моно 11025 Гц → энергия в трёх полосах (низ / середина / верх) по кадрам 23 мс →
всплески энергии (onset) → темп автокорреляцией → ноты на сильных всплесках, притянутые к сетке четвертей доли."""
import json, math, os, re, shutil, struct, subprocess, sys, hashlib

LIB = os.path.expanduser("~/.local/share/cove/rhythm")
TRACKS, MAPS = os.path.join(LIB, "tracks"), os.path.join(LIB, "maps")
SR, HOP = 11025, 256
AUDIO = (".mp3", ".flac", ".ogg", ".opus", ".m4a", ".wav", ".aac", ".webm")

def out(o): print(json.dumps(o, ensure_ascii=False)); sys.exit(0)
def slug(s): return re.sub(r"[^\w\-]+", "-", s.lower()).strip("-")[:48] or "track"

def fetch(url):
    os.makedirs(TRACKS, exist_ok=True)
    tpl = os.path.join(TRACKS, "%(title).60s.%(ext)s")
    r = subprocess.run(["yt-dlp", "--no-playlist", "-x", "--audio-format", "opus", "--audio-quality", "0",
                        "--print", "after_move:filepath", "-o", tpl, url], capture_output=True, text=True)
    if r.returncode != 0: out({"ok": False, "error": (r.stderr.strip().splitlines() or ["yt-dlp: ошибка"])[-1]})
    return r.stdout.strip().splitlines()[-1]

def tags(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration:format_tags=title,artist",
                        "-of", "json", path], capture_output=True, text=True)
    try: f = json.loads(r.stdout)["format"]
    except Exception: f = {}
    t = f.get("tags", {}) or {}
    t = {k.lower(): v for k, v in t.items()}
    base = os.path.splitext(os.path.basename(path))[0]
    artist, title = t.get("artist", ""), t.get("title", "")
    if not title and " - " in base: artist, title = base.split(" - ", 1)
    return title or base, artist, float(f.get("duration", 0) or 0)

def decode(path):
    r = subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"], capture_output=True)
    if r.returncode != 0 or not r.stdout: out({"ok": False, "error": "ffmpeg не смог прочитать файл"})
    n = len(r.stdout) // 2
    return struct.unpack("<%dh" % n, r.stdout[:n * 2])

def bands(x):
    """энергия в трёх полосах по кадрам: однополюсные фильтры — низ < ~180 Гц, верх > ~2.5 кГц, середина — остаток"""
    a_lo = math.exp(-2 * math.pi * 180 / SR)
    a_hi = math.exp(-2 * math.pi * 2500 / SR)
    lo = mid_lp = 0.0
    e = [[], [], []]
    acc = [0.0, 0.0, 0.0]
    for i, v in enumerate(x):
        v /= 32768.0
        lo = (1 - a_lo) * v + a_lo * lo
        mid_lp = (1 - a_hi) * v + a_hi * mid_lp
        hi = v - mid_lp
        mid = mid_lp - lo
        acc[0] += lo * lo; acc[1] += mid * mid; acc[2] += hi * hi
        if (i + 1) % HOP == 0:
            for k in range(3): e[k].append(math.log(1e-9 + acc[k])); acc[k] = 0.0
    return e

def onsets(env):
    """всплеск = рост логарифма энергии; адаптивный порог по окну ±0.5 с"""
    d = [0.0] + [max(0.0, env[i] - env[i - 1]) for i in range(1, len(env))]
    w = int(0.5 * SR / HOP)
    pref = [0.0]
    for v in d: pref.append(pref[-1] + v)
    peaks = []
    for i in range(1, len(d) - 1):
        lo_, hi_ = max(0, i - w), min(len(d), i + w)
        mean = (pref[hi_] - pref[lo_]) / (hi_ - lo_)
        if d[i] > mean * 1.6 + 0.12 and d[i] >= d[i - 1] and d[i] >= d[i + 1]:
            peaks.append((i, d[i]))
    return d, peaks

def tempo(flux):
    """темп: автокорреляция суммарного потока всплесков на лагах 70–190 BPM"""
    fps = SR / HOP
    best, best_bpm = -1, 120
    n = len(flux)
    m = sum(flux) / max(1, n)
    f = [v - m for v in flux]
    for bpm in range(70, 191):
        lag = fps * 60 / bpm
        L = int(round(lag))
        s = sum(f[i] * f[i + L] for i in range(0, n - L, 2))
        # предпочтение «удобному» диапазону 90–150
        s *= 1.0 + 0.15 * math.exp(-((bpm - 120) / 35) ** 2)
        if s > best: best, best_bpm = s, bpm
    return best_bpm

def analyze(path):
    title, artist, dur = tags(path)
    x = decode(path)
    e = bands(x)
    fluxes, peaks = [], []
    for k in range(3):
        d, p = onsets(e[k])
        fluxes.append(d)
        peaks += [(i, v, k) for i, v in p]
    total = [fluxes[0][i] + fluxes[1][i] + fluxes[2][i] for i in range(len(fluxes[0]))]
    bpm = tempo(total)
    fps = SR / HOP
    # фаза сетки: где сумма всплесков на долях максимальна
    beat = fps * 60 / bpm
    best_ph, best_s = 0.0, -1
    for ph in range(int(beat)):
        s = sum(total[int(ph + j * beat)] for j in range(int((len(total) - ph) / beat)))
        if s > best_s: best_s, best_ph = s, ph
    # сила: нормируем по 95-му перцентилю в каждой полосе
    by = [sorted(v for _, v, k in peaks if k == b) for b in range(3)]
    p95 = [(s[int(len(s) * 0.95)] if s else 1.0) for s in by]
    notes = []
    for i, v, k in peaks:
        t = i / fps
        # притянуть к сетке четвертей доли, если рядом (≤ 40 мс)
        q = beat / 4
        gi = round((i - best_ph) / q)
        gt = (best_ph + gi * q) / fps
        if abs(gt - t) <= 0.04: t = gt
        s = min(1.0, v / max(1e-6, p95[k])) * (1.0 if k != 2 else 0.85)
        notes.append({"t": round(t * 1000 - 15), "s": round(s, 2), "b": k})   # −15 мс: кадр запаздывает на половину окна
    notes.sort(key=lambda n: n["t"])
    merged = []
    for n in notes:
        if n["t"] < 300: continue
        if merged and n["t"] - merged[-1]["t"] < 40:
            if n["s"] > merged[-1]["s"]: merged[-1] = n
            continue
        merged.append(n)
    return {"title": title, "artist": artist, "bpm": bpm, "duration": round((dur or len(x) / SR) * 1000), "notes": merged}

def main():
    if len(sys.argv) < 2: out({"ok": False, "error": "нужен файл или ссылка"})
    if sys.argv[1] == "--list":
        os.makedirs(MAPS, exist_ok=True)
        res = []
        for f in sorted(os.listdir(MAPS)):
            if not f.endswith(".json"): continue
            try:
                m = json.load(open(os.path.join(MAPS, f)))
                res.append({k: m[k] for k in ("id", "title", "artist", "bpm", "duration", "audio") if k in m} | {"count": len(m.get("notes", []))})
            except Exception: pass
        out(res)
    if sys.argv[1] == "--remove":
        mid = sys.argv[2]
        p = os.path.join(MAPS, mid + ".json")
        try:
            m = json.load(open(p))
            if m.get("audio", "").startswith(TRACKS) and os.path.exists(m["audio"]): os.remove(m["audio"])
            os.remove(p)
        except Exception as ex: out({"ok": False, "error": str(ex)})
        out({"ok": True})
    src = sys.argv[1]
    if re.match(r"^https?://", src): path = fetch(src)
    else:
        path = os.path.expanduser(src)
        if not os.path.isfile(path): out({"ok": False, "error": "файл не найден"})
        os.makedirs(TRACKS, exist_ok=True)
        dst = os.path.join(TRACKS, os.path.basename(path))
        if os.path.abspath(dst) != os.path.abspath(path): shutil.copy2(path, dst)
        path = dst
    m = analyze(path)
    if len(m["notes"]) < 20: out({"ok": False, "error": "в треке не нашлось ритма"})
    mid = slug(m["title"]) + "-" + hashlib.md5(path.encode()).hexdigest()[:6]
    m.update({"id": mid, "audio": path, "builtin": False})
    os.makedirs(MAPS, exist_ok=True)
    with open(os.path.join(MAPS, mid + ".json"), "w") as f: json.dump(m, f, ensure_ascii=False)
    out({"ok": True, "id": mid, "map": os.path.join(MAPS, mid + ".json"), "title": m["title"], "bpm": m["bpm"], "notes": len(m["notes"])})

if __name__ == "__main__":
    main()
