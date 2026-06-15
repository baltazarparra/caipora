#!/usr/bin/env python3
"""Gera a Erva da Vida — pickup de HP máximo, UMA por fase (premium AAA).

Mesma receita premium de gen_inimigos.py (classe `Painter`): vetores orgânicos
supersampled 8× → downsample BOX → snap de paleta fechada → outline 1px contínuo.
Saída 48×48 (erva "grande", transborda o tile de 32px) em assets/sprites/:
  erva_vida_p1.png … erva_vida_p5.png  + prancha de conceito.

Verde NEON FORTE: o miolo lima brilhante casa com o glow aditivo in-engine
(ForestLight + Constants.COLOR_HERB_GLOW). Cada fase tem uma erva distinta com o
mesmo DNA verde, com acento temático (mata / brasas / ventre / vento / igreja).

Lei de marca: exceção deliberada (verde normalmente é acento mínimo do cristal) —
decisão explícita do dono. Roda standalone, como gen_bosses:
  python3 scripts/tools/gen_ervas_vida.py
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

from gen_inimigos import Painter, _outline, OUTLINE


OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
SIZE = 48
GRID = 48

# ── Paleta fechada: verde neon forte + acentos por fase ──
STEM_DK   = (16, 38, 18)        # caule / nervura / sombra
LEAF_DK   = (22, 58, 26)        # folha em sombra
LEAF_MID  = (40, 102, 44)       # folha base
LEAF_LT   = (78, 168, 70)       # folha iluminada
CORE      = (120, 255, 90)      # miolo neon lima — o read "vivo"
CORE_HOT  = (200, 255, 160)     # brilho quente do miolo
GLOW_RING = (90, 230, 140)      # halo verde-água em volta do miolo
AMBER     = (255, 150, 40)      # brasa (fase 2)
AMBER_HOT = (255, 210, 120)
SPORE     = (150, 240, 200)     # esporo bioluminescente (fase 3)
PALE      = (210, 255, 210)     # ponto pálido sacro (fase 5)
EARTH     = (40, 28, 18)        # torrão/raiz na base

PALETTE = [OUTLINE, STEM_DK, LEAF_DK, LEAF_MID, LEAF_LT, CORE, CORE_HOT,
           GLOW_RING, AMBER, AMBER_HOT, SPORE, PALE, EARTH]


# ── Primitivas ────────────────────────────────────────
def _leaf(p: Painter, base: tuple[float, float], ang: float, length: float, width: float) -> None:
    """Folha lanceolada apontando em `ang` rad (0 = pra cima), com nervura e meia-sombra."""
    dx, dy = math.sin(ang), -math.cos(ang)
    perpx, perpy = -dy, dx
    bx, by = base
    tip = (bx + dx * length, by + dy * length)
    mid = (bx + dx * length * 0.45, by + dy * length * 0.45)
    hw = width * 0.5
    left = (mid[0] + perpx * hw, mid[1] + perpy * hw)
    right = (mid[0] - perpx * hw, mid[1] - perpy * hw)
    p.poly([base, left, tip, right], LEAF_MID)
    p.poly([base, right, tip], LEAF_DK)                    # meia-sombra
    hl_base = (bx + dx * length * 0.15, by + dy * length * 0.15)
    hl_mid = (mid[0] + perpx * hw * 0.5, mid[1] + perpy * hw * 0.5)
    p.poly([hl_base, hl_mid, tip], LEAF_LT)                # destaque
    p.limb(base, tip, width * 0.18, 0.5, STEM_DK)          # nervura


def _core(p: Painter, cx: float, cy: float, r: float, ring: bool = True) -> None:
    """Miolo neon: halo verde-água + bulbo lima + brilho quente + faísca pálida."""
    if ring:
        p.ellipse(cx, cy, r * 1.6, r * 1.6, GLOW_RING)
    p.ellipse(cx, cy, r, r, CORE)
    p.ellipse(cx - 0.2 * r, cy - 0.2 * r, r * 0.55, r * 0.55, CORE_HOT)
    p.ellipse(cx - 0.3 * r, cy - 0.3 * r, r * 0.22, r * 0.22, PALE)


def _base(p: Painter, cx: float, by: float) -> None:
    p.ellipse(cx, by, 5.0, 2.2, EARTH)                     # torrão
    p.limb((cx, by), (cx - 3.0, by + 3.0), 1.4, 0.6, STEM_DK)
    p.limb((cx, by), (cx + 3.0, by + 3.0), 1.4, 0.6, STEM_DK)


# ── Erva por fase ─────────────────────────────────────
def erva(phase: int) -> Image.Image:
    p = Painter(SIZE, GRID)
    cx = 24.0
    by = 41.0       # base do caule
    top = 16.0      # centro do miolo
    fan = (cx, by - 3.0)
    _base(p, cx, by)
    p.limb((cx, by), (cx, top + 2.0), 2.4, 1.5, STEM_DK)

    if phase == 1:
        # Mata: 4 folhas simétricas, miolo redondo — a erva-mãe.
        for ang, ln, w in [(-0.70, 16, 7), (0.70, 16, 7), (-1.15, 12, 5.5), (1.15, 12, 5.5)]:
            _leaf(p, fan, ang, ln, w)
        _core(p, cx, top, 4.2)
    elif phase == 2:
        # Brasas: pontas das folhas acesas (acento âmbar), miolo verde domina.
        for ang, ln, w in [(-0.60, 16, 7), (0.60, 16, 7), (-1.10, 12, 5.5), (1.10, 12, 5.5)]:
            _leaf(p, fan, ang, ln, w)
        for ang, ln in [(-0.60, 16), (0.60, 16), (-1.10, 12), (1.10, 12)]:
            ex = fan[0] + math.sin(ang) * ln
            ey = fan[1] - math.cos(ang) * ln
            p.ellipse(ex, ey, 1.5, 1.5, AMBER)
            p.ellipse(ex, ey, 0.7, 0.7, AMBER_HOT)
        _core(p, cx, top, 4.2)
    elif phase == 3:
        # Ventre da mata: bioluminescente, folhas pendentes + esporos flutuando.
        for ang, ln, w in [(-0.95, 15, 6.5), (0.95, 15, 6.5), (-1.45, 11, 5), (1.45, 11, 5)]:
            _leaf(p, fan, ang, ln, w)
        _core(p, cx, top, 4.2)
        for sx, sy, r in [(13, 14, 1.1), (35, 18, 1.3), (17, 8, 0.9), (31, 9, 1.0), (24, 4, 1.2)]:
            p.ellipse(sx, sy, r, r, SPORE)
    elif phase == 4:
        # Vento (Saci): folhas varridas pro lado num redemoinho, rastros de ar.
        for ang, ln, w in [(-0.30, 15, 6.5), (0.45, 17, 7), (1.00, 15, 6), (1.50, 12, 5)]:
            _leaf(p, fan, ang, ln, w)
        _core(p, cx - 1.0, top, 4.0)
        for a, b in [((30, 19), (36, 16)), ((31, 24), (38, 22)), ((28, 13), (34, 11))]:
            p.limb(a, b, 0.9, 0.4, GLOW_RING)
    else:
        # A Igreja: ereta e formal, halo sacro, fronde central + laterais.
        for ang, ln, w in [(-0.55, 17, 7), (0.55, 17, 7), (0.0, 18, 6), (-1.20, 11, 5), (1.20, 11, 5)]:
            _leaf(p, fan, ang, ln, w)
        p.ellipse(cx, top, 7.0, 7.0, GLOW_RING)            # halo
        _core(p, cx, top, 4.4, ring=False)
        p.ellipse(cx, top - 8.0, 1.3, 1.3, PALE)           # ponto sacro acima

    img = p.render(PALETTE)
    _outline(img)
    return img


# ── Prancha de conceito (QA visual a 4× + leitura 32px) ──
def _contact_sheet(imgs: list[Image.Image]) -> None:
    zoom = 4
    cell = SIZE * zoom + 14
    width = cell * len(imgs)
    height = SIZE * zoom + 14 + 36
    sheet = Image.new("RGBA", (width, height), (16, 14, 15, 255))
    draw = ImageDraw.Draw(sheet)
    for i, img in enumerate(imgs):
        x = i * cell + 7
        big = img.resize((SIZE * zoom, SIZE * zoom), Image.Resampling.NEAREST)
        sheet.alpha_composite(big, (x, 7))
        tiny = img.resize((32, 32), Image.Resampling.BOX)
        sheet.alpha_composite(tiny, (x, SIZE * zoom + 10))
        draw.text((x, SIZE * zoom + 10), "fase %d" % (i + 1), fill=(220, 240, 210, 255))
    sheet.save(os.path.join(OUT, "erva_vida_contact_sheet.png"))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    imgs: list[Image.Image] = []
    for phase in range(1, 6):
        img = erva(phase)
        img.save(os.path.join(OUT, "erva_vida_p%d.png" % phase))
        imgs.append(img)
    _contact_sheet(imgs)
    print("[gen_ervas_vida] 5 ervas (48x48) + prancha geradas")


if __name__ == "__main__":
    main()
