#!/usr/bin/env python3
"""Generate AAA premium combat feedback sprites.

Outputs to assets/effects/:
  hit_vfx_sheet.png       — 6-frame blood impact animation (288×48)
  critical_vfx_sheet.png  — 6-frame orange explosion (384×64)
  dodge_vfx_sheet.png     — 4-frame cyan streak animation (320×48)
  result_critico.png      — pixel-art label "CRITICO" (orange)
  result_perfeito.png     — pixel-art label "PERFEITO" (crystal green)
  result_errou.png        — pixel-art label "ERROU" (blood red)
  result_esquiva.png      — pixel-art label "ESQUIVA!" (cyan)
  combo_digit_sheet.png   — digits 0-9 + "x" at 8×12 each (88×12)
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "effects")
os.makedirs(OUT, exist_ok=True)

# ─── Palette ──────────────────────────────────────
TRANSPARENT = (0, 0, 0, 0)
WHITE = (255, 255, 255, 255)
OUTLINE_COL = (26, 18, 10, 255)       # #1a120a — same as gen_caipora
ORANGE = (255, 69, 0, 255)            # #ff4500 — Caipora mane
ORANGE_DK = (139, 42, 0, 255)         # #8b2a00 — mane shadow
BLOOD = (139, 0, 0, 255)              # #8b0000 — dark blood
BLOOD_MID = (200, 20, 20, 255)        # intermediate blood
BLOOD_BRIGHT = (220, 50, 50, 255)
CRYSTAL = (0, 250, 154, 255)          # #00fa9a — crystal green
CRYSTAL_DIM = (0, 180, 110, 255)
CYAN = (21, 153, 255, 255)            # #1599ff — dodge blue
DODGE_PALE = (220, 235, 255, 255)     # pale cyan-white streaks
VOID = (10, 8, 12, 255)               # garra/void da Caipora (quase preto)
HEART_HOT = (220, 50, 50, 255)        # coração vivo (mesmo que BLOOD_BRIGHT)
HEART_MID = (200, 20, 20, 255)        # coração comprimido
HEART_DEAD = (110, 0, 0, 255)         # coração drenado (mais escuro que BLOOD)


def _a(col: tuple, alpha: int) -> tuple:
    """Return color with adjusted alpha."""
    return (col[0], col[1], col[2], alpha)


# ─── Drawing helpers ──────────────────────────────
def _circle(d: ImageDraw.Draw, cx: int, cy: int, r: int, color: tuple) -> None:
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


def _ring(d: ImageDraw.Draw, cx: int, cy: int, r: int, width: int, color: tuple) -> None:
    if r <= 0:
        return
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=width)


def _dots(d: ImageDraw.Draw, cx: int, cy: int, radius: int,
          count: int, dot_r: int, color: tuple, offset_angle: float = 0.0) -> None:
    for i in range(count):
        angle = offset_angle + i * (2 * math.pi / count)
        dx = int(round(math.cos(angle) * radius))
        dy = int(round(math.sin(angle) * radius))
        if dot_r <= 0:
            d.point([cx + dx, cy + dy], fill=color)
        else:
            d.ellipse([cx + dx - dot_r, cy + dy - dot_r,
                       cx + dx + dot_r, cy + dy + dot_r], fill=color)


def _line_radial(d: ImageDraw.Draw, cx: int, cy: int, r_in: int, r_out: int,
                 count: int, width: int, color: tuple, offset_angle: float = 0.0) -> None:
    for i in range(count):
        angle = offset_angle + i * (2 * math.pi / count)
        x1 = cx + int(round(math.cos(angle) * r_in))
        y1 = cy + int(round(math.sin(angle) * r_in))
        x2 = cx + int(round(math.cos(angle) * r_out))
        y2 = cy + int(round(math.sin(angle) * r_out))
        d.line([x1, y1, x2, y2], fill=color, width=width)


def _hstreak(d: ImageDraw.Draw, cx: int, cy: int, lengths: list[int],
             spacing: int, color: tuple, x_offset: int = 0) -> None:
    """Draw horizontal motion streaks centered at cx,cy."""
    total_h = (len(lengths) - 1) * spacing
    y_start = cy - total_h // 2
    for i, length in enumerate(lengths):
        y = y_start + i * spacing
        x0 = cx - length // 2 + x_offset
        x1 = cx + length // 2 + x_offset
        d.line([x0, y, x1, y], fill=color, width=1)


def _heart(d: ImageDraw.Draw, cx: int, cy: int, size: int, color: tuple,
           squeeze: float = 0.0) -> None:
    """Pixel heart centered at cx,cy. squeeze 0..1 comprime a largura (esmagado)."""
    r = max(2, int(round(size * (1.0 - 0.40 * squeeze))))
    lobe_y = cy - r // 2
    # Dois lóbulos
    d.ellipse([cx - 2 * r, lobe_y - r, cx, lobe_y + r], fill=color)
    d.ellipse([cx, lobe_y - r, cx + 2 * r, lobe_y + r], fill=color)
    # Ponta inferior (encurta junto com o aperto)
    tip_y = cy + int(round(size * 1.3 * (1.0 - 0.30 * squeeze)))
    d.polygon([(cx - 2 * r, lobe_y), (cx + 2 * r, lobe_y), (cx, tip_y)], fill=color)


def _talon(d: ImageDraw.Draw, bx: float, by: float, tx: float, ty: float,
           base_w: float, color: tuple) -> None:
    """Garra cônica: larga na base (bx,by), pontuda na ponta (tx,ty)."""
    ang = math.atan2(ty - by, tx - bx)
    px = math.cos(ang + math.pi / 2)
    py = math.sin(ang + math.pi / 2)
    hw = base_w / 2.0
    d.polygon([
        (bx + px * hw, by + py * hw),
        (bx - px * hw, by - py * hw),
        (tx, ty),
    ], fill=color)


# ─── Outline pass ─────────────────────────────────
def _add_outline(img: Image.Image, outline_color: tuple = OUTLINE_COL) -> Image.Image:
    """Add 1px outline around all non-transparent pixels."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 16:
                continue
            # Transparent pixel — check 4-connected neighbors
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 16:
                    dst[x, y] = outline_color
                    break
    return out


# ─── HIT VFX (6 frames × 48×48) ──────────────────
def gen_hit_vfx() -> None:
    W, H, N = 48, 48, 6
    sheet = Image.new("RGBA", (W * N, H), TRANSPARENT)
    cx, cy = W // 2, H // 2

    specs = [
        # (fills, rings, dots)
        [],  # frame 0: blank
        [("circle", cx, cy, 4, BLOOD)],
        [("circle", cx, cy, 8, BLOOD),
         ("dots", cx, cy, 14, 4, 3, BLOOD_MID, math.pi / 4)],
        [("ring", cx, cy, 16, 3, BLOOD),
         ("dots", cx, cy, 20, 4, 2, BLOOD, math.pi / 4),
         ("dots", cx, cy, 20, 4, 1, BLOOD_MID, 0.0)],
        [("ring", cx, cy, 20, 2, _a(BLOOD, 160)),
         ("dots", cx, cy, 24, 4, 1, _a(BLOOD, 120), math.pi / 4)],
        [("ring", cx, cy, 24, 1, _a(BLOOD, 70))],
    ]

    for fi, ops in enumerate(specs):
        frame = Image.new("RGBA", (W, H), TRANSPARENT)
        d = ImageDraw.Draw(frame)
        for op in ops:
            if op[0] == "circle":
                _circle(d, op[1], op[2], op[3], op[4])
            elif op[0] == "ring":
                _ring(d, op[1], op[2], op[3], op[4], op[5])
            elif op[0] == "dots":
                angle = op[6] if len(op) > 6 else 0.0
                _dots(d, op[1], op[2], op[3], op[4], op[5], op[6] if len(op) == 7 and isinstance(op[6], tuple) else op[-1] if isinstance(op[-1], tuple) else (0, 0, 0, 0))
        sheet.paste(frame, (fi * W, 0))

    sheet.save(os.path.join(OUT, "hit_vfx_sheet.png"))


def _gen_hit_vfx_clean() -> None:
    """Clean hit vfx generation."""
    W, H, N = 48, 48, 6
    sheet = Image.new("RGBA", (W * N, H), TRANSPARENT)
    cx, cy = W // 2, H // 2

    def frame(fi: int) -> Image.Image:
        img = Image.new("RGBA", (W, H), TRANSPARENT)
        d = ImageDraw.Draw(img)
        if fi == 1:
            _circle(d, cx, cy, 4, BLOOD)
        elif fi == 2:
            _circle(d, cx, cy, 9, BLOOD)
            _dots(d, cx, cy, 14, 4, 3, BLOOD_MID, math.pi / 4)
        elif fi == 3:
            _ring(d, cx, cy, 16, 3, BLOOD)
            _dots(d, cx, cy, 20, 4, 2, BLOOD, math.pi / 4)
            _dots(d, cx, cy, 18, 4, 1, BLOOD_MID, 0.0)
        elif fi == 4:
            _ring(d, cx, cy, 20, 2, _a(BLOOD, 160))
            _dots(d, cx, cy, 24, 4, 1, _a(BLOOD, 120), math.pi / 4)
        elif fi == 5:
            _ring(d, cx, cy, 24, 1, _a(BLOOD, 70))
        return img

    for fi in range(N):
        sheet.paste(frame(fi), (fi * W, 0))
    sheet.save(os.path.join(OUT, "hit_vfx_sheet.png"))


# ─── CRITICAL VFX (6 frames × 64×64) ─────────────
def _gen_critical_vfx() -> None:
    W, H, N = 64, 64, 6
    sheet = Image.new("RGBA", (W * N, H), TRANSPARENT)
    cx, cy = W // 2, H // 2

    def frame(fi: int) -> Image.Image:
        img = Image.new("RGBA", (W, H), TRANSPARENT)
        d = ImageDraw.Draw(img)
        if fi == 1:
            _circle(d, cx, cy, 7, WHITE)
            _circle(d, cx, cy, 4, WHITE)
        elif fi == 2:
            _circle(d, cx, cy, 5, WHITE)
            _ring(d, cx, cy, 16, 6, ORANGE)
            _ring(d, cx, cy, 16, 2, _a(WHITE, 200))
        elif fi == 3:
            _circle(d, cx, cy, 3, _a(WHITE, 180))
            _ring(d, cx, cy, 24, 5, ORANGE)
            _line_radial(d, cx, cy, 22, 30, 8, 2, ORANGE_DK, math.pi / 8)
            _ring(d, cx, cy, 14, 2, BLOOD)
        elif fi == 4:
            _ring(d, cx, cy, 30, 3, _a(ORANGE, 180))
            _line_radial(d, cx, cy, 26, 32, 8, 1, _a(ORANGE_DK, 140), math.pi / 8)
            _ring(d, cx, cy, 20, 2, _a(BLOOD, 120))
        elif fi == 5:
            _ring(d, cx, cy, 36, 2, _a(ORANGE, 70))
            _ring(d, cx, cy, 26, 1, _a(BLOOD, 50))
        return img

    for fi in range(N):
        sheet.paste(frame(fi), (fi * W, 0))
    sheet.save(os.path.join(OUT, "critical_vfx_sheet.png"))


# ─── DODGE VFX (4 frames × 80×48) ────────────────
def _gen_dodge_vfx() -> None:
    W, H, N = 80, 48, 4
    sheet = Image.new("RGBA", (W * N, H), TRANSPARENT)
    cx, cy = W // 2, H // 2

    def frame(fi: int) -> Image.Image:
        img = Image.new("RGBA", (W, H), TRANSPARENT)
        d = ImageDraw.Draw(img)
        if fi == 1:
            _hstreak(d, cx, cy, [28, 20, 14], 5, DODGE_PALE)
            _hstreak(d, cx, cy, [28, 20, 14], 5, _a(CYAN, 100), x_offset=-6)
        elif fi == 2:
            _hstreak(d, cx, cy, [22, 15, 10], 5, _a(DODGE_PALE, 160), x_offset=-8)
            _hstreak(d, cx, cy, [14, 10, 7], 5, _a(CYAN, 60), x_offset=-14)
        elif fi == 3:
            _hstreak(d, cx, cy, [14, 10, 7], 5, _a(DODGE_PALE, 80), x_offset=-12)
        return img

    for fi in range(N):
        sheet.paste(frame(fi), (fi * W, 0))
    sheet.save(os.path.join(OUT, "dodge_vfx_sheet.png"))


# ─── FINISHER VFX (5 frames × 64×64) ─────────────
# Golpe final: a garra preta da Caipora agarra o coração do inimigo, esmaga e
# drena o sangue. Toca em câmera lenta (herda Engine.time_scale) sobre o peito.
def _gen_finisher_vfx() -> None:
    W, H, N = 64, 64, 5
    sheet = Image.new("RGBA", (W * N, H), TRANSPARENT)
    hx, hy = 32, 36  # centro do coração (peito)

    bases = [(20, 17), (28, 14), (36, 14), (44, 17)]      # base dos talões (dorso)
    tips_open = [(13, 33), (23, 37), (41, 37), (51, 33)]  # garra aberta
    tips_close = [(26, 40), (30, 43), (34, 43), (38, 40)]  # garra cravada
    grips = [0.0, 0.45, 0.72, 0.9, 1.0]
    sizes = [10, 9, 8, 7, 6]
    squeezes = [0.0, 0.25, 0.5, 0.78, 0.95]
    hcols = [HEART_HOT, HEART_HOT, HEART_MID, HEART_DEAD, HEART_DEAD]

    def lerp(a: float, b: float, t: float) -> float:
        return a + (b - a) * t

    def frame(fi: int) -> Image.Image:
        img = Image.new("RGBA", (W, H), TRANSPARENT)
        d = ImageDraw.Draw(img)
        grip = grips[fi]
        sq = squeezes[fi]

        # 1) Coração (sob a garra)
        _heart(d, hx, hy, sizes[fi], hcols[fi], sq)
        if fi <= 1:  # brilho vivo do órgão pulsante
            _circle(d, hx - 3, hy - 3, 2, _a(WHITE, 150))

        # 2) Garra (4 talões) cravando por cima
        for i in range(4):
            tx = lerp(tips_open[i][0], tips_close[i][0], grip)
            ty = lerp(tips_open[i][1], tips_close[i][1], grip)
            bw = lerp(8, 6, grip)
            _talon(d, bases[i][0], bases[i][1], tx, ty, bw, VOID)

        # 3) Dorso/punho (massa preta) e pulso saindo do topo
        d.ellipse([hx - 13, 8, hx + 13, 22], fill=VOID)
        d.rectangle([hx - 7, 0, hx + 7, 12], fill=VOID)

        # 4) Sangue espremido (cresce no aperto, dreia/escorre no fim)
        if fi == 1:
            _dots(d, hx, hy, 12, 5, 1, HEART_MID, 0.3)
        elif fi == 2:
            _line_radial(d, hx, hy, 11, 20, 8, 2, HEART_HOT, math.pi / 8)
            _dots(d, hx, hy, 22, 8, 2, BLOOD, 0.0)
            _dots(d, hx, hy, 16, 6, 1, HEART_HOT, 0.5)
        elif fi == 3:
            _line_radial(d, hx, hy, 12, 26, 6, 2, BLOOD, math.pi / 6)
            _dots(d, hx, hy, 28, 6, 2, _a(BLOOD, 180), 0.2)
            d.line([hx - 6, hy + 8, hx - 7, hy + 20], fill=BLOOD, width=2)
            d.line([hx + 5, hy + 10, hx + 6, hy + 22], fill=BLOOD, width=2)
            _circle(d, hx - 7, hy + 21, 2, BLOOD)
            _circle(d, hx + 6, hy + 23, 2, BLOOD)
        elif fi == 4:
            _dots(d, hx, hy, 26, 6, 1, _a(BLOOD, 90), 0.4)
            d.line([hx - 6, hy + 12, hx - 7, hy + 24], fill=_a(BLOOD, 140), width=2)
            _circle(d, hx - 7, hy + 25, 2, _a(BLOOD, 150))
        return img

    for fi in range(N):
        f = _add_outline(frame(fi), OUTLINE_COL)
        sheet.paste(f, (fi * W, 0))
    sheet.save(os.path.join(OUT, "finisher_vfx_sheet.png"))


# ─── Pixel font 5×7 ───────────────────────────────
# Each entry: list of 7 rows, each row is 5-char string of X/.
FONT_5x7: dict[str, list[str]] = {
    "A": ["..X..", ".X.X.", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
    "C": [".XXX.", "X...X", "X....", "X....", "X....", "X...X", ".XXX."],
    "E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
    "F": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...."],
    "I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
    "O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "P": ["XXXX.", "X...X", "X...X", "XXXX.", "X....", "X....", "X...."],
    "Q": [".XXX.", "X...X", "X...X", "X...X", "X.X.X", "X..XX", ".XXXX"],
    "R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
    "S": [".XXX.", "X...X", "X....", ".XXX.", "....X", "X...X", ".XXX."],
    "T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
    "U": ["X...X", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
    "V": ["X...X", "X...X", "X...X", ".X.X.", ".X.X.", "..X..", "..X.."],
    "!": ["..X..", "..X..", "..X..", "..X..", "..X..", ".....", "..X.."],
    "0": [".XXX.", "X...X", "X..XX", "X.X.X", "XX..X", "X...X", ".XXX."],
    "1": ["..X..", ".XX..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
    "2": [".XXX.", "X...X", "....X", "..XX.", ".X...", "X....", "XXXXX"],
    "3": ["XXXX.", "....X", "....X", ".XXX.", "....X", "....X", "XXXX."],
    "4": ["X...X", "X...X", "X...X", "XXXXX", "....X", "....X", "....X"],
    "5": ["XXXXX", "X....", "X....", "XXXX.", "....X", "....X", "XXXX."],
    "6": [".XXX.", "X....", "X....", "XXXX.", "X...X", "X...X", ".XXX."],
    "7": ["XXXXX", "....X", "...X.", "..X..", ".X...", ".X...", ".X..."],
    "8": [".XXX.", "X...X", "X...X", ".XXX.", "X...X", "X...X", ".XXX."],
    "9": [".XXX.", "X...X", "X...X", ".XXXX", "....X", "X...X", ".XXX."],
    "x": [".....", "X...X", ".X.X.", "..X..", ".X.X.", "X...X", "....."],
}

CHAR_W, CHAR_H = 5, 7
CHAR_GAP = 1  # px between characters


def _draw_char(d: ImageDraw.Draw, char: str, ox: int, oy: int, color: tuple) -> None:
    rows = FONT_5x7.get(char)
    if rows is None:
        return
    for row_i, row in enumerate(rows):
        for col_i, px in enumerate(row):
            if px == "X":
                d.point([ox + col_i, oy + row_i], fill=color)


def _text_width(text: str) -> int:
    return len(text) * CHAR_W + (len(text) - 1) * CHAR_GAP


def _gen_label(text: str, text_color: tuple, accent_color: tuple, out_name: str) -> None:
    MARGIN_X = 4
    MARGIN_Y = 2
    tw = _text_width(text)
    iw = tw + MARGIN_X * 2
    ih = CHAR_H + MARGIN_Y * 2 + 3  # 3px for gap + underline strip
    img = Image.new("RGBA", (iw, ih), TRANSPARENT)
    d = ImageDraw.Draw(img)

    # Draw characters
    x = MARGIN_X
    y = MARGIN_Y
    for ch in text:
        _draw_char(d, ch, x, y, text_color)
        x += CHAR_W + CHAR_GAP

    # Outline pass (1px around text pixels)
    img = _add_outline(img, OUTLINE_COL)
    d = ImageDraw.Draw(img)

    # Underline accent strip (2px tall, below chars with 1px gap)
    uy = MARGIN_Y + CHAR_H + 1
    d.rectangle([MARGIN_X, uy, iw - MARGIN_X - 1, uy + 1], fill=accent_color)

    img.save(os.path.join(OUT, out_name))


# ─── COMBO DIGIT SHEET (11 frames × 8×12) ─────────
def _gen_combo_digits() -> None:
    CHARS = "0123456789x"
    CW, CH = 8, 12
    sheet = Image.new("RGBA", (CW * len(CHARS), CH), TRANSPARENT)

    for i, ch in enumerate(CHARS):
        frame = Image.new("RGBA", (CW, CH), TRANSPARENT)
        d = ImageDraw.Draw(frame)
        ox = (CW - CHAR_W) // 2
        oy = (CH - CHAR_H) // 2
        _draw_char(d, ch, ox, oy, ORANGE)
        frame = _add_outline(frame, OUTLINE_COL)
        sheet.paste(frame, (i * CW, 0))

    sheet.save(os.path.join(OUT, "combo_digit_sheet.png"))


# ─── Entry point ──────────────────────────────────
def main() -> None:
    print("Generating feedback sprites → assets/effects/")

    _gen_hit_vfx_clean()
    print("  ✓ hit_vfx_sheet.png (6×48×48)")

    _gen_critical_vfx()
    print("  ✓ critical_vfx_sheet.png (6×64×64)")

    _gen_dodge_vfx()
    print("  ✓ dodge_vfx_sheet.png (4×80×48)")

    _gen_finisher_vfx()
    print("  ✓ finisher_vfx_sheet.png (5×64×64)")

    _gen_label("CRITICO", WHITE, ORANGE,   "result_critico.png")
    print("  ✓ result_critico.png")

    _gen_label("PERFEITO", WHITE, CRYSTAL, "result_perfeito.png")
    print("  ✓ result_perfeito.png")

    _gen_label("ERROU", WHITE, BLOOD,      "result_errou.png")
    print("  ✓ result_errou.png")

    _gen_label("ESQUIVA!", WHITE, CYAN,    "result_esquiva.png")
    print("  ✓ result_esquiva.png")

    _gen_combo_digits()
    print("  ✓ combo_digit_sheet.png (11×8×12)")

    print("Done.")


if __name__ == "__main__":
    main()
