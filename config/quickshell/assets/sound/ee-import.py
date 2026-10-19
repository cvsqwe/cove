#!/usr/bin/env python3
"""Эквалайзер EasyEffects → наборы Cove (services/SoundFx.qml).

Печатает JSON: [{ name, bands: [{f, g, q, type}], preamp, skipped: [...] }].
Источники: текущее состояние EasyEffects 8 (~/.config/easyeffects/db/equalizerrc —
KConfig хранит только отличия от умолчаний, умолчания ниже из easyeffects_db_equalizer_channel.kcfg)
и сохранённые пресеты выхода (*.json). Полосы с нулевым усилением выкидываются: на звук не влияют.
"""
import configparser
import glob
import json
import os
import re

HOME = os.path.expanduser("~")

# умолчания EasyEffects: 32 полосы, Q 4.36, тип Bell
DEF_FREQ = [22.4, 27.8, 34.51, 42.82, 53.14, 65.95, 81.83, 101.55, 126, 156.38, 194.06, 240.81,
            298.834, 370.834, 460.182, 571.057, 708.647, 879.387, 1091.26, 1354.19, 1680.47,
            2085.35, 2587.79, 3211.29, 3985.01, 4945.15, 6136.63, 7615.17, 9449.96, 11726.8,
            14552.2, 18058.4]
DEF_Q = 4.36
# индексы типа в EasyEffects 8: Off, Bell, High-pass, High-shelf, Low-pass, Low-shelf, Notch, …
TYPE_BY_INDEX = [None, "bell", "highpass", "highshelf", "lowpass", "lowshelf", "notch"]


def type_from_label(label):
    s = str(label).lower().replace(" ", "")
    if s in ("off", ""):
        return None
    if "shelf" in s:
        return "lowshelf" if s.startswith("lo") else "highshelf"
    if "pass" in s and not s.startswith(("all", "band", "ladder")):
        return "lowpass" if s.startswith("lo") else "highpass"
    if "notch" in s:
        return "notch"
    return "bell"  # Bell, Resonance и прочее — ближе всего колокол


def clean(bands):
    out = []
    for b in bands:
        if not b["type"]:
            continue
        if b["type"] in ("bell", "lowshelf", "highshelf") and abs(b["g"]) < 0.01:
            continue
        out.append({"f": round(float(b["f"]), 2), "g": round(float(b["g"]), 2),
                    "q": round(float(b["q"]), 3), "type": b["type"]})
    return sorted(out, key=lambda b: b["f"])


def from_db():
    path = os.path.join(HOME, ".config/easyeffects/db/equalizerrc")
    if not os.path.exists(path):
        return []
    cp = configparser.RawConfigParser(strict=False)
    cp.optionxform = str
    try:
        cp.read(path)
    except configparser.Error:
        return []
    result = []
    # секции вида [soe][Equalizer#0#left]: soe — выход, sie — микрофон
    for sec in cp.sections():
        m = re.match(r"\[soe\]\[(Equalizer#\d+)#left", "[" + sec + "]")
        if not m:
            continue
        inst = m.group(1)
        left = cp[sec]
        common = cp[f"soe][{inst}"] if cp.has_section(f"soe][{inst}") else {}
        n = int(common.get("numBands", 32))
        bands = []
        for i in range(n):
            t = left.get(f"band{i}Type")
            mute = left.get(f"band{i}Mute", "false") == "true"
            bands.append({
                "f": float(left.get(f"band{i}Frequency", DEF_FREQ[i] if i < len(DEF_FREQ) else 1000)),
                "g": float(left.get(f"band{i}Gain", 0)),
                "q": float(left.get(f"band{i}Q", DEF_Q)),
                "type": None if mute else (TYPE_BY_INDEX[int(t)] if t is not None and int(t) < len(TYPE_BY_INDEX) else "bell"),
            })
        pre = float(common.get("inputGain", 0)) + float(common.get("outputGain", 0))
        result.append({"name": "EasyEffects", "bands": clean(bands), "preamp": round(pre, 2), "skipped": []})
    return result


def from_presets():
    result = []
    files = glob.glob(os.path.join(HOME, ".local/share/easyeffects/output/*.json")) + \
        glob.glob(os.path.join(HOME, ".config/easyeffects/output/*.json"))
    for f in sorted(files):
        try:
            data = json.load(open(f))["output"]
        except (OSError, ValueError, KeyError):
            continue
        order = data.get("plugins_order", [])
        eq_key = next((k for k in order if k.startswith("equalizer")), None)
        skipped = sorted({re.sub(r"#\d+$", "", k) for k in order if not k.startswith("equalizer")})
        if not eq_key:
            continue
        eq = data[eq_key]
        left = eq.get("left", {})
        bands = []
        for i in range(int(eq.get("num-bands", 32))):
            b = left.get(f"band{i}")
            if not b:
                continue
            bands.append({"f": b.get("frequency", 1000), "g": b.get("gain", 0), "q": b.get("q", DEF_Q),
                          "type": None if b.get("mute") else type_from_label(b.get("type", "Bell"))})
        pre = float(eq.get("input-gain", 0)) + float(eq.get("output-gain", 0))
        name = os.path.splitext(os.path.basename(f))[0].replace("_", " ")
        result.append({"name": name, "bands": clean(bands), "preamp": round(pre, 2), "skipped": skipped})
    return result


if __name__ == "__main__":
    print(json.dumps([p for p in from_db() + from_presets() if p["bands"] or p["preamp"]], ensure_ascii=False))
