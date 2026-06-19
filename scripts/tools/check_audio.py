#!/usr/bin/env python3
"""Fiscal do padrão de loudness do caipora (PRD-audio-v2 §3, etapa E1).

Mede cada .wav de assets/audio/ e compara com o alvo da sua categoria
(= subdiretório). Saída: tabela ✅/❌ por asset; exit 1 se qualquer um falhar.

Medições (stdlib pura — wave/struct/math):
  LUFS  — BS.1770 simplificado: K-weighting (high-pass RLB 38 Hz Q=0.5 +
          high-shelf +4 dB acima de ~1.5 kHz, coeficientes RBJ recalculados por
          sample rate), blocos de 400 ms com hop de 100 ms, gate ABSOLUTO de
          −70 LUFS. O gate relativo (−10 LU) do BS.1770 fica de fora: existe
          para conteúdo com silêncios longos, e os loops daqui são contínuos.
  Pico  — pico de amostra. NÃO é true peak (sem oversampling): conteúdo mono
          lo-fi a 11/22 kHz tem inter-sample overs limitados, então o limite de
          "true peak ≤ −1 dBFS" da PRD vira proxy de sample peak ≤ −1.2 dBFS.
  RMS   — plano (sem ponderação), usado só nos SFX curtos.

As funções são importáveis: gen_sfx.py usa o MESMO medidor ao normalizar
(gerador e fiscal medem igual → `make audio` verde por construção).

Uso: python3 scripts/tools/check_audio.py [raiz]   (default: assets/audio)
"""

import math
import os
import struct
import sys
import wave

AUDIO_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")

# Alvos por categoria (= subdiretório de assets/audio). PRD-audio-v2 §3.
#   lufs: faixa (min, max) de loudness integrado
#   rms / peak: faixa (min, max) em dBFS — só para SFX curtos
#   peak_max: teto de pico de amostra (proxy de true peak ≤ −1 dBFS)
TARGETS = {
    "music": {"lufs": (-17.0, -15.0), "peak_max": -1.2},
    "ambience": {"lufs": (-17.0, -15.0), "peak_max": -1.2},
    "stingers": {"lufs": (-15.0, -13.0), "peak_max": -1.2},
    "sfx": {"peak": (-3.5, -2.5), "rms": (-12.0, -9.0), "peak_max": -1.2},
    # Stems (mus_*_{base,mid,top}.wav): só o teto de pico — LUFS individual não se
    # aplica a camada (a normalização é em GRUPO, sobre o mix, no gen_sfx).
    "stem": {"peak_max": -1.2},
}

STEM_SUFFIXES = ("_base.wav", "_mid.wav", "_top.wav")

BLOCK_SECS = 0.400
HOP_SECS = 0.100
ABS_GATE_LUFS = -70.0

# Budget de peso do catálogo (PLAN-audio-v3-1 S8): browser-first, cada MB custa
# tempo de load. Warn avisa sem quebrar; fail bloqueia o gate.
BUDGET_WARN_MB = 9.0
BUDGET_FAIL_MB = 10.0


# ─── IO ────────────────────────────────────────────
def read_wav(path):
    """Lê WAV mono 16-bit ou 8-bit -> (samples [-1..1], rate). Falha alto em outro formato."""
    with wave.open(path, "r") as w:
        if w.getnchannels() != 1 or w.getsampwidth() not in (1, 2):
            raise ValueError(f"{path}: esperado mono 8 ou 16-bit")
        width = w.getsampwidth()
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())
    if width == 1:  # PCM 8-bit é unsigned (0..255, centro em 128)
        samples = [(b - 128) / 128.0 for b in raw]
    else:
        n = len(raw) // 2
        samples = [s / 32768.0 for s in struct.unpack(f"<{n}h", raw)]
    return samples, rate


def read_ogg(path):
    """Lê OGG Vorbis mono -> (samples [-1..1], rate). Codec de música/ambiência v5;
    usa soundfile (libvorbis já presente). Mono garantido (canal 0 se vier estéreo)."""
    import soundfile as sf
    data, rate = sf.read(path, dtype="float64", always_2d=False)
    if getattr(data, "ndim", 1) > 1:
        data = data[:, 0]
    return data.tolist(), rate


def read_audio(path):
    """Despacha leitura por extensão: .ogg (Vorbis) ou .wav (PCM)."""
    return read_ogg(path) if path.lower().endswith(".ogg") else read_wav(path)


# ─── Filtros ───────────────────────────────────────
def biquad(samples, b0, b1, b2, a1, a2):
    """Biquad em forma direta II transposta (coeficientes já normalizados por a0)."""
    z1 = z2 = 0.0
    out = []
    for x in samples:
        y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        out.append(y)
    return out


def _highpass_coefs(rate, freq, q):
    """RBJ cookbook high-pass, normalizado por a0."""
    w0 = 2.0 * math.pi * freq / rate
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * q)
    a0 = 1.0 + alpha
    b0 = (1.0 + cw) / 2.0 / a0
    b1 = -(1.0 + cw) / a0
    b2 = (1.0 + cw) / 2.0 / a0
    a1 = (-2.0 * cw) / a0
    a2 = (1.0 - alpha) / a0
    return b0, b1, b2, a1, a2


def _highshelf_coefs(rate, freq, gain_db, q=0.707):
    """RBJ cookbook high-shelf, normalizado por a0."""
    a = 10.0 ** (gain_db / 40.0)
    w0 = 2.0 * math.pi * freq / rate
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / 2.0 * math.sqrt((a + 1.0 / a) * (1.0 / q - 1.0) + 2.0)
    two_sqrt_a_alpha = 2.0 * math.sqrt(a) * alpha
    a0 = (a + 1.0) - (a - 1.0) * cw + two_sqrt_a_alpha
    b0 = (a * ((a + 1.0) + (a - 1.0) * cw + two_sqrt_a_alpha)) / a0
    b1 = (-2.0 * a * ((a - 1.0) + (a + 1.0) * cw)) / a0
    b2 = (a * ((a + 1.0) + (a - 1.0) * cw - two_sqrt_a_alpha)) / a0
    a1 = (2.0 * ((a - 1.0) - (a + 1.0) * cw)) / a0
    a2 = ((a + 1.0) - (a - 1.0) * cw - two_sqrt_a_alpha) / a0
    return b0, b1, b2, a1, a2


def k_weight(samples, rate):
    """K-weighting do BS.1770: shelf de presença (+4 dB ≳1.5 kHz) + RLB HP 38 Hz."""
    samples = biquad(samples, *_highshelf_coefs(rate, 1500.0, 4.0))
    return biquad(samples, *_highpass_coefs(rate, 38.0, 0.5))


# ─── Medidores ─────────────────────────────────────
def lufs(samples, rate):
    """Loudness integrado aproximado (mono => peso de canal 1.0)."""
    kw = k_weight(samples, rate)
    block = max(1, int(BLOCK_SECS * rate))
    hop = max(1, int(HOP_SECS * rate))
    means = []
    if len(kw) <= block:
        windows = [kw]  # asset mais curto que 400 ms: bloco único
    else:
        windows = [kw[i:i + block] for i in range(0, len(kw) - block + 1, hop)]
    for win in windows:
        ms = sum(s * s for s in win) / len(win)
        loud = -0.691 + 10.0 * math.log10(ms) if ms > 0.0 else -120.0
        if loud >= ABS_GATE_LUFS:
            means.append(ms)
    if not means:
        return -120.0
    return -0.691 + 10.0 * math.log10(sum(means) / len(means))


def sample_peak_db(samples):
    hi = max((abs(s) for s in samples), default=0.0)
    return 20.0 * math.log10(hi) if hi > 1e-9 else -120.0


def rms_db(samples):
    if not samples:
        return -120.0
    ms = sum(s * s for s in samples) / len(samples)
    return 10.0 * math.log10(ms) if ms > 0.0 else -120.0


# ─── Checagem ──────────────────────────────────────
def check_file(path, category):
    """-> (ok: bool, métricas: str). Aplica o alvo da categoria ao arquivo."""
    target = TARGETS[category]
    samples, rate = read_audio(path)
    peak = sample_peak_db(samples)
    fails = []
    cols = [f"peak {peak:6.1f}"]
    if peak > target["peak_max"]:
        fails.append(f"peak > {target['peak_max']}")
    if "lufs" in target:
        loud = lufs(samples, rate)
        cols.append(f"lufs {loud:6.1f}")
        lo, hi = target["lufs"]
        if not lo <= loud <= hi:
            fails.append(f"lufs fora de [{lo}, {hi}]")
    if "rms" in target:
        level = rms_db(samples)
        cols.append(f"rms {level:6.1f}")
        lo, hi = target["rms"]
        if not lo <= level <= hi:
            fails.append(f"rms fora de [{lo}, {hi}]")
    if "peak" in target:
        lo, hi = target["peak"]
        if not lo <= peak <= hi:
            fails.append(f"peak fora de [{lo}, {hi}]")
    return (not fails), "  ".join(cols) + ("  ⟵ " + "; ".join(fails) if fails else "")


def main(root=None):
    root = os.path.abspath(root or AUDIO_DIR)
    rows = []
    failures = 0
    bytes_by_category = {}
    for category in sorted(TARGETS):
        if category == "stem":
            continue  # stems vivem em music/ e são detectados pelo sufixo
        cat_dir = os.path.join(root, category)
        if not os.path.isdir(cat_dir):
            continue
        for name in sorted(os.listdir(cat_dir)):
            if not name.endswith((".wav", ".ogg")):
                continue
            path = os.path.join(cat_dir, name)
            bytes_by_category[category] = bytes_by_category.get(category, 0) \
                + os.path.getsize(path)
            stem_name = os.path.splitext(name)[0]  # detecção de stem é agnóstica de ext
            effective = "stem" if stem_name.endswith(("_base", "_mid", "_top")) else category
            ok, info = check_file(path, effective)
            failures += 0 if ok else 1
            rows.append(("✅" if ok else "❌", f"{category}/{name}", info))
    width = max((len(r[1]) for r in rows), default=0)
    for mark, rel, info in rows:
        print(f"  {mark} {rel:<{width}}  {info}")
    print(f"\n{len(rows)} assets, {failures} fora do padrão")

    total_mb = sum(bytes_by_category.values()) / 1_000_000.0
    print("\nbudget (MB):")
    for category, size in sorted(bytes_by_category.items()):
        print(f"  {category:<10} {size / 1_000_000.0:6.2f}")
    print(f"  {'total':<10} {total_mb:6.2f}  (warn > {BUDGET_WARN_MB}, fail > {BUDGET_FAIL_MB})")
    if total_mb > BUDGET_FAIL_MB:
        print(f"  ❌ budget estourado: {total_mb:.2f} MB > {BUDGET_FAIL_MB} MB")
        failures += 1
    elif total_mb > BUDGET_WARN_MB:
        print(f"  ⚠️  acima da linha de aviso ({BUDGET_WARN_MB} MB) — ver S8 do PLAN-audio-v3-1")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else None))
