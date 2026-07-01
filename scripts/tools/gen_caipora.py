#!/usr/bin/env python3
"""Generate the Caipora protagonist sprites.

Canonical read: the silhouette board, not the refined illustration. The sprite
must read first as a violent orange cloak, a black void/animal body, two white
eyes, black horns, and a black staff. A tiny green crystal core remains only so
the FuriaVisual anchor has a visible in-world source.
"""

from __future__ import annotations

import math
import os
from dataclasses import dataclass

from PIL import Image, ImageDraw


OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
SIZE = 96
SS = 8
IDLE_FRAMES = 5        # idle vira loop de respiracao da capa (frame 0 = player_idle.png)
IDLE_BREATH_AMP = 1.6  # amplitude (px) do sobe/desce da bainha; corpo/olhos travados
WALK_FRAMES = 6        # walk vira ciclo de 6 frames (bounce do torso + overlap da capa)
IDLE_DIM_FRAMES = 2    # blink "olhos apagam": 2 frames sem olhos (loop=false)
WINDUP_FRAMES = 3      # windup coila em 3 frames (anticipacao mais funda)
STRIKE_FRAMES = 2      # strike ganha 1 frame de rastro/smear (loop=false)
RECOVER_FRAMES = 3     # recover: a capa chicoteia e assenta (loop=false)

TRANSPARENT = (0, 0, 0, 0)
ORANGE_DK = (139, 42, 0)
ORANGE = (255, 69, 0)
BLACK = (0, 0, 0)
EYE = (255, 255, 255)
CRYSTAL = (0, 250, 154)
CRYSTAL_HL = (138, 255, 204)
FIRE = (255, 104, 8)
FIRE_HOT = (255, 176, 50)
FIRE_CORE = (255, 239, 178)

# Selout chapado (F1.2): oclusao (sombra profunda) e realce (aresta iluminada)
# por material, dando volume estilo Cult of the Lamb sem gradiente. O realce
# nunca e branco puro (branco pertence so aos olhos). Familias travadas pelo
# teste (_count_orange_family/_count_dark_family) e pela lei (CONCEITO secao 3).
ORANGE_OCC = (90, 26, 0)     # #5a1a00
ORANGE_HI = (255, 122, 51)   # #ff7a33
FIRE_OCC = (194, 74, 8)      # #c24a08

# Paleta fechada POR VARIANTE (F1.2.1): o sprite BASE nunca deve encaixar cores
# da rampa CHAMA no snap (senao aparece franja quente na aresta preta) e a CHAMA
# nunca encaixa cores da rampa base. render() escolhe a rampa por rig.chama.
PALETTE_BASE = [
    ORANGE_DK,
    ORANGE,
    ORANGE_OCC,
    ORANGE_HI,
    BLACK,
    EYE,
    CRYSTAL,
    CRYSTAL_HL,
]
PALETTE_CHAMA = [
    FIRE_OCC,
    FIRE,
    FIRE_HOT,
    FIRE_CORE,
    BLACK,
    EYE,
    CRYSTAL,
    CRYSTAL_HL,
]


@dataclass(frozen=True)
class Rig:
    pose: str
    phase: int
    chama: bool
    head: tuple[float, float]
    body: tuple[float, float]
    foot_y: float
    lean: float
    staff_base: tuple[float, float]
    staff_tip: tuple[float, float]
    breath: float = 0.0
    bob: float = 0.0
    stretch: float = 0.0


class Painter:
    def __init__(self) -> None:
        self.im = Image.new("RGBA", (SIZE * SS, SIZE * SS), TRANSPARENT)
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

    def render(self, chama: bool = False) -> Image.Image:
        palette = PALETTE_CHAMA if chama else PALETTE_BASE
        small = self.im.resize((SIZE, SIZE), Image.Resampling.BOX)
        px = small.load()
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b, a = px[x, y]
                if a < 112:
                    px[x, y] = TRANSPARENT
                else:
                    px[x, y] = _nearest_palette((r, g, b), palette)
        return small


def _nearest_palette(
    color: tuple[int, int, int], palette: list[tuple[int, int, int]]
) -> tuple[int, int, int, int]:
    best = palette[0]
    best_d = 10**12
    for candidate in palette:
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
    for y in range(SIZE):
        for x in range(SIZE):
            if px[x, y][3] == 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx = x + ox
                ny = y + oy
                if not (0 <= nx < SIZE and 0 <= ny < SIZE) or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = BLACK + (255,)


def _rig(pose: str, phase: int, chama: bool, breath: float = 0.0, bob: float = 0.0, stretch: float = 0.0) -> Rig:
    lean_by_pose = {"idle": 0.0, "walk": phase * 0.8, "windup": -1.0, "strike": 7.0, "recover": 1.0, "back": 0.0, "dead": 0.0}
    crouch_by_pose = {"idle": 0.0, "walk": 0.0, "windup": 4.0, "strike": 1.0, "recover": 1.5, "back": 0.0, "dead": 0.0}
    lean = lean_by_pose[pose]
    crouch = crouch_by_pose[pose]
    head = (43.5 + lean * 0.35, 36.0 + crouch * 0.35 - bob)
    body = (43.0 + lean, 62.0 + crouch - bob)
    foot_y = 87.5 + crouch * 0.25
    if pose == "strike":
        staff_base = (31.0, 70.0)
        staff_tip = (75.0, 31.0)
    elif pose == "windup":
        staff_base = (66.5, 87.0)
        staff_tip = (62.0, 20.0)
    elif pose == "back":
        # Vista de costas: a mao da haste espelha para o outro lado da tela e a
        # lamina desponta ACIMA da capa (a haste em si some sob a juba).
        staff_base = (28.0, 88.0)
        staff_tip = (25.0, 14.0)
    else:
        staff_base = (66.5 + lean * 0.2, 88.0)
        staff_tip = (66.5 + lean * 0.2, 23.5)
    return Rig(pose, phase, chama, head, body, foot_y, lean, staff_base, staff_tip, breath, bob, stretch)


def _cloak_color(rig: Rig) -> tuple[int, int, int]:
    return FIRE if rig.chama else ORANGE


def _cloak_shadow(rig: Rig) -> tuple[int, int, int]:
    return FIRE_HOT if rig.chama else ORANGE_DK


def _cloak_occlusion(rig: Rig) -> tuple[int, int, int]:
    return FIRE_OCC if rig.chama else ORANGE_OCC


def _cloak_highlight(rig: Rig) -> tuple[int, int, int]:
    return FIRE_HOT if rig.chama else ORANGE_HI


def _draw_serrated_cloak(p: Painter, rig: Rig) -> None:
    hx, hy = rig.head
    bx, by = rig.body
    orange = _cloak_color(rig)
    shadow = _cloak_shadow(rig)

    if rig.pose == "strike":
        # `stretch` alonga o rastro no eixo do golpe (smear): escala a distancia
        # horizontal ao hx. stretch=0 -> identico ao contato canonico.
        s = 1.0 + rig.stretch

        def sx(dx: float, dy: float) -> tuple[float, float]:
            return (hx + dx * s, hy + dy)

        main = [
            sx(-13, -14), sx(10, -17), sx(24, -4), sx(31, 10), sx(28, 24),
            sx(38, 27), sx(24, 34), sx(12, 42), sx(-2, 39), sx(-15, 33),
            sx(-25, 20), sx(-33, 8), sx(-24, -2),
        ]
        p.poly(main, orange)
        p.poly([sx(15, 20), sx(36, 28), sx(8, 39)], shadow)
        # Selout do strike: oclusao dentro da sombra + realce na crista de ataque.
        p.poly([sx(20, 24), sx(33, 29), sx(12, 37)], _cloak_occlusion(rig))
        p.poly([sx(-11, -12), sx(7, -15), sx(1, -6), sx(-13, -5)], _cloak_highlight(rig))
        return

    left = bx - 31
    right = bx + 29
    top = hy - 18
    bottom = 86 + rig.breath  # respiracao: so a bainha sobe/desce (corpo/olhos travados)
    cloak = [
        (hx - 8, top + 3),
        (hx + 8, top),
        (right - 8, hy - 2),
        (right + 2, hy + 10),
        (right - 3, hy + 21),
        (right + 3, hy + 32),
        (right - 3, hy + 44),
        (right - 13, bottom - 3),
        (right - 25, bottom),
        (bx + 3, bottom - 4),
        (bx - 7, bottom),
        (bx - 17, bottom - 6),
        (left + 8, bottom - 2),
        (left + 2, hy + 47),
        (left - 7, hy + 42),
        (left - 1, hy + 34),
        (left - 10, hy + 28),
        (left - 3, hy + 20),
        (left - 11, hy + 13),
        (left + 1, hy + 4),
    ]
    p.poly(cloak, orange)

    shadow_pts = [
        (right - 13, hy + 13),
        (right - 10, hy + 34),
        (right - 17, bottom - 5),
        (bx + 5, bottom - 8),
        (bx + 9, hy + 30),
    ]
    p.poly(shadow_pts, shadow)

    # Selout (fill -> sombra -> oclusao -> realce): pool de oclusao profunda na
    # bainha inferior-direita (dentro da sombra) e realce na crista superior e no
    # flanco esquerdo (lado iluminado). Tudo INSET da borda -> sem halo (o
    # _outline preto fecha a silhueta).
    occ = _cloak_occlusion(rig)
    hi = _cloak_highlight(rig)
    p.poly(
        [
            (right - 12, hy + 34),
            (right - 14, bottom - 7),
            (bx + 6, bottom - 9),
            (bx + 9, hy + 37),
        ],
        occ,
    )
    p.poly(
        [
            (hx - 7, top + 3),
            (hx + 5, top + 1),
            (hx + 4, top + 6),
            (hx - 6, top + 8),
        ],
        hi,
    )
    p.poly(
        [
            (left - 1, hy + 1),
            (left + 4, hy),
            (left + 2, hy + 11),
            (left - 2, hy + 9),
        ],
        hi,
    )

    # Serrilhado ritmico e assimetrico (3 grandes + 2 pequenos) no flanco esquerdo,
    # ecoando as silhuetas da prancha — dentes desiguais leem mais organicos/premium.
    teeth = [
        (hy + 1, 10, 9),
        (hy + 11, 5, 6),
        (hy + 20, 11, 10),
        (hy + 31, 5, 6),
        (hy + 41, 9, 9),
    ]
    for i, (ty, depth, th) in enumerate(teeth):
        x = left - 1 + (i % 2) * 2
        p.poly([(x, ty), (x - depth, ty + th * 0.55), (x + 2, ty + th)], orange)

    if rig.chama:
        p.poly([(hx - 2, top - 1), (hx + 2, top - 13), (hx + 8, top)], FIRE_HOT)
        p.poly([(left + 5, hy + 6), (left - 6, hy - 5), (left + 13, hy + 2)], FIRE_HOT)
        p.poly([(right - 5, hy + 8), (right + 7, hy - 1), (right + 2, hy + 17)], FIRE_HOT)
        p.ellipse(hx + 1, top - 1, 2.5, 2.0, FIRE_CORE)


def _draw_face_and_horns(p: Painter, rig: Rig, eyes: bool = True) -> None:
    hx, hy = rig.head
    p.poly(
        [
            (hx - 12.5, hy - 8.0),
            (hx - 3.5, hy - 13.0),
            (hx + 10.5, hy - 8.5),
            (hx + 13.0, hy + 3.0),
            (hx + 5.5, hy + 11.0),
            (hx - 8.5, hy + 9.8),
            (hx - 14.0, hy + 0.5),
        ],
        BLACK,
    )
    if eyes:
        # Olhos IGUAIS (trava de marca): mesmo rx/ry/y, x simetrico. A FORMA muda
        # por pose, igual nos dois (CONCEITO 2.2): windup arregala, strike vira fenda.
        eye_rx = 2.4
        eye_ry = 2.6
        if rig.pose == "windup":
            eye_ry *= 1.3
        elif rig.pose == "strike":
            eye_ry *= 0.5
        p.ellipse(hx - 4.75, hy - 0.5, eye_rx, eye_ry, EYE)
        p.ellipse(hx + 4.75, hy - 0.5, eye_rx, eye_ry, EYE)

    p.limb((hx - 7.5, hy - 10.0), (hx - 12.0, hy - 19.0), 4.3, 2.2, BLACK)
    p.limb((hx - 12.0, hy - 19.0), (hx - 9.5, hy - 24.0), 2.1, 1.0, BLACK)
    p.limb((hx + 7.5, hy - 9.8), (hx + 12.0, hy - 19.5), 4.3, 2.2, BLACK)
    p.limb((hx + 12.0, hy - 19.5), (hx + 10.0, hy - 24.6), 2.1, 1.0, BLACK)


def _draw_black_body(p: Painter, rig: Rig) -> None:
    bx, by = rig.body
    if rig.pose == "strike":
        p.ellipse(bx + 5, by + 3, 10.0, 14.0, BLACK)
        p.limb((bx - 1, by + 5), (bx - 25, by + 10), 4.2, 3.0, BLACK)
        p.limb((bx + 8, by + 13), (bx + 2, rig.foot_y), 5.0, 3.5, BLACK)
        p.limb((bx + 2, rig.foot_y), (bx + 10, rig.foot_y + 1), 3.0, 2.0, BLACK)
        p.limb((bx + 15, by + 14), (bx + 21, rig.foot_y - 2), 5.0, 3.0, BLACK)
        return

    p.poly(
        [
            (bx - 8, by - 12),
            (bx + 5, by - 10),
            (bx + 10, by + 4),
            (bx + 5, by + 17),
            (bx - 5, by + 19),
            (bx - 11, by + 5),
        ],
        BLACK,
    )
    p.limb((bx - 7, by + 11), (bx - 8 - rig.phase * 2, rig.foot_y), 4.4, 2.8, BLACK)
    p.limb((bx + 5, by + 12), (bx + 8 + rig.phase * 2, rig.foot_y), 4.4, 2.8, BLACK)
    p.limb((bx - 8 - rig.phase * 2, rig.foot_y), (bx - 13 - rig.phase * 2, rig.foot_y + 1), 2.6, 1.8, BLACK)
    p.limb((bx + 8 + rig.phase * 2, rig.foot_y), (bx + 13 + rig.phase * 2, rig.foot_y + 1), 2.6, 1.8, BLACK)


def _draw_staff(p: Painter, rig: Rig) -> None:
    p.limb(rig.staff_base, rig.staff_tip, 3.0, 3.0, BLACK)
    tx, ty = rig.staff_tip
    if rig.pose == "strike":
        blade = [(tx - 3, ty - 3), (tx + 8, ty - 11), (tx + 5, ty + 3), (tx + 13, ty + 7), (tx + 1, ty + 8)]
    else:
        blade = [(tx - 4, ty + 2), (tx + 2, ty - 12), (tx + 9, ty - 3), (tx + 5, ty + 8)]
    p.poly(blade, BLACK)
    # Tiny green core: preserves the Furia anchor without stealing silhouette.
    p.ellipse(tx, ty, 1.1, 1.1, CRYSTAL)


def _draw_dead(p: Painter, chama: bool) -> None:
    """Tombada no chão (final do sacrifício): juba drapejada como mortalha sobre
    o corpo deitado, cabeca pousada à esquerda SEM olhos (o vazio fechou),
    pés despontando à direita e o cajado caído à frente. Sem pose heroica."""
    orange = FIRE if chama else ORANGE
    shadow = FIRE_HOT if chama else ORANGE_DK

    # Cabeça tombada, orelha no chão; chifres: um fincado na terra, outro ao alto.
    p.ellipse(22.0, 72.0, 11.0, 9.5, BLACK)
    p.limb((16.0, 66.0), (8.0, 58.0), 4.3, 2.0, BLACK)
    p.limb((8.0, 58.0), (6.0, 53.0), 2.0, 1.0, BLACK)
    p.limb((26.0, 64.0), (30.0, 54.0), 4.3, 2.0, BLACK)
    p.limb((30.0, 54.0), (29.0, 49.0), 2.0, 1.0, BLACK)

    # Pés/pernas largados despontando do lado direito da mortalha.
    p.limb((70.0, 76.0), (84.0, 74.0), 5.0, 3.0, BLACK)
    p.limb((68.0, 80.0), (82.0, 81.0), 5.0, 3.0, BLACK)

    # A juba-capa cobre o corpo como um monte serrilhado baixo.
    heap = [
        (26.0, 80.0),
        (30.0, 66.0),
        (38.0, 59.0),
        (35.0, 53.0),
        (44.0, 56.0),
        (52.0, 52.0),
        (54.0, 58.0),
        (63.0, 56.0),
        (62.0, 62.0),
        (72.0, 64.0),
        (68.0, 70.0),
        (76.0, 76.0),
        (70.0, 82.0),
        (56.0, 84.0),
        (40.0, 84.0),
    ]
    p.poly(heap, orange)
    p.poly([(54.0, 62.0), (70.0, 68.0), (64.0, 80.0), (48.0, 80.0)], shadow)
    # Selout tambem na mortalha, coerente com as outras poses (chama-aware).
    occ = FIRE_OCC if chama else ORANGE_OCC
    hi = FIRE_HOT if chama else ORANGE_HI
    p.poly([(37.0, 55.0), (44.0, 53.5), (51.0, 53.5), (49.0, 56.0), (43.0, 56.5), (37.0, 57.0)], hi)
    p.poly([(57.0, 67.0), (69.0, 69.5), (65.0, 78.0), (55.0, 77.0)], occ)

    # O cajado caiu junto: haste no chão, lâmina morta apontando para longe.
    p.limb((30.0, 90.0), (74.0, 88.0), 2.8, 2.8, BLACK)
    blade = [(74.0, 84.0), (82.0, 80.0), (86.0, 87.0), (78.0, 91.0)]
    p.poly(blade, BLACK)
    p.ellipse(79.0, 86.0, 1.1, 1.1, CRYSTAL)


def caipora(pose: str = "idle", leg_phase: int = 0, chama: bool = False, breath: float = 0.0, bob: float = 0.0, stretch: float = 0.0, eyes: bool = True) -> Image.Image:
    rig = _rig(pose, leg_phase, chama, breath, bob, stretch)
    p = Painter()
    if pose == "dead":
        _draw_dead(p, chama)
        img = p.render(chama)
        _outline(img)
        return img
    if pose == "back":
        # De costas a juba-capa cobre o corpo: corpo e haste por BAIXO da capa,
        # cabeca/chifres por cima e SEM olhos — ela olha para dentro da cena.
        _draw_black_body(p, rig)
        _draw_staff(p, rig)
        _draw_serrated_cloak(p, rig)
        _draw_face_and_horns(p, rig, eyes=False)
    else:
        _draw_serrated_cloak(p, rig)
        _draw_black_body(p, rig)
        _draw_staff(p, rig)
        _draw_face_and_horns(p, rig, eyes)
    img = p.render(chama)
    _outline(img)
    return img


POSES = [
    ("player_idle.png", "idle", 0),
    ("player_windup.png", "windup", 0),
    ("player_strike.png", "strike", 0),
    ("player_recover.png", "recover", 0),
    ("player_back.png", "back", 0),
    ("player_dead.png", "dead", 0),
]


def _make_contact_sheet() -> None:
    frames: list[tuple[str, Image.Image, Image.Image]] = []
    for name, pose, phase in POSES:
        base = caipora(pose, phase)
        chama = caipora(pose, phase, chama=True)
        frames.append((name.replace("player_", "").replace(".png", ""), base, chama))

    cell = 208
    label_h = 14
    sheet = Image.new("RGBA", (cell * len(frames), cell * 2 + label_h), (18, 14, 15, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (label, base, chama) in enumerate(frames):
        x = i * cell
        for row, img in enumerate((base, chama)):
            big = img.resize((SIZE * 2, SIZE * 2), Image.Resampling.NEAREST)
            sheet.alpha_composite(big, (x + 8, label_h + row * cell + 8))
        draw.text((x + 6, 1), label, fill=(230, 210, 180, 255))
    sheet.save(os.path.join(OUT, "caipora_pop_dark_contact_sheet.png"))


# Contrato do SpriteFrames: os NOMES das animacoes sao estaveis (ActorAnimator e
# cenas so dependem deles). Cada frame name mapeia para player_<name>[_chama].png.
_ANIMATIONS: list[tuple[str, list[str], bool, float]] = [
    ("default", [], True, 5.0),
    ("idle", ["idle"] + [f"idle_{i:02d}" for i in range(1, IDLE_FRAMES)], True, 5.0),
    ("idle_dim", [f"idle_dim_{i}" for i in range(1, IDLE_DIM_FRAMES + 1)], False, 12.0),
    ("walk", [f"walk_{i + 1}" for i in range(WALK_FRAMES)], True, 8.0),
    ("windup", ["windup"] + [f"windup_{i}" for i in range(1, WINDUP_FRAMES)], False, 9.0),
    ("strike", ["strike"] + [f"strike_{i}" for i in range(1, STRIKE_FRAMES)], False, 12.0),
    ("recover", ["recover"] + [f"recover_{i}" for i in range(1, RECOVER_FRAMES)], False, 14.0),
]


def _write_sprite_frames(chama: bool) -> None:
    """Emite o .tres deterministicamente (base E chama pelo MESMO codigo -> a
    simetria de contrato base<->chama sai por construcao)."""
    suffix = "_chama" if chama else ""
    order: list[str] = []
    for _name, frames, _loop, _speed in _ANIMATIONS:
        for fr in frames:
            if fr not in order:
                order.append(fr)
    ids = {fr: f"{i + 1}_{fr}" for i, fr in enumerate(order)}
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for fr in order:
        path = f"res://assets/sprites/player_{fr}{suffix}.png"
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
    with open(os.path.join(OUT, f"caipora_sprite_frames{suffix}.tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


# Ciclo de caminhada: 6 frames DISTINTOS (leg_swing, bob, cloak_breath). bob
# levanta o torso (pes plantados) num sobe/desce de passada; a capa segue com
# defasagem (overlap/secondary motion). Keyframes a mao (o rig frontal nao vira
# walk-cycle real por 1 seno so).
_WALK_CYCLE = [
    (-1.0, 0.2, -0.6),
    (-0.3, 1.5, 0.4),
    (0.6, 0.6, 1.3),
    (1.0, 0.2, 0.6),
    (0.3, 1.5, -0.4),
    (-0.6, 0.6, -1.2),
]

_WINDUP_COIL = [-1.2, -2.2]  # bob dos 2 frames extras do windup (coil progressivo)
_RECOVER_WHIP = [2.5, -1.0]  # breath dos frames extras do recover (capa chicoteia e assenta)
_STRIKE_TRAIL = [0.35]       # stretch do frame extra do strike (rastro/smear)


def generate_all() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, pose, phase in POSES:
        caipora(pose, phase).save(os.path.join(OUT, name))
        caipora(pose, phase, chama=True).save(os.path.join(OUT, name.replace(".png", "_chama.png")))
    # Idle multi-frame: respiracao da capa. Frame 0 = player_idle.png (ja salvo,
    # breath=0 -> byte-identico); frames 1..N-1 variam SO a bainha.
    for i in range(1, IDLE_FRAMES):
        breath = math.sin(2.0 * math.pi * i / IDLE_FRAMES) * IDLE_BREATH_AMP
        caipora("idle", 0, breath=breath).save(os.path.join(OUT, f"player_idle_{i:02d}.png"))
        caipora("idle", 0, chama=True, breath=breath).save(
            os.path.join(OUT, f"player_idle_{i:02d}_chama.png")
        )
    # Walk multi-frame: ciclo de passada (bounce + overlap da capa).
    for i, (swing, bob, cbreath) in enumerate(_WALK_CYCLE):
        caipora("walk", swing, breath=cbreath, bob=bob).save(
            os.path.join(OUT, f"player_walk_{i + 1}.png")
        )
        caipora("walk", swing, chama=True, breath=cbreath, bob=bob).save(
            os.path.join(OUT, f"player_walk_{i + 1}_chama.png")
        )
    # Blink: olhos apagam (o vazio os engole; eyes=False no idle). NAO e palpebra.
    for i in range(1, IDLE_DIM_FRAMES + 1):
        breath = 0.0 if i == 1 else 1.0
        caipora("idle", 0, eyes=False, breath=breath).save(
            os.path.join(OUT, f"player_idle_dim_{i}.png")
        )
        caipora("idle", 0, chama=True, eyes=False, breath=breath).save(
            os.path.join(OUT, f"player_idle_dim_{i}_chama.png")
        )
    # Windup: a anticipacao coila mais fundo (bob negativo) frame a frame.
    for i, wbob in enumerate(_WINDUP_COIL, start=1):
        caipora("windup", 0, bob=wbob).save(os.path.join(OUT, f"player_windup_{i}.png"))
        caipora("windup", 0, chama=True, bob=wbob).save(
            os.path.join(OUT, f"player_windup_{i}_chama.png")
        )
    # Recover: a capa chicoteia pra frente e assenta (breath overshoot).
    for i, rbreath in enumerate(_RECOVER_WHIP, start=1):
        caipora("recover", 0, breath=rbreath).save(os.path.join(OUT, f"player_recover_{i}.png"))
        caipora("recover", 0, chama=True, breath=rbreath).save(
            os.path.join(OUT, f"player_recover_{i}_chama.png")
        )
    # Strike: frame extra de rastro/smear (a capa alonga no eixo do golpe).
    for i, strk in enumerate(_STRIKE_TRAIL, start=1):
        caipora("strike", 0, stretch=strk).save(os.path.join(OUT, f"player_strike_{i}.png"))
        caipora("strike", 0, chama=True, stretch=strk).save(
            os.path.join(OUT, f"player_strike_{i}_chama.png")
        )
    _write_sprite_frames(False)
    _write_sprite_frames(True)
    _make_contact_sheet()
    print(f"[gen_caipora] Caipora: idle {IDLE_FRAMES}f + walk {WALK_FRAMES}f + poses (base+CHAMA) + 2 .tres + sheet")


if __name__ == "__main__":
    generate_all()
