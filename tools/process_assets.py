#!/usr/bin/env python3
"""
Dream Repair — AI art post-processing pipeline.

Takes the raw AI-generated images in art_src/raw/ (rendered on a flat
#00FF00 chroma background) and produces game-ready sprites:

  1. Chroma key   : soft alpha from "greenness" (g - max(r, b)), so enclosed
                    background pockets (e.g. between a lollipop's stick and
                    candies) are removed too, not only edge-connected ones.
  2. Despill      : clamps green spill on anti-aliased edges.
  3. Auto-crop    : trims to the opaque bounding box.
  4. Scale        : downsamples to the target world height (pixel-art look,
                    nearest-filtered in Godot), hard-thresholds alpha.
  5. Palette      : optional colour quantisation for a crisper pixel look.
  6. Portrait     : characters also get a large upper-body dialogue portrait.

Usage:  python3 tools/process_assets.py            (process everything)
        python3 tools/process_assets.py player bear (only listed assets)
Requires: pillow, numpy
"""
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "art_src", "raw")
OUT_SPRITES = os.path.join(ROOT, "game", "assets", "sprites")
OUT_PORTRAITS = os.path.join(ROOT, "game", "assets", "portraits")

# name: (target world height in px, palette colours or 0, make portrait?, portrait crop ratio)
ASSETS = {
    # characters (pixel art)
    "player":       (52, 48, True, 0.55),
    "duoduo":       (42, 48, True, 0.55),
    "bear":         (42, 40, True, 0.60),
    "xiaomian":     (28, 32, True, 1.00),
    "tangxin":      (64, 48, True, 0.60),
    "shadow":       (76, 24, False, 0.5),
    # props (pre-rendered "3D" look, downsampled)
    "house":        (150, 64, False, 0),
    "house_melted": (150, 64, False, 0),
    "clocktower":   (250, 64, False, 0),
    "lollipop":     (92, 48, False, 0),
    "carousel":     (130, 64, False, 0),
}

# Tiles: stretched to an exact size and made fully opaque, so neighbouring
# blocks join without seams.  name: (width, height, palette colours)
TILES = {
    "chocowall":    (48, 64, 32),          # maze wall block; procedural fallback exists
}

KEY_LO = 40    # greenness below this -> fully opaque
KEY_HI = 120   # greenness above this -> fully transparent


def chroma_key(img: Image.Image) -> Image.Image:
    a = np.asarray(img.convert("RGB")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip((KEY_HI - greenness) / float(KEY_HI - KEY_LO), 0.0, 1.0)
    # despill: never let green exceed the brighter of red/blue on kept pixels
    g2 = np.where(greenness > 0, np.maximum(r, b), g)
    out = np.dstack([r, g2, b, (alpha * 255).astype(np.int32)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def clean_islands(img: Image.Image, min_ratio=0.0015) -> Image.Image:
    """Remove tiny stray opaque specks (JPEG-ish noise in the background)."""
    a = np.asarray(img).copy()
    mask = a[..., 3] > 128
    h, w = mask.shape
    seen = np.zeros_like(mask)
    min_px = int(h * w * min_ratio)
    for y0 in range(0, h, 1):
        row = mask[y0] & ~seen[y0]
        if not row.any():
            continue
        for x0 in np.nonzero(row)[0]:
            if seen[y0, x0]:
                continue
            stack = [(y0, x0)]
            seen[y0, x0] = True
            comp = []
            while stack:
                y, x = stack.pop()
                comp.append((y, x))
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(comp) < min_px:
                ys, xs = zip(*comp)
                a[list(ys), list(xs), 3] = 0
    return Image.fromarray(a, "RGBA")


def autocrop(img: Image.Image, pad=2) -> Image.Image:
    alpha = np.asarray(img)[..., 3]
    ys, xs = np.nonzero(alpha > 24)
    if len(xs) == 0:
        return img
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, img.width)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, img.height)
    return img.crop((x0, y0, x1, y1))


def to_pixel(img: Image.Image, height: int, colors: int) -> Image.Image:
    w = max(1, round(img.width * height / img.height))
    small = img.resize((w, height), Image.LANCZOS)
    arr = np.asarray(small).copy()
    # hard alpha edges = crisp pixel silhouette
    arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
    small = Image.fromarray(arr, "RGBA")
    if colors:
        rgb = small.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE)
        rgb = rgb.convert("RGB")
        out = np.dstack([np.asarray(rgb), arr[..., 3]])
        small = Image.fromarray(out.astype(np.uint8), "RGBA")
    return small


def portrait(img: Image.Image, ratio: float, size=300) -> Image.Image:
    crop = img.crop((0, 0, img.width, max(1, int(img.height * ratio))))
    crop = autocrop(crop, pad=4)
    scale = size / max(crop.width, crop.height)
    return crop.resize((max(1, int(crop.width * scale)), max(1, int(crop.height * scale))), Image.LANCZOS)


def process_tile(name: str) -> bool:
    src = os.path.join(RAW, name + ".png")
    if not os.path.exists(src):
        print(f"  - skip {name} (no raw image)")
        return False
    w, h, colors = TILES[name]
    keyed = autocrop(clean_islands(chroma_key(Image.open(src))), pad=0)
    small = keyed.resize((w, h), Image.LANCZOS)
    arr = np.asarray(small).astype(np.int32)
    solid = arr[..., 3] > 110
    # transparent corner pixels -> darkest opaque colour (a clean outline)
    dark = arr[solid][:, :3]
    dark = dark[np.argsort(dark.sum(axis=1))[: max(1, len(dark) // 50)]].mean(axis=0)
    arr[~solid, :3] = dark.astype(np.int32)
    arr[..., 3] = 255
    rgb = Image.fromarray(arr[..., :3].astype(np.uint8), "RGB")
    if colors:
        rgb = rgb.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    rgb.convert("RGBA").save(os.path.join(OUT_SPRITES, name + ".png"))
    print(f"  + {name}: tile {w}x{h}")
    return True


def process(name: str) -> bool:
    if name in TILES:
        return process_tile(name)
    src = os.path.join(RAW, name + ".png")
    if not os.path.exists(src):
        print(f"  - skip {name} (no raw image)")
        return False
    height, colors, make_portrait, pr = ASSETS[name]
    keyed = autocrop(clean_islands(chroma_key(Image.open(src))))
    sprite = to_pixel(keyed, height, colors)
    sprite.save(os.path.join(OUT_SPRITES, name + ".png"))
    msg = f"  + {name}: sprite {sprite.size}"
    if make_portrait:
        p = portrait(keyed, pr)
        p.save(os.path.join(OUT_PORTRAITS, name + ".png"))
        msg += f", portrait {p.size}"
    print(msg)
    return True


def main():
    os.makedirs(OUT_SPRITES, exist_ok=True)
    os.makedirs(OUT_PORTRAITS, exist_ok=True)
    names = sys.argv[1:] or list(ASSETS) + list(TILES)
    for n in names:
        if n not in ASSETS and n not in TILES:
            print(f"  ! unknown asset {n}")
            continue
        process(n)


if __name__ == "__main__":
    main()
