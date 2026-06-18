"""Gera os sprites da TERRA RARA — a economia do jogo (antes "fragmentos").

Conceito (docs/CONCEITO-terra-rara.md): minério bruto cristalino. Matriz de rocha
escura com facetas de cristal âmbar/laranja-quente erupcionando — lê como recurso
raro e precioso, alinhado à marca (laranja/preto/branco). SEM verde (reservado à
Fúria/cristal da Caipora).

Saídas em assets/sprites/ (32×32 cada):
  terra_rara_icon.png   — ícone do contador no HUD (cluster limpo, lê pequeno).
  terra_rara_node.png   — a veia caída na exploração (souls-like): minério meio
                          enterrado numa poça de sangue, no tile da morte.

Pipeline stdlib puro (struct/zlib), determinístico, pixel-art NEAREST — espelha
gen_ervas.py (zero dependência externa).
"""
import struct, zlib, os, math

ICON = 32


# ─── PNG encode (stdlib puro: struct/zlib) ────────────────────────────────────
def png_chunk(tag: bytes, data: bytes) -> bytes:
    c = zlib.crc32(tag + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", c)


def encode_png(pixels: list[list[tuple[int, int, int, int]]]) -> bytes:
    h, w = len(pixels), len(pixels[0])
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b, a in row:
            raw += bytes([r, g, b, a])
    ihdr = struct.pack(">II", w, h) + bytes([8, 6, 0, 0, 0])  # RGBA, 8-bit
    compressed = zlib.compress(raw, 9)
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", ihdr)
        + png_chunk(b"IDAT", compressed)
        + png_chunk(b"IEND", b"")
    )


# ─── Paleta (r,g,b,a) — espelha constants.gd ──────────────────────────────────
TRANSP      = (  0,   0,   0,   0)
OUTLINE     = ( 10,   8,   6, 255)
# Matriz de rocha (minério bruto)
ROCK_DARK   = ( 28,  22,  18, 255)
ROCK_MID    = ( 52,  38,  28, 255)
ROCK_HI     = ( 92,  64,  38, 255)
# Cristal âmbar (a "terra rara" que brilha) — COLOR_AMBER #ff6b00 no miolo
AMBER_DARK  = (190,  70,   0, 255)
AMBER_MID   = (255, 107,   0, 255)
AMBER_LIGHT = (255, 170,  70, 255)
AMBER_TIP   = (255, 214, 150, 255)
# Sangue (poça da morte no node) — COLOR_BLOOD #8b0000 chapado
BLOOD       = (139,   0,   0, 255)
BLOOD_DARK  = ( 74,   0,   0, 255)


def blank(w: int = ICON, h: int = ICON) -> list[list[tuple]]:
    return [[TRANSP] * w for _ in range(h)]


def put(g, x: int, y: int, col) -> None:
    if 0 <= y < len(g) and 0 <= x < len(g[0]):
        g[y][x] = col


def ellipse_fill(g, cx, cy, rx, ry, col) -> None:
    for y in range(int(cy - ry), int(cy + ry + 1)):
        for x in range(int(cx - rx), int(cx + rx + 1)):
            if rx > 0 and ry > 0 and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                put(g, x, y, col)


# ─── Primitivas ───────────────────────────────────────────────────────────────
def rock_mound(g, cx, top, bottom, half_w) -> None:
    """Monte de rocha escura: estreito no topo, largo na base, com contorno e brilho."""
    for y in range(top, bottom + 1):
        t = (y - top) / float(max(1, bottom - top))
        w = int(round(half_w * (0.45 + 0.55 * t)))
        for x in range(cx - w, cx + w + 1):
            if y == bottom or x == cx - w or x == cx + w:
                col = OUTLINE
            elif x <= cx - w + 1:
                col = ROCK_DARK
            elif (x * 3 + y * 5) % 7 == 0:
                col = ROCK_HI
            elif (x + y) % 3 == 0:
                col = ROCK_DARK
            else:
                col = ROCK_MID
            put(g, x, y, col)


def crystal(g, cx, base_y, top_y, half_w) -> None:
    """Cristal de terra rara: prisma vertical facetado, ponta acesa, contorno 1px.

    Luz vem de cima-esquerda → faceta esquerda clara, miolo médio, direita escura.
    """
    h = base_y - top_y
    shoulder = top_y + max(2, int(h * 0.45))
    for y in range(top_y, base_y + 1):
        if y < shoulder:
            t = (y - top_y) / float(max(1, shoulder - top_y))  # 0 ponta .. 1 ombro
            w = int(round(half_w * t))
        else:
            w = half_w
        if w < 0:
            continue
        for x in range(cx - w, cx + w + 1):
            if x == cx - w or x == cx + w:
                col = OUTLINE
            elif x < cx:
                col = AMBER_LIGHT
            elif x == cx:
                col = AMBER_MID
            else:
                col = AMBER_DARK
            put(g, x, y, col)
    # ponta acesa
    put(g, cx, top_y, AMBER_TIP)
    put(g, cx, min(top_y + 1, base_y), AMBER_TIP)
    # base com contorno
    for x in range(cx - half_w, cx + half_w + 1):
        put(g, x, base_y, OUTLINE)
    # crista clara (aresta da faceta) descendo pelo corpo
    ridge_x = cx - max(1, half_w // 2)
    for y in range(shoulder, base_y):
        put(g, ridge_x, y, AMBER_TIP if y % 3 == 0 else AMBER_LIGHT)
    # pequeno glint quente perto da ponta
    put(g, cx - 1, top_y + max(2, h // 4), AMBER_TIP)


# ─── Sprites ───────────────────────────────────────────────────────────────────
def icon():
    """Cluster de cristais erupcionando da rocha — leitura forte em ~24px no HUD."""
    g = blank()
    rock_mound(g, 16, 18, 29, 12)
    crystal(g, 9, 24, 12, 3)    # esquerdo
    crystal(g, 23, 24, 11, 3)   # direito
    crystal(g, 16, 22, 3, 5)    # central (mais alto, domina)
    # faíscas soltas
    for (x, y) in [(6, 14), (26, 13), (16, 1)]:
        put(g, x, y, AMBER_LIGHT)
    return g


def node():
    """Veia caída na exploração: minério meio enterrado numa poça de sangue (souls-like)."""
    g = blank()
    # poça de sangue sob o minério (mancha de morte) — larga e visível: marca o tile da queda
    ellipse_fill(g, 16, 26, 15, 5, BLOOD_DARK)
    ellipse_fill(g, 16, 25, 13, 4, BLOOD)
    for (x, y) in [(2, 25), (29, 24), (24, 30), (7, 30), (16, 31)]:
        put(g, x, y, BLOOD)
    # bloco de rocha repousando na poça
    rock_mound(g, 16, 15, 26, 13)
    # cristais erupcionando do bloco
    crystal(g, 11, 21, 9, 3)
    crystal(g, 22, 21, 10, 3)
    crystal(g, 16, 19, 2, 6)
    # respingo de luz quente no topo
    put(g, 16, 0, AMBER_TIP)
    put(g, 12, 6, AMBER_LIGHT)
    put(g, 21, 5, AMBER_LIGHT)
    return g


# ─── Saída ───────────────────────────────────────────────────────────────────
SPRITES = {
    "terra_rara_icon": icon,
    "terra_rara_node": node,
}


def main() -> None:
    out_dir = os.path.normpath(
        os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
    )
    for name, fn in SPRITES.items():
        grid = fn()
        path = os.path.join(out_dir, name + ".png")
        with open(path, "wb") as f:
            f.write(encode_png(grid))
        print(f"Gerado: {path}  ({len(grid[0])}x{len(grid)}px)")


if __name__ == "__main__":
    main()
