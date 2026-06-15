#!/usr/bin/env python3
"""Quantiza as tiras/posters de site/assets/clips para PNG indexado leve.

As capturas de capture_clips.gd saem como PNG RGBA truecolor (~3-4MB cada): a
arena é pixel-art de paleta fechada, então 256 cores indexadas reproduzem o
quadro quase sem perda e cortam o payload ~5x. O dither (Floyd-Steinberg) quebra
o banding do gradiente escuro do vignette e se funde com o grão do site.

Determinístico, só stdlib + Pillow. Roda DEPOIS do capture_clips.gd:
    python3 scripts/tools/optimize_clips.py [--colors=256] [--dir=site/assets/clips]
"""
from __future__ import annotations

import glob
import os
import sys

from PIL import Image

COLORS = 256
CLIP_DIR = "site/assets/clips"


def _parse_args() -> None:
    global COLORS, CLIP_DIR
    for arg in sys.argv[1:]:
        if arg.startswith("--colors="):
            COLORS = max(2, min(256, int(arg[len("--colors="):])))
        elif arg.startswith("--dir="):
            CLIP_DIR = arg[len("--dir="):]


def _optimize(path: str) -> None:
    before = os.path.getsize(path)
    img = Image.open(path).convert("RGB")  # clipes são opacos (frame cheio)
    q = img.quantize(colors=COLORS, method=Image.MEDIANCUT,
                     dither=Image.Dither.FLOYDSTEINBERG)
    q.save(path, optimize=True)
    after = os.path.getsize(path)
    print(f"  {os.path.basename(path):28s} {before/1e6:5.2f}MB -> {after/1e6:5.2f}MB")


def main() -> None:
    _parse_args()
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    target = os.path.join(root, CLIP_DIR)
    pngs = sorted(glob.glob(os.path.join(target, "*.png")))
    if not pngs:
        print(f"[optimize] nenhum PNG em {target}")
        return
    print(f"[optimize] {len(pngs)} PNG(s) @ {COLORS} cores em {CLIP_DIR}")
    for p in pngs:
        _optimize(p)


if __name__ == "__main__":
    main()
