#!/usr/bin/env python3
"""Монтаж ролика для TikTok из съёмки demo.sh.

Берёт ~/Videos/cove-demo/raw.mp4 + scenes.tsv и собирает вертикальный 1080×1920:
размытый кадр на фоне, сверху подпись сцены, по центру — кадрирование нужной части экрана.
Результат — ~/Videos/cove-demo/cove-tiktok.mp4 (без музыки — звук добавляется в TikTok).
"""
import subprocess
import sys
import textwrap
from pathlib import Path

D = Path.home() / "Videos/cove-demo"
RAW, SCENES, OUT = D / "raw.mp4", D / "scenes.tsv", D / "cove-tiktok.mp4"
FONT = "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
# gsr стартует раньше первой отметки (sleep 1.2 в demo.sh минус запуск самого gsr)
OFFSET = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0

# кадрирование исходника 1920×1080: x, y, w, h — что показывать крупно
CROPS = {
    "full":   (0, 0, 1920, 1080),
    "island": (560, 0, 800, 800),
    "center": (420, 0, 1080, 1080),
    "right":  (1160, 0, 760, 900),
    "top":    (360, 0, 1200, 675),
}


def scenes():
    rows = [l.split("\t") for l in SCENES.read_text().splitlines() if l.strip()]
    out = []
    for (t, kind, text), nxt in zip(rows, rows[1:]):
        out.append((float(t) + OFFSET, float(nxt[0]) + OFFSET, kind, text.strip()))
    return out


def main():
    parts = []
    tmp = D / "parts"
    tmp.mkdir(exist_ok=True)
    for i, (a, b, kind, text) in enumerate(scenes()):
        x, y, w, h = CROPS[kind]
        cap = tmp / f"{i:02d}.txt"
        cap.write_text("\n".join(textwrap.wrap(text, 24)))
        part = tmp / f"{i:02d}.mp4"
        fh = round(1080 * h / w / 2) * 2  # высота переднего плана при ширине 1080
        top = 1920 // 2 - fh // 2 + 140   # чуть ниже центра — сверху место под подпись
        graph = (
            f"[0:v]split[a][b];"
            f"[a]scale=-2:1920,crop=1080:1920,gblur=sigma=40,eq=brightness=-0.18[bg];"
            f"[b]crop={w}:{h}:{x}:{y},scale=1080:{fh}:flags=lanczos[fg];"
            f"[bg][fg]overlay=0:{top},"
            f"drawtext=fontfile={FONT}:textfile={cap}:fontsize=68:fontcolor=white:line_spacing=14:"
            f"x=(w-text_w)/2:y={top}-text_h-80:shadowcolor=black@0.6:shadowx=0:shadowy=4,"
            f"drawtext=fontfile={FONT}:text=cove:fontsize=44:fontcolor=white@0.55:"
            f"x=(w-text_w)/2:y=h-170,"
            f"fade=t=in:st=0:d=0.25,fps=60,format=yuv420p[v]"
        )
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-nostdin", "-ss", f"{a:.3f}", "-to", f"{b:.3f}", "-i", str(RAW),
             "-filter_complex", graph, "-map", "[v]", "-an",
             "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", str(part)],
            check=True,
        )
        parts.append(part)
        print(f"{i + 1:2d}/{len(parts)}  {b - a:5.1f} с  {kind:6s} {text}", flush=True)

    lst = tmp / "list.txt"
    lst.write_text("".join(f"file '{p}'\n" for p in parts))
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-nostdin", "-f", "concat", "-safe", "0", "-i", str(lst),
         "-c", "copy", "-movflags", "+faststart", str(OUT)],
        check=True,
    )
    print(OUT)


if __name__ == "__main__":
    main()
