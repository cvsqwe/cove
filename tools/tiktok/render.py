#!/usr/bin/env python3
"""Динамичный монтаж ролика Cove для TikTok (1080×1920, 60 к/с).

Покадровый рендер: виртуальная камера с плавными наездами по ключевым кадрам, карточка экрана
со скруглением и тенью поверх размытого фона, анимированные подписи, переходы «рывком»
с размытием движения, полоса прогресса. Исходник — съёмка demo.sh (~/Videos/cove-demo/raw.mp4).

Запуск: ~/.local/share/cove/video-venv/bin/python render.py [--preview] [--only N]
  --preview  — половинное разрешение и 30 к/с, быстро проверить тайминг
  --only N   — отрендерить только сцену N (для отладки кадрирования)
"""
import argparse
import math
import subprocess
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

D = Path.home() / "Videos/cove-demo"
RAW = D / "raw.mp4"
OUT = D / "cove-tiktok.mp4"
FONT = "/usr/share/fonts/Adwaita/AdwaitaSans-Regular.ttf"
SRC_W, SRC_H, SRC_FPS = 1920, 1080, 60
ACCENT = (255, 168, 201)          # BGR: сиреневый, под фиолетовые обои
TRANS = 0.42                      # длительность перехода, с
REPO = "github.com/cvsqwe/cove"

# ---------------------------------------------------------------- сценарий
# src: отрезок исходника; dur: длительность в ролике (скорость = длина отрезка / dur)
# card: (ширина, высота) карточки или None — во весь экран
# cam: ключевые кадры камеры (доля сцены 0..1, центр x, центр y, ширина окна в исходнике)
SCENES = [
    dict(src=(0.4, 3.4), dur=2.6, card=None, kind="intro",
         cam=[(0, 980, 540, 600), (1, 900, 540, 540)]),
    dict(src=(4.3, 14.2), dur=5.0, card=None, title="Живые обои", sub="и цвета всей системы — под них",
         cam=[(0, 960, 540, 607), (0.3, 1000, 560, 640), (1, 840, 540, 607)]),
    dict(src=(14.3, 23.4), dur=3.6, card=(1000, 230), title="Динамический остров", sub="таймеры · загрузки · микрофон",
         cam=[(0, 960, 200, 1500), (0.35, 960, 60, 560), (1, 960, 56, 500)]),
    dict(src=(23.8, 32.6), dur=5.2, card=(1000, 800), title="Лаунчер", sub="калькулятор · валюты · эмодзи · таймеры",
         cam=[(0, 960, 420, 1300), (0.25, 960, 300, 800), (1, 960, 290, 740)]),
    dict(src=(32.8, 38.6), dur=4.0, card=(720, 1240), title="Центр управления", sub="сеть · звук · Bluetooth",
         cam=[(0, 1500, 520, 900), (0.3, 1712, 450, 470), (1, 1712, 440, 450)]),
    dict(src=(38.9, 42.4), dur=3.0, card=(1000, 420), title="Дашборд", sub="погода · музыка · календарь · система",
         cam=[(0, 960, 300, 1500), (0.35, 960, 190, 1080), (1, 960, 186, 1050)]),
    dict(src=(43.3, 51.3), dur=5.0, card=(1000, 720), title="Настройки", sub="всё кнопками — без конфигов",
         cam=[(0, 960, 540, 1300), (0.3, 960, 540, 1240), (1, 900, 470, 1000)]),
    dict(src=(54.9, 59.7), dur=3.6, card=(1000, 820), title="Окна и обзор", sub="все рабочие столы разом",
         cam=[(0, 640, 540, 1320), (0.4, 900, 540, 1320), (0.62, 960, 560, 1320), (1, 960, 560, 1250)]),
    dict(src=(60.2, 81.6), dur=5.0, card=(1000, 820), title="Стиль в один клик", sub="Неон · Минимал · День · Уют",
         cam=[(0, 760, 520, 1320), (0.5, 1160, 560, 1250), (1, 960, 540, 1200)]),
    dict(src=(81.8, 85.6), dur=3.0, card=(900, 820), title="Запрос пароля", sub="даже он — в стиле системы",
         cam=[(0, 960, 540, 1200), (0.35, 950, 540, 640), (1, 950, 540, 600)]),
    dict(src=(86.0, 92.4), dur=4.2, card=(1000, 1250), title="Экран блокировки", sub="и меню питания",
         cam=[(0, 960, 520, 760), (0.6, 960, 540, 820), (1, 960, 560, 864)]),
    dict(src=(92.6, 96.6), dur=3.2, card=None, kind="outro",
         cam=[(0, 960, 540, 560), (1, 960, 540, 640)]),
]


# ---------------------------------------------------------------- плавности
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def ease_io(x):  # cubic in-out
    x = clamp(x)
    return 4 * x ** 3 if x < 0.5 else 1 - (-2 * x + 2) ** 3 / 2


def ease_out(x):
    return 1 - (1 - clamp(x)) ** 3


def ease_in(x):
    return clamp(x) ** 3


def ease_back(x, s=1.4):
    x = clamp(x) - 1
    return 1 + (s + 1) * x ** 3 + s * x ** 2


def cam_at(keys, p):
    """Камера между ключевыми кадрами с плавностью in-out на каждом участке."""
    if p <= keys[0][0]:
        return keys[0][1:]
    for (p0, *a), (p1, *b) in zip(keys, keys[1:]):
        if p <= p1:
            k = ease_io((p - p0) / (p1 - p0))
            return tuple(u + (v - u) * k for u, v in zip(a, b))
    return keys[-1][1:]


# ---------------------------------------------------------------- исходник
class Reader:
    """Последовательное чтение отрезка исходника; get(t) — кадр на секунде t от начала отрезка."""

    def __init__(self, a, b):
        self.p = subprocess.Popen(
            ["ffmpeg", "-v", "error", "-nostdin", "-ss", f"{a:.3f}", "-to", f"{b + 0.5:.3f}", "-i", str(RAW),
             "-vf", f"fps={SRC_FPS}", "-f", "rawvideo", "-pix_fmt", "bgr24", "-"],
            stdout=subprocess.PIPE, bufsize=SRC_W * SRC_H * 3 * 4)
        self.idx, self.frame = -1, None

    def get(self, t):
        want = max(0, int(round(t * SRC_FPS)))
        while self.idx < want:
            buf = self.p.stdout.read(SRC_W * SRC_H * 3)
            if len(buf) < SRC_W * SRC_H * 3:
                break  # конец отрезка — держим последний кадр
            self.frame = np.frombuffer(buf, np.uint8).reshape(SRC_H, SRC_W, 3)
            self.idx += 1
        return self.frame

    def close(self):
        self.p.kill()


# ---------------------------------------------------------------- графика
def font(size, weight=b"Bold"):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def text_rgba(text, size, weight=b"Bold", color=(255, 255, 255), tracking=0):
    """Строка текста → BGRA-картинка (с запасом под тень)."""
    f = font(size, weight)
    l, t, r, b = f.getbbox(text)
    w = r - l + tracking * max(0, len(text) - 1) + 40
    h = b - t + 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if tracking:
        x = 20
        for ch in text:
            d.text((x - l, 20 - t), ch, font=f, fill=color + (255,))
            x += f.getlength(ch) + tracking
    else:
        d.text((20 - l, 20 - t), text, font=f, fill=color + (255,))
    a = np.array(img)
    return cv2.cvtColor(a, cv2.COLOR_RGBA2BGRA)


def with_shadow(img, blur=14, alpha=0.55, dy=6):
    """Мягкая тень под текстом — читается на любом фоне."""
    h, w = img.shape[:2]
    pad = blur * 2
    out = np.zeros((h + pad * 2, w + pad * 2, 4), np.float32)
    sh = np.zeros_like(out)
    sh[pad + dy:pad + dy + h, pad:pad + w, 3] = img[:, :, 3] * alpha
    sh[:, :, 3] = cv2.GaussianBlur(sh[:, :, 3], (0, 0), blur)
    out[:] = sh
    blend(out, img.astype(np.float32), pad, pad, 1.0)
    return out


def blend(dst, src, x, y, opacity):
    """Альфа-наложение BGRA/float src на dst (BGR или BGRA float) в точке x, y."""
    h, w = src.shape[:2]
    H, W = dst.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(W, x + w), min(H, y + h)
    if x0 >= x1 or y0 >= y1 or opacity <= 0:
        return
    s = src[y0 - y:y1 - y, x0 - x:x1 - x]
    a = (s[:, :, 3:4] / 255.0) * opacity
    d = dst[y0:y1, x0:x1]
    d[:, :, :3] = d[:, :, :3] * (1 - a) + s[:, :, :3] * a
    if dst.shape[2] == 4:
        d[:, :, 3:4] = np.maximum(d[:, :, 3:4], a * 255)


def rounded_mask(w, h, r, ss=3):
    img = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(img).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), r * ss, fill=255)
    return np.array(img.resize((w, h), Image.LANCZOS), np.float32) / 255.0


def shift(img, dy):
    out = np.empty_like(img)
    dy = int(round(dy))
    if dy > 0:
        out[dy:] = img[:-dy]
        out[:dy] = img[:1]
    elif dy < 0:
        out[:dy] = img[-dy:]
        out[dy:] = img[-1:]
    else:
        out[:] = img
    return out


# ---------------------------------------------------------------- рендер
class Renderer:
    def __init__(self, W, H, fps):
        self.W, self.H, self.fps = W, H, fps
        self.k = W / 1080  # масштаб относительно 1080×1920
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        r = np.sqrt(((xx - W / 2) / (W * 0.75)) ** 2 + ((yy - H / 2) / (H * 0.62)) ** 2)
        self.vignette = np.clip(1.05 - r ** 2 * 0.55, 0.35, 1)[:, :, None]
        g = np.clip(1 - yy[:, :1] / (H * 0.42), 0, 1) ** 1.6  # затемнение сверху — под подписи
        self.scrim = (1 - 0.72 * g)[:, :, None].astype(np.float32)
        self.cache = {}

    def S(self, v):
        return int(round(v * self.k))

    # --- элементы сцены
    def card_assets(self, i, cw, ch):
        key = ("card", i)
        if key not in self.cache:
            r = self.S(44)
            mask = rounded_mask(cw, ch, r)
            pad = self.S(90)
            sh = np.zeros((ch + pad * 2, cw + pad * 2), np.float32)
            sh[pad + self.S(24):pad + self.S(24) + ch, pad:pad + cw] = mask
            sh = cv2.GaussianBlur(sh, (0, 0), self.S(38)) * 0.75
            # тонкая светлая обводка
            inner = rounded_mask(cw - 4, ch - 4, max(1, r - 2))
            ring = mask.copy()
            ring[2:-2, 2:-2] -= inner
            self.cache[key] = (mask, sh, pad, np.clip(ring, 0, 1))
        return self.cache[key]

    def fit(self, el):
        room = self.W - self.S(80)
        if el.shape[1] <= room:
            return el
        s = room / el.shape[1]
        return cv2.resize(el, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)

    def caption_assets(self, i, sc):
        key = ("cap", i)
        if key not in self.cache:
            n = sum(1 for s in SCENES if "title" in s)
            num = 1 + sum(1 for s in SCENES[:i] if "title" in s)
            self.cache[key] = (
                with_shadow(text_rgba(f"{num:02d} / {n:02d}", self.S(30), b"SemiBold", (201, 168, 255), self.S(3)), self.S(8)),
                self.fit(with_shadow(text_rgba(sc["title"], self.S(88), b"ExtraBold"), self.S(16))),
                self.fit(with_shadow(text_rgba(sc["sub"], self.S(44), b"Medium", (226, 220, 240)), self.S(12))),
            )
        return self.cache[key]

    def logo_assets(self):
        if "logo" not in self.cache:
            self.cache["logo"] = (
                with_shadow(text_rgba("cove", self.S(250), b"Black", tracking=-self.S(6)), self.S(30), 0.6),
                with_shadow(text_rgba("моя оболочка для Linux", self.S(54), b"Medium", (232, 226, 246)), self.S(12)),
                with_shadow(text_rgba("Hyprland  ·  Quickshell", self.S(46), b"SemiBold", (201, 168, 255)), self.S(12)),
                with_shadow(text_rgba(REPO, self.S(38), b"Medium", (210, 205, 225)), self.S(10)),
            )
        return self.cache["logo"]

    # --- кадр сцены
    def scene_frame(self, i, sc, src, p, t_local):
        W, H, S = self.W, self.H, self.S
        cx, cy, sw = cam_at(sc["cam"], p)
        card = sc["card"]
        if card:
            cw, ch = S(card[0]), S(card[1])
        else:
            cw, ch = W, H
        sh_ = sw * ch / cw
        # окно не выходит за кадр исходника
        if sh_ > SRC_H:
            sh_ = SRC_H
            sw = sh_ * cw / ch
        sw = min(sw, SRC_W)
        sh_ = sw * ch / cw
        cx = clamp(cx, sw / 2, SRC_W - sw / 2)
        cy = clamp(cy, sh_ / 2, SRC_H - sh_ / 2)

        # фон: размытый исходник вокруг камеры, медленно «дышит»
        small = cv2.resize(src, (240, 135), interpolation=cv2.INTER_AREA)
        bw = 135 * W / H
        bx = clamp(cx / 8 - bw / 2, 0, 240 - bw)
        bg = small[:, int(bx):int(bx + bw)]
        bg = cv2.GaussianBlur(bg, (0, 0), 5)
        bg = cv2.resize(bg, (W, H), interpolation=cv2.INTER_CUBIC).astype(np.float32)
        bg = bg * (0.42 if card else 1.0) * self.vignette

        if card:
            # карточка: въезд с пружинкой в начале сцены
            enter = ease_back(t_local / 0.55) if t_local < 0.55 else 1.0
            s = 0.86 + 0.14 * enter
            dw, dh = cw * s, ch * s
            top_area = S(560)
            dx = (W - dw) / 2
            dy = top_area + (H - top_area - S(150) - dh) / 2
            M = np.float32([[dw / sw, 0, -(cx - sw / 2) * dw / sw],
                            [0, dh / sh_, -(cy - sh_ / 2) * dh / sh_]])
            iw, ih = int(math.ceil(dw)), int(math.ceil(dh))
            content = cv2.warpAffine(src, M, (iw, ih), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
            mask, shadow, pad, ring = self.card_assets(i, cw, ch)
            if s != 1.0:
                mask = cv2.resize(mask, (iw, ih))
                ring = cv2.resize(ring, (iw, ih))
                shadow = cv2.resize(shadow, (int(shadow.shape[1] * s), int(shadow.shape[0] * s)))
                pad = int(pad * s)
            else:
                mask, ring = mask[:ih, :iw], ring[:ih, :iw]
            x, y = int(round(dx)), int(round(dy))
            # тень
            sx, sy = x - pad, y - pad
            hh, ww = shadow.shape
            y0, x0, y1, x1 = max(0, sy), max(0, sx), min(H, sy + hh), min(W, sx + ww)
            bg[y0:y1, x0:x1] *= (1 - shadow[y0 - sy:y1 - sy, x0 - sx:x1 - sx])[:, :, None]
            # содержимое + обводка
            a = mask[:, :, None]
            region = bg[y:y + ih, x:x + iw]
            a = a[:region.shape[0], :region.shape[1]]
            c = content[:region.shape[0], :region.shape[1]].astype(np.float32)
            rg = ring[:region.shape[0], :region.shape[1], None] * 0.22
            region[:] = region * (1 - a) + c * a
            region[:] = region * (1 - rg) + 255 * rg
        else:
            M = np.float32([[W / sw, 0, -(cx - sw / 2) * W / sw],
                            [0, H / sh_, -(cy - sh_ / 2) * H / sh_]])
            bg = cv2.warpAffine(src, M, (W, H), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE).astype(np.float32)
            kind = sc.get("kind")
            bg *= self.vignette * (0.62 if kind else 1.0)

        bg *= self.scrim if "title" in sc else 1.0
        self.overlay_text(bg, i, sc, t_local)
        return bg

    def overlay_text(self, img, i, sc, t):
        W, S = self.W, self.S
        kind = sc.get("kind")
        if "title" in sc:
            num, title, sub = self.caption_assets(i, sc)
            y = S(250)
            for k, (el, y_el, delay) in enumerate([(num, y - S(80), 0.10), (title, y, 0.16), (sub, y + S(118), 0.26)]):
                q = ease_out((t - delay) / 0.5)
                if q <= 0:
                    continue
                x = (W - el.shape[1]) // 2
                blend(img, el, x, int(y_el + (1 - q) * S(46)), q)
        elif kind == "intro":
            logo, sub, *_ = self.logo_assets()
            q = ease_out((t - 0.15) / 0.7)
            s = 1.25 - 0.25 * ease_back((t - 0.15) / 0.8, 1.2)
            if q > 0:
                el = cv2.resize(logo, None, fx=s, fy=s, interpolation=cv2.INTER_CUBIC)
                blend(img, el, (W - el.shape[1]) // 2, int(self.H * 0.42 - el.shape[0] / 2), q)
            q2 = ease_out((t - 0.7) / 0.5)
            if q2 > 0:
                blend(img, sub, (W - sub.shape[1]) // 2, int(self.H * 0.42 + S(150) + (1 - q2) * S(40)), q2)
        elif kind == "outro":
            logo, _, stack, repo = self.logo_assets()
            for el, y, d in [(logo, self.H * 0.40, 0.15), (stack, self.H * 0.40 + S(170), 0.45), (repo, self.H * 0.40 + S(250), 0.7)]:
                q = ease_out((t - d) / 0.6)
                if q > 0:
                    blend(img, el, (W - el.shape[1]) // 2, int(y - el.shape[0] / 2 + (1 - q) * S(50)), q)

    def progress(self, img, p):
        W, H, S = self.W, self.H, self.S
        y0, y1 = H - S(60), H - S(54)
        x0, x1 = S(90), W - S(90)
        img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * 0.6 + 255 * 0.15
        xe = int(x0 + (x1 - x0) * p)
        img[y0:y1, x0:xe] = ACCENT


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--only", type=int)
    args = ap.parse_args()
    W, H, fps = (540, 960, 30) if args.preview else (1080, 1920, 60)
    R = Renderer(W, H, fps)
    scenes = SCENES if args.only is None else [SCENES[args.only]]
    base = 0 if args.only is None else args.only

    starts, t = [], 0.0
    for sc in scenes:
        starts.append(t)
        t += sc["dur"]
    total = t
    out = OUT if args.only is None and not args.preview else D / f"preview{'' if args.only is None else args.only}.mp4"

    enc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-y", "-nostdin",
         "-f", "rawvideo", "-pix_fmt", "bgr24", "-s", f"{W}x{H}", "-r", str(fps), "-i", "-",
         "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
         "-map", "0:v", "-map", "1:a", "-shortest",
         "-c:v", "libx264", "-preset", "veryfast" if args.preview else "slow", "-crf", "16",
         "-profile:v", "high", "-pix_fmt", "yuv420p", "-maxrate", "24M", "-bufsize", "48M",
         "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(out)],
        stdin=subprocess.PIPE)

    readers = {}

    def reader(j):
        if j not in readers:
            readers[j] = Reader(*scenes[j]["src"])
        return readers[j]

    def frame_of(j, t_local):
        sc = scenes[j]
        a, b = sc["src"]
        speed = (b - a) / sc["dur"]
        src = reader(j).get(clamp(t_local, 0, sc["dur"] + TRANS) * speed)
        p = clamp(t_local / sc["dur"])
        return R.scene_frame(base + j, sc, src, p, max(0.0, t_local))

    n = int(round(total * fps))
    for f in range(n):
        tg = f / fps
        j = max(k for k, s in enumerate(starts) if s <= tg)
        tl = tg - starts[j]
        # переход: последние TRANS/2 сцены j-1… и первые TRANS/2 сцены j
        img = None
        if j > 0 and tl < TRANS / 2:
            q = 0.5 + tl / TRANS
            prev = frame_of(j - 1, scenes[j - 1]["dur"] + tl)
            cur = frame_of(j, tl)
            img = transition(prev, cur, q, H)
        elif j + 1 < len(scenes) and tl > scenes[j]["dur"] - TRANS / 2:
            q = 0.5 - (scenes[j]["dur"] - tl) / TRANS
            cur = frame_of(j, tl)
            nxt = frame_of(j + 1, tl - scenes[j]["dur"])
            img = transition(cur, nxt, q, H)
        else:
            img = frame_of(j, tl)
        # закрываем ридеры прошлых сцен
        for k in [k for k in readers if k < j - 1]:
            readers.pop(k).close()
        if f < fps * 0.25:  # мягкое появление в самом начале
            img = img * (f / (fps * 0.25))
        R.progress(img, tg / total)
        enc.stdin.write(np.clip(img, 0, 255).astype(np.uint8).tobytes())
        if f % fps == 0:
            print(f"\r{tg:5.1f}/{total:.1f} с", end="", flush=True)
    enc.stdin.close()
    enc.wait()
    for r in readers.values():
        r.close()
    print(f"\n{out}")


def transition(a, b, q, H):
    """Рывок вверх: старый кадр уезжает, новый въезжает снизу, размытие движения + вспышка."""
    e = ease_io(q)
    off = H * 0.28
    A = shift(a, -e * off)
    B = shift(b, (1 - e) * off)
    k = clamp((q - 0.25) / 0.5)  # перекрёстное смешивание в середине
    img = A * (1 - k) + B * k
    blur = int(H * 0.09 * math.sin(math.pi * q))
    if blur > 2:
        img = cv2.blur(img, (1, blur))
    flash = 0.10 * math.sin(math.pi * q)
    return img * (1 - flash) + 255 * flash


if __name__ == "__main__":
    main()
