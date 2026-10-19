"""Telegram: собирает Cove.tdesktop-theme (палитра + фон чата сплошным цветом)."""
import io
import os
import struct
import subprocess
import zipfile
import zlib

DIR = os.path.expanduser("~/.cache/cove/telegram")
THEME = os.path.join(DIR, "Cove.tdesktop-theme")


def png(color, size=8):
    """Маленькая одноцветная PNG; Telegram замостит её (имя tiled.png)."""
    row = b"\x00" + bytes((color.r, color.g, color.b)) * size
    raw = zlib.compress(row * size)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", raw) + chunk(b"IEND", b""))


def apply(ctx, api):
    colors = open(os.path.join(DIR, "colors.tdesktop-theme"), "rb").read()
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("colors.tdesktop-theme", colors)
        z.writestr("tiled.png", png(ctx["crust"].mix(ctx["base"], 0.5)))
    api.write(THEME, buf.getvalue())
    return "ok"


def disable(api):
    api.restore(THEME)


def action(api):
    # открыть тему в уже запущенном Telegram: он покажет предпросмотр с кнопкой «Применить»
    for b in ("telegram-desktop", "Telegram"):
        try:
            subprocess.Popen([b, "--", THEME], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            return
        except OSError:
            continue
