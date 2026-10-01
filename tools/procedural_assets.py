#!/usr/bin/env python3
"""
Dream Repair — procedural pixel assets + synthesized audio.

Generates the small assets that don't need AI art (or are placeholders until
an AI version is generated and dropped into art_src/raw/ with the same name):

  sprites/ground.png        seamless candy pavement tile (128x128)
  sprites/cracks.png        seamless crack overlay tile (anger emotion)
  sprites/chocowall.png     maze wall block (48x64)  [skipped if AI version exists]
  sprites/cake.png          birthday cake with 10 candles (Duoduo's fear)
  sprites/schoolbag.png     hidden memory object (night only)
  sprites/syrup.png         syrup puddle / lake piece
  sprites/sugarglass.png    crystallised syrup (happy emotion)
  sprites/gumdrop.png       floating gumdrop stepping stone (fantasy level)
  sprites/crystal.png       emotion fragment (white; tinted in engine)
  sprites/photo.png         memory fragment (polaroid)
  sprites/footprint.png     small footprints (sad rain reveals them)
  sprites/lamp.png          candy lamp (night reveals path)
  sprites/glitch.png        glitch spot base
  sprites/fence.png         candy-cane fence segment
  audio/music/*.wav         music-box loops (sweet / melting / maze)
  audio/sfx/*.wav           UI + gameplay sound effects
  sprites/st_*.png          Old Street props (lamp, bench, shutter, puddle, signpost,
                            window, light path, planter, fog) + street_ground_<stage>.png
  audio/music/street_*.wav  Old Street loops (summer / fading / echo)

Usage: python3 tools/procedural_assets.py          # everything
       python3 tools/procedural_assets.py street   # only the Old Street assets
"""
import math
import os
import random
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "game", "assets", "sprites")
MUS = os.path.join(ROOT, "game", "assets", "audio", "music")
SFX = os.path.join(ROOT, "game", "assets", "audio", "sfx")
RNG = random.Random(417)


def rgba(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


# ---------------------------------------------------------------- sprites
def ground():
    s = 128
    base = np.zeros((s, s, 3), np.float32)
    # soft pastel noise, tileable via sum of periodic sines
    yy, xx = np.mgrid[0:s, 0:s] / s * 2 * math.pi
    n = (np.sin(xx * 2 + 1.3) * np.cos(yy * 3 + 0.4) + 0.6 * np.sin(xx * 5 + yy * 4) +
         0.4 * np.cos(xx * 7 - yy * 6 + 2.0))
    n = (n - n.min()) / (n.max() - n.min())
    c1 = np.array([255, 226, 232])
    c2 = np.array([250, 208, 222])
    base = c1 * (1 - n[..., None]) + c2 * n[..., None]
    img = Image.fromarray(base.astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(img)
    # cobble grid of biscuit tiles (tileable: 4x4 tiles of 32px)
    for gy in range(4):
        for gx in range(4):
            off = 16 if gy % 2 else 0
            x0 = (gx * 32 + off) % s
            y0 = gy * 32
            for dx in (0, -s):
                d.rectangle([x0 + dx + 1, y0 + 1, x0 + dx + 30, y0 + 30], outline=(236, 186, 204, 255))
                d.line([x0 + dx + 2, y0 + 2, x0 + dx + 29, y0 + 2], fill=(255, 240, 244, 255))
    # sprinkles
    cols = ["#ff8fb1", "#9ad8ff", "#ffe07a", "#c9a7ff", "#ffffff"]
    for _ in range(70):
        x, y = RNG.randrange(s), RNG.randrange(s)
        c = rgba(RNG.choice(cols))
        if RNG.random() < 0.5:
            pts = [(x, y), ((x + 1) % s, y)]
        else:
            pts = [(x, y), (x, (y + 1) % s)]
        for p in pts:
            img.putpixel(p, c)
    img.save(os.path.join(SPR, "ground.png"))


def cracks():
    s = 128
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for _ in range(5):
        x, y = RNG.uniform(0, s), RNG.uniform(0, s)
        ang = RNG.uniform(0, 2 * math.pi)
        for _ in range(RNG.randint(8, 16)):
            ang += RNG.uniform(-0.8, 0.8)
            nx, ny = x + math.cos(ang) * RNG.uniform(4, 9), y + math.sin(ang) * RNG.uniform(4, 9)
            for ox in (-s, 0, s):
                for oy in (-s, 0, s):
                    d.line([x + ox, y + oy, nx + ox, ny + oy], fill=(90, 20, 40, 220), width=1)
            x, y = nx, ny
    img.save(os.path.join(SPR, "cracks.png"))


def chocowall():
    if os.path.exists(os.path.join(ROOT, "art_src", "raw", "chocowall.png")):
        return
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # front face (bottom 24px)
    d.rectangle([0, 40, w - 1, h - 1], fill=rgba("#4a2618"))
    d.line([0, h - 1, w - 1, h - 1], fill=rgba("#2c150d"))
    for x in range(0, w, 12):
        d.line([x, 42, x, h - 3], fill=rgba("#3a1d12"))
    # top face
    d.rectangle([0, 0, w - 1, 39], fill=rgba("#6b3a24"))
    for gx in range(3):
        for gy in range(3):
            x0, y0 = 3 + gx * 15, 3 + gy * 12
            d.rectangle([x0, y0, x0 + 12, y0 + 9], fill=rgba("#7d4a2f"), outline=rgba("#55301d"))
            d.line([x0 + 1, y0 + 1, x0 + 11, y0 + 1], fill=rgba("#9a6344"))
    # frosting trim with drips
    d.rectangle([0, 37, w - 1, 41], fill=rgba("#ffb3cf"))
    d.line([0, 37, w - 1, 37], fill=rgba("#ffe0ec"))
    for x in range(2, w, 7):
        L = RNG.randint(1, 6)
        d.rectangle([x, 41, x + 2, 41 + L], fill=rgba("#ffb3cf"))
    d.rectangle([0, 0, w - 1, h - 1], outline=rgba("#26110a"))
    img.save(os.path.join(SPR, "chocowall.png"))


def cake():
    w, h = 96, 92
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # plate
    d.ellipse([4, 70, 92, 90], fill=rgba("#e9e4f5"), outline=rgba("#9e93bf"))
    # bottom tier
    d.rectangle([12, 50, 84, 78], fill=rgba("#ffc4d8"))
    d.ellipse([12, 72, 84, 84], fill=rgba("#ffc4d8"))
    d.ellipse([12, 44, 84, 56], fill=rgba("#fff1f6"))
    for x in range(14, 84, 8):
        d.ellipse([x, 52, x + 6, 60 + RNG.randint(0, 5)], fill=rgba("#fff1f6"))
    # top tier
    d.rectangle([24, 28, 72, 50], fill=rgba("#ff9fc0"))
    d.ellipse([24, 44, 72, 54], fill=rgba("#ff9fc0"))
    d.ellipse([24, 22, 72, 34], fill=rgba("#fff6d9"))
    for x in range(26, 72, 7):
        d.ellipse([x, 30, x + 5, 36 + RNG.randint(0, 4)], fill=rgba("#fff6d9"))
    # strawberries
    for x in (18, 40, 62, 78):
        d.ellipse([x - 4, 60, x + 3, 67], fill=rgba("#e8384f"))
    # 10 candles
    for i in range(10):
        a = i / 10 * 2 * math.pi
        cx = 48 + math.cos(a) * 19
        cy = 27 + math.sin(a) * 4
        col = ["#8fd3ff", "#ffe07a", "#c9a7ff", "#ff8fb1"][i % 4]
        d.rectangle([cx - 1, cy - 12, cx + 1, cy], fill=rgba(col))
        d.ellipse([cx - 2, cy - 18, cx + 2, cy - 12], fill=rgba("#ffcf4a"))
        d.point((cx, cy - 16), fill=rgba("#fff7d0"))
    img.save(os.path.join(SPR, "cake.png"))


def schoolbag():
    w, h = 30, 30
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 6, 26, 28], 5, fill=rgba("#5b7fd6"), outline=rgba("#233a78"))
    d.rounded_rectangle([7, 16, 23, 26], 3, fill=rgba("#7899ea"), outline=rgba("#233a78"))
    d.arc([9, 0, 21, 12], 180, 360, fill=rgba("#233a78"), width=2)
    d.rectangle([13, 18, 17, 20], fill=rgba("#ffe07a"))
    d.line([6, 8, 24, 8], fill=rgba("#9ab4ff"))
    img.save(os.path.join(SPR, "schoolbag.png"))


def blob(w, h, fill, outline, hl, name, alpha=255, seed=0):
    r = random.Random(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(18):
        a = i / 18 * 2 * math.pi
        rr = 0.82 + r.uniform(-0.1, 0.12)
        pts.append((w / 2 + math.cos(a) * (w / 2 - 2) * rr, h / 2 + math.sin(a) * (h / 2 - 2) * rr))
    f = fill[:3] + (alpha,)
    d.polygon(pts, fill=f, outline=outline[:3] + (min(255, alpha + 40),))
    d.ellipse([w * 0.25, h * 0.22, w * 0.5, h * 0.36], fill=hl[:3] + (min(255, alpha),))
    d.ellipse([w * 0.56, h * 0.5, w * 0.64, h * 0.58], fill=hl[:3] + (min(255, alpha),))
    img.save(os.path.join(SPR, name))


def gumdrop():
    w, h = 22, 20
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 12, 21, 19], fill=(60, 30, 80, 90))
    d.pieslice([2, 1, 20, 26], 180, 360, fill=rgba("#b48cff"), outline=rgba("#6a45b8"))
    d.rectangle([2, 13, 20, 15], fill=rgba("#b48cff"))
    d.line([2, 15, 20, 15], fill=rgba("#6a45b8"))
    for _ in range(8):
        d.point((RNG.randint(5, 17), RNG.randint(4, 13)), fill=rgba("#f1e7ff"))
    img.save(os.path.join(SPR, "gumdrop.png"))


def crystal():
    w, h = 16, 22
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(8, 0), (15, 7), (11, 21), (5, 21), (1, 7)], fill=(235, 235, 245, 255), outline=(120, 120, 150, 255))
    d.polygon([(8, 0), (8, 21), (5, 21), (1, 7)], fill=(255, 255, 255, 255))
    d.line([(1, 7), (15, 7)], fill=(160, 160, 190, 255))
    d.point((6, 4), fill=(255, 255, 255, 255))
    img.save(os.path.join(SPR, "crystal.png"))


def photo():
    w, h = 18, 20
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=rgba("#fbf6ea"), outline=rgba("#8c7a66"))
    d.rectangle([2, 2, w - 3, 13], fill=rgba("#ffcf8a"))
    d.rectangle([2, 9, w - 3, 13], fill=rgba("#7fc8f0"))
    d.ellipse([10, 3, 14, 7], fill=rgba("#fff3b0"))
    d.rectangle([5, 7, 7, 12], fill=rgba("#e46a8a"))
    d.point((6, 6), fill=rgba("#5a3a2a"))
    img.save(os.path.join(SPR, "photo.png"))


def footprint():
    img = Image.new("RGBA", (10, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([0, 2, 3, 8], fill=(255, 255, 255, 210))
    d.ellipse([6, 4, 9, 11], fill=(255, 255, 255, 210))
    img.save(os.path.join(SPR, "footprint.png"))


def lamp():
    w, h = 12, 30
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(10, h):
        d.line([5, y, 6, y], fill=rgba("#ffffff") if (y // 3) % 2 else rgba("#ff5c8a"))
    d.ellipse([1, 0, 10, 10], fill=rgba("#fff3a8"), outline=rgba("#e0a830"))
    d.point((4, 3), fill=rgba("#ffffff"))
    img.save(os.path.join(SPR, "lamp.png"))


def glitch():
    w = h = 28
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - w / 2, y - h / 2) / (w / 2)
            if dist < 1 and RNG.random() > dist * 0.9:
                c = RNG.choice([(80, 255, 240), (255, 80, 200), (255, 255, 255), (40, 40, 60)])
                img.putpixel((x, y), c + (int(255 * (1 - dist * 0.7)),))
    img.save(os.path.join(SPR, "glitch.png"))


def fence():
    w, h = 32, 22
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 7, w - 1, 9], fill=rgba("#ffffff"), outline=rgba("#c7426a"))
    d.rectangle([0, 14, w - 1, 16], fill=rgba("#ffffff"), outline=rgba("#c7426a"))
    for x in (3, 19):
        d.rectangle([x, 2, x + 8, h - 1], fill=rgba("#ffffff"), outline=rgba("#c7426a"))
        for y in range(3, h - 1, 4):
            d.line([x + 1, y, x + 7, y + 2], fill=rgba("#ff5c8a"))
    img.save(os.path.join(SPR, "fence.png"))


def town_ground(melted=False):
    """Pre-baked 1600x1200 ground for the Candy City map, with roads that
    match the layout in scripts/dream.gd (the 'pre-rendered background')."""
    W, H = 1600, 1200
    tile = Image.open(os.path.join(SPR, "ground.png")).convert("RGB")
    base = Image.new("RGB", (W, H))
    for y in range(0, H, 128):
        for x in range(0, W, 128):
            base.paste(tile, (x, y))
    arr = np.asarray(base).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    rng = np.random.default_rng(7)

    def smooth_noise(scale, seed):
        r = np.random.default_rng(seed)
        gw, gh = W // scale + 2, H // scale + 2
        g = r.random((gh, gw)).astype(np.float32)
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((gw * scale, gh * scale), Image.BICUBIC)
        return np.asarray(im).astype(np.float32)[:H, :W] / 255.0

    n1 = smooth_noise(90, 1)
    n2 = smooth_noise(24, 2)
    # soft pastel meadow patches (lilac / mint cream) away from roads
    lilac = np.array([236, 214, 245], np.float32)
    mint = np.array([214, 244, 232], np.float32)
    m1 = np.clip((n1 - 0.62) * 5, 0, 1)[..., None]
    m2 = np.clip((0.3 - n1) * 5, 0, 1)[..., None]
    arr = arr * (1 - m1 * 0.55) + lilac * m1 * 0.55
    arr = arr * (1 - m2 * 0.45) + mint * m2 * 0.45

    # roads: distance to polyline segments
    def seg_dist(ax, ay, bx, by):
        dx, dy = bx - ax, by - ay
        t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / (dx * dx + dy * dy), 0, 1)
        return np.hypot(xx - (ax + t * dx), yy - (ay + t * dy))

    segs = [(800, 1200, 800, 330, 38), (250, 770, 1180, 770, 30), (800, 520, 320, 380, 26),
            (800, 520, 1150, 330, 22), (250, 770, 250, 900, 24)]
    road = np.zeros((H, W), np.float32)
    for ax, ay, bx, by, w in segs:
        d = seg_dist(ax, ay, bx, by) + (n2 - 0.5) * 10
        road = np.maximum(road, np.clip((w - d) / 4.0, 0, 1))
    # plazas
    for cx, cy, r in [(1250, 640, 150), (800, 360, 90), (800, 1120, 70)]:
        d = np.hypot(xx - cx, (yy - cy) * 1.25) + (n2 - 0.5) * 12
        road = np.maximum(road, np.clip((r - d) / 4.0, 0, 1))
    # chocolate brick texture
    bw, bh = 20, 10
    row = (yy // bh).astype(int)
    off = (row % 2) * (bw // 2)
    mortar = (((xx + off) % bw) < 1.5) | ((yy % bh) < 1.5)
    brick_var = smooth_noise(12, 5)
    brick = np.dstack([196 + brick_var * 22, 138 + brick_var * 18, 116 + brick_var * 14])
    brick[mortar] = [236, 196, 206]
    hl = ((yy % bh) >= 1.5) & ((yy % bh) < 3)
    brick[hl & ~mortar] += 18
    arr = arr * (1 - road[..., None]) + brick * road[..., None]
    # road edge frosting
    edge = (road > 0.05) & (road < 0.6)
    arr[edge] = arr[edge] * 0.4 + np.array([255, 235, 242]) * 0.6

    if melted:
        # warm, syrupy tint + drips and stains
        arr = arr * np.array([1.0, 0.9, 0.84]) + np.array([6, 0, 0])
        stains = np.clip((smooth_noise(40, 9) - 0.66) * 6, 0, 1)[..., None]
        arr = arr * (1 - stains * 0.6) + np.array([196, 110, 130]) * stains * 0.6
    arr = np.clip(arr, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr, "RGB")
    # sprinkles on top
    d = ImageDraw.Draw(img)
    cols = [(255, 143, 177), (154, 216, 255), (255, 224, 122), (201, 167, 255), (255, 255, 255)]
    for _ in range(2500):
        x, y = int(rng.integers(0, W)), int(rng.integers(0, H))
        c = cols[int(rng.integers(0, len(cols)))]
        if rng.random() < 0.5:
            d.line([x, y, x + 1, y], fill=c)
        else:
            d.line([x, y, x, y + 1], fill=c)
    img.save(os.path.join(SPR, "town_ground_melted.png" if melted else "town_ground.png"), optimize=True)


# ------------------------------------------------------------------ audio
SR = 22050


def write_wav(path, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32000).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def note_freq(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def musicbox_tone(freq, dur, detune=0.0):
    t = np.arange(int(SR * dur)) / SR
    f = freq * (1 + detune * np.sin(2 * np.pi * 0.7 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t * 3.2)
    tone = (np.sin(ph) + 0.35 * np.sin(2 * ph) * np.exp(-t * 6) + 0.15 * np.sin(4.01 * ph) * np.exp(-t * 9))
    return tone * env


def music(name, melody, bass, bpm, detune=0.0, dark=0.0, repeats=2, tone_fn=None, echo=0.0):
    tone_fn = tone_fn or musicbox_tone
    beat = 60 / bpm
    total = len(melody) * beat * repeats
    out = np.zeros(int(SR * (total + 2)))
    for rep in range(repeats):
        for i, n in enumerate(melody):
            if n is None:
                continue
            start = int(SR * (rep * len(melody) + i) * beat)
            tone = tone_fn(note_freq(n), 2.2, detune) * 0.35
            out[start:start + len(tone)] += tone
        for i, n in enumerate(bass):
            start = int(SR * (rep * len(melody) + i * 4) * beat)
            tone = tone_fn(note_freq(n), 4 * beat + 1, detune * 0.5) * 0.22
            out[start:start + len(tone)] += tone
    if echo > 0:
        dl = int(SR * echo)
        dry = out.copy()
        out[dl:] += dry[:-dl] * 0.5
        out[2 * dl:] += dry[:-2 * dl] * 0.28
    if dark > 0:
        t = np.arange(len(out)) / SR
        drone = np.sin(2 * np.pi * 55 * t) * 0.5 + np.sin(2 * np.pi * 58.3 * t) * 0.5
        out += drone * dark * 0.12
    # fold tail into the start for a seamless loop
    n = int(SR * total)
    tail = out[n:]
    out = out[:n]
    out[:len(tail)] += tail
    out /= max(1e-6, np.abs(out).max()) * 1.25
    write_wav(os.path.join(MUS, name), out)


def sfx():
    t = lambda d: np.arange(int(SR * d)) / SR
    # pickup chime
    a = t(0.6)
    s = sum(np.sin(2 * np.pi * f * a) * np.exp(-a * 5) * (a > dly) for f, dly in ((1046, 0), (1318, 0.07), (1568, 0.14)))
    write_wav(os.path.join(SFX, "pickup.wav"), s * 0.4)
    # UI click
    a = t(0.06)
    write_wav(os.path.join(SFX, "click.wav"), np.sin(2 * np.pi * 900 * a) * np.exp(-a * 60) * 0.5)
    # dialogue blip
    a = t(0.05)
    write_wav(os.path.join(SFX, "blip.wav"), np.sign(np.sin(2 * np.pi * 620 * a)) * np.exp(-a * 50) * 0.18)
    # glitch
    a = t(0.5)
    rng = np.random.default_rng(3)
    noise = rng.uniform(-1, 1, len(a))
    gate = (np.floor(a * 40) % 3 != 0).astype(float)
    tone = np.sign(np.sin(2 * np.pi * (200 + 900 * rng.random(len(a)).cumsum() % 400) * a))
    write_wav(os.path.join(SFX, "glitch.wav"), (noise * 0.4 + tone * 0.2) * gate * np.exp(-a * 3) * 0.6)
    # dream shift whoosh (editor change)
    a = t(0.9)
    sweep = np.sin(2 * np.pi * (300 + 500 * a) * a) * np.sin(np.pi * a / 0.9)
    shimmer = np.sin(2 * np.pi * 1760 * a) * 0.2 * np.sin(np.pi * a / 0.9)
    write_wav(os.path.join(SFX, "shift.wav"), (sweep * 0.3 + shimmer) * 0.6)
    # repair (rising, warm)
    a = t(1.0)
    s = sum(np.sin(2 * np.pi * f * a) * np.exp(-a * 2.5) for f in (523, 659, 784, 1046))
    write_wav(os.path.join(SFX, "repair.wav"), s * 0.18)
    # enhance (sparkly, detuned)
    s = sum(np.sin(2 * np.pi * f * a * (1 + 0.01 * np.sin(20 * a))) * np.exp(-a * 2.5) for f in (587, 740, 932, 1175))
    write_wav(os.path.join(SFX, "enhance.wav"), s * 0.18)
    # hit by shadow (low thud)
    a = t(0.7)
    write_wav(os.path.join(SFX, "caught.wav"), np.sin(2 * np.pi * (90 - 50 * a) * a) * np.exp(-a * 4) * 0.8 + rng.uniform(-1, 1, len(a)) * np.exp(-a * 10) * 0.2)
    # wall break
    a = t(0.5)
    write_wav(os.path.join(SFX, "break.wav"), rng.uniform(-1, 1, len(a)) * np.exp(-a * 8) * 0.6 + np.sin(2 * np.pi * 70 * a) * np.exp(-a * 6) * 0.5)
    # rain loop (filtered noise, 6s, seamless)
    a = t(6.0)
    n = rng.uniform(-1, 1, len(a))
    k = np.ones(6) / 6
    n = np.convolve(n, k, mode="same")
    drops = np.zeros(len(a))
    for _ in range(240):
        p = rng.integers(0, len(a) - 400)
        drops[p:p + 400] += np.sin(2 * np.pi * rng.uniform(2000, 4000) * a[:400]) * np.exp(-a[:400] * 90) * 0.3
    write_wav(os.path.join(SFX, "rain.wav"), (n * 0.5 + drops) * 0.5)
    # wake-up bell
    a = t(2.0)
    s = sum(np.sin(2 * np.pi * f * a) * np.exp(-a * k2) for f, k2 in ((880, 1.5), (1320, 2.2), (1760, 3)))
    write_wav(os.path.join(SFX, "wake.wav"), s * 0.25)


# ================================================================ dream 2: Old Street
# Everything here is generated after the candy assets so that the seeded RNG
# stream of the older generators is untouched.
def _save(img, name):
    img.save(os.path.join(SPR, name))


def st_lamp():
    w, h = 18, 78
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    iron, dark = rgba("#3b3f4a"), rgba("#23252d")
    d.rectangle([6, 24, 11, h - 1], fill=iron)
    d.rectangle([5, h - 8, 12, h - 1], fill=dark)       # base
    d.line([8, 24, 8, h - 9], fill=rgba("#5a5f6e"))
    d.rectangle([3, 18, 14, 24], fill=dark)             # collar
    d.polygon([(2, 18), (15, 18), (13, 4), (4, 4)], fill=rgba("#ffe9a0"), outline=dark)
    d.polygon([(1, 5), (16, 5), (9, 0)], fill=dark)
    d.line([8, 6, 8, 16], fill=rgba("#fff9d6"))
    _save(img, "st_lamp.png")


def st_bench():
    w, h = 110, 70
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wood, wood_d, iron = rgba("#a9794a"), rgba("#6e4a2b"), rgba("#30343e")
    # bench
    for i in range(3):
        d.rectangle([6, 22 + i * 7, 70, 27 + i * 7], fill=wood, outline=wood_d)
    d.rectangle([6, 44, 70, 49], fill=wood, outline=wood_d)
    for x in (10, 62):
        d.rectangle([x, 49, x + 3, h - 1], fill=iron)
        d.rectangle([x, 18, x + 3, 44], fill=iron)
    # a forgotten umbrella leaning on the bench
    d.line([76, 60, 70, 44], fill=rgba("#2a2d4a"), width=2)
    d.arc([66, 36, 80, 50], 180, 360, fill=rgba("#4a5aa0"), width=2)
    # bus stop pole + sign
    d.rectangle([94, 8, 96, h - 1], fill=iron)
    d.rectangle([84, 4, 106, 22], fill=rgba("#2c5fa8"), outline=rgba("#d8e4f4"))
    d.rectangle([88, 8, 102, 11], fill=rgba("#f4f4f4"))
    d.rectangle([88, 14, 98, 17], fill=rgba("#f4f4f4"))
    _save(img, "st_bench.png")


def st_shutter():
    w, h = 48, 66
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=rgba("#4a3a32"))
    for y in range(2, h - 2, 5):
        base = RNG.choice(["#8d5a3b", "#9a6540", "#7d4f35"])
        d.rectangle([2, y, w - 3, y + 3], fill=rgba(base))
        d.line([2, y + 4, w - 3, y + 4], fill=rgba("#2c211c"))
        for _ in range(5):       # rust
            x = RNG.randint(3, w - 5)
            d.point((x, y + RNG.randint(0, 3)), fill=rgba("#c4783a"))
    d.rectangle([w // 2 - 3, h - 12, w // 2 + 3, h - 8], fill=rgba("#222222"))   # handle
    d.rectangle([0, 0, w - 1, 2], fill=rgba("#2a211d"))
    _save(img, "st_shutter.png")


def st_puddle():
    w, h = 52, 20
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([1, 2, w - 2, h - 2], fill=(93, 134, 184, 200), outline=rgba("#a8c8f0")[:3] + (230,))
    d.ellipse([8, 5, w - 14, 10], fill=(200, 225, 255, 150))
    d.arc([14, 7, 26, 15], 0, 360, fill=(255, 255, 255, 150))
    _save(img, "st_puddle.png")


def st_signpost():
    w, h = 50, 62
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    iron = rgba("#2e323c")
    d.rectangle([23, 14, 26, h - 1], fill=iron)
    d.rectangle([2, 2, w - 3, 16], fill=rgba("#e8e2cf"), outline=iron)
    d.rectangle([4, 4, w - 5, 14], outline=rgba("#2c5a3a"))
    for x in range(8, w - 8, 6):
        d.point((x, 9), fill=rgba("#2c5a3a"))
    d.line([24, 30, 14, 36], fill=rgba("#c8b88a"), width=1)   # a rag tied round the post
    _save(img, "st_signpost.png")


def st_window():
    w, h = 30, 26
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=rgba("#3a2e28"))
    d.rectangle([2, 2, w - 3, h - 3], fill=rgba("#ffd27a"))
    d.rectangle([4, 4, w - 5, h - 5], fill=rgba("#ffe9b0"))
    d.line([w // 2, 2, w // 2, h - 3], fill=rgba("#3a2e28"))
    d.line([2, h // 2, w - 3, h // 2], fill=rgba("#3a2e28"))
    # a little radio on the sill
    d.rectangle([5, h - 9, 13, h - 4], fill=rgba("#6b4a2e"))
    d.point((8, h - 7), fill=rgba("#ffcc55"))
    _save(img, "st_window.png")


def st_lightpath():
    w, h = 16, 8
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 1, w - 1, h - 2], 2, fill=(190, 240, 255, 210), outline=(255, 255, 255, 255))
    d.line([2, 3, w - 3, 3], fill=(255, 255, 255, 230))
    _save(img, "st_lightpath.png")


def st_planter():
    w, h = 28, 26
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 12), (24, 12), (21, h - 1), (7, h - 1)], fill=rgba("#c0714a"), outline=rgba("#7a3f26"))
    d.rectangle([3, 9, 25, 13], fill=rgba("#d98a60"), outline=rgba("#7a3f26"))
    for i, c in enumerate(["#4f9a55", "#6bb870", "#3f8248", "#7ccc82"]):
        x = 6 + i * 5
        d.polygon([(x, 10), (x + 4, 10), (x + 2 + (i - 1) * 2, 0)], fill=rgba(c))
    d.point((13, 3), fill=rgba("#ffd0dc"))
    _save(img, "st_planter.png")


def st_fog():
    w, h = 120, 350
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ramp = np.clip(xx / (w * 0.75), 0, 1) ** 1.3
    wob = 0.12 * np.sin(yy / 17.0 + xx / 23.0) + 0.08 * np.sin(yy / 5.0 - xx / 9.0)
    a = np.clip(ramp + wob * ramp, 0, 1) * 235
    img = np.zeros((h, w, 4), np.uint8)
    img[..., 0] = 205
    img[..., 1] = 218
    img[..., 2] = 236
    img[..., 3] = a.astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(SPR, "st_fog.png"))


def street_ground(stage):
    W, H = 1760, 700
    rng = np.random.default_rng({"summer": 1, "fading": 2, "echo": 3}[stage])
    pal = {
        "summer": dict(sky=("#f2a56b", "#6c4a8a"), face="#6b4c46", road="#4c4a55", walk="#d3c4a4", walk2="#bfae8c",
                       grass="#4a7a48", line="#e8c860", alley="#8a7a68", win="#ffd27a"),
        "fading": dict(sky=("#9a94a0", "#4c4a58"), face="#5a5557", road="#4a4a50", walk="#b8b2a4", walk2="#a39d90",
                       grass="#5a6a58", line="#b8b090", alley="#7a756e", win="#c8c4b0"),
        "echo": dict(sky=("#1e2a4a", "#0c1226"), face="#2c3550", road="#262c42", walk="#58607c", walk2="#4c546e",
                     grass="#2a4048", line="#7a88b8", alley="#444c68", win="#9ab8ff"),
    }[stage]

    def col(h):
        h = h.lstrip("#")
        return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)

    img = np.zeros((H, W, 3), np.float32)
    # sky
    for y in range(H):
        k = min(1.0, y / 150.0)
        img[y, :, :] = col(pal["sky"][1]) * (1 - k) + col(pal["sky"][0]) * k
    if stage == "echo":
        for _ in range(90):
            x, y = int(rng.integers(0, W)), int(rng.integers(0, 110))
            img[y, x] = (230, 235, 255)
    # rear facade band
    img[120:300, :, :] = col(pal["face"])
    # alley opening: lighter floor, taller wall
    img[40:300, 1330:1480, :] = col(pal["alley"])
    img[40:90, 1310:1500, :] = col(pal["face"])
    img[90:300, 1310:1330, :] = col(pal["face"]) * 0.8
    img[90:300, 1480:1500, :] = col(pal["face"]) * 0.8
    # pavements, road, south strip, hedge
    img[300:370, :, :] = col(pal["walk"])
    img[370:500, :, :] = col(pal["road"])
    img[500:560, :, :] = col(pal["walk"])
    img[560:700, :, :] = col(pal["grass"])
    img[285:300, :, :] = col(pal["walk2"]) * 0.8
    # texture noise
    n = rng.normal(0, 4.0, (H, W, 1)).astype(np.float32)
    img += n
    # pavement slab lines
    for x in range(0, W, 48):
        img[300:370, x:x + 1, :] *= 0.9
        img[500:560, x:x + 1, :] *= 0.9
    for y in (335, 530):
        img[y:y + 1, :, :] *= 0.9
    img[370:374, :, :] *= 0.8
    img[496:500, :, :] *= 0.8
    # south hedge texture
    hn = rng.normal(0, 9.0, (140, W, 1)).astype(np.float32)
    img[560:700, :, :] += hn
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(out)
    # lit windows on the rear facade
    for x in range(20, W, 62):
        for y in (140, 190, 240):
            if 1300 < x < 1510:
                continue
            on = rng.random() < (0.55 if stage == "summer" else 0.25 if stage == "fading" else 0.4)
            c = pal["win"] if on else "#2a2630"
            d.rectangle([x, y, x + 20, y + 26], fill=c, outline="#1c1a20")
    # road: centre dashes + kerbs
    for x in range(0, W, 70):
        d.rectangle([x, 433, x + 36, 437], fill=pal["line"])
    # alley cobbles
    for y in range(92, 300, 14):
        off = 7 if (y // 14) % 2 else 0
        for x in range(1330 + off, 1480, 14):
            d.rectangle([x, y, x + 12, y + 11], outline=tuple(int(v * 0.8) for v in col(pal["alley"])))
    # echo: wet sheen on the road
    if stage == "echo":
        for _ in range(60):
            x, y = int(rng.integers(0, W - 80)), int(rng.integers(376, 494))
            d.line([x, y, x + int(rng.integers(20, 80)), y], fill=(70, 82, 120))
    # south hedge: a few round bushes
    for _ in range(120):
        x, y = int(rng.integers(-20, W)), int(rng.integers(572, 660))
        r = int(rng.integers(14, 34))
        k = float(rng.uniform(0.62, 1.05))
        d.ellipse([x, y, x + 2 * r, y + int(1.4 * r)], fill=tuple(int(v * k) for v in col(pal["grass"])))
    # the fracture of the fading street
    if stage == "fading":
        fx0, fx1 = 1040, 1120
        rows = []
        jag = rng.integers(-8, 9, 600)
        for y in range(285, 592):
            a = fx0 + int(jag[y - 285])
            b = fx1 + int(jag[(y - 285 + 37) % 300])
            rows.append((y, a, b))
        for y, a, b in rows:
            d.line([a, y, b, y], fill=(14, 10, 24))
        # glow along the edges + a few stars falling in
        for y, a, b in rows[::3]:
            d.point((a - 1, y), fill=(120, 110, 150))
            d.point((b + 1, y), fill=(120, 110, 150))
        for _ in range(40):
            x, y = int(rng.integers(fx0 + 4, fx1 - 4)), int(rng.integers(290, 585))
            d.point((x, y), fill=(200, 200, 255))
    out.save(os.path.join(SPR, f"street_ground_{stage}.png"))


def street_music():
    def rhodes(freq, dur, detune=0.0):
        t = np.arange(int(SR * dur)) / SR
        f = freq * (1 + detune * np.sin(2 * np.pi * 0.5 * t))
        ph = 2 * np.pi * np.cumsum(f) / SR
        env = np.exp(-t * 1.5) * (1 - np.exp(-t * 80))
        return (np.sin(ph) + 0.3 * np.sin(2 * ph) * np.exp(-t * 3) + 0.08 * np.sin(5 * ph) * np.exp(-t * 12)) * env

    # a warm, slightly worn 6/8 tune in A minor
    mel = [69, None, 72, 76, None, 74, 72, None, 69, 67, None, 64,
           65, None, 69, 72, None, 71, 69, None, 67, 64, None, None]
    bass = [45, 41, 43, 45, 40, 41]
    music("street_summer.wav", mel, bass, 92, detune=0.002, tone_fn=rhodes, repeats=2)
    sparse = [n if (n and i % 3 != 2) else None for i, n in enumerate(mel)]
    music("street_fading.wav", sparse, [b - 12 for b in bass], 66, detune=0.012, dark=0.35, tone_fn=rhodes, repeats=2)
    ech = [n - 12 if n and i % 4 == 0 else n for i, n in enumerate(sparse)]
    music("street_echo.wav", ech, [b - 12 for b in bass], 72, detune=0.02, dark=0.6, tone_fn=rhodes, repeats=2, echo=0.55)


def street_main():
    for d in (SPR, MUS):
        os.makedirs(d, exist_ok=True)
    # these five have AI versions (art_src/raw/<name>.png -> process_assets.py);
    # the procedural drawing is only the fallback
    for fn, name in ((st_lamp, "st_lamp"), (st_bench, "st_bench"), (st_shutter, "st_shutter"),
                     (st_signpost, "st_signpost"), (st_planter, "st_planter")):
        if os.path.exists(os.path.join(ROOT, "art_src", "raw", name + ".png")):
            continue
        fn()
    st_puddle(); st_window(); st_lightpath(); st_fog()
    for stage in ("summer", "fading", "echo"):
        street_ground(stage)
    print("street sprites ok")
    street_music()
    print("street music ok")


def main():
    for d in (SPR, MUS, SFX):
        os.makedirs(d, exist_ok=True)
    ground(); cracks(); chocowall(); cake(); schoolbag()
    blob(96, 64, rgba("#d9728c"), rgba("#8e3350"), rgba("#ffd0dc"), "syrup.png", 235, seed=1)
    blob(96, 64, rgba("#bfe9ff"), rgba("#6fa6d6"), rgba("#ffffff"), "sugarglass.png", 200, seed=1)
    gumdrop(); crystal(); photo(); footprint(); lamp(); glitch(); fence()
    town_ground(False); town_ground(True)
    print("sprites ok")
    # C major-ish lullaby (MIDI notes); None = rest
    mel = [72, 76, 79, 76, 77, 74, 71, None, 72, 76, 79, 84, 83, 79, 76, None,
           74, 77, 81, 77, 76, 72, 69, None, 71, 74, 79, 77, 76, 74, 72, None]
    bass = [48, 43, 45, 43, 50, 45, 43, 48]
    music("sweet.wav", mel, bass, 96)
    mel_melt = [n - 1 if n and i % 3 == 0 else n for i, n in enumerate(mel)]
    music("melting.wav", mel_melt, [b - 12 for b in bass], 78, detune=0.012)
    mel_maze = [None if i % 4 == 3 else (n - 3 if n else None) for i, n in enumerate(mel)]
    music("maze.wav", mel_maze, [b - 15 for b in bass], 70, detune=0.02, dark=1.0)
    music("clinic.wav", [67, None, 71, None, 74, None, 71, None, 69, None, 72, None, 76, None, 72, None],
          [43, 45, 47, 45], 84, repeats=2)
    print("music ok")
    sfx()
    print("sfx ok")
    street_main()


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "street":
        street_main()      # only the Old Street assets
    else:
        main()
