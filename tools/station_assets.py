#!/usr/bin/env python3
"""Reproducible station floors, soft sci-fi props and three music loops.
AI characters/dome use process_assets.py; this script never touches them.
1920x1000 geometry matches station_map.gd. Pixel edges and alpha are hard.
Usage: python3 tools/station_assets.py  (requires pillow, numpy)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw
from procedural_assets import MUS, SPR, music


def sprite(name, size, painter):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    painter(ImageDraw.Draw(im))
    im.save(os.path.join(SPR, name + ".png"))


def floor(stage):
    rng = random.Random(1208)
    w, h = 960, 500
    im = Image.new("RGB", (w, h), "#0c1531" if stage != "genesis" else "#201638")
    d = ImageDraw.Draw(im)
    # Quiet star field beyond the glass. Big shapes, very little visual noise.
    for _ in range(290):
        x, y = rng.randrange(w), rng.randrange(h)
        c = rng.choice(["#42607e", "#7e97bc", "#d9e8ef", "#bfa4cd"])
        d.point((x, y), fill=c)
        if rng.random() < 0.08:
            d.line((x - 2, y, x + 2, y), fill=c)
            d.line((x, y - 2, x, y + 2), fill=c)
    # Earth in the window: a stylised, friendly blue planet.
    d.ellipse((802, -60, 1030, 136), fill="#4a85b8", outline="#8abdd6", width=3)
    d.ellipse((814, -53, 1025, 127), fill="#2c689a")
    d.polygon([(850, 0), (889, 5), (921, 39), (897, 57), (916, 80), (879, 66), (862, 34)], fill="#7dadb0")
    for y in (14, 78, 100):
        d.arc((810, y - 30, 1015, y + 40), 175, 330, fill="#c4dfde", width=3)
    panel = {"orbit": "#596c86", "drift": "#645b83", "genesis": "#646085"}[stage]
    edge = {"orbit": "#82c5d7", "drift": "#bc98e1", "genesis": "#b994ca"}[stage]
    d.rounded_rectangle((30, 138, 930, 443), radius=20, fill="#131e3a", outline=edge, width=2)
    d.rectangle((31, 147, 928, 435), fill=panel)
    # Floor panels, bevel shading, path bands. All remain visible at night.
    for y in range(147, 435, 24):
        for x in range(32, 930, 32):
            d.rectangle((x + 1, y + 1, x + 30, y + 22), fill=panel, outline="#414963")
            d.line((x + 2, y + 2, x + 28, y + 2), fill="#78809b")
            if (x // 32 + y // 24) % 5 == 0:
                d.rectangle((x + 13, y + 10, x + 17, y + 12), fill="#7d91ad")
    for y in (268, 280):
        d.line((50, y, 909, y), fill=edge, width=2)
    for x in range(62, 914, 40):
        d.line((x, 274, x + 15, 274), fill="#dde3ec", width=1)
    # Top window rail / bottom light rail.
    for y in (139, 435):
        d.line((33, y, 928, y), fill="#b6c7d4", width=3)
        for x in range(50, 925, 39):
            d.rectangle((x, y - 1, x + 8, y + 1), fill="#8ce4e6")
    # The seed vault is a genuinely accessible northern room, not just a prop.
    d.rectangle((260, 50, 390, 140), fill="#495b72", outline="#93bac6", width=2)
    for y in range(52, 138, 14):
        d.line((262, y, 388, y), fill="#697c8b")
    for x in (270, 377):
        d.line((x, 50, x, 133), fill="#a0bdd1", width=2)
    d.rectangle((271, 59, 292, 109), fill="#303e60")
    d.rectangle((355, 59, 377, 109), fill="#303e60")
    if stage == "drift":
        # Exactly x890..1030, y280..870: the collision gap in StationMap.
        d.rectangle((445, 140, 514, 434), fill="#10132c")
        for y in range(147, 435, 12):
            d.line((443, y, 448, y + 4), fill="#d9b8e8", width=2)
            d.line((512, y + 3, 517, y), fill="#d9b8e8", width=2)
        for _ in range(44):
            x, y = rng.randint(449, 510), rng.randint(148, 428)
            d.point((x, y), fill="#91afd7")
        for x, y in [(84, 329), (285, 360), (597, 169), (738, 373)]:
            d.ellipse((x, y, x + 34, y + 12), fill="#333048", outline="#a695c9")
    if stage == "genesis":
        for y in range(15, 124, 12):
            points = [(x, y + int(math.sin(x / 43 + y / 15) * 5)) for x in range(0, 810, 2)]
            d.line(points, fill="#6e5988" if y % 24 else "#8466a3", width=2)
        for _ in range(36):
            x, y = rng.randint(43, 916), rng.randint(158, 417)
            d.ellipse((x, y, x + 5, y + 2), fill="#b896c9")
        # Tomorrow chamber threshold: align with x1580.
        d.line((790, 142, 790, 434), fill="#caa3e3", width=2)
        for y in range(155, 426, 23):
            d.rectangle((824, y, 904, y + 12), outline="#879fb4")
    im.resize((1920, 1000), Image.Resampling.NEAREST).save(os.path.join(SPR, f"station_ground_{stage}.png"))


def props():
    navy, cyan, cream, shadow = "#1b284c", "#8de5e6", "#e5e7ee", "#6f819c"

    def console(d):
        d.rounded_rectangle((4, 22, 72, 65), 5, fill=shadow, outline=navy, width=2)
        d.polygon([(4, 22), (17, 8), (64, 8), (72, 22)], fill=cream, outline=navy)
        d.rounded_rectangle((14, 25, 63, 49), 3, fill=navy, outline=cyan, width=2)
        for x in (22, 34, 46):
            d.line((x, 37, x + 6, 37), fill=cyan, width=2)
        d.rectangle((15, 56, 57, 60), fill="#495877")
        d.ellipse((61, 55, 65, 59), fill="#edba70")
    sprite("sp_console", (76, 70), console)

    def pod(d):
        d.rounded_rectangle((8, 3, 68, 107), 22, fill=cream, outline=navy, width=2)
        d.rounded_rectangle((16, 13, 60, 82), 16, fill="#3d5b82", outline=shadow, width=2)
        d.line((23, 28, 23, 63), fill="#94bccd", width=3)
        d.rectangle((28, 92, 49, 98), fill=cyan)
    sprite("sp_pod", (76, 112), pod)

    def greenhouse(d):
        d.rounded_rectangle((5, 28, 155, 94), 14, fill=shadow, outline=navy, width=2)
        d.pieslice((5, 0, 155, 125), 180, 360, fill="#88bbc8", outline=navy, width=2)
        for x in (36, 80, 124):
            d.line((x, 9, x, 61), fill=cream, width=2)
        d.rectangle((31, 48, 131, 69), fill="#415e70", outline=navy)
        for x in (40, 68, 101, 123):
            d.line((x, 57, x, 28), fill="#d2dbbf", width=2)
            d.ellipse((x - 7, 27, x + 7, 37), fill="#b2d8c2", outline="#6890a7")
            d.ellipse((x - 3, 22, x + 3, 29), fill="#efcb83")
        d.rounded_rectangle((65, 68, 96, 96), 3, fill=navy, outline=cyan, width=2)
    sprite("sp_greenhouse", (162, 100), greenhouse)

    def clock(d):
        d.rectangle((18, 47, 29, 71), fill=shadow, outline=navy, width=2)
        d.ellipse((3, 3, 44, 49), fill=cream, outline=navy, width=2)
        d.ellipse((8, 8, 39, 44), fill=navy, outline=cyan, width=2)
        d.line((23, 12, 23, 27, 33, 27), fill="#edba70", width=2)
        d.ellipse((19, 23, 27, 31), fill=cream)
    sprite("sp_clock", (48, 76), clock)

    def chart(d):
        d.polygon([(7, 60), (65, 60), (75, 78), (0, 78)], fill=shadow, outline=navy)
        d.rounded_rectangle((5, 3, 70, 61), 5, fill=navy, outline="#b997df", width=2)
        pts = [(15, 39), (31, 22), (50, 32), (60, 14)]
        d.line(pts, fill=cyan, width=1)
        for x, y in pts:
            d.line((x - 3, y, x + 3, y), fill=cream)
            d.line((x, y - 3, x, y + 3), fill=cream)
    sprite("sp_chart", (78, 82), chart)

    def terminal(d):
        d.rounded_rectangle((3, 3, 41, 45), 6, fill=cream, outline=navy, width=2)
        d.rectangle((8, 10, 36, 30), fill=navy, outline=cyan)
        d.line((14, 20, 17, 17, 23, 24, 29, 17), fill=cyan, width=2)
        d.rectangle((16, 46, 28, 57), fill=shadow, outline=navy)
        d.line((8, 58, 37, 58), fill=navy, width=3)
    sprite("sp_terminal", (46, 62), terminal)

    def planter(d):
        d.polygon([(5, 29), (38, 29), (33, 47), (10, 47)], fill=shadow, outline=navy)
        d.ellipse((5, 24, 38, 33), fill=navy, outline=cream)
        d.line((22, 27, 22, 9), fill="#a6d2c0", width=2)
        d.ellipse((9, 10, 22, 18), fill="#b2d8c2", outline="#608498")
        d.ellipse((22, 6, 34, 14), fill="#b2d8c2", outline="#608498")
        d.ellipse((18, 1, 25, 8), fill="#ffe0a4", outline="#c39c68")
    sprite("sp_planter", (44, 50), planter)

    def gate(d):
        d.rectangle((2, 2, 66, 48), fill=shadow, outline=navy, width=2)
        for x in range(8, 62, 9):
            d.line((x, 5, x, 46), fill=cream, width=2)
        d.line((25, 4, 33, 19, 28, 26, 43, 46), fill="#efb385", width=3)
    sprite("sp_gate", (70, 52), gate)

    def hatch(d):
        d.rounded_rectangle((2, 2, 29, 587), 8, fill=navy, outline="#8eced6", width=2)
        for y in range(8, 580, 12):
            d.line((10, y, 21, y + 5), fill="#ba9edf", width=2)
        d.rectangle((8, 280, 23, 311), fill="#edc881", outline=cream)
    sprite("sp_hatch", (32, 590), hatch)

    def bridge(d):
        d.polygon([(1, 18), (18, 18), (17, 24), (2, 24)], fill="#715d9b", outline=navy)
        d.polygon([(1, 18), (4, 4), (17, 4), (18, 18)], fill="#c5c0e9", outline=cyan)
        d.line((6, 9, 13, 9), fill=cream, width=2)
    sprite("sp_bridge", (20, 28), bridge)

    def water(d):
        d.ellipse((2, 9, 77, 32), fill="#425f87", outline="#9dcbdd", width=2)
        d.line((14, 18, 63, 18), fill="#94bdd7", width=1)
        d.line((30, 24, 70, 24), fill="#7189b8", width=1)
    sprite("sp_condensate", (80, 36), water)

    def beacon(d):
        d.rectangle((6, 16, 16, 40), fill=shadow, outline=navy)
        d.ellipse((2, 2, 20, 20), fill=cream, outline=navy)
        d.ellipse((6, 6, 16, 16), fill=cyan)
    sprite("sp_beacon", (24, 44), beacon)

    def bot(d, repair=False):
        d.ellipse((3, 5, 37, 38), fill=cream, outline=navy, width=2)
        d.rounded_rectangle((7, 12, 33, 25), 4, fill=navy)
        d.rectangle((12, 17, 15, 20), fill=cyan)
        d.rectangle((25, 17, 28, 20), fill=cyan)
        d.line((15, 29, 25, 29), fill="#efa67f" if repair else cyan, width=2)
        d.ellipse((8, 35, 16, 43), fill=shadow, outline=navy)
        d.ellipse((24, 35, 32, 43), fill=shadow, outline=navy)
        if repair:
            d.line((20, 0, 20, 5), fill="#edba70", width=2)
        else:
            d.line((20, 0, 20, 7), fill="#b7d7c0", width=2)
            d.ellipse((20, 0, 27, 4), fill="#b7d7c0")
    sprite("sp_bot", (42, 46), bot)
    sprite("sp_drone", (42, 46), lambda d: bot(d, True))

    def seedbox(d):
        d.rounded_rectangle((2, 6, 34, 27), 4, fill="#d6b987", outline=navy, width=2)
        d.rectangle((12, 9, 23, 18), fill=cream, outline=shadow)
        d.ellipse((15, 11, 20, 16), fill="#a1bfb3")
    sprite("sp_seedbox", (38, 32), seedbox)

    def starflower(d):
        d.ellipse((3, 51, 71, 67), fill="#685591", outline="#af9cd8")
        d.line((38, 50, 38, 21), fill=cyan, width=3)
        d.ellipse((15, 29, 38, 42), fill="#93c5d4", outline=navy)
        d.ellipse((38, 21, 59, 34), fill="#bcb1e2", outline=navy)
        d.polygon([(38, 2), (43, 13), (55, 14), (46, 22), (49, 34), (38, 28), (26, 34), (29, 22), (19, 14), (32, 13)], fill="#ffe2a6", outline="#b69b86")
    sprite("sp_starflower", (76, 72), starflower)

    def island(d):
        d.polygon([(5, 41), (41, 67), (82, 41)], fill="#5b4d8d", outline=navy)
        d.ellipse((4, 21, 82, 49), fill="#acb8d0", outline=cyan, width=2)
        d.polygon([(24, 34), (42, 16), (60, 34)], fill=cream, outline=navy)
        d.rectangle((28, 34, 56, 43), fill=shadow, outline=navy)
        d.line((43, 2, 43, 16), fill="#e1bd89", width=2)
        d.polygon([(44, 3), (60, 5), (44, 10)], fill="#e1bd89")
    sprite("sp_island", (88, 72), island)

    def books(d):
        d.ellipse((2, 52, 78, 68), fill="#604e86", outline="#b0a3d5")
        for x, y, c in [(12, 30, "#95ced7"), (42, 25, "#e1bc86"), (28, 7, "#b8a3dc")]:
            d.rectangle((x, y, x + 19, y + 24), fill=c, outline=navy, width=2)
            d.line((x + 5, y + 4, x + 5, y + 20), fill=cream)
        d.line((22, 10, 10, 18), fill=cyan, width=1)
        d.line((60, 3, 71, 14), fill="#d2a3e9", width=2)
    sprite("sp_books", (82, 74), books)


def soundtrack():
    def bell(freq, dur, detune=0):
        t = np.arange(int(22050 * dur)) / 22050
        phase = 2 * math.pi * freq * t + detune * np.sin(t * 2)
        envelope = (1 - np.exp(-t * 45)) * np.exp(-t * 1.9)
        return (np.sin(phase) + 0.18 * np.sin(phase * 2) + 0.04 * np.sin(phase * 3)) * envelope
    melody = [74, None, 78, 81, 83, None, 81, 78, 76, None, 74, None, 78, 81, 86, None,
              83, None, 81, 78, 76, None, 74, None]
    bass = [50, 57, 54, 55, 57, 50]
    music("station_orbit.wav", melody, bass, 88, tone_fn=bell, repeats=2, echo=0.32)
    drift = [n + 7 if n and i % 5 == 0 else n for i, n in enumerate(melody)]
    music("station_drift.wav", drift, bass, 82, detune=0.004, tone_fn=bell, repeats=2, echo=0.46)
    music("station_genesis.wav", [n + 12 if n and i % 3 == 0 else n for i, n in enumerate(melody)],
          [50, 55, 57, 54, 55, 50], 94, tone_fn=bell, repeats=2, echo=0.55)


def main():
    for folder in (SPR, MUS):
        os.makedirs(folder, exist_ok=True)
    props()
    for stage in ("orbit", "drift", "genesis"):
        floor(stage)
    soundtrack()
    print("station: 18 props, 3 floors (1920x1000), 3 music loops generated")


if __name__ == "__main__":
    main()
