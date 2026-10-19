#!/bin/sh
# Что за песня играет (services/SongId.qml): 8 секунд системного звука → songrec (Shazam).
# Пишем монитор выхода, не микрофон (stream.capture.sink) — индикатор микрофона не загорается.
# Печатает JSON: {"title","artist","url","cover"} | {"none":true} | {"missing":true}
exec </dev/null
command -v songrec >/dev/null || { echo '{"missing":true}'; exit 0; }
dir="${XDG_RUNTIME_DIR:-/tmp}/cove-songid"; mkdir -p "$dir"
wav="$dir/sample.wav"; rm -f "$wav"
timeout "${1:-8}" pw-record -P '{ stream.capture.sink = true node.description = "Cove: распознавание песни" }' \
    --rate 44100 --channels 2 "$wav" 2>/dev/null
[ -s "$wav" ] || { echo '{"none":true}'; exit 0; }
songrec audio-file-to-recognized-song "$wav" 2>/dev/null | python3 -c '
import json, sys, urllib.request, os
try:
    d = json.load(sys.stdin)
except Exception:
    print(json.dumps({"none": True})); sys.exit()
t = d.get("track") or {}
if not t.get("title"):
    print(json.dumps({"none": True})); sys.exit()
cover = (t.get("images") or {}).get("coverart") or ""
path = ""
if cover:
    path = os.path.join(sys.argv[1], "cover.jpg")
    try:
        urllib.request.urlretrieve(cover, path)
    except Exception:
        path = ""
print(json.dumps({"title": t.get("title"), "artist": t.get("subtitle", ""), "url": t.get("url", ""), "cover": path}, ensure_ascii=False))
' "$dir"
