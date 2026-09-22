#!/usr/bin/env python3
"""crop.py — cut a region out of a screenshot, optionally enlarged.

Coordinates are IMAGE pixels (Obsidian screenshots are 2x on Retina).
A negative X or Y counts from the right or bottom edge; a W or H of 0
runs to that edge.

    scripts/crop.py IN OUT X Y W H [--zoom N]

    scripts/crop.py shot.png bar.png 0 -80 0 0 --zoom 3   # bottom 80 px, 3x
    scripts/crop.py shot.png top.png 0 0 0 300            # top 300 px

(`sips -c` crops around the centre, which is why this exists.)
Needs PIL: if `python3` lacks it, run with a python3 that has it
(`pil_python` in scripts/lib-obsidian.sh finds one).
"""
import argparse

from PIL import Image


def main():
    p = argparse.ArgumentParser(description="Crop (and optionally zoom) a screenshot.")
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("x", type=int)
    p.add_argument("y", type=int)
    p.add_argument("w", type=int)
    p.add_argument("h", type=int)
    p.add_argument("--zoom", type=float, default=1.0)
    a = p.parse_args()

    im = Image.open(a.src)
    iw, ih = im.size
    x = a.x if a.x >= 0 else iw + a.x
    y = a.y if a.y >= 0 else ih + a.y
    w = a.w or iw - x
    h = a.h or ih - y
    if not (0 <= x < iw and 0 <= y < ih and w > 0 and h > 0):
        raise SystemExit(f"crop box {x},{y} {w}x{h} is outside the {iw}x{ih} image")
    out = im.crop((x, y, min(iw, x + w), min(ih, y + h)))
    if a.zoom != 1.0:
        out = out.resize((round(out.width * a.zoom), round(out.height * a.zoom)), Image.NEAREST)
    out.save(a.dst)
    print(f"{a.dst}: {out.width}x{out.height}")


if __name__ == "__main__":
    main()
