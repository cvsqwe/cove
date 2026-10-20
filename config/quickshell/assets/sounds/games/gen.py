#!/usr/bin/env python3
"""Синтез звуков игр (assets/sounds/games/*.wav). Запуск: python3 gen.py — перезапишет файлы.
Тёплые тембры без звона и шипения: FM-электропиано, удар молоточком (как калимба),
глухой «тук» с падением высоты. Ноты — пентатоника до мажор в средней октаве, сверху срез ~3 кГц,
у мелодий — лёгкая реверберация. Частые звуки (ход, клавиша, клетка) почти не слышны.
Только стандартная библиотека."""
import math, random, struct, wave, os

SR = 44100
random.seed(7)
HERE = os.path.dirname(os.path.abspath(__file__))

N = {"G3": 196.0, "A3": 220.0, "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.0, "A4": 440.0,
     "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.0}


def blank(dur): return [0.0] * int(SR * dur)


def epiano(f, dur=0.6, vol=1.0, decay=5.0, bright=1.0):
    """мягкое электропиано: FM с затухающим индексом — тёплая атака, чистый хвост"""
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        idx = 1.1 * bright * math.exp(-t * 9)
        s = math.sin(2 * math.pi * f * t + idx * math.sin(2 * math.pi * f * t))
        s += 0.18 * math.sin(2 * math.pi * 2 * f * t) * math.exp(-t * 14)
        att = min(1.0, t / 0.005)
        out.append(vol * att * s * math.exp(-t * decay))
    return out


def pluck(f, dur=0.35, vol=1.0, decay=11.0):
    """мягкий удар молоточком (как калимба): синус с коротким тёплым призвуком в атаке"""
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        idx = 0.7 * math.exp(-t * 28)
        s = math.sin(2 * math.pi * f * t + idx * math.sin(2 * math.pi * 2 * f * t))
        att = min(1.0, t / 0.003)
        out.append(vol * att * s * math.exp(-t * decay))
    return out


def tok(f0, f1, dur=0.06, vol=1.0, decay=40.0):
    """глухой «тук»: синус, высота быстро падает с f0 до f1"""
    out, ph = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        fr = f1 + (f0 - f1) * math.exp(-t * 30)
        ph += 2 * math.pi * fr / SR
        att = min(1.0, t / 0.002)
        out.append(vol * att * math.sin(ph) * math.exp(-t * decay))
    return out


def glide(f0, f1, dur=0.14, vol=1.0):
    """плавное скольжение высоты с мягкими краями"""
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        fr = f0 + (f1 - f0) * (i / n) ** 0.7
        ph += 2 * math.pi * fr / SR
        e = math.sin(math.pi * i / n) ** 2
        out.append(vol * e * math.sin(ph))
    return out


def rumble(dur, vol=1.0, decay=6.0):
    """очень низкий приглушённый шум — тело взрыва без треска"""
    out = []; y = 0.0; z = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        y += 0.01 * (random.uniform(-1, 1) - y)
        z += 0.05 * (y - z)
        out.append(vol * z * 40 * min(1.0, t / 0.01) * math.exp(-t * decay))
    return out


def mix(*parts):
    n = max(len(p) for p in parts); out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p): out[i] += v
    return out


def at(offset, part): return blank(offset) + part


def seq(notes, step, make):
    return mix(*[at(i * step, make(f)) for i, f in enumerate(notes)])


def lowpass(x, k):
    y = 0.0; out = []
    for v in x: y += k * (v - y); out.append(y)
    return out


def reverb(x, wet=0.2, tail=0.6):
    """маленькая комната (Freeverb в миниатюре): четыре гребёнки + два всепропускающих"""
    x = x + blank(tail)
    combs = [1116, 1188, 1277, 1356]
    acc = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d; f = 0.0
        for i, v in enumerate(x):
            o = buf[i % d]
            f = o * 0.7 + f * 0.3          # затухание высоких в хвосте
            buf[i % d] = v + f * 0.76
            acc[i] += o
    for d in (556, 441):
        buf = [0.0] * d
        for i, v in enumerate(acc):
            o = buf[i % d]
            buf[i % d] = v + o * 0.5
            acc[i] = o - v
    return [a + wet * b / len(combs) for a, b in zip(x, acc)]


def save(name, x, peak, verb=0.0):
    if verb: x = reverb(x, verb)
    x = lowpass(lowpass(x, 0.38), 0.6)       # срез сверху около 3 кГц
    # обрезаем тишину в хвосте
    m = max(1e-9, max(abs(v) for v in x))
    end = len(x)
    while end > 1 and abs(x[end - 1]) < m * 0.002: end -= 1
    x = x[:end]
    g = peak / m
    fade_in, fade_out = int(SR * 0.002), min(len(x) // 2, int(SR * 0.025))
    for i in range(fade_in): x[i] *= i / fade_in
    for i in range(fade_out): x[-1 - i] *= i / fade_out
    with wave.open(os.path.join(HERE, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in x))


ep = lambda f: epiano(f, 0.7, decay=5)
ep_long = lambda f: epiano(f, 1.4, decay=2.6)

# частые — тихие и короткие
save("move", tok(170, 120, 0.05, decay=60), 0.10)
save("key", tok(520, 420, 0.02, decay=180), 0.07)
save("reveal", pluck(N["C5"], 0.12, decay=30), 0.10)
save("flip", tok(300, 230, 0.07, decay=45), 0.13)
save("flap", tok(240, 190, 0.08, decay=40), 0.12)
save("flag", mix(tok(420, 330, 0.05, decay=60), pluck(N["A4"], 0.15, 0.5, decay=25)), 0.15)
save("pop", pluck(N["G4"], 0.22, decay=16), 0.20)
save("jump", glide(N["G3"], N["D4"], 0.13), 0.16)

# события — мелодичные
save("point", mix(pluck(N["G4"], 0.3), at(0.07, pluck(N["C5"], 0.4))), 0.20)
save("merge", mix(epiano(N["C4"], 0.4, decay=8), at(0.05, epiano(N["E4"], 0.45, decay=8))), 0.24)
save("match", mix(epiano(N["E4"], 0.6, decay=6), at(0.07, epiano(N["A4"], 0.7, decay=6))), 0.24, verb=0.15)
save("start", mix(epiano(N["C4"], 0.5, decay=6), at(0.09, epiano(N["G4"], 0.6, decay=6))), 0.22, verb=0.12)
save("line", seq([N["C4"], N["E4"], N["G4"], N["C5"]], 0.06, ep), 0.26, verb=0.18)
save("combo", seq([N["E4"], N["G4"], N["A4"], N["C5"], N["E5"]], 0.05, ep), 0.26, verb=0.2)
save("cheat", seq([N["C5"], N["D5"], N["E5"], N["G5"], N["A5"]], 0.045, lambda f: pluck(f, 0.5, 0.8)), 0.20, verb=0.25)

# неудачи — низкие и мягкие, без жужжания
save("err", tok(230, 170, 0.12, decay=28), 0.16)
save("hit", mix(tok(150, 60, 0.3, decay=12), rumble(0.25, 0.35, decay=16)), 0.30)
save("boom", mix(tok(100, 40, 0.7, decay=6), rumble(0.7, 0.8, decay=6)), 0.34)
save("over", seq([N["G4"], N["E4"], N["D4"], N["C4"]], 0.17, lambda f: epiano(f, 0.8, decay=4.5)), 0.24, verb=0.18)

# победы — аккорд с хвостом
save("win", mix(seq([N["C4"], N["E4"], N["G4"]], 0.09, ep),
                at(0.27, mix(ep_long(N["C4"]), ep_long(N["E4"]), ep_long(N["G4"]), ep_long(N["C5"])))), 0.30, verb=0.25)
save("record", mix(seq([N["G3"], N["C4"], N["E4"], N["G4"]], 0.1, ep),
                   at(0.4, mix(ep_long(N["C4"]), ep_long(N["G4"]), ep_long(N["C5"]), ep_long(N["E5"])))), 0.32, verb=0.28)
print("ok")
