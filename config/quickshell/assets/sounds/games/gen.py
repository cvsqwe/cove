#!/usr/bin/env python3
"""Синтез звуков игр (assets/sounds/games/*.wav). Запуск: python3 gen.py — перезапишет файлы.
Мягкие тембры: маримба (синус с быстрым затуханием и тихим обертоном), колокольчик
(негармонические обертоны), приглушённый шум. Ноты — мажорная пентатоника, плавная атака,
фильтр сверху, пик громкости ~0.5. Только стандартная библиотека."""
import math, random, struct, wave, os

SR = 44100
random.seed(3)
HERE = os.path.dirname(os.path.abspath(__file__))
PEAK = 0.5

# пентатоника до мажор
N = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.0, "A4": 440.0,
     "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.0, "C6": 1046.5, "E6": 1318.5}

def blank(dur): return [0.0] * int(SR * dur)

def marimba(f, dur=0.35, vol=1.0, decay=9.0):
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        att = min(1.0, t / 0.006)
        s = math.sin(2 * math.pi * f * t) + 0.18 * math.sin(2 * math.pi * f * 4 * t) * math.exp(-t * 30)
        out.append(vol * att * s * math.exp(-t * decay))
    return out

def bell(f, dur=0.9, vol=1.0, decay=4.5):
    parts = [(1.0, 1.0), (2.76, 0.35), (5.4, 0.12), (8.93, 0.05)]
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        att = min(1.0, t / 0.004)
        s = sum(a * math.sin(2 * math.pi * f * r * t) * math.exp(-t * decay * (1 + r * 0.25)) for r, a in parts)
        out.append(vol * att * s * 0.7)
    return out

def soft(f, dur=0.12, vol=1.0, f2=None):
    """мягкий синус со скольжением высоты, плавные края"""
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        fr = f if f2 is None else f + (f2 - f) * i / n
        ph += 2 * math.pi * fr / SR
        e = math.sin(math.pi * i / n) ** 1.5
        out.append(vol * e * math.sin(ph))
    return out

def noise(dur, vol=1.0, k=0.06, decay=25.0, att=0.004):
    out = []; y = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        y += k * (random.uniform(-1, 1) - y)
        out.append(vol * y * min(1.0, t / att) * math.exp(-t * decay) * 6)
    return out

def mix(*parts):
    n = max(len(p) for p in parts); out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p): out[i] += v
    return out

def at(offset, part): return blank(offset) + part

def lowpass(x, k=0.25):
    y = 0.0; out = []
    for v in x: y += k * (v - y); out.append(y)
    return out

def save(name, x, peak=PEAK):
    x = lowpass(x, 0.45)
    m = max(1e-6, max(abs(v) for v in x))
    g = peak / m
    # хвост 15 мс — без щелчка в конце
    tail = int(SR * 0.015)
    for i in range(tail): x[-1 - i] *= i / tail
    with wave.open(os.path.join(HERE, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in x))

save("move", soft(300, 0.05, 1, f2=260), 0.18)                                   # еле слышный шорох-тук
save("pop", marimba(N["G4"], 0.22, decay=14), 0.32)                               # фигура легла
save("merge", mix(marimba(N["C5"], 0.25), at(0.05, marimba(N["E5"], 0.3))), 0.36)
save("line", mix(*[at(i * 0.06, marimba(f, 0.4)) for i, f in enumerate([N["C5"], N["E5"], N["G5"], N["C6"]])]), 0.4)
save("combo", mix(*[at(i * 0.055, bell(f, 0.7, decay=6)) for i, f in enumerate([N["E5"], N["G5"], N["A5"], N["C6"], N["E6"]])]), 0.36)
save("boom", mix(noise(0.6, 1.0, k=0.02, decay=7), soft(110, 0.45, 0.8, f2=55)), 0.42)   # мягкий «бум», без треска
save("flag", marimba(N["A5"], 0.12, decay=25), 0.22)
save("reveal", marimba(N["E5"], 0.1, decay=30), 0.16)
save("jump", soft(330, 0.13, 1, f2=520), 0.26)
save("flap", noise(0.1, 1, k=0.05, decay=30, att=0.01), 0.2)
save("point", mix(marimba(N["G5"], 0.2), at(0.07, marimba(N["C6"], 0.3))), 0.3)
save("hit", mix(noise(0.25, 1, k=0.03, decay=14), soft(160, 0.2, 0.9, f2=80)), 0.36)
save("over", mix(*[at(i * 0.16, marimba(f, 0.5, decay=6)) for i, f in enumerate([N["G4"], N["E4"], N["D4"], N["C4"]])]), 0.36)
save("win", mix(*[at(i * 0.09, bell(f, 1.0, decay=4)) for i, f in enumerate([N["C5"], N["E5"], N["G5"], N["C6"]])]), 0.4)
save("record", mix(*[at(i * 0.11, bell(f, 1.2, decay=3.5)) for i, f in enumerate([N["G4"], N["C5"], N["E5"], N["G5"], N["C6"]])],
                   at(0.55, bell(N["E6"], 1.0, 0.6, decay=4))), 0.42)
save("key", mix(noise(0.03, 1, k=0.25, decay=120, att=0.0008), soft(2000, 0.012, 0.15)), 0.12)   # тихий «тик» клавиши
save("err", soft(196, 0.09, 1, f2=170), 0.22)
save("flip", noise(0.08, 1, k=0.08, decay=40, att=0.01), 0.16)
save("match", mix(bell(N["E5"], 0.6, decay=6), at(0.08, bell(N["A5"], 0.7, decay=6))), 0.34)
save("start", mix(marimba(N["C5"], 0.3), at(0.08, marimba(N["G5"], 0.35))), 0.3)
save("cheat", mix(*[at(i * 0.045, bell(f, 0.8, 0.8, decay=5)) for i, f in enumerate([N["C6"], N["A5"], N["G5"], N["E5"], N["G5"], N["C6"], N["E6"]])]), 0.36)
print("ok")
