#!/usr/bin/env python3
"""Перевод для «Перевести с экрана» (services/Lens.qml). Без ключей.

echo "текст" | translate.py <язык интерфейса: ru|en>
Русский текст переводится на английский, остальное — на язык интерфейса.
Печатает JSON: { "text": "...", "src": "en", "dst": "ru", "engine": "google|mymemory" } или { "error": "..." }.
Сначала Google (translate_a, бывает закрыт капчей), затем MyMemory (до 500 байт за запрос).
"""
import json
import re
import sys
import urllib.parse
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Cove"}


def fetch(url, timeout=8):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
        return r.read().decode("utf-8")


def google(text, src, dst):
    q = urllib.parse.urlencode({"client": "gtx", "sl": src, "tl": dst, "dt": "t", "q": text})
    data = json.loads(fetch("https://translate.googleapis.com/translate_a/single?" + q))
    return "".join(part[0] for part in data[0] if part and part[0])


def chunks(text, limit=450):
    # MyMemory берёт до 500 байт: режем по строкам, длинные строки — по предложениям
    out, cur = [], ""
    for line in text.split("\n"):
        pieces = [line] if len(line.encode()) <= limit else re.split(r"(?<=[.!?…])\s+", line)
        for p in pieces:
            while len(p.encode()) > limit:   # совсем длинное без точек — режем грубо
                cut = p[:limit // 2]
                out.append(cur + cut) if cur else out.append(cut)
                cur, p = "", p[limit // 2:]
            if len((cur + "\n" + p).encode()) > limit and cur:
                out.append(cur)
                cur = p
            else:
                cur = f"{cur}\n{p}" if cur else p
    if cur:
        out.append(cur)
    return out


def mymemory(text, src, dst):
    res = []
    for part in chunks(text):
        if not part.strip():
            res.append(part)
            continue
        q = urllib.parse.urlencode({"q": part, "langpair": f"{src}|{dst}"})
        data = json.loads(fetch("https://api.mymemory.translated.net/get?" + q))
        if data.get("quotaFinished"):
            raise RuntimeError("quota")
        res.append(data["responseData"]["translatedText"])
    return "\n".join(res)


def main():
    ui = sys.argv[1] if len(sys.argv) > 1 else "ru"
    text = sys.stdin.read().strip()
    if not text:
        print(json.dumps({"error": "empty"}))
        return
    letters = re.findall(r"[^\W\d_]", text)
    cyr = sum(1 for c in letters if "Ѐ" <= c <= "ӿ")
    src = "ru" if letters and cyr / len(letters) > 0.5 else "en"
    dst = "en" if src == ui else ui
    for name, fn in (("google", google), ("mymemory", mymemory)):
        try:
            out = fn(text, "auto" if name == "google" else src, dst)
            if out.strip():
                print(json.dumps({"text": out, "src": src, "dst": dst, "engine": name}, ensure_ascii=False))
                return
        except Exception:
            continue
    print(json.dumps({"error": "offline"}))


if __name__ == "__main__":
    main()
