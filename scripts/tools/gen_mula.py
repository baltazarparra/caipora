#!/usr/bin/env python3
"""Generate the Mula sem Cabeça boss sprites — premium flat pipeline (v3).

Art law: docs/CONCEITO-mula.md. The Mula is the Phase 1 boss: a headless
mule whose neck stump jets a serrated column of fire, wearing a blood-red
cursed harness and shining iron horseshoes.

v3 — the Caipora mirror-read: the body is a flat BLACK-VOID mass (like the
protagonist's body/horns) and the fire column is her "juba" — the dominant
serrated hot mass, drawn as DELIBERATE hard teeth (never jag-noise), with
flat 4-tone selout (deep → mid → hot → core). No rim light, no random
embers, no soft gradients. She faces LEFT, at the Caipora, like every enemy.

Pipeline: deliberate vector shapes on a 64 logical grid, supersampled 8x,
area-downsampled to 192x192, closed-palette snap, continuous 1px dark outline.
Fully deterministic — no RNG anywhere.
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw


OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites")
SIZE = 192
GRID = 64
SS = 8

TRANSPARENT = (0, 0, 0, 0)
OUTLINE = (26, 18, 10)          # #1a120a

# ── Mula palette (closed) ───────────────────────────
VOID_DK = (10, 7, 8)            # #0a0708 far legs / occlusion
VOID = (21, 15, 16)             # #150f10 body base — black-void mass
VOID_EDGE = (38, 26, 26)        # #261a1a flat top-edge accent (fire catches the back)
HOOF = (16, 10, 9)              # #100a09 hoof
IRON = (122, 124, 138)          # #7a7c8a horseshoe
IRON_LT = (188, 192, 206)       # #bcc0ce horseshoe glint
WOUND = (74, 8, 8)              # #4a0808 raw flesh stump
SADDLE = (40, 22, 14)           # #28160e dark leather
SADDLE_BLOOD = (150, 24, 16)    # #961810 blood-red trim
FIRE_DEEP = (188, 42, 0)        # #bc2a00 fire occlusion / outer tooth
FIRE_MID = (255, 107, 8)        # #ff6b08 fire base
FIRE_HOT = (255, 168, 56)       # #ffa838 fire highlight
FIRE_CORE = (255, 240, 200)     # #fff0c8 white-hot heart (never pure white)

MULA_PALETTE = [
    OUTLINE, VOID_DK, VOID, VOID_EDGE, HOOF, IRON, IRON_LT,
    WOUND, SADDLE, SADDLE_BLOOD,
    FIRE_DEEP, FIRE_MID, FIRE_HOT, FIRE_CORE,
]


class Painter:
    def __init__(self, size: int = SIZE) -> None:
        self.size = size
        self.k = size / GRID * SS
        self.im = Image.new("RGBA", (size * SS, size * SS), TRANSPARENT)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts: list[tuple[float, float]], col: tuple[int, int, int]) -> None:
        self.d.polygon([(x * self.k, y * self.k) for x, y in pts], fill=col)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col: tuple[int, int, int]) -> None:
        self.d.ellipse(
            [(cx - rx) * self.k, (cy - ry) * self.k,
             (cx + rx) * self.k, (cy + ry) * self.k],
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

    def render(self, palette: list[tuple[int, int, int]]) -> Image.Image:
        small = self.im.resize((self.size, self.size), Image.Resampling.BOX)
        px = small.load()
        for y in range(self.size):
            for x in range(self.size):
                r, g, b, a = px[x, y]
                if a < 112:
                    px[x, y] = TRANSPARENT
                else:
                    px[x, y] = _nearest_palette((r, g, b), palette)
        return small


def _nearest_palette(
    color: tuple[int, int, int],
    palette: list[tuple[int, int, int]],
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


def _outline(img: Image.Image, palette: list[tuple[int, int, int]]) -> None:
    """Continuous 1px dark outline on every opaque pixel touching transparency."""
    size = img.size[0]
    px = img.load()
    outline_rgb = OUTLINE
    if outline_rgb not in palette:
        return
    edge: list[tuple[int, int]] = []
    for y in range(size):
        for x in range(size):
            if px[x, y][3] == 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx = x + ox
                ny = y + oy
                if not (0 <= nx < size and 0 <= ny < size) or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = outline_rgb + (255, )


# ── Pose channels ─────────────────────────────────────────
# coil  : 0 → 1  windup anticipation (body sinks, haunches gather, fire swells)
# breath: −1 → 1 idle barrel breathing (E2)
# flame : 0 → 1  flame flicker phase (E2)

_GROUND_Y = 60.5        # hoof contact line (grid); shoe band ends ~62.5 → px ~187


def _sink(coil: float) -> float:
    """Vertical body drop while coiling (feet stay planted)."""
    return coil * 2.2


# ── Drawing routines (all facing LEFT) ────────────────────

def _hoof_and_shoe(p: Painter, foot: tuple[float, float], glint: bool) -> None:
    """Hoof block and iron horseshoe; near feet get the silver glint."""
    fx, fy = foot
    p.poly([
        (fx - 2.0, fy - 1.0),
        (fx + 2.0, fy - 1.0),
        (fx + 2.2, fy + 1.3),
        (fx - 2.2, fy + 1.3),
    ], HOOF)
    p.poly([
        (fx - 2.3, fy + 1.0),
        (fx + 2.3, fy + 1.0),
        (fx + 2.4, fy + 2.0),
        (fx - 2.4, fy + 2.0),
    ], IRON)
    if glint:
        p.ellipse(fx - 1.5, fy + 1.5, 0.6, 0.35, IRON_LT)
        p.ellipse(fx + 1.5, fy + 1.5, 0.6, 0.35, IRON_LT)


def _leg(
    p: Painter,
    top: tuple[float, float],
    knee: tuple[float, float],
    foot: tuple[float, float],
    col: tuple[int, int, int],
    glint: bool,
) -> None:
    """Thigh + shin capsules + shod hoof. Flat single-tone limb, CHUNKY."""
    p.limb(top, knee, 6.4, 4.0, col)
    p.limb(knee, foot, 4.0, 2.6, col)
    _hoof_and_shoe(p, foot, glint)


def _legs(p: Painter, coil: float) -> None:
    """Four legs braced to gallop; far pair darker, no glint. Feet planted."""
    s = _sink(coil)
    gather = coil * 2.0   # hind feet slide toward the body when coiling
    bend = coil * 1.8     # knees push outward as the body drops
    # Far pair first (behind the body).
    _leg(p, (22.0, 42.0 + s), (20.0 - bend * 0.5, 50.5 + s * 0.5), (19.0, _GROUND_Y), VOID_DK, False)
    _leg(p, (48.5, 42.0 + s), (52.5 + bend * 0.5, 50.0 + s * 0.5), (50.5 - gather, _GROUND_Y), VOID_DK, False)
    # Near pair.
    _leg(p, (17.0, 42.0 + s), (13.8 - bend, 50.5 + s * 0.5), (12.5, _GROUND_Y), VOID, True)
    _leg(p, (44.0, 42.0 + s), (49.5 + bend, 49.5 + s * 0.5), (46.5 - gather, _GROUND_Y), VOID, True)


def _body(p: Painter, coil: float, breath: float) -> None:
    """Black-void barrel in profile, serrated with DELIBERATE teeth.

    Chest teeth face the player (left) — aggression reads in silhouette.
    Massive and chibi-monumental, never naturalistic.
    """
    s = _sink(coil)
    bl = breath * 0.4     # belly swells on inhale
    bk = breath * 0.2     # back rises on inhale
    body = [
        (14.0, 27.0 + s),
        (20.0, 24.0 + s - bk),            # withers
        (30.0, 23.2 + s - bk),            # back mid
        (42.0, 24.0 + s - bk),            # croup
        (50.0, 26.5 + s),
        (54.0, 29.5 + s),                 # rump teeth →
        (56.5, 32.0 + s),
        (54.0, 34.5 + s),
        (56.0, 37.5 + s),
        (52.0, 40.5 + s),
        (45.0, 44.0 + s + bl),            # hind belly
        (37.0, 44.5 + s + bl),
        (32.5, 46.5 + s + bl),            # belly tooth ↓
        (28.0, 44.5 + s + bl),
        (20.0, 44.0 + s + bl),
        (13.0, 41.5 + s),                 # chest teeth (facing the Caipora) →
        (9.5, 38.5 + s),
        (12.5, 35.0 + s),
        (8.8, 31.5 + s),
        (12.8, 28.5 + s),
    ]
    p.poly(body, VOID)
    # Flat edge accent along the back — the fire's constant glow, one hard tone.
    p.poly([
        (20.0, 24.0 + s - bk), (30.0, 23.2 + s - bk), (42.0, 24.0 + s - bk),
        (42.0, 25.4 + s - bk), (30.0, 24.6 + s - bk), (20.0, 25.4 + s - bk),
    ], VOID_EDGE)


def _tail(p: Painter, coil: float) -> None:
    """Tail streams BACK (right), void teeth ending in a burning tuft."""
    s = _sink(coil)
    p.poly([
        (53.0, 30.5 + s),
        (57.5, 32.0 + s),
        (60.0, 34.0 + s),                 # tooth →
        (58.0, 35.5 + s),
        (61.0, 37.5 + s),                 # tooth →
        (57.5, 38.5 + s),
        (53.5, 36.0 + s),
    ], VOID)
    # Burning tuft — small deliberate flame teeth.
    p.poly([
        (58.0, 35.5 + s), (62.0, 37.0 + s), (60.0, 39.5 + s),
        (61.5, 41.5 + s), (57.5, 40.0 + s), (56.0, 37.5 + s),
    ], FIRE_DEEP)
    p.poly([
        (58.5, 36.5 + s), (61.0, 38.0 + s), (59.4, 39.6 + s),
        (60.4, 40.8 + s), (58.0, 39.6 + s), (57.2, 37.6 + s),
    ], FIRE_MID)
    p.ellipse(59.2, 38.5 + s, 0.8, 1.0, FIRE_HOT)


def _neck_and_stump(p: Painter, coil: float) -> None:
    """Thick neck leaning INTO the player, ending in the raw stump.

    The mane edge carries three deliberate void teeth — fur, not noise.
    """
    s = _sink(coil)
    p.poly([
        (23.0, 25.5 + s),
        (18.5, 16.0 + s),
        (16.0, 11.5 + s),
        (9.0, 12.5 + s),
        (9.5, 19.0 + s),
        (12.0, 28.0 + s),
    ], VOID)
    # Mane teeth on the back edge (pointing up-right) — big, deliberate fur.
    p.poly([(21.5, 22.5 + s), (26.0, 19.5 + s), (19.7, 18.2 + s)], VOID)
    p.poly([(19.0, 17.2 + s), (23.2, 14.0 + s), (17.4, 13.6 + s)], VOID)
    p.poly([(17.0, 13.4 + s), (20.6, 10.2 + s), (15.4, 10.4 + s)], VOID)
    # Flat edge accent on the chest edge of the neck.
    p.poly([
        (9.0, 12.5 + s), (9.5, 19.0 + s), (11.2, 27.0 + s),
        (10.1, 27.0 + s), (8.4, 19.2 + s), (7.9, 13.0 + s),
    ], VOID_EDGE)
    # Raw stump — the decapitation wound the fire erupts from.
    p.ellipse(12.5, 11.8 + s, 3.7, 1.7, WOUND)
    p.ellipse(12.5, 11.0 + s, 2.0, 0.9, FIRE_CORE)


# Flame crown teeth in flame-space: (dx, h) pairs — dx in grid units from the
# stump, h as fraction of the column height. Tip, valley, tip, valley...
_FIRE_CROWN = [
    (-3.6, 0.06),   # base left
    (-4.2, 0.35),   # left edge
    (-1.0, 1.00),   # tooth A (tallest — the head that isn't there)
    (1.3, 0.63),
    (3.5, 0.88),    # tooth B
    (5.7, 0.48),
    (8.0, 0.70),    # tooth C
    (10.0, 0.28),
    (11.5, 0.43),   # tooth D
    (13.0, 0.08),
    (15.0, 0.13),   # tooth E — trailing ember tongue
    (13.5, -0.12),  # underside, floating over the back
    (8.5, -0.15),
    (3.5, -0.14),   # closes at the stump's right lip
]

# Extra tooth inserted between A and B when the column surges (windup).
_FIRE_SURGE_TOOTH = [(0.2, 0.72), (1.0, 0.97), (2.0, 0.68)]

_EMBERS_IDLE = [
    (23.0, 4.8, 0.70, FIRE_HOT),
    (26.0, 8.5, 0.55, FIRE_MID),
    (28.5, 12.3, 0.45, FIRE_DEEP),
]
_EMBERS_SURGE = [
    (19.5, 2.2, 0.60, FIRE_HOT),
    (24.5, 4.2, 0.50, FIRE_MID),
]


def _flame_pts(
    base: tuple[float, float],
    height: float,
    width: float,
    crown: list[tuple[float, float]],
    flame: float,
) -> list[tuple[float, float]]:
    """Map flame-space crown to grid space; `flame` phases tooth heights."""
    bx, by = base
    pts: list[tuple[float, float]] = []
    for i, (dx, h) in enumerate(crown):
        wobble = 0.0
        if h > 0.3 and flame > 0.0:
            wobble = math.sin(math.tau * (flame + i * 0.37)) * 0.045
        # Never let a tooth tip clip the canvas top (bbox/scale contract).
        pts.append((bx + dx * width, max(0.5, by - (h + wobble) * height)))
    return pts


def _fire_column(p: Painter, coil: float, flame: float) -> None:
    """The Mula's juba: a serrated column of fire with flat 4-tone selout."""
    s = _sink(coil)
    base = (12.5, 11.2 + s)
    height = 10.4 + coil * 2.4          # windup tips reach ~y 0.8 (px ~2.4)
    width = 1.1 + coil * 0.55

    crown = list(_FIRE_CROWN)
    if coil > 0.5:
        crown = crown[:3] + _FIRE_SURGE_TOOTH + crown[3:]

    # Deep silhouette → mid → hot: same crown, inset by scale. Flat layers.
    p.poly(_flame_pts(base, height, width, crown, flame), FIRE_DEEP)
    p.poly(_flame_pts((base[0], base[1] - 0.2), height * 0.80, width * 0.78, crown, flame), FIRE_MID)
    hot_crown = [(dx, h) for dx, h in crown if h >= -0.05][:9]
    hot_crown.append((3.0, -0.02))
    p.poly(_flame_pts((base[0] + 0.2, base[1] - 0.4), height * 0.52, width * 0.55, hot_crown, flame), FIRE_HOT)
    # White-hot heart hugging the stump — the only near-white, never pure.
    p.ellipse(base[0], base[1] - 1.8, 1.6 + coil * 0.5, 2.3 + coil * 1.1, FIRE_CORE)
    if coil > 0.5:
        p.ellipse(base[0] + 0.6, base[1] - 5.6, 1.0, 2.2, FIRE_CORE)
        p.ellipse(base[0] + 3.6, base[1] - 3.2, 0.7, 1.4, FIRE_CORE)

    # Deliberate embers trailing back — fixed, few, decreasing.
    embers = list(_EMBERS_IDLE)
    if coil > 0.5:
        embers += _EMBERS_SURGE
    for ex, ey, r, col in embers:
        drift = math.sin(math.tau * (flame + ex)) * 0.4 if flame > 0.0 else 0.0
        p.ellipse(ex + drift * 0.3, ey + s * 0.4 - drift, r, r, col)


def _harness(p: Painter, coil: float) -> None:
    """Cursed saddle + blood trim + girth. The last ride never ended."""
    s = _sink(coil)
    p.poly([
        (24.0, 24.2 + s), (36.0, 23.6 + s), (38.5, 27.0 + s),
        (36.0, 30.0 + s), (26.0, 30.5 + s), (22.5, 27.4 + s),
    ], SADDLE)
    p.poly([
        (24.0, 24.2 + s), (36.0, 23.6 + s), (37.0, 25.4 + s), (25.0, 26.0 + s),
    ], SADDLE_BLOOD)
    # Girth descending the flank + blood buckle.
    p.limb((30.5, 30.0 + s), (29.8, 43.5 + s), 1.7, 1.3, SADDLE)
    p.ellipse(30.2, 35.0 + s, 1.0, 1.0, SADDLE_BLOOD)
    # Breast strap toward the chest, still dripping.
    p.limb((22.5, 28.0 + s), (13.0, 32.5 + s), 1.2, 0.9, SADDLE)
    p.ellipse(13.8, 34.4 + s, 0.55, 0.9, SADDLE_BLOOD)


def _draw_mula(pose: str = "idle", *, breath: float = 0.0, flame: float = 0.0) -> Image.Image:
    """Compose one frame. Pose presets set the coil channel; E2 threads the rest."""
    coil = 1.0 if pose == "windup" else 0.0
    p = Painter()
    _tail(p, coil)
    _legs(p, coil)
    _body(p, coil, breath)
    _harness(p, coil)
    _neck_and_stump(p, coil)
    _fire_column(p, coil, flame)
    img = p.render(MULA_PALETTE)
    _outline(img, MULA_PALETTE)
    return img


def _caipora_ref() -> Image.Image:
    """Load the canonical Caipora idle at game scale for the sheet."""
    path = os.path.join(OUT, "player_idle.png")
    if not os.path.exists(path):
        return Image.new("RGBA", (1, 1), TRANSPARENT)
    return Image.open(path).convert("RGBA")


def _contact_sheet() -> None:
    """Contact sheet with idle, windup, and a Caipora reference for scale."""
    idle = _draw_mula("idle")
    windup = _draw_mula("windup")

    cell = SIZE + 32
    ref = _caipora_ref()
    ref_size = ref.size[0]
    sheet_w = cell * 2 + ref_size + 48
    sheet_h = max(cell, ref_size) + 40
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (18, 14, 15, 255))
    draw = ImageDraw.Draw(sheet)

    sheet.alpha_composite(idle, (16, 28))
    draw.text((16, 6), "mula idle", fill=(230, 210, 180, 255))

    sheet.alpha_composite(windup, (16 + cell, 28))
    draw.text((16 + cell, 6), "mula windup", fill=(230, 210, 180, 255))

    ref_x = 16 + cell * 2
    sheet.alpha_composite(ref, (ref_x, 28))
    draw.text((ref_x, 6), "caipora ref (96px)", fill=(230, 210, 180, 255))

    sheet.save(os.path.join(OUT, "mula_contact_sheet.png"))


def generate_all() -> None:
    os.makedirs(OUT, exist_ok=True)
    _draw_mula("idle").save(os.path.join(OUT, "mula_idle.png"))
    _draw_mula("windup").save(os.path.join(OUT, "mula_windup.png"))
    _contact_sheet()
    print("[gen_mula] Mula sem Cabeça v3 generated: idle + windup (192x192) + contact sheet")


if __name__ == "__main__":
    generate_all()
