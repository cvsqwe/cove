#!/usr/bin/env python3
"""Демон миниатюр Cove Files (кэш по стандарту freedesktop: ~/.cache/thumbnails/large).

stdin:  строки «путь» — какие файлы нужны
stdout: строки «путь\\tминиатюра» (пустая миниатюра — сделать не получилось)
Картинки — Pillow, видео и обложки аудио — ffmpegthumbnailer, PDF — pdftoppm. Работает в 3 потока.
"""

import hashlib
import os
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import quote

try:
    from PIL import Image, ImageOps, PngImagePlugin
except ImportError:
    Image = None

SIZE = 256
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "thumbnails")
LARGE = os.path.join(CACHE, "large")
FAIL = os.path.join(CACHE, "fail", "cove-files")
lock = threading.Lock()

IMG = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tif", ".tiff", ".ico", ".tga", ".avif", ".heic", ".jxl"}
VID = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v", ".wmv", ".flv", ".mpg", ".mpeg", ".3gp", ".ts"}
AUD = {".mp3", ".flac", ".m4a", ".ogg", ".opus"}
DOC = {".pdf"}


def say(path, thumb):
    with lock:
        sys.stdout.write(f"{path}\t{thumb}\n")
        sys.stdout.flush()


def cached(path, mtime, md5):
    t = os.path.join(LARGE, md5 + ".png")
    if os.path.exists(t) and Image:
        try:
            with Image.open(t) as im:
                if im.info.get("Thumb::MTime") == str(mtime):
                    return t
        except Exception:
            pass
    return None


def save(im, path, uri, mtime, md5):
    im.thumbnail((SIZE, SIZE))
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA")
    info = PngImagePlugin.PngInfo()
    info.add_text("Thumb::URI", uri)
    info.add_text("Thumb::MTime", str(mtime))
    info.add_text("Software", "Cove Files")
    os.makedirs(LARGE, exist_ok=True)
    out = os.path.join(LARGE, md5 + ".png")
    tmp = out + f".{os.getpid()}.tmp"
    im.save(tmp, "PNG", pnginfo=info)
    os.chmod(tmp, 0o600)
    os.replace(tmp, out)
    return out


def make(path):
    try:
        mtime = int(os.stat(path).st_mtime)
    except OSError:
        return say(path, "")
    uri = "file://" + quote(path)
    md5 = hashlib.md5(uri.encode()).hexdigest()
    t = cached(path, mtime, md5)
    if t:
        return say(path, t)
    fail = os.path.join(FAIL, md5 + ".png")
    if not Image or (os.path.exists(fail) and os.stat(fail).st_mtime >= mtime):
        return say(path, "")
    ext = os.path.splitext(path)[1].lower()
    try:
        if ext in IMG:
            with Image.open(path) as im:
                im.draft("RGB", (SIZE * 2, SIZE * 2))  # JPEG: декодировать сразу уменьшенным
                im = ImageOps.exif_transpose(im)
                return say(path, save(im, path, uri, mtime, md5))
        with tempfile.TemporaryDirectory() as td:
            out = os.path.join(td, "t.png")
            if ext in VID or ext in AUD:
                cmd = ["ffmpegthumbnailer", "-i", path, "-o", out, "-s", str(SIZE), "-c", "png"]
                if ext in VID:
                    cmd += ["-t", "15%"]
            elif ext in DOC:
                cmd = ["pdftoppm", "-png", "-singlefile", "-f", "1", "-l", "1", "-scale-to", str(SIZE), path, out[:-4]]
            else:
                return say(path, "")
            subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
            with Image.open(out) as im:
                return say(path, save(im.copy(), path, uri, mtime, md5))
    except Exception:
        # не получилось — запоминаем, чтобы не пытаться снова до изменения файла
        try:
            os.makedirs(FAIL, exist_ok=True)
            open(os.path.join(FAIL, md5 + ".png"), "wb").close()
        except OSError:
            pass
        return say(path, "")


def main():
    with ThreadPoolExecutor(3) as pool:
        for ln in sys.stdin:
            p = ln.rstrip("\n")
            if p:
                pool.submit(make, p)


if __name__ == "__main__":
    main()
