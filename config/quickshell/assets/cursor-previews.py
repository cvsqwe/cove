#!/usr/bin/env python3
"""Превью тем курсоров для галереи в Настройках → Оформление.
Читает Xcursor-файлы (указатель, рука, текст) каждой темы и складывает их в одну PNG:
~/.cache/quickshell/cursors/<тема>.png. Уже готовые превью не пересоздаёт."""
import os, struct, sys
from PIL import Image

DIRS = ["/usr/share/icons", os.path.expanduser("~/.local/share/icons")]
OUT = os.path.expanduser("~/.cache/quickshell/cursors")
ROLES = [["left_ptr", "default", "arrow"], ["pointer", "hand2", "hand1", "pointing_hand"], ["xterm", "text", "ibeam"]]
SIZE = 48

def read_xcursor(path, want=SIZE):
    data = open(path, "rb").read()
    if data[:4] != b"Xcur": return None
    ntoc = struct.unpack_from("<I", data, 12)[0]
    imgs = []
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", data, 16 + i * 12)
        if typ == 0xFFFD0002: imgs.append((sub, pos))
    if not imgs: return None
    nominal = min({s for s, _ in imgs}, key=lambda s: (abs(s - want), -s))
    pos = next(p for s, p in imgs if s == nominal)  # первый кадр анимации
    _, _, _, _, w, h, xhot, yhot, _ = struct.unpack_from("<IIIIIIIII", data, pos)
    px = data[pos + 36: pos + 36 + w * h * 4]
    im = Image.frombuffer("RGBA", (w, h), px, "raw", "BGRA", 0, 1)
    # Xcursor хранит предумноженную альфу
    r, g, b, a = im.split()
    out = Image.new("RGBA", (w, h))
    pr, pg, pb, pa = r.load(), g.load(), b.load(), a.load()
    op = out.load()
    for y in range(h):
        for x in range(w):
            al = pa[x, y]
            op[x, y] = (0, 0, 0, 0) if al == 0 else (min(255, pr[x, y] * 255 // al), min(255, pg[x, y] * 255 // al), min(255, pb[x, y] * 255 // al), al)
    return out

def find(theme_dir, names):
    for n in names:
        p = os.path.join(theme_dir, "cursors", n)
        if os.path.exists(p): return os.path.realpath(p)
    return None

def main():
    os.makedirs(OUT, exist_ok=True)
    force = "--force" in sys.argv
    for base in DIRS:
        if not os.path.isdir(base): continue
        for theme in sorted(os.listdir(base)):
            d = os.path.join(base, theme)
            if not os.path.isdir(os.path.join(d, "cursors")): continue
            dst = os.path.join(OUT, theme + ".png")
            if os.path.exists(dst) and not force: continue
            cells = []
            for names in ROLES:
                p = find(d, names)
                try: im = read_xcursor(p) if p else None
                except Exception: im = None
                if im:
                    im.thumbnail((SIZE, SIZE), Image.LANCZOS)
                    cells.append(im)
            if not cells: continue
            sheet = Image.new("RGBA", (len(cells) * (SIZE + 8), SIZE))
            for i, im in enumerate(cells):
                sheet.paste(im, (i * (SIZE + 8) + (SIZE - im.width) // 2, (SIZE - im.height) // 2), im)
            sheet.save(dst)
            print(theme)

main()
