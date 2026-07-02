#!/usr/bin/env python3
"""Generate the Boitatá arena sprites — premium flat pipeline (v2).

Art law: docs/CONCEITO-boitata.md. The Boitatá is the Phase 2 boss: a giant
serpent of corpse-fire coiled like a burning rampart, watching the road.

v2 — the Caipora mirror-read (molde Mula v3): the body is a flat
CHARRED-BLACK mass (its own warm-black family, never the Mula's cold void)
and the fire is her "juba" — a serrated crest of DELIBERATE flame teeth
running the spine from nape to tail, with flat 4-tone selout
(deep → fire → hot → white spectral heart). Slit fire-eyes (never the
protagonist's white dots), ash horns, segmented belly plates, blood scars
and a few FIXED corpse-lights. It faces LEFT, at the Caipora.

Pipeline: deliberate vector shapes on the 160×128 canvas, supersampled 8x,
area-downsampled, closed-palette snap, continuous 1px dark outline.
Fully deterministic — no RNG anywhere.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw


OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
SIZE = (160, 128)
SS = 8

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (26, 18, 10)          # #1a120a — contorno do mundo (padronizado na v2)

# ── Boitatá palette (closed) ────────────────────────
CHAR_DK = (12, 7, 6)            # oclusão / mandíbula / vãos das placas
CHAR = (24, 12, 9)              # corpo carbonizado — massa preta-quente
CHAR_EDGE = (46, 22, 16)        # acento chapado de borda (brasa sob a casca)
SCALE_DK = (72, 22, 13)         # placa de barriga, tom fundo
SCALE = (132, 38, 19)           # placa de barriga, escama vermelho-queimada
FIRE_DEEP = (168, 44, 10)       # dente da crista, camada externa (oclusão)
FIRE = (226, 87, 24)            # corpo da chama
FIRE_HOT = (255, 178, 72)       # realce da chama
FIRE_WHITE = (255, 232, 174)    # coração espectral (fogo-fátuo; nunca branco puro)
ASH = (126, 119, 98)            # chifres/raízes de cinza
BLOOD = (139, 0, 0)             # cicatrizes/sangue material
EYE = (250, 203, 83)            # olhos em fenda quentes

PALETTE = [
    OUTLINE,
    CHAR_DK,
    CHAR,
    CHAR_EDGE,
    SCALE_DK,
    SCALE,
    FIRE_DEEP,
    FIRE,
    FIRE_HOT,
    FIRE_WHITE,
    ASH,
    BLOOD,
    EYE,
]


class Painter:
    def __init__(self) -> None:
        self.im = Image.new("RGBA", (SIZE[0] * SS, SIZE[1] * SS), TRANSPARENT)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts: list[tuple[float, float]], col: tuple[int, int, int]) -> None:
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=col)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col: tuple[int, int, int]) -> None:
        self.d.ellipse(
            [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS],
            fill=col,
        )

    def limb(
        self,
        a: tuple[float, float],
        b: tuple[float, float],
        wa: float,
        wb: float,
        col: tuple[int, int, int],
    ) -> None:
        x0, y0 = a
        x1, y1 = b
        dx = x1 - x0
        dy = y1 - y0
        length = math.hypot(dx, dy) or 1.0
        nx = -dy / length
        ny = dx / length
        self.poly(
            [
                (x0 + nx * wa / 2, y0 + ny * wa / 2),
                (x1 + nx * wb / 2, y1 + ny * wb / 2),
                (x1 - nx * wb / 2, y1 - ny * wb / 2),
                (x0 - nx * wa / 2, y0 - ny * wa / 2),
            ],
            col,
        )
        self.ellipse(x0, y0, wa / 2, wa / 2, col)
        self.ellipse(x1, y1, wb / 2, wb / 2, col)

    def render(self) -> Image.Image:
        small = self.im.resize(SIZE, Image.Resampling.BOX)
        px = small.load()
        for y in range(SIZE[1]):
            for x in range(SIZE[0]):
                r, g, b, a = px[x, y]
                if a < 112:
                    px[x, y] = TRANSPARENT
                else:
                    px[x, y] = _nearest_palette((r, g, b))
        return small


def _nearest_palette(color: tuple[int, int, int]) -> tuple[int, int, int, int]:
    best = PALETTE[0]
    best_d = 10**12
    for candidate in PALETTE:
        d = (
            (color[0] - candidate[0]) ** 2
            + (color[1] - candidate[1]) ** 2
            + (color[2] - candidate[2]) ** 2
        )
        if d < best_d:
            best = candidate
            best_d = d
    return best + (255,)


def _outline(img: Image.Image) -> None:
    px = img.load()
    edge: list[tuple[int, int]] = []
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] == 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx = x + ox
                ny = y + oy
                if not (0 <= nx < img.width and 0 <= ny < img.height) or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = OUTLINE + (255,)


# ── Pose channels ─────────────────────────────────────────
# rise  : 0 → 1  windup (cabeça/pescoço ERGUEM, espirais apertam, crista incha)
# breath: −1 → 1 respiração das espirais (E2)
# flame : 0 → 1  fase da crista/faíscas (E2)

_GROUND_Y = 112.5   # base da massa (banda dos pés do contrato: bottom ∈ [110,116])


def _lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _flame_tooth(
    p: Painter,
    x: float,
    y: float,
    h: float,
    lean: float,
    flame: float,
    white_heart: bool = False,
) -> None:
    """Um dente deliberado da crista de fogo, selout chapado 3-4 tons."""
    wob = math.sin(math.tau * (flame + x * 0.05)) * h * 0.07 if flame > 0.0 else 0.0
    hh = max(h + wob, 2.0)
    # A ponta nunca clipa o topo do canvas (contrato de bbox/escala).
    tip_y = max(y - hh, 1.5)
    w = h * 0.45
    p.poly([(x - w, y), (x + lean, tip_y), (x + w * 0.7, y + 1.0)], FIRE_DEEP)
    p.poly([(x - w * 0.62, y), (x + lean * 0.8, y - (y - tip_y) * 0.78), (x + w * 0.45, y + 0.5)], FIRE)
    p.poly([(x - w * 0.32, y), (x + lean * 0.5, y - (y - tip_y) * 0.5), (x + w * 0.2, y)], FIRE_HOT)
    if white_heart:
        p.ellipse(x + lean * 0.2, y - hh * 0.24, w * 0.3, hh * 0.2, FIRE_WHITE)


def _draw_coils(p: Painter, rise: float, breath: float) -> None:
    """Dois patamares de espiral em massa preta-carbonizada chapada.

    Fim das elipses moles: a informação vive na silhueta — dentes duros no
    dorso do patamar de trás e no rabo. A largura é assinatura (>120px bbox).
    """
    b = breath * 1.2
    t = rise * 2.0      # espirais apertam/erguem levemente no windup
    # Patamar de base (encosta no chão) — dorso com entalhes duros à direita.
    p.poly([
        (34.0, 86.0 - b * 0.4),
        (52.0, 80.0 - b),
        (78.0, 78.0 - b),
        (106.0, 80.0 - b * 0.6),
        (112.0, 74.0 - b * 0.6),          # entalhe →
        (116.0, 82.0),
        (124.0, 77.0),                    # entalhe →
        (128.0, 84.0),
        (142.0, 92.0),
        (146.0, 104.0),
        (138.0, _GROUND_Y),
        (44.0, _GROUND_Y),
        (36.0, 103.0),
    ], CHAR)
    # Patamar de cima (a espiral que carrega a crista) — aperta no windup.
    p.poly([
        (50.0 - t * 0.8, 81.0),
        (60.0 - t, 64.0 - t),
        (84.0 - t, 60.0 - t),
        (108.0 - t, 64.0 - t * 0.5),
        (122.0 - t, 72.0),
        (118.0, 82.0),
        (60.0, 84.0),
    ], CHAR)
    # Oclusão chapada onde um patamar assenta no outro (um tom, faixa curta —
    # os patamares se fundem nas pontas, a sombra só vive no vão central).
    p.poly([
        (62.0, 80.5), (110.0, 78.5), (111.0, 83.0), (63.0, 84.5),
    ], CHAR_DK)
    # Acento de borda no dorso do patamar de cima — a brasa sob a casca.
    p.poly([
        (60.0 - t, 64.0 - t), (84.0 - t, 60.0 - t), (108.0 - t, 64.0 - t * 0.5),
        (108.0 - t, 66.6 - t * 0.5), (84.0 - t, 62.6 - t), (60.0 - t, 66.6 - t),
    ], CHAR_EDGE)


def _draw_tail(p: Painter, flame: float) -> None:
    """Rabo emergindo da espiral à direita, dentes duros e brasa na ponta."""
    p.poly([
        (128.0, 84.0),
        (144.0, 79.0),
        (152.0, 85.0),                    # dente →
        (147.0, 91.0),
        (154.0, 97.0),                    # dente →
        (145.0, 103.0),
        (136.0, 98.0),
    ], CHAR)
    # Brasa da ponta do rabo (eco da crista, mínima).
    _flame_tooth(p, 149.0, 94.0, 6.0, 1.5, flame)


def _draw_belly_plates(p: Painter) -> None:
    """Placas de barriga segmentadas — a leitura clássica de serpente, chapada."""
    p.poly([
        (44.0, 98.0), (126.0, 96.0), (134.0, 104.0), (132.0, 109.0), (42.0, 109.0),
    ], SCALE)
    p.poly([
        (44.0, 98.0), (126.0, 96.0), (127.5, 99.5), (45.0, 101.5),
    ], SCALE_DK)
    # Vãos entre as placas (segmentação) — um tom, traço duro.
    for gx in (58.0, 72.0, 86.0, 100.0, 114.0):
        p.limb((gx, 97.5), (gx - 1.5, 109.0), 1.6, 1.6, CHAR_DK)
    # Cicatrizes de sangue: o horror é material.
    p.limb((118.0, 88.0), (127.0, 95.0), 2.0, 1.2, BLOOD)
    p.ellipse(48.0, 110.0, 3.0, 1.0, BLOOD)


# Crista da espinha: dentes DELIBERADOS sobre o dorso do patamar de cima —
# (x, base_y, altura). O maior fica atrás da nuca; escada decrescente rabo afora.
_SPINE_TEETH = [
    (64.0, 64.5, 15.0),
    (71.0, 62.0, 12.0),
    (78.0, 60.5, 13.0),
    (85.0, 60.5, 10.0),
    (92.0, 62.0, 11.0),
    (99.0, 63.5, 8.0),
    (106.0, 65.5, 9.0),
]


def _draw_crest(p: Painter, rise: float, flame: float) -> None:
    """A "juba" do Boitatá: crista de fogo serrilhada correndo a espinha.

    Uma cumeeira contínua conecta os dentes na base — a crista é UMA massa
    serrilhada (linguagem da juba/coroa), nunca velas soltas."""
    t = rise * 2.0
    grow = 1.0 + rise * 0.35
    p.poly([
        (58.0 - t, 67.0 - t),
        (78.0 - t, 62.5 - t),
        (110.0 - t, 67.5 - t * 0.5),
        (110.0 - t, 71.0 - t * 0.5),
        (78.0 - t, 66.5 - t),
        (58.0 - t, 71.0 - t),
    ], FIRE_DEEP)
    for i, (x, y, h) in enumerate(_SPINE_TEETH):
        _flame_tooth(p, x - t, y - t * 0.8 + 1.0, h * grow, 2.5, flame, white_heart=(i == 0))


def _draw_neck_head(p: Painter, rise: float, flame: float) -> None:
    """Pescoço-S de vigia erguendo no windup; cabeça em cunha apontada à esquerda."""
    base = _lerp((86.0, 76.0), (88.0, 72.0), rise)
    mid = _lerp((72.0, 60.0), (80.0, 42.0), rise)
    head = _lerp((54.0, 46.0), (68.0, 26.0), rise)
    hx, hy = head

    p.limb(base, mid, 16.0, 13.0, CHAR)
    p.limb(mid, (hx + 8.0, hy + 8.0), 13.0, 11.0, CHAR)
    # Dentes da nuca — a crista nasce atrás da cabeça e acompanha o pescoço.
    _flame_tooth(p, mid[0] + 6.0, mid[1] - 3.0, 12.0 * (1.0 + rise * 0.3), 2.0, flame, white_heart=True)
    _flame_tooth(p, mid[0] + 12.0, mid[1] + 5.0, 9.0 * (1.0 + rise * 0.3), 2.0, flame)

    # Cabeça em cunha angular (leitura de víbora), massa preta chapada.
    p.poly([
        (hx + 14.0, hy - 8.0),
        (hx - 4.0, hy - 11.0),
        (hx - 20.0, hy - 4.0),
        (hx - 27.0, hy + 5.0),            # focinho
        (hx - 19.0, hy + 13.0),
        (hx + 2.0, hy + 16.0),
        (hx + 15.0, hy + 10.0),
    ], CHAR)
    # Acento chapado no topo do crânio.
    p.poly([
        (hx - 4.0, hy - 11.0), (hx - 20.0, hy - 4.0), (hx - 17.5, hy - 1.8),
        (hx - 3.0, hy - 8.4),
    ], CHAR_EDGE)
    # Mandíbula — abre no windup (jaw_open) para a boca de fogo-fátuo.
    jaw = rise * 8.0
    p.poly([
        (hx - 8.0, hy + 12.0),
        (hx - 24.0, hy + 16.0 + jaw),
        (hx - 2.0, hy + 18.0 + jaw * 0.4),
    ], CHAR_DK)

    # Chifres/raízes de cinza; olhos em FENDA quente (nunca ponto branco).
    p.limb((hx - 2.0, hy - 9.0), (hx - 11.0, hy - 23.0), 3.0, 1.2, ASH)
    p.limb((hx + 8.0, hy - 7.0), (hx + 16.0, hy - 20.0), 3.0, 1.2, ASH)
    p.ellipse(hx - 7.0, hy + 1.0, 3.4, 1.0, EYE)
    p.ellipse(hx + 5.0, hy + 0.5, 3.0, 0.9, EYE)

    if rise > 0.5:
        # Boca acesa de fogo-fátuo — o coração espectral do especial.
        p.ellipse(hx - 8.0, hy + 13.0 + jaw * 0.5, 7.5, 5.5, FIRE_WHITE)
        p.ellipse(hx - 8.0, hy + 13.0 + jaw * 0.5, 4.5, 3.2, FIRE_HOT)
    else:
        # Língua de fogo provando o ar.
        p.limb((hx - 20.0, hy + 8.0), (hx - 32.0, hy + 6.0), 1.6, 0.7, FIRE_HOT)


def _draw_ground_fire(p: Painter, rise: float, flame: float) -> None:
    """Fogo-cadáver rente ao chão flanqueando a espiral — deliberado, 2 línguas."""
    _flame_tooth(p, 24.0, 108.0, 15.0 * (1.0 + rise * 0.2), -2.0, flame)
    _flame_tooth(p, 139.0, 109.0, 9.0, 2.0, flame)


_SPARKS = [
    (27.0, 40.0, 1.7),
    (101.0, 43.0, 1.2),
    (141.0, 64.0, 1.5),
]


def _draw_sparks(p: Painter, rise: float, flame: float) -> None:
    """Fogos-fátuos fixos orbitando a serpente — poucos e deliberados."""
    for i, (x, y, r) in enumerate(_SPARKS):
        drift = math.sin(math.tau * (flame + i * 0.31)) * 2.0 if flame > 0.0 else 0.0
        p.ellipse(x + drift * 0.4, y - rise * 4.0 - drift, r, r, FIRE_HOT)
        p.ellipse(x + drift * 0.4, y - rise * 4.0 - drift + r * 1.2, r * 0.55, r * 0.55, FIRE)


def boitata(pose: str = "idle", *, rise: float | None = None,
        breath: float = 0.0, flame: float = 0.0) -> Image.Image:
    """Compose one frame. Pose presets set the rise channel; keyframes override."""
    if rise is None:
        rise = 1.0 if pose == "windup" else 0.0
    p = Painter()
    _draw_ground_fire(p, rise, flame)
    _draw_sparks(p, rise, flame)
    _draw_tail(p, flame)
    _draw_coils(p, rise, breath)
    _draw_crest(p, rise, flame)
    _draw_belly_plates(p)
    _draw_neck_head(p, rise, flame)
    img = p.render()
    _outline(img)
    return img


# ── Animation contract ────────────────────────────────────
# Nomes estáveis: boitata.tscn/camp_spirit/boss_intro dependem só deles.
# idle  — 5f loop: respiração das espirais (seno) + fase da crista/faíscas.
#         Frame 0 = boitata_idle.png (canais zerados — âncora byte-estável).
# windup — 3f build-up do rise (0.45→0.78→1.0); loop=false segura o último
#         frame = boitata_windup.png. 3f @ 15fps = 0.2s — cabe no wind_up
#         mais curto do kit dele (Brasa Rasteira, 0.2s).
IDLE_FRAMES = 5
_IDLE_KEYS = [
    (0.0, 0.0),                        # (breath, flame) — frame 0 canônico
    (0.951, 0.2),
    (0.588, 0.4),
    (-0.588, 0.6),
    (-0.951, 0.8),
]
_WINDUP_KEYS = [
    (0.45, 0.35),                      # (rise, flame) — a vigia se ergue
    (0.78, 0.7),                       # espirais apertam, crista inchando
    (1.0, 0.0),                        # pose canônica, segurada pelo loop=false
]

_ANIMATIONS: list[tuple[str, list[str], bool, float]] = [
    ("idle", ["idle"] + [f"idle_{i:02d}" for i in range(1, IDLE_FRAMES)], True, 5.0),
    ("windup", [f"windup_{i}" for i in range(1, len(_WINDUP_KEYS))] + ["windup"], False, 15.0),
]


def _write_sprite_frames() -> None:
    """Emite boitata_sprite_frames.tres deterministicamente (formato do .tres
    escrito à mão que ele substitui: format=3, sem uid, ext_resource por path)."""
    order: list[str] = []
    for _name, frames, _loop, _speed in _ANIMATIONS:
        for fr in frames:
            if fr not in order:
                order.append(fr)
    ids = {fr: f"{i + 1}_{fr}" for i, fr in enumerate(order)}
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for fr in order:
        path = f"res://assets/sprites/boitata_{fr}.png"
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{ids[fr]}"]')
    lines.append("")
    lines.append("[resource]")
    blocks: list[str] = []
    for name, frames, loop, speed in _ANIMATIONS:
        entries = ", ".join(
            '{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % ids[fr] for fr in frames
        )
        blocks.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
            % (entries, "true" if loop else "false", name, f"{speed:.1f}")
        )
    lines.append("animations = [" + ", ".join(blocks) + "]")
    with open(os.path.join(OUT, "boitata_sprite_frames.tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


def _frame_images() -> dict[str, Image.Image]:
    """Render every animation frame keyed by its PNG stem (sans boitata_)."""
    frames: dict[str, Image.Image] = {}
    for i, (breath, flame) in enumerate(_IDLE_KEYS):
        key = "idle" if i == 0 else f"idle_{i:02d}"
        frames[key] = boitata("idle", breath=breath, flame=flame)
    for i, (rise, flame) in enumerate(_WINDUP_KEYS):
        key = "windup" if i == len(_WINDUP_KEYS) - 1 else f"windup_{i + 1}"
        frames[key] = boitata("windup", rise=rise, flame=flame)
    return frames


def _contact_sheet(frames: dict[str, Image.Image]) -> None:
    """Contact sheet: uma linha por animação + a Caipora para escala/traço."""
    rows: list[tuple[str, list[str]]] = [(name, keys) for name, keys, _l, _s in _ANIMATIONS]
    cell_w = SIZE[0] + 16
    cell_h = SIZE[1] + 16
    label_h = 22
    cols = max(len(keys) for _n, keys in rows)
    caipora_path = os.path.join(OUT, "player_idle.png")
    ref = Image.open(caipora_path).convert("RGBA") if os.path.exists(caipora_path) \
        else Image.new("RGBA", (1, 1), TRANSPARENT)
    sheet_w = cell_w * cols + ref.size[0] + 48
    sheet_h = (cell_h + label_h) * len(rows)
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (18, 14, 15, 255))
    draw = ImageDraw.Draw(sheet)

    for r, (name, keys) in enumerate(rows):
        y = r * (cell_h + label_h)
        draw.text((16, y + 4), f"boitata {name} ({len(keys)}f)", fill=(230, 210, 180, 255))
        for c, key in enumerate(keys):
            sheet.alpha_composite(frames[key], (16 + c * cell_w, y + label_h))

    ref_x = cell_w * cols + 24
    draw.text((ref_x, 4), "caipora ref (96px)", fill=(230, 210, 180, 255))
    sheet.alpha_composite(ref, (ref_x, label_h))

    sheet.save(os.path.join(OUT, "boitata_contact_sheet.png"))


def generate_all() -> None:
    os.makedirs(OUT, exist_ok=True)
    frames = _frame_images()
    for key, img in frames.items():
        img.save(os.path.join(OUT, f"boitata_{key}.png"))
    _write_sprite_frames()
    _contact_sheet(frames)
    print(
        "[gen_boitata] Boitatá v2: %d frames (160x128) + sprite_frames.tres + contact sheet"
        % len(frames)
    )


if __name__ == "__main__":
    generate_all()
