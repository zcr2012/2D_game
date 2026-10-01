#!/usr/bin/env python3
"""Xiaomian (小眠) voice-over pipeline.

  python3 tools/xm_voice.py manifest     # scan the game, write art_src/xm_lines.json
  python3 tools/xm_voice.py chunks       # write the still-missing TTS batches to art_src/voice_work/chunk_NN.txt
  python3 tools/xm_voice.py split        # cut art_src/voice_work/chunk_NN.* into game/assets/audio/voice/xm_<id>.mp3
  python3 tools/xm_voice.py check        # every line in the manifest has an mp3

Every fixed line Xiaomian says gets the clip  xm_<md5(text)[:10]>.mp3 ; the
game computes the same id (Audio.xm_id). Texts that differ per device (key
names) are voiced device-neutral: Plat.speech_of() strips the key names.
Lines produced live by an AI provider cannot be recorded; they stay text-only.
"""
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "game", "scripts")
VOICE_DIR = os.path.join(ROOT, "game", "assets", "audio", "voice")
WORK = os.path.join(ROOT, "art_src", "voice_work")
MANIFEST = os.path.join(ROOT, "art_src", "xm_lines.json")
STORIES = ["story.gd", "story_street.gd", "story_station.gd", "clinic.gd"]
LIT = r'"((?:[^"\\]|\\.)*)"'
CJK = re.compile(r"[\u4e00-\u9fff]")


def lit(s):
    return json.loads('"' + s + '"')


def norm(t):
    t = re.sub(r"\[[^\]]*\]", "", t)
    return re.sub(r"[ \n\t\r\u3000]", "", t)


def line_id(t):
    return "xm_" + hashlib.md5(norm(t).encode("utf-8")).hexdigest()[:10]


def read(name):
    with open(os.path.join(SCRIPTS, name), encoding="utf-8") as f:
        return f.read()


def func_body(src, name):
    m = re.search(r"^func %s\(.*?\n(?=^func |^# =====|\Z)" % name, src, re.S | re.M)
    return m.group(0) if m else ""


def speak(t):
    """What the TTS reads (keeps the key text; only smooths symbols)."""
    t = re.sub(r"\[[^\]]*\]", "", t)
    t = t.replace("（", "，").replace("）", "，").replace("『", "").replace("』", "")
    t = t.replace("……", "，").replace("…", "，").replace("——", "，").replace("·", "，")
    t = t.replace("\n", "")
    t = re.sub(r"，[、，]+", lambda m: m.group(0)[1:] if m.group(0)[1] == "、" else "，", t)
    t = re.sub(r"，+", "，", t)
    t = re.sub(r"([！？。])，", r"\1", t)
    return t.strip("，")


def collect():
    out = {}

    def add(text, src):
        text = text.strip()
        if not speak(text) or not re.search(r"[\u4e00-\u9fffA-Za-z0-9]", speak(text).replace("%s", "")):
            return
        # composite hints are recorded in pieces (see Dialog._xm_ids)
        for marker in (" 还差：", " 另外，"):
            i = text.find(marker)
            if i > 0:
                add(text[:i], src)
                add(text[i + 1:], src)
                return
        prio = 0 if "controls" in src else 1 if src.startswith("clinic") else 3 if "prefix" in src else \
            4 if "residue" in src else 5 if ("hint" in src or "tip" in src or "echo" in src) else 2
        out.setdefault(line_id(text), {"key": text, "speak": speak(text), "src": src, "prio": prio})

    for name in STORIES:
        src = read(name)
        # direct lines / questions asked by Xiaomian
        for m in re.finditer(r'Dialog\.(?:say|choose)\("xm",\s*' + LIT + r'(\s*%\s*Plat\.(?:press|k)\("editor"\))?(\s*\+)?', src):
            text = lit(m.group(1))
            if m.group(3) or "%d" in text:
                continue
            add(text.replace("%s", "") if m.group(2) else text, name)
        # the status panel prefixes
        for m in re.finditer(r'"(?:naive|warm|doubt|curious)":\s*' + LIT, src):
            add(lit(m.group(1)), name + ":prefix")
        for m in re.finditer(r'_set_speech\(' + LIT, src):
            add(lit(m.group(1)), name + ":panel")
        # lists of lines
        for fn in ("residue_lines", "_between_line", "current_hint"):
            for body in re.findall(r"^func %s\(.*?\n(?=^func |^# =====|\Z)" % fn, src, re.S | re.M):
                for line in body.splitlines():
                    if re.search(r"left\.append|\bs \+=|var s :=|GS\.flag\(|d\.nodes\.has\(|for k in", line) and "return" not in line:
                        continue
                    for m in re.finditer(LIT, line):
                        t = lit(m.group(1))
                        if len(CJK.findall(t)) < 6 or "%d" in t:
                            continue
                        if t.startswith(("glitch_",)):
                            continue
                        t = t.replace("%s", "")
                        add(t, name + ":" + fn)
    # composite hints
    cs = read("story.gd")
    base = re.search(r'var s := ' + LIT, func_body(cs, "current_hint")).group(1)
    base = lit(base)
    add(base, "story.gd:hint")
    add(base + " 另外，疯狂梦境下，东北角的房间里好像有声音。", "story.gd:hint")
    ss = read("story_street.gd")
    body = func_body(ss, "current_hint")
    base = lit(re.search(r'var s := ' + LIT, body).group(1))
    parts = [("夜晚·去找老灯",), ("悲伤·街中间的积水",), ("疯狂·路牌", "疯狂·路牌（先去修理铺找恐惧碎片）")]
    for mask in range(1, 8):
        chosen = [parts[i] for i in range(3) if mask >> i & 1]
        variants = [[]]
        for p in chosen:
            variants = [v + [alt] for v in variants for alt in p]
        for v in variants:
            add(base + " 还差：" + "、".join(v) + "。", "story_street.gd:hint")
    add(base, "story_street.gd:hint")
    for n in range(3):
        add("三个回声，已经找到了%d个。" % n, "story_street.gd:echo")
    add("小提示。", "story_street.gd:tip")
    # controls tips for every device
    pf = read("../autoload/platform.gd")
    body = func_body(pf, "controls_intro")
    for m in re.finditer(r'return ' + LIT, body):
        add(lit(m.group(1)), "platform.gd:controls")
    # ending remarks
    en = read("ending.gd")
    for m in re.finditer(r'return "[^"]*?『([^』]*)』"', func_body(en, "_xm_line")):
        add(m.group(1), "ending.gd")
    return out


def cmd_manifest():
    lines = collect()
    items = sorted((dict(id=k, **v) for k, v in lines.items()), key=lambda i: i["prio"])
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, indent=1)
    chars = sum(len(i["speak"]) for i in items)
    print("%d lines, %d characters -> %s" % (len(items), chars, MANIFEST))


def load():
    with open(MANIFEST, encoding="utf-8") as f:
        return json.load(f)


def cmd_chunks(limit=54):
    os.makedirs(WORK, exist_ok=True)
    # The speech service refuses batches longer than ~18 s of audio (about 60
    # characters), so each batch is a handful of short lines.
    for f in os.listdir(WORK):
        if f.startswith("chunk_"):
            os.remove(os.path.join(WORK, f))
    items = [i for i in load() if not os.path.exists(os.path.join(VOICE_DIR, i["id"] + ".mp3"))]
    def spoken(i):
        return i["speak"] if i["speak"][-1] in "。！？～" else i["speak"] + "。"

    # first-fit decreasing inside each priority group keeps the playing order
    # of importance but fills every batch up to the service limit
    chunks = []
    for band in ((0, 1, 2), (3, 4), (5,)):
        bins = []
        for it in sorted((i for i in items if i["prio"] in band), key=lambda i: (i["prio"] if band[0] == 0 and i["prio"] < 2 else 2, -len(spoken(i)))):
            n = len(spoken(it))
            for b in bins:
                if len(b["items"]) < 6 and b["size"] + n + 1 <= limit:
                    b["items"].append(it)
                    b["size"] += n + 1
                    break
            else:
                bins.append({"items": [it], "size": n})
        chunks += [b["items"] for b in bins]
    for n, ch in enumerate(chunks):
        with open(os.path.join(WORK, "chunk_%02d.json" % n), "w", encoding="utf-8") as f:
            json.dump(ch, f, ensure_ascii=False, indent=1)
        with open(os.path.join(WORK, "chunk_%02d.txt" % n), "w", encoding="utf-8") as f:
            f.write("\n".join(spoken(i) for i in ch))
        print("chunk_%02d: %d lines, %d chars" % (n, len(ch), sum(len(i["speak"]) for i in ch)))


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path):
    import numpy as np
    raw = subprocess.run([ffmpeg(), "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-ar", "24000", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<i2").astype("float32") / 32768.0, 24000


def silences(x, sr, frame=0.01):
    import numpy as np
    n = int(sr * frame)
    env = np.sqrt(np.convolve(x[: len(x) // n * n].reshape(-1, n) ** 2 @ np.ones(n) / n, np.ones(3) / 3, "same"))
    thr = max(0.004, float(np.percentile(env, 90)) * 0.045)
    quiet = env < thr
    runs, start = [], None
    for i, q in enumerate(quiet):
        if q and start is None:
            start = i
        if not q and start is not None:
            runs.append((start * frame, i * frame))
            start = None
    if start is not None:
        runs.append((start * frame, len(quiet) * frame))
    return runs, len(x) / sr


def cmd_split():
    import numpy as np
    for jpath in sorted(f for f in os.listdir(WORK) if f.endswith(".json")):
        base = jpath[:-5]
        audio = next((os.path.join(WORK, base + e) for e in (".mp3", ".wav", ".m4a") if os.path.exists(os.path.join(WORK, base + e))), None)
        if audio is None:
            continue
        with open(os.path.join(WORK, jpath), encoding="utf-8") as f:
            items = json.load(f)
        x, sr = decode(audio)
        runs, total = silences(x, sr)
        runs = [r for r in runs if r[0] > 0.2 and r[1] < total - 0.05]
        # the N-1 longest pauses separate the N lines
        cuts = sorted(sorted(runs, key=lambda r: r[1] - r[0], reverse=True)[: len(items) - 1])
        print(base, "lines", len(items), "pauses", len(runs), "audio %.1fs" % total)
        if len(cuts) != len(items) - 1:
            print("  !! not enough pauses; skip", base)
            continue
        bounds = [0.0] + [(a + b) / 2 for a, b in cuts] + [total]
        chars = np.array([len(i["speak"]) + 8 for i in items], dtype=float)
        got = np.diff(bounds)
        ratio = got / chars
        bad = [i for i in range(len(items)) if ratio[i] < 0.5 * np.median(ratio) or ratio[i] > 2.0 * np.median(ratio)]
        if bad:
            print("  !! suspicious durations for lines", bad, "-> skip; retry with a different split")
            continue
        os.makedirs(VOICE_DIR, exist_ok=True)
        for it, a, b in zip(items, bounds[:-1], bounds[1:]):
            seg = x[int(a * sr): int(b * sr)].copy()
            loud = np.where(np.abs(seg) > 0.02)[0]
            if len(loud) == 0:
                print("  !! silent segment for", it["id"])
                continue
            seg = seg[max(0, loud[0] - int(0.08 * sr)): loud[-1] + int(0.20 * sr)]
            fi, fo = int(0.01 * sr), min(len(seg), int(0.08 * sr))
            seg[:fi] *= np.linspace(0, 1, fi)
            seg[-fo:] *= np.linspace(1, 0, fo)
            pcm = (np.clip(seg, -1, 1) * 32767).astype("<i2").tobytes()
            out = os.path.join(VOICE_DIR, it["id"] + ".mp3")
            subprocess.run([ffmpeg(), "-v", "error", "-y", "-f", "s16le", "-ar", str(sr), "-ac", "1", "-i", "-",
                            "-b:a", "40k", out], input=pcm, check=True)
        print("  cut", len(items), "clips")


def cmd_check():
    missing = [i for i in load() if not os.path.exists(os.path.join(VOICE_DIR, i["id"] + ".mp3"))]
    print("%d / %d lines missing" % (len(missing), len(load())))
    for i in missing[:40]:
        print("  ", i["id"], i["key"])
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    {"manifest": cmd_manifest, "chunks": cmd_chunks, "split": cmd_split, "check": cmd_check}[sys.argv[1] if len(sys.argv) > 1 else "manifest"]()
