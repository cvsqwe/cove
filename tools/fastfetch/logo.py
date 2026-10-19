#!/usr/bin/env python3
# Знак Cove для fastfetch: рисует data/cove.svg (дуга и волны) октантами Unicode 16 — 2×4 пикселя
# на символ, сплошные (kitty рисует их сам, шрифт не нужен; брайль в kitty выходит пунктиром).
# Дуга — цвет $1, волны — $2: fastfetch красит их ANSI-цветами, то есть палитрой из обоев.
# Запуск: python3 logo.py  (нужны rsvg-convert и Pillow) → config/cove/branding/logo{,-small}.txt
import subprocess
import tempfile
import unicodedata
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ARC = '<path d="M48.06 14.17A24 24 0 1 0 48.06 49.83" stroke-width="{w}"/>'
WAVES = '<path d="M21 30Q26.5 24 32 30T43 30" stroke-width="{w}"/><path d="M26 41Q31.5 35.5 37 41" stroke-width="{w}"/>'
# пиксели символа: 1 2 / 3 4 / 5 6 / 7 8 → бит (номер − 1)
DOTS = [(dx, dy, 1 << (dy * 2 + dx)) for dy in range(4) for dx in range(2)]


def glyphs() -> dict:
    # 230 узоров — «BLOCK OCTANT-…», остальные 26 давно есть среди блоков и четвертей
    table = {}
    for cp in range(0x1CD00, 0x1CDE6):
        cells = unicodedata.name(chr(cp)).split("-")[1]
        table[sum(1 << (int(n) - 1) for n in cells)] = chr(cp)
    for bits, name in {
        0xFF: "FULL BLOCK", 0x0F: "UPPER HALF BLOCK", 0xF0: "LOWER HALF BLOCK", 0x55: "LEFT HALF BLOCK",
        0xAA: "RIGHT HALF BLOCK", 0x05: "QUADRANT UPPER LEFT", 0x0A: "QUADRANT UPPER RIGHT",
        0x50: "QUADRANT LOWER LEFT", 0xA0: "QUADRANT LOWER RIGHT",
        0xA5: "QUADRANT UPPER LEFT AND LOWER RIGHT", 0x5A: "QUADRANT UPPER RIGHT AND LOWER LEFT",
        0x5F: "QUADRANT UPPER LEFT AND UPPER RIGHT AND LOWER LEFT",
        0xAF: "QUADRANT UPPER LEFT AND UPPER RIGHT AND LOWER RIGHT",
        0xF5: "QUADRANT UPPER LEFT AND LOWER LEFT AND LOWER RIGHT",
        0xFA: "QUADRANT UPPER RIGHT AND LOWER LEFT AND LOWER RIGHT",
        0x03: "UPPER ONE QUARTER BLOCK", 0xC0: "LOWER ONE QUARTER BLOCK", 0x14: "MIDDLE LEFT ONE QUARTER BLOCK",
        0x28: "MIDDLE RIGHT ONE QUARTER BLOCK", 0x3F: "UPPER THREE QUARTERS BLOCK", 0xFC: "LOWER THREE QUARTERS BLOCK",
        0x01: "LEFT HALF UPPER ONE QUARTER BLOCK", 0x02: "RIGHT HALF UPPER ONE QUARTER BLOCK",
        0x40: "LEFT HALF LOWER ONE QUARTER BLOCK", 0x80: "RIGHT HALF LOWER ONE QUARTER BLOCK",
    }.items():
        table[bits] = unicodedata.lookup(name)
    assert len(table) == 255, "нужен Python с Unicode 16"
    return table


GLYPH = glyphs()
SUPER = 8       # суперсэмплинг: пиксель горит, если покрыт больше чем на ~40%
THRESHOLD = 100


def mask(paths: str, cols: int, rows: int):
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="4 4 54 56"><g fill="none" stroke-linecap="round" stroke="#fff">{paths}</g></svg>'
    with tempfile.TemporaryDirectory() as tmp:
        src, png = Path(tmp, "m.svg"), Path(tmp, "m.png")
        src.write_text(svg)
        subprocess.run(["rsvg-convert", "-w", str(cols * 2 * SUPER), "-h", str(rows * 4 * SUPER), str(src), "-o", str(png)], check=True)
        return Image.open(png).getchannel("A").resize((cols * 2, rows * 4), Image.BOX).load()


def render(cols: int, rows: int, arc_w: float, wave_w: float) -> str:
    arc = mask(ARC.format(w=arc_w), cols, rows)
    wav = mask(WAVES.format(w=wave_w), cols, rows)
    lines = []
    for r in range(rows):
        line, cur = "", None
        for c in range(cols):
            a = w = 0
            for dx, dy, bit in DOTS:
                x, y = 2 * c + dx, 4 * r + dy
                if wav[x, y] > THRESHOLD:
                    w |= bit
                elif arc[x, y] > THRESHOLD:
                    a |= bit
            if not a | w:
                line += " "
                continue
            col = "$2" if w and bin(w).count("1") >= bin(a).count("1") else "$1"
            if col != cur:
                line, cur = line + col, col
            line += GLYPH[a | w]
        lines.append(line.rstrip())
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    out = ROOT / "config/cove/branding"
    (out / "logo.txt").write_text(render(24, 12, 5.5, 3.6))
    (out / "logo-small.txt").write_text(render(16, 8, 6, 4.2))
    print("логотипы →", out)
