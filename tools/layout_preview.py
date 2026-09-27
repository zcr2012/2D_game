#!/usr/bin/env python3
"""Draws the UI boxes measured by tests/platform_test.gd for each screen shape.

    godot --headless --path game res://tests/platform_test.tscn > plat.log
    python3 tools/layout_preview.py plat.log out_dir/
"""
import json
import os
import sys

from PIL import Image, ImageDraw

COLORS = {"hud": (80, 200, 255), "touch": (255, 140, 200), "dialog": (255, 230, 120),
          "button": (160, 255, 170), "panel": (200, 170, 255)}


def main(log, out):
    os.makedirs(out, exist_ok=True)
    for line in open(log, encoding="utf-8"):
        if not line.startswith("LAYOUT "):
            continue
        d = json.loads(line[7:])
        cw, ch = d["canvas"]
        s = 0.5
        for scene in ("title", "dream"):
            img = Image.new("RGB", (int(cw * s), int(ch * s)), (40, 30, 60))
            dr = ImageDraw.Draw(img)
            for b in d["boxes"]:
                if (scene == "title") != (b["scene"] == "title"):
                    continue
                if b["scene"] == "panel" and b["kind"] != "editor":
                    continue
                x, y, w, h = [v * s for v in b["r"]]
                c = COLORS.get(b["kind"], COLORS["panel"])
                if b["kind"] == "touch":
                    dr.ellipse([x, y, x + w, y + h], outline=c, width=2)
                else:
                    dr.rectangle([x, y, x + w, y + h], outline=c, width=2)
            dr.text((6, int(ch * s) - 16), f'{d["name"]}  canvas {cw:.0f}x{ch:.0f}', fill=(255, 255, 255))
            name = d["name"].split()[0].replace(":", "")
            img.save(os.path.join(out, f"{scene}_{name}.png"))
    print("wrote", out)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "layout_preview")
