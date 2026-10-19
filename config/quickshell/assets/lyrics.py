#!/usr/bin/env python3
"""Текст песни для острова (services/Lyrics.qml): LRCLIB, без ключа.

lyrics.py <исполнитель> <название> [длительность, с]
Печатает JSON: { "synced": [[секунда, строка], …], "plain": "…", "source": "lrclib" } или { "none": true }.
Кэш — ~/.cache/cove/lyrics (найденное и «не найдено», чтобы не спрашивать снова).
"""
import hashlib
import json
import os
import re
import sys
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
CACHE = os.path.join(os.path.expanduser("~"), ".cache/cove/lyrics")
UA = {"User-Agent": "Cove shell (https://github.com/cvsqwe/cove)"}

# хвосты из YouTube и стримингов: (Official Video), [Lyrics], feat. …, - Remastered 2011
JUNK = re.compile(r"\s*[\(\[][^)\]]*(official|video|audio|lyric|visuali[sz]er|remaster|live|hd|4k|mv|клип|премьера)[^)\]]*[\)\]]", re.I)
FEAT = re.compile(r"\s+(feat\.?|ft\.?|featuring)\s+.*$", re.I)
TAIL = re.compile(r"\s+-\s+(\d{4}\s+)?remaster(ed)?.*$", re.I)


def clean(artist, title):
    title = TAIL.sub("", JUNK.sub("", title)).strip()
    # «Исполнитель - Название» в заголовке видео, исполнитель пустой или это имя канала
    if " - " in title and (not artist or artist.lower().endswith(("topic", "vevo")) or title.lower().startswith(artist.lower())):
        a, t = title.split(" - ", 1)
        artist, title = a.strip(), t.strip()
    artist = re.sub(r"\s*-\s*topic$", "", artist, flags=re.I).replace("VEVO", "").strip()
    return FEAT.sub("", artist).strip(), FEAT.sub("", title).strip()


def get(path, params):
    url = f"{API}/{path}?" + urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=8) as r:
            return json.load(r)
    except Exception:
        return None


def parse(lrc):
    out = []
    for line in (lrc or "").splitlines():
        stamps = re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", line)
        text = re.sub(r"\[[^\]]*\]", "", line).strip()
        for m, s in stamps:
            out.append([round(int(m) * 60 + float(s), 2), text])
    return sorted(out, key=lambda x: x[0])


def good(r):
    # в базе бывают пустышки («probe» одной строкой) — нужен хоть какой-то текст
    text = (r or {}).get("syncedLyrics") or (r or {}).get("plainLyrics") or ""
    return bool(r) and (r.get("instrumental") or len([l for l in text.splitlines() if l.strip()]) >= 4)


def find(artist, title, duration):
    params = {"artist_name": artist, "track_name": title}
    if duration > 0:
        params["duration"] = int(round(duration))
    hit = get("get", params)
    if good(hit):
        return hit
    # точного совпадения нет — поиск, ближайший по длительности и с синхронизацией
    res = get("search", {"track_name": title, "artist_name": artist}) or get("search", {"q": f"{artist} {title}".strip()}) or []
    res = [r for r in res if good(r)]
    if not res:
        return None
    def score(r):
        d = abs((r.get("duration") or 0) - duration) if duration > 0 else 0
        return (0 if r.get("syncedLyrics") else 1, d)
    best = min(res, key=score)
    if duration > 0 and abs((best.get("duration") or 0) - duration) > 8:
        return None   # другая версия песни — строки разъедутся
    return best


def main():
    artist, title = (sys.argv[1] if len(sys.argv) > 1 else ""), (sys.argv[2] if len(sys.argv) > 2 else "")
    duration = float(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else 0
    artist, title = clean(artist, title)
    if not title:
        print(json.dumps({"none": True}))
        return
    os.makedirs(CACHE, exist_ok=True)
    key = hashlib.sha1(f"{artist.lower()}\n{title.lower()}".encode()).hexdigest()
    path = os.path.join(CACHE, key + ".json")
    if os.path.exists(path):
        print(open(path).read())
        return
    hit = find(artist, title, duration)
    if hit is None:
        data = {"none": True}
    elif hit.get("instrumental"):
        data = {"none": True, "instrumental": True}
    else:
        data = {"synced": parse(hit.get("syncedLyrics")), "plain": hit.get("plainLyrics") or "", "source": "lrclib"}
    text = json.dumps(data, ensure_ascii=False)
    # «не найдено» из-за сети не кэшируем: get вернул None и на ошибке
    if not data.get("none") or hit is not None or get("search", {"q": "test"}) is not None:
        with open(path, "w") as f:
            f.write(text)
    print(text)


if __name__ == "__main__":
    main()
