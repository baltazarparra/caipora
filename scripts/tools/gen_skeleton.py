#!/usr/bin/env python3
"""Generate the skeleton map sprite — marca permanente onde um inimigo foi derrotado.

Um esqueleto flat, visto de cima-ligeiramente-inclinado, deitado no chão da mata.
Paleta fechada de osso/sangue/terra; outline 1px #1a120a. Sem branco puro, sem
laranja juba, sem verde cristal (leis da identidade visual). Horror físico: sangue
seco, mandíbula aberta, raízes da floresta começando a consumir os ossos.

Pipeline: vetores no grid 48 → supersampled 8× → downsample BOX → snap paleta
fechada → outline 1px contínuo. Mesmo processo de gen_inimigos.py / gen_bosses.py.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
SIZE = 56
GRID = 48
SS = 8

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (26, 18, 10)          # #1a120a — contorno padrão do mundo

# ── Paleta do esqueleto ──────────────────────────────
BONE_HI  = (232, 216, 176)     # #e8d8b0 osso iluminado (highlight)
BONE     = (200, 184, 144)     # #c8b890 osso principal
BONE_DK  = (122, 106, 80)      # #7a6a50 osso em sombra / frestas
BLOOD    = (58, 10, 10)        # #3a0a0a poça de sangue seco (escuro)
BLOOD_LT = (90, 16, 16)        # #5a1010 sangue ligeiramente fresco na borda
EARTH    = (26, 18, 8)         # #1a1208 terra escura / raiz profunda
ROOT     = (42, 30, 12)        # #2a1e0c raiz superficial / tendrilha

SKELETON_PALETTE = [
    OUTLINE, BONE_HI, BONE, BONE_DK, BLOOD, BLOOD_LT, EARTH, ROOT,
]


class Painter:
    def __init__(self, size: int = SIZE, grid: float = GRID) -> None:
        self.size = size
        self.k = size / grid * SS
        self.im = Image.new("RGBA", (size * SS, size * SS), TRANSPARENT)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts: list[tuple[float, float]], col: tuple[int, int, int]) -> None:
        self.d.polygon([(x * self.k, y * self.k) for x, y in pts], fill=col)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float,
                col: tuple[int, int, int]) -> None:
        self.d.ellipse(
            [(cx - rx) * self.k, (cy - ry) * self.k,
             (cx + rx) * self.k, (cy + ry) * self.k],
            fill=col,
        )

    def limb(self, a: tuple[float, float], b: tuple[float, float],
             wa: float, wb: float, col: tuple[int, int, int]) -> None:
        x0, y0 = a
        x1, y1 = b
        dx, dy = x1 - x0, y1 - y0
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        self.poly([
            (x0 + nx * wa / 2, y0 + ny * wa / 2),
            (x1 + nx * wb / 2, y1 + ny * wb / 2),
            (x1 - nx * wb / 2, y1 - ny * wb / 2),
            (x0 - nx * wa / 2, y0 - ny * wa / 2),
        ], col)
        self.ellipse(x0, y0, wa / 2, wa / 2, col)
        self.ellipse(x1, y1, wb / 2, wb / 2, col)

    def render(self, palette: list[tuple[int, int, int]]) -> Image.Image:
        small = self.im.resize((self.size, self.size), Image.Resampling.BOX)
        px = small.load()
        for y in range(self.size):
            for x in range(self.size):
                r, g, b, a = px[x, y]
                if a < 112:
                    px[x, y] = TRANSPARENT
                else:
                    px[x, y] = _nearest(r, g, b, palette)
        return small


def _nearest(r: int, g: int, b: int,
             palette: list[tuple[int, int, int]]) -> tuple[int, int, int, int]:
    best, best_d = palette[0], 10 ** 12
    for c in palette:
        d = (r - c[0]) ** 2 + (g - c[1]) ** 2 + (b - c[2]) ** 2
        if d < best_d:
            best, best_d = c, d
    return best + (255,)


def _outline(img: Image.Image) -> None:
    px = img.load()
    edge: list[tuple[int, int]] = []
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] == 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if not (0 <= nx < img.width and 0 <= ny < img.height) or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = OUTLINE + (255,)


# ════════════════════════════════════════════════════
# Esqueleto — leitura a 32px: crânio (esq) + fêmur diagonal (dir) + mancha escura
# ════════════════════════════════════════════════════

def _blood_pool(p: Painter) -> None:
    # Poça de sangue seco — base visual mais escura, âncora o esqueleto no chão
    p.ellipse(17, 27, 13.5, 7.0, BLOOD)
    p.ellipse(18, 25, 9.5, 5.0, BLOOD_LT)   # ligeiramente mais fresco no centro


def _skull(p: Painter) -> None:
    # Crânio visto ligeiramente de cima, tombado para o lado esquerdo / boca aberta
    # — "predador que a floresta consumiu"

    # Crânio (vista de 3/4 tombado para baixo-esquerda)
    p.ellipse(13, 19, 8.5, 6.5, BONE)          # massa craniana
    p.ellipse(11, 16, 6.0, 3.8, BONE_HI)       # highlight topo (osso seco ao sol)
    p.poly([(5, 19), (13, 13.5), (21, 19), (20, 23), (6, 23)], BONE)  # face plate
    # sombra do lado direito do crânio (profundidade)
    p.poly([(18, 17), (21, 19), (20, 23), (17, 22)], BONE_DK)

    # Órbita (cavidade ocular) — ESCURA, não branca; não redonda como olhos da Caipora
    p.ellipse(10, 18, 3.2, 2.4, OUTLINE)       # cavidade principal escura
    p.ellipse(10, 18, 1.8, 1.2, BONE_DK)       # fundo da cavidade (tom osso-sombra)

    # Cavidade nasal
    p.poly([(13, 21.5), (15.5, 21.5), (14.2, 24.0)], OUTLINE)

    # Maxilar (mandíbula tombada, boca aberta — horror)
    p.poly([(6, 24), (20, 24), (19, 28), (7, 28)], BONE_DK)
    # Dentes (superiores e inferiores visiveis com boca aberta)
    for tx in [8.0, 10.0, 12.0, 14.0, 16.0, 18.0]:
        p.poly([(tx - 0.9, 23), (tx + 0.9, 23), (tx + 0.8, 25.5), (tx - 0.8, 25.5)], BONE)
    # Dentes inferiores (mandíbula)
    for tx in [8.5, 10.5, 12.5, 14.5, 16.5]:
        p.poly([(tx - 0.8, 28), (tx + 0.8, 28), (tx + 0.7, 26.2), (tx - 0.7, 26.2)], BONE_HI)

    # Gotas de sangue coagulado na boca
    p.ellipse(9.0, 26.5, 1.0, 0.8, BLOOD)
    p.ellipse(14.5, 27.5, 0.8, 0.6, BLOOD)
    p.ellipse(18.0, 26.0, 0.7, 0.6, BLOOD)


def _ribcage(p: Painter) -> None:
    # Fragmentos de costelas espalhados — corpo se desfez, a mata encolheu os ossos
    # Costelas do lado esquerdo (visíveis, arco curvo)
    p.limb((22, 22), (25, 17), 1.4, 0.8, BONE_DK)
    p.limb((25, 23), (29, 17), 1.3, 0.8, BONE_DK)
    p.limb((22, 26), (25, 31), 1.3, 0.8, BONE_DK)
    p.limb((25, 25), (29, 31), 1.3, 0.8, BONE_DK)
    # Vértebras (série de pequenos ovais — coluna horizontal)
    for vx in [21.5, 24.5, 27.5, 30.5]:
        p.ellipse(vx, 24, 1.8, 1.3, BONE)
        p.ellipse(vx, 24, 1.0, 0.7, BONE_HI)


def _femur(p: Painter) -> None:
    # Fêmur — o osso longo e reconhecível, leitura a 32px garantida pelo tamanho
    # diagonal: upper-center → lower-right
    p.limb((30, 22), (44, 39), 3.2, 2.8, BONE)         # diáfise (corpo)
    p.limb((30, 22), (44, 39), 1.4, 1.2, BONE_HI)      # reflexo no cimo
    p.ellipse(30, 22, 4.2, 3.6, BONE)                  # cabeça do fêmur (epífise)
    p.ellipse(30, 22, 2.6, 2.2, BONE_HI)               # destaque da cabeça
    p.ellipse(44, 39, 3.8, 3.2, BONE)                  # côndilo distal
    p.ellipse(44, 39, 2.2, 1.8, BONE_DK)               # sombra côndilo
    # Ranhura anatômica (linha escura no eixo longo)
    p.limb((33, 25), (42, 37), 0.6, 0.6, BONE_DK)

    # Fragmento de tíbia (osso menor ao lado)
    p.limb((34, 16), (44, 26), 1.8, 1.4, BONE_DK)
    p.ellipse(34, 16, 2.0, 1.6, BONE_DK)
    p.ellipse(44, 26, 1.8, 1.4, BONE_DK)


def _roots(p: Painter) -> None:
    # Raízes da mata começando a consumir — detalhe de horror lento
    # A floresta reclama seus mortos
    p.limb((3, 30), (16, 27), 1.3, 0.9, EARTH)       # raiz vinda da borda esq
    p.limb((16, 27), (28, 33), 0.9, 0.7, EARTH)      # continua sob costelas
    p.limb((4, 40), (20, 35), 1.1, 0.7, ROOT)        # tendrilha mais clara
    p.limb((20, 35), (30, 30), 0.7, 0.5, ROOT)       # bifurca em direção ao fêmur
    p.limb((40, 44), (36, 34), 1.0, 0.7, EARTH)      # raiz vinda de baixo-dir


def skeleton() -> Image.Image:
    p = Painter()
    _blood_pool(p)
    _roots(p)           # raízes ABAIXO dos ossos (z-order paint order)
    _ribcage(p)
    _femur(p)
    _skull(p)           # crânio por cima de tudo (destaque)
    img = p.render(SKELETON_PALETTE)
    _outline(img)
    return img


def generate() -> None:
    os.makedirs(OUT, exist_ok=True)
    img = skeleton()
    out_path = os.path.join(OUT, "skeleton_map.png")
    img.save(out_path)
    print(f"[gen_skeleton] skeleton_map.png (56×56) → {out_path}")


if __name__ == "__main__":
    generate()
