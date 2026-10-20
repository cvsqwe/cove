#!/usr/bin/env python3
"""Синтез звуков игр (assets/sounds/games/*.wav). Запуск: python3 gen.py — перезапишет файлы.
Только стандартная библиотека: синусы/квадраты/шум с огибающими."""
import math, random, struct, wave, os

SR = 44100
random.seed(3)
HERE = os.path.dirname(os.path.abspath(__file__))

def env(i, n, a=0.005, r=0.6):
    t = i / SR; dur = n / SR
    att = min(1.0, t / a) if a > 0 else 1.0
    rel = max(0.0, 1 - max(0.0, t - dur * (1 - r)) / (dur * r)) if r > 0 else 1.0
    return att * rel

def tone(freq, dur, wave_="sine", vol=0.5, a=0.005, r=0.7, f2=None, vib=0):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = freq if f2 is None else freq + (f2 - freq) * i / n
        if vib: f *= 1 + vib * math.sin(2 * math.pi * 6 * i / SR)
        ph += 2 * math.pi * f / SR
        if wave_ == "sine": s = math.sin(ph)
        elif wave_ == "square": s = 1.0 if math.sin(ph) > 0 else -1.0
        elif wave_ == "tri": s = 2 / math.pi * math.asin(math.sin(ph))
        elif wave_ == "noise": s = random.uniform(-1, 1)
        else: s = math.sin(ph)
        out.append(s * vol * env(i, n, a, r))
    return out

def mix(*parts):
    n = max(len(p) for p in parts); out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p): out[i] += v
    return out

def seq(*parts, gap=0.0):
    out = []
    for p in parts: out += p + [0.0] * int(SR * gap)
    return out

def lowpass(x, k=0.15):
    y = 0.0; out = []
    for v in x: y += k * (v - y); out.append(y)
    return out

def save(name, x):
    peak = max(1e-6, max(abs(v) for v in x))
    g = min(1.0, 0.9 / peak)
    with wave.open(os.path.join(HERE, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in x))

N = {"C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.0, "C6": 1046.5, "E6": 1318.5, "G6": 1568.0, "C4": 261.63, "G4": 392.0, "E4": 329.63, "A4": 440.0}

save("move", tone(420, 0.045, "tri", 0.35, r=0.9, f2=360))
save("pop", mix(tone(620, 0.08, "sine", 0.5, f2=880), tone(1240, 0.05, "sine", 0.15)))
save("merge", seq(tone(N["E5"], 0.05, "tri", 0.45), tone(N["A5"], 0.09, "tri", 0.45)))
save("line", seq(*[tone(f, 0.06, "tri", 0.4, r=0.8) for f in (N["C5"], N["E5"], N["G5"], N["C6"])]))
save("combo", seq(*[tone(f, 0.05, "square", 0.22, r=0.8) for f in (N["E5"], N["G5"], N["C6"], N["E6"], N["G6"])]))
save("boom", lowpass(mix(tone(0, 0.55, "noise", 0.9, a=0.001, r=0.95), tone(90, 0.5, "sine", 0.7, f2=40, r=0.9)), 0.08))
save("flag", tone(1500, 0.03, "square", 0.18, r=0.9, f2=1100))
save("reveal", tone(880, 0.035, "sine", 0.3, r=0.9))
save("jump", tone(320, 0.14, "square", 0.2, f2=720, r=0.6))
save("flap", lowpass(tone(0, 0.09, "noise", 0.6, a=0.01, r=0.8), 0.25))
save("point", seq(tone(N["E6"] * 0.75, 0.05, "square", 0.2), tone(N["E6"], 0.12, "square", 0.2, r=0.8)))
save("hit", lowpass(mix(tone(0, 0.18, "noise", 0.8, a=0.001), tone(140, 0.2, "sine", 0.6, f2=60)), 0.12))
save("over", seq(*[tone(f, 0.16, "tri", 0.4, r=0.5) for f in (N["G4"], N["E4"], N["C4"] * 0.9)], gap=0.02))
save("win", seq(*[tone(f, 0.09, "tri", 0.4, r=0.6) for f in (N["C5"], N["E5"], N["G5"])] + [tone(N["C6"], 0.3, "tri", 0.45, r=0.7, vib=0.01)]))
save("record", seq(tone(N["G5"], 0.1, "square", 0.22), tone(N["G5"], 0.1, "square", 0.22), tone(N["C6"], 0.1, "square", 0.22),
                   mix(tone(N["E6"], 0.45, "square", 0.2, r=0.7, vib=0.012), tone(N["C6"], 0.45, "tri", 0.25, r=0.7)), gap=0.015))
save("key", lowpass(mix(tone(0, 0.022, "noise", 0.7, a=0.0005, r=0.9), tone(1800, 0.015, "sine", 0.2)), 0.5))
save("err", tone(140, 0.09, "square", 0.25, r=0.6))
save("flip", lowpass(tone(0, 0.07, "noise", 0.5, a=0.005, r=0.7), 0.35))
save("match", seq(tone(N["A5"], 0.06, "sine", 0.45), tone(N["E6"], 0.14, "sine", 0.45, r=0.8)))
save("start", seq(tone(N["C5"], 0.06, "tri", 0.35), tone(N["G5"], 0.1, "tri", 0.35)))
print("ok")
