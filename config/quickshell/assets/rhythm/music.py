#!/usr/bin/env python3
"""Встроенная музыка «Ритма»: сочиняет и синтезирует трек и сразу пишет карту нот.

    python3 music.py list                 — список треков (JSON)
    python3 music.py make <id> <out_dir>  — <out_dir>/<id>.ogg и <id>.json

Ноты карты берутся из самой партитуры (бочка, малый, мелодия), поэтому попадают точно в музыку.
Только стандартная библиотека + ffmpeg для сжатия в ogg. Детерминировано: один id — один трек."""
import json, math, os, random, struct, subprocess, sys, wave

SR = 22050

TRACKS = {
    # id: (название, автор, bpm, тоника (midi), лад, стиль, тактов, сид)
    "neon":   ("Neon Drive", "Cove", 110, 45, "minor", "synthwave", 40, 11),
    "lofi":   ("Rainy Window", "Cove", 84, 50, "dorian", "lofi", 28, 23),
    "chip":   ("Pixel Heart", "Cove", 140, 48, "major", "chip", 48, 37),
    "house":  ("Night Shift", "Cove", 124, 43, "minor", "house", 48, 41),
    "dnb":    ("Afterburner", "Cove", 172, 50, "minor", "dnb", 64, 53),
    "waltz":  ("Glass Garden", "Cove", 96, 52, "major", "dream", 32, 67),
}
SCALES = {"major": [0, 2, 4, 5, 7, 9, 11], "minor": [0, 2, 3, 5, 7, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10]}
PROGS = {"major": [[0, 4, 7], [5, 9, 12], [7, 11, 14], [-3, 0, 4]], "minor": [[0, 3, 7], [-4, 0, 3], [-2, 2, 5], [-5, -1, 2]],
         "dorian": [[0, 3, 7], [5, 9, 12], [-2, 2, 5], [0, 3, 10]]}

def hz(m): return 440.0 * 2 ** ((m - 69) / 12)

class Mix:
    def __init__(self, seconds): self.buf = [0.0] * int(SR * seconds + SR)
    def add(self, t, samples, vol=1.0):
        i0 = int(t * SR)
        b = self.buf
        for i, v in enumerate(samples):
            j = i0 + i
            if j >= len(b): break
            b[j] += v * vol

def env_ad(n, a, d):
    out = []
    for i in range(n):
        t = i / SR
        out.append(min(1.0, t / a) * math.exp(-t / d) if a > 0 else math.exp(-t / d))
    return out

def kick(vol=1.0):
    n = int(SR * 0.32); out = []; ph = 0.0
    for i in range(n):
        t = i / SR
        f = 45 + 110 * math.exp(-t * 28)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-t * 9) * vol)
    return out

def snare(vol=1.0, rnd=random.Random(1)):
    n = int(SR * 0.22); out = []; y = 0.0
    for i in range(n):
        t = i / SR
        y += 0.5 * (rnd.uniform(-1, 1) - y)
        out.append((y * 0.8 * math.exp(-t * 18) + 0.35 * math.sin(2 * math.pi * 190 * t) * math.exp(-t * 25)) * vol)
    return out

def hat(vol=1.0, open_=False, rnd=random.Random(2)):
    n = int(SR * (0.12 if open_ else 0.04)); out = []; prev = 0.0
    for i in range(n):
        t = i / SR
        x = rnd.uniform(-1, 1)
        hp = x - prev; prev = x                       # грубый фильтр сверху — «шипение»
        out.append(hp * math.exp(-t * (25 if open_ else 80)) * 0.35 * vol)
    return out

def tone(m, dur, kind="tri", vol=1.0, a=0.005, d=None, vib=0.0, detune=0.0):
    n = int(SR * dur); out = []; ph = 0.0; ph2 = 0.0
    f = hz(m)
    d = d or dur
    for i in range(n):
        t = i / SR
        ff = f * (1 + vib * math.sin(2 * math.pi * 5.5 * t))
        ph += 2 * math.pi * ff / SR
        ph2 += 2 * math.pi * ff * (1 + detune) / SR
        if kind == "sine": s = math.sin(ph)
        elif kind == "tri": s = 2 / math.pi * math.asin(math.sin(ph))
        elif kind == "saw": s = sum(math.sin(ph * k) / k for k in (1, 2, 3, 4)) * 0.6
        elif kind == "square": s = sum(math.sin(ph * k) / k for k in (1, 3, 5)) * 0.8
        elif kind == "pluck": s = math.sin(ph) + 0.3 * math.sin(2 * ph) * math.exp(-t * 20)
        else: s = math.sin(ph)
        if detune: s = 0.5 * s + 0.5 * math.sin(ph2)
        e = min(1.0, t / a) * (math.exp(-t / d) if d < dur else max(0.0, 1 - max(0.0, t - dur + 0.03) / 0.03))
        out.append(s * e * vol)
    return out

def make(tid, out_dir):
    title, artist, bpm, root, mode, style, bars, seed = TRACKS[tid]
    rnd = random.Random(seed)
    beat = 60 / bpm
    meter = 3 if style == "dream" else 4
    bar = beat * meter
    total = bars * bar + 2
    mix = Mix(total)
    notes = []                                  # {t, s, b}: время (мс), сила, полоса 0 низ / 1 середина / 2 верх
    scale = SCALES[mode]; prog = PROGS[mode]

    def note(t, s, b):
        notes.append({"t": round(t * 1000), "s": round(s, 2), "b": b})

    # мотив мелодии: 2 такта, потом варьируется
    def motif():
        steps = []
        pos = 0.0
        while pos < 2 * meter:
            dur = rnd.choice([0.5, 0.5, 1, 1, 1.5, 2] if style != "dnb" else [0.25, 0.5, 0.5, 1])
            deg = rnd.choice([0, 1, 2, 3, 4, 4, 5, 7, 7, 9])
            steps.append((pos, min(dur, 2 * meter - pos), deg))
            pos += dur
        return steps
    mot = [motif(), motif()]

    # секции: вступление (0–25%), куплет, припев (сильнее), бридж, финальный припев
    def section(b):
        f = b / bars
        return "intro" if f < 0.125 else "verse" if f < 0.375 else "chorus" if f < 0.625 else "bridge" if f < 0.75 else "chorus"

    for b in range(bars):
        t0 = 1.0 + b * bar
        sec = section(b)
        chord = prog[(b // (2 if style in ("lofi", "dream") else 1)) % len(prog)]
        intense = sec == "chorus"
        # пэд / аккорд
        for iv in chord:
            mix.add(t0, tone(root + 12 + iv, bar, "saw" if style in ("synthwave", "house") else "sine", 0.06 if intense else 0.045, a=0.08, detune=0.004), 1)
        # бас
        for k in range(meter * (2 if style in ("house", "dnb", "synthwave") else 1)):
            sub = beat / (2 if style in ("house", "dnb", "synthwave") else 1)
            tb = t0 + k * sub
            m = root + chord[0] - 12 + (12 if (style == "house" and k % 2) else 0)
            mix.add(tb, tone(m, sub * 0.9, "tri" if style != "chip" else "square", 0.22, a=0.004, d=sub * 0.8))
        # барабаны
        if sec != "intro" or b >= bars * 0.06:
            for k in range(meter):
                tb = t0 + k * beat
                if style == "dnb":
                    if k in (0,) or (k == 2 and b % 2): mix.add(tb, kick(), 0.9); note(tb, 0.95, 0)
                    if k in (1, 3): mix.add(tb, snare(), 0.7); note(tb, 0.85, 1)
                    if k == 2 and not b % 2: mix.add(tb + beat / 2, kick(), 0.7); note(tb + beat / 2, 0.6, 0)
                elif style == "dream":
                    if k == 0: mix.add(tb, kick(), 0.6); note(tb, 0.8, 0)
                    else: mix.add(tb, hat(open_=True), 0.4); note(tb, 0.35, 1)
                else:
                    four = style in ("house", "synthwave", "chip")
                    if four or k in (0, 2): mix.add(tb, kick(), 0.85); note(tb, 0.9 if k == 0 else 0.7, 0)
                    if k in (1, 3): mix.add(tb, snare(), 0.6 if style == "lofi" else 0.7); note(tb, 0.8, 1)
                # хэты на восьмые
                for h in (0, 0.5):
                    if style == "lofi" and h: tb2 = tb + beat * 0.58   # «качающиеся» восьмые
                    else: tb2 = tb + beat * h
                    mix.add(tb2, hat(open_=(h and intense and style == "house")), 0.5)
                    if intense and h: note(tb2, 0.3, 2)
        # мелодия (не во вступлении)
        if sec != "intro":
            mm = mot[(b // 2 + (1 if sec == "bridge" else 0)) % 2]
            half = b % 2
            for pos, dur, deg in mm:
                if not (half * meter <= pos < (half + 1) * meter): continue
                if sec == "verse" and rnd.random() < 0.25: continue
                tn = t0 + (pos - half * meter) * beat
                oct_ = 12 if intense else 0
                m = root + 24 + scale[deg % 7] + 12 * (deg // 7) + oct_ - (12 if style == "lofi" else 0)
                kind = {"synthwave": "saw", "chip": "square", "lofi": "pluck", "house": "pluck", "dnb": "saw", "dream": "sine"}[style]
                mix.add(tn, tone(m, dur * beat * 0.95, kind, 0.13, a=0.006, d=dur * beat * (0.4 if kind == "pluck" else 2), vib=0.003), 1)
                note(tn, min(1.0, 0.55 + dur * 0.12 + (0.15 if intense else 0)), 2)

    # сведение: мягкое ограничение и нормировка
    buf = mix.buf
    peak = max(1e-6, max(abs(v) for v in buf))
    g = 0.95 / peak
    data = b"".join(struct.pack("<h", int(math.tanh(v * g * 1.3) / math.tanh(1.3) * 30000)) for v in buf)
    os.makedirs(out_dir, exist_ok=True)
    wav = os.path.join(out_dir, tid + ".wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)
    ogg = os.path.join(out_dir, tid + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-nostdin", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    os.remove(wav)

    # близкие ноты одной полосы сливаем (сильнейшая остаётся)
    notes.sort(key=lambda n: n["t"])
    merged = []
    for n in notes:
        if merged and n["t"] - merged[-1]["t"] < 30:
            if n["s"] > merged[-1]["s"]: merged[-1] = n
            continue
        merged.append(n)
    meta = {"id": tid, "title": title, "artist": artist, "bpm": bpm, "duration": round(total * 1000),
            "audio": ogg, "builtin": True, "style": style, "notes": merged}
    with open(os.path.join(out_dir, tid + ".json"), "w") as f:
        json.dump(meta, f, ensure_ascii=False)
    return meta

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "list":
        # list [cache_dir] — с пометкой ready, если трек уже сочинён в cache_dir
        cache = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps([{"id": k, "title": v[0], "artist": v[1], "bpm": v[2], "style": v[5],
                           "seconds": round(v[6] * (3 if v[5] == "dream" else 4) * 60 / v[2] + 2),
                           "ready": bool(cache) and os.path.exists(os.path.join(cache, k + ".json")),
                           "map": os.path.join(cache, k + ".json") if cache else ""} for k, v in TRACKS.items()], ensure_ascii=False))
    elif len(sys.argv) > 3 and sys.argv[1] == "make":
        m = make(sys.argv[2], sys.argv[3])
        print(json.dumps({"ok": True, "id": m["id"], "notes": len(m["notes"])}))
    else:
        print(__doc__)
