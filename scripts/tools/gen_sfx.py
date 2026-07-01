#!/usr/bin/env python3
"""Gera os SFX de combate de caipora com DNA percussivo do maracatu (baque virado).

Fallback para jsfxr (indisponível via CLI). Usa apenas a stdlib (wave/math/struct)
para modelar instrumentos do maracatu nação e texturas amazônicas, e compor a partir
deles os 7 SFX de combate. Cada som é gerado em 3 variantes (primário + _2 + _3) com
seeds distintas — o SfxSystem faz round-robin entre elas para nunca soar idêntico.

Paleta tímbrica:
  alfaia  — bumbo grave de pele (impacto carnudo)
  caixa   — tarol/caixa com esteira (estalo seco, brilhante)
  ganza   — chocalho metálico (chiado filtrado, sopro)
  agogo   — sino de dois bocais (parciais inarmônicos, "ding" da recompensa)
  gongue  — sino de ferro grave (chamada metálica)
  assovio — leitmotif da Caipora (seno com vibrato + sopro)

Saída: WAV mono 22050Hz 16-bit em assets/audio/sfx/.
Uso: python3 scripts/tools/gen_sfx.py
"""

import math
import os
import random
import struct
import sys
import wave

import check_audio  # fiscal de loudness (E1) — gerador e fiscal medem com o MESMO medidor

SAMPLE_RATE = 22050
# As faixas de música (loops longos) saem em SR reduzido — o grão lo-fi é parte da
# estética 8-bit e corta o peso a ~metade (browser-first, .wav versionados).
MUSIC_RATE = 11025
AUDIO_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")

# Seeds das variantes. A 1ª mantém os nomes originais (attack.wav...); as demais
# viram attack_2.wav / attack_3.wav e alimentam o round-robin do SfxSystem.
VARIANT_SEEDS = [42, 1337, 2024]


# ─── IO + conformidade de loudness (motor v2) ──────
# Alvo de loudness por categoria (centro das faixas do check_audio.TARGETS).
# O _write entrega o asset JÁ no padrão: `make audio` é verde por construção.
_LUFS_TARGET = {"music": -16.0, "ambience": -16.0, "stingers": -14.0}
_SFX_PEAK_DB = -3.0          # alvo de pico dos SFX curtos
_PEAK_CEIL_DB = -1.4         # teto de pico (margem sob o -1.2 do fiscal)
_SFX_RMS_FLOOR_DB = -11.5    # RMS mínimo dos SFX (faixa -12..-9, com margem)
_DRIVES = (1.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0)
# Passada escura: teto de low-pass por categoria (Hz). Abafa o agudo no funil único
# _write. SFX um pouco mais aberto p/ não perder o ataque do feedback de combate.
_GLOBAL_LP = {"sfx": 1600.0, "music": 1300.0, "ambience": 1300.0, "stingers": 1500.0}


def _db_to_gain(db):
    return 10.0 ** (db / 20.0)


def saturate(samples, drive=2.0):
    """Saturação tanh (pico preservado: 1→1). Reduz o crest factor — o corpo sobe
    sem o pico estourar. É o 'cola analógica' que deixa o lo-fi carnudo."""
    if drive <= 1.0:
        return list(samples)
    norm = math.tanh(drive)
    return [math.tanh(s * drive) / norm for s in samples]


def _conform_lufs(samples, rate, target_lufs):
    """Ganho para o alvo LUFS respeitando o teto de pico. Se o crest factor não
    deixa (pico estouraria), satura progressivamente até caber; no limite, encosta
    no teto de pico e o fiscal acusa (ajusta-se a fonte)."""
    cand = samples
    for drive in _DRIVES:
        cand = saturate(samples, drive)
        gain_db = target_lufs - check_audio.lufs(cand, rate)
        if check_audio.sample_peak_db(cand) + gain_db <= _PEAK_CEIL_DB:
            g = _db_to_gain(gain_db)
            return [s * g for s in cand]
    g = _db_to_gain(_PEAK_CEIL_DB - check_audio.sample_peak_db(cand))
    return [s * g for s in cand]


def _conform_sfx(samples):
    """Pico em -3 dBFS; se o RMS ficar abaixo da faixa (-12..-9), satura até o
    corpo subir. Percussivo continua percussivo — só mais denso."""
    cand = samples
    for drive in _DRIVES:
        cand = saturate(samples, drive)
        g = _db_to_gain(_SFX_PEAK_DB - check_audio.sample_peak_db(cand))
        cand = [s * g for s in cand]
        if check_audio.rms_db(cand) >= _SFX_RMS_FLOOR_DB:
            return cand
    return cand


def _encode_ogg(path, samples, rate):
    """Grava OGG Vorbis (PRD-audio-v5 — codec de música/ambiência: ~5-8x menor que
    WAV, paga loops longos e ricos dentro do budget). Usa soundfile+libvorbis já
    presentes no ambiente (sem ffmpeg/oggenc). Mono float [-1,1]; o grão lo-fi
    (bitcrush + MUSIC_RATE) já está no sinal — o Vorbis só comprime o arquivo."""
    import numpy as np
    import soundfile as sf
    data = np.clip(np.asarray(samples, dtype=np.float32), -1.0, 1.0)
    sf.write(path, data, rate, format="OGG", subtype="VORBIS")


def _remove_stale(name, subdir):
    """Apaga um asset legado (ex.: .wav substituído por .ogg) para o budget refletir
    a realidade e o runtime não achar dois arquivos. O .gitignore cobre o .import."""
    p = os.path.join(AUDIO_DIR, subdir, name)
    if os.path.exists(p):
        os.remove(p)


def _write(name, samples, subdir="sfx", rate=SAMPLE_RATE, gain=None, width=2):
    """Grava o asset já conforme ao padrão (PRD-audio-v2 §3). `gain=None` calcula o
    ganho pelo alvo da categoria (= subdir), MEDINDO NO RATE FINAL (o mesmo que o
    fiscal mede); `gain: float` aplica ganho linear direto (caminho dos stems).
    `width=1` grava PCM 8-bit unsigned: a música já é bitcrushada a 7 bits, então
    8-bit é quase lossless aqui — e corta o peso pela metade (browser-first).
    Se `name` terminar em .ogg, grava Vorbis (codec de música v5) — a mesma cadeia
    de LP/resample/conform roda antes; só o encode final muda."""
    # Passada escura: low-pass global por categoria. Catch-all "suave" que abafa o ruído
    # agudo (chimbais NES, estouro de brasa, chiados) sem caçar cada filtro à mão.
    # Aplicado AQUI (no SAMPLE_RATE, antes de resample/conform), o único funil de todos
    # os assets — junto do teto de tom (grave_fold) entrega o "cavernoso".
    if subdir in _GLOBAL_LP:
        samples = biquad(samples, "lp", _GLOBAL_LP[subdir])
    out_dir = os.path.join(AUDIO_DIR, subdir)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name)
    if rate != SAMPLE_RATE:
        samples = _resample(samples, SAMPLE_RATE, rate)
    if gain is None:
        if subdir in _LUFS_TARGET:
            samples = _conform_lufs(samples, rate, _LUFS_TARGET[subdir])
        else:
            samples = _conform_sfx(samples)
    else:
        samples = [s * gain for s in samples]
        peak = check_audio.sample_peak_db(samples)
        if peak > _PEAK_CEIL_DB:  # clamp de segurança (não deve disparar nos stems)
            print(f"  AVISO: {name} clampado em {peak:.1f} dBFS (balanço relativo alterado)")
            g = _db_to_gain(_PEAK_CEIL_DB - peak)
            samples = [s * g for s in samples]
    if name.lower().endswith(".ogg"):
        _encode_ogg(path, samples, rate)
        print(f"  {name}: {len(samples)} samples → {os.path.getsize(path)} bytes (ogg)")
        return
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(width)
        w.setframerate(rate)
        frames = bytearray()
        for s in samples:
            c = max(-1.0, min(1.0, s))
            if width == 1:
                frames += struct.pack("<B", max(0, min(255, 128 + int(round(c * 127.0)))))
            else:
                frames += struct.pack("<h", int(c * 32767))
        w.writeframes(frames)
    print(f"  {name}: {len(samples)} samples ({len(samples) * width} bytes)")


def _write_stems(name, layers):
    """Grava stems sincronizados (mus_<name>_{base,mid,top}.wav) com NORMALIZAÇÃO
    EM GRUPO: o ganho é calculado sobre o MIX das camadas (alvo LUFS de música) e
    aplicado igual nas três — normalizar stem a stem destruiria o balanço relativo.
    O fiscal checa só o pico dos stems (LUFS individual não se aplica a camada)."""
    n = max(len(s) for s in layers.values())
    mix = [0.0] * n
    for samples in layers.values():
        for i, s in enumerate(samples):
            mix[i] += s
    mix = _resample(mix, SAMPLE_RATE, MUSIC_RATE)
    gain_db = _LUFS_TARGET["music"] - check_audio.lufs(mix, MUSIC_RATE)
    peak = check_audio.sample_peak_db(mix) + gain_db
    if peak > _PEAK_CEIL_DB:
        gain_db -= peak - _PEAK_CEIL_DB  # o mix nunca estoura quando somado no bus
    g = _db_to_gain(gain_db)
    for layer, samples in layers.items():
        _write(f"{name}_{layer}.wav", samples, subdir="music", rate=MUSIC_RATE, gain=g,
               width=1)


# ─── Helpers de síntese ────────────────────────────
def _noise():
    return random.uniform(-1.0, 1.0)


def _jit(amount):
    """Aleatoriedade simétrica (±amount) por variante."""
    return 1.0 + random.uniform(-amount, amount)


def _env(i, n, attack=0.01, release=0.3):
    """Envelope ataque/decay linear simples (0..1) em fração de duração."""
    t = i / n
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = 1.0 - max(0.0, (t - (1.0 - release)) / release) if release > 0 else 1.0
    return max(0.0, a * r)


def _mix(*layers):
    """Soma camadas de tamanhos diferentes (zero-pad nas curtas)."""
    n = max(len(layer) for layer in layers)
    out = [0.0] * n
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def _normalize(samples, peak=0.92):
    """Normaliza para um pico-alvo, evitando clipping ao empilhar camadas."""
    hi = max((abs(s) for s in samples), default=0.0)
    if hi <= 1e-6:
        return samples
    g = peak / hi
    return [s * g for s in samples]


def bitcrush(samples, bits=8, rate_div=1):
    """Grão 8-bit: quantiza a amplitude em 2^bits degraus e (opcional) segura cada
    'rate_div' amostras (sample-and-hold = redução de taxa). Cola o híbrido orgânico
    + chiptune num timbre só."""
    levels = float(1 << (bits - 1))
    out = []
    held = 0.0
    for i, s in enumerate(samples):
        if rate_div <= 1 or i % rate_div == 0:
            held = round(max(-1.0, min(1.0, s)) * levels) / levels
        out.append(held)
    return out


def _resample(samples, src_rate, dst_rate):
    """Reamostragem linear (decimação) src->dst. Usado para gravar música a MUSIC_RATE
    sem mexer na matemática de síntese (que roda toda em SAMPLE_RATE)."""
    if dst_rate == src_rate or not samples:
        return samples
    ratio = dst_rate / float(src_rate)
    n_out = max(1, int(len(samples) * ratio))
    out = [0.0] * n_out
    step = src_rate / float(dst_rate)
    for i in range(n_out):
        pos = i * step
        j = int(pos)
        frac = pos - j
        a = samples[j]
        b = samples[j + 1] if j + 1 < len(samples) else samples[j]
        out[i] = a + (b - a) * frac
    return out


# ─── DSP v2: filtros, reverb e eco de síntese ──────
# ─── Passada escura: teto de tom grave ─────────────
# "Cavernoso": nenhum conteúdo TONAL passa do teto. Dobra oitavas pra baixo até caber,
# preservando a classe de altura (escala/harmonia intactas) — só o registro desce.
# Aplicado no topo dos osciladores (pulse/agogo/gongue/triangle/assovio), nunca em
# note(): as notas de melodia já vivem <650 Hz; foldá-las só quebraria contorno. Os
# ofensores são as frequências hardcoded dos osciladores (sinos agogô, whooshes).
TONE_CEILING_HZ = 650.0


def grave_fold(freq, ceiling=TONE_CEILING_HZ):
    if freq <= 0.0:
        return freq
    while freq > ceiling:
        freq *= 0.5
    return freq


def biquad(samples, kind, freq, q=0.707, gain_db=0.0, rate=SAMPLE_RATE):
    """Filtro biquad RBJ ("lp"/"hp"/"bp"/"lowshelf"/"highshelf"/"peak"). Dá corpo
    e foco aos timbres — o que osciladores nus + média móvel não alcançam."""
    a = 10.0 ** (gain_db / 40.0)
    w0 = 2.0 * math.pi * freq / rate
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * q)
    if kind == "lp":
        b0 = b2 = (1.0 - cw) / 2.0
        b1 = 1.0 - cw
        a0, a1, a2 = 1.0 + alpha, -2.0 * cw, 1.0 - alpha
    elif kind == "hp":
        b0 = b2 = (1.0 + cw) / 2.0
        b1 = -(1.0 + cw)
        a0, a1, a2 = 1.0 + alpha, -2.0 * cw, 1.0 - alpha
    elif kind == "bp":
        b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1.0 + alpha, -2.0 * cw, 1.0 - alpha
    elif kind == "peak":
        b0, b1, b2 = 1.0 + alpha * a, -2.0 * cw, 1.0 - alpha * a
        a0, a1, a2 = 1.0 + alpha / a, -2.0 * cw, 1.0 - alpha / a
    elif kind in ("lowshelf", "highshelf"):
        sq = 2.0 * math.sqrt(a) * alpha
        sign = 1.0 if kind == "lowshelf" else -1.0
        b0 = a * ((a + 1.0) - sign * (a - 1.0) * cw + sq)
        b1 = sign * 2.0 * a * ((a - 1.0) - sign * (a + 1.0) * cw)
        b2 = a * ((a + 1.0) - sign * (a - 1.0) * cw - sq)
        a0 = (a + 1.0) + sign * (a - 1.0) * cw + sq
        a1 = sign * -2.0 * ((a - 1.0) + sign * (a + 1.0) * cw)
        a2 = (a + 1.0) + sign * (a - 1.0) * cw - sq
    else:
        raise ValueError(f"biquad: tipo desconhecido {kind!r}")
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    z1 = z2 = 0.0
    out = []
    for x in samples:
        y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        out.append(y)
    return out


def schroeder(samples, mix=0.25, decay=0.72, predelay=0.0, tail=0.6, rate=SAMPLE_RATE):
    """Reverb de Schroeder: 4 combs paralelos + 2 all-pass em série. Cauda CURTA
    impressa no asset (corpo do som); o espaço da sala é o bus Reverb (E3).
    'tail' = segundos extras de cauda anexados ao fim."""
    if mix <= 0.0:
        return list(samples)
    n = len(samples) + int(tail * rate)
    dry = list(samples) + [0.0] * (n - len(samples))
    pre = int(predelay * rate)
    wet = [0.0] * n
    for delay_ms in (29.7, 37.1, 41.1, 43.7):
        d = max(1, int(delay_ms * rate / 1000.0))
        buf = [0.0] * d
        for i in range(n):
            j = i - pre
            x = dry[j] if 0 <= j < len(samples) else 0.0
            y = buf[i % d]
            buf[i % d] = x + y * decay
            wet[i] += y * 0.25
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = max(1, int(delay_ms * rate / 1000.0))
        buf = [0.0] * d
        for i in range(n):
            x = wet[i]
            y = buf[i % d]
            buf[i % d] = x + y * g
            wet[i] = y - g * buf[i % d]
    return [dry[i] + wet[i] * mix for i in range(n)]


def echo(samples, time_s=0.28, feedback=0.35, mix=0.3, taps=4, rate=SAMPLE_RATE):
    """Delay com feedback: eco de mata para o assovio da Caipora. 'taps' limita a
    cauda anexada (taps * time_s segundos a mais)."""
    if mix <= 0.0:
        return list(samples)
    d = max(1, int(time_s * rate))
    n = len(samples) + d * taps
    line = [0.0] * n  # entrada da linha de delay: dry + feedback do atraso
    for i in range(n):
        x = samples[i] if i < len(samples) else 0.0
        line[i] = x + (line[i - d] * feedback if i >= d else 0.0)
    return [(samples[i] if i < len(samples) else 0.0)
            + (line[i - d] * mix if i >= d else 0.0) for i in range(n)]


# ─── Instrumentos do maracatu ──────────────────────
def alfaia(dur=0.18, base=64.0, punch=1.0):
    """Bumbo grave de pele: transiente de baqueta + fundamental com pitch-down +
    corpo ressonante (sub-oitava). É o impacto 'carnudo'."""
    n = int(SAMPLE_RATE * dur)
    base *= _jit(0.05)
    body = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # fundamental que afunda (~18%): a pancada assenta.
        f = base * (1.0 - 0.18 * (i / n))
        fund = math.sin(2 * math.pi * f * t)
        sub = 0.5 * math.sin(2 * math.pi * f * 0.5 * t)  # sub reforça o grave
        # transiente de baqueta: ruído lowpass forte só no ataque.
        lp = lp * 0.6 + _noise() * 0.4
        thwack = lp * math.exp(-38.0 * t) * 0.6 * punch
        e = _env(i, n, 0.003, 0.8)
        body.append((0.7 * fund + sub) * e + thwack)
    return body


def caixa(dur=0.1, bright=1.0):
    """Caixa/tarol: ruído de esteira (highpass por subtração de lowpass) + estalo
    de pele mid. Seco e brilhante."""
    n = int(SAMPLE_RATE * dur)
    out = []
    lp = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        raw = _noise()
        lp = lp * 0.5 + raw * 0.5
        hp = raw - lp  # componente alta = chiado da esteira
        crack = math.sin(2 * math.pi * 330.0 * t) * math.exp(-40.0 * t)
        e = math.exp(-30.0 * t)
        out.append((0.7 * hp * bright + 0.3 * crack) * e * 0.8)
    return out


def ganza(dur=0.18, rising=True):
    """Chocalho: ruído filtrado com swell de amplitude/brilho. 'rising' faz o
    chiado abrir (tensão antes do golpe); senão é um sopro curto e limpo."""
    n = int(SAMPLE_RATE * dur)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        cut = (0.25 + 0.6 * t) if rising else (0.55 - 0.2 * t)
        prev = prev * (1.0 - cut) + _noise() * cut
        if rising:
            amp = t  # abre
        else:
            amp = max(0.0, 1.0 - t ** 0.5)  # fecha
        out.append(prev * amp * 0.6)
    return out


def _inharmonic(dur, freq, partials, decay, fm=0.0):
    """Sino genérico: soma de parciais inarmônicos com decaimento exponencial e
    leve FM para cintilar. 'partials' = lista de (mult_freq, amp)."""
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        mod = 1.0 + fm * math.sin(2 * math.pi * 5.0 * t)
        s = 0.0
        for mult, amp in partials:
            s += amp * math.sin(2 * math.pi * freq * mult * mod * t)
        e = math.exp(-decay * t)
        # ataque muito curto p/ não estalar
        a = min(1.0, t / 0.004) if t < 0.004 else 1.0
        out.append(s * e * a)
    return out


def agogo(dur=0.2, freq=1320.0, bend=0.05):
    """Sino agudo de dois bocais: parciais inarmônicos brilhantes + leve bend
    ascendente. O 'ding' cultural da recompensa."""
    freq = grave_fold(freq)
    freq *= _jit(0.02) * (1.0 + bend)
    return _inharmonic(
        dur, freq,
        [(1.0, 0.5), (2.76, 0.28), (5.40, 0.15), (8.93, 0.07)],
        decay=14.0, fm=0.004,
    )


def gongue(dur=0.16, freq=620.0):
    """Sino de ferro grave: parciais mais baixos e secos. Chamada metálica."""
    freq = grave_fold(freq)
    freq *= _jit(0.02)
    return _inharmonic(
        dur, freq,
        [(1.0, 0.5), (2.4, 0.25), (3.9, 0.12)],
        decay=22.0, fm=0.0,
    )


def assovio(dur=0.5, freq=900.0, freq_end=None, breath=0.05):
    """Leitmotif da Caipora: seno com vibrato + fiapo de sopro. Suave nas pontas.
    A assinatura vive no CONTORNO (S5): `freq_end` desenha o glide — sobe no
    perfect, cai aspirado no dodge, fica plano e baixo na caça (boss intro).
    `breath` controla o fiapo de ar (o dodge aspirado usa mais). Fase contínua
    (integrada): glide sem artefato de chirp."""
    n = int(SAMPLE_RATE * dur)
    freq = grave_fold(freq)
    if freq_end is not None:
        freq_end = grave_fold(freq_end)
    freq *= _jit(0.02)
    end = freq if freq_end is None else freq_end * _jit(0.02)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        vib = 1.0 + 0.012 * math.sin(2 * math.pi * 6.0 * t)
        f = freq + (end - freq) * (i / n)
        phase += f * vib / SAMPLE_RATE
        tone = math.sin(2 * math.pi * phase)
        e = _env(i, n, 0.15, 0.4)
        out.append((tone + _noise() * breath) * e * 0.5)
    return out


# ─── Vozes chiptune (canais estilo NES) ────────────
# Lead/harmonia em pulso, baixo em triângulo, percussão metálica no canal de ruído.
# São a metade "8-bit" do híbrido; o maracatu orgânico acima é a metade "terra".
def pulse(dur, freq, duty=0.5, vib=0.0, attack=0.005, release=0.25):
    """Onda de pulso (square com duty variável). duty 0.5=oco, 0.25/0.125=nasal/fino."""
    n = int(SAMPLE_RATE * dur)
    freq = grave_fold(freq)
    freq *= _jit(0.004)  # micro-detune por variante, sem soar desafinado
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq * (1.0 + vib * math.sin(2 * math.pi * 5.5 * t))
        phase += f / SAMPLE_RATE
        ph = phase % 1.0
        s = 1.0 if ph < duty else -1.0
        out.append(s * _env(i, n, attack, release) * 0.5)
    return out


def triangle(dur, freq, attack=0.004, release=0.2):
    """Onda triângulo: baixo/sub redondo do NES, sem o brilho áspero do pulso."""
    n = int(SAMPLE_RATE * dur)
    freq = grave_fold(freq)
    freq *= _jit(0.004)
    out = []
    phase = 0.0
    for i in range(n):
        phase += freq / SAMPLE_RATE
        ph = phase % 1.0
        tri = 4.0 * abs(ph - 0.5) - 1.0  # -1..1
        out.append(tri * _env(i, n, attack, release) * 0.6)
    return out


def nes_noise(dur, decay=40.0, lp=0.0, gain=0.5):
    """Canal de ruído (LFSR de 15 bits, como o NES). 'lp' (0..1) escurece o chiado;
    'decay' molda hat curto vs. crash. Percussão metálica 8-bit."""
    n = int(SAMPLE_RATE * dur)
    reg = 0x7FFF
    out = []
    prev = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        bit = (reg ^ (reg >> 1)) & 1
        reg = (reg >> 1) | (bit << 14)
        raw = 1.0 if (reg & 1) else -1.0
        prev = prev * lp + raw * (1.0 - lp)
        out.append(prev * math.exp(-decay * t) * gain)
    return out


# ─── Teoria mínima p/ coesão melódica ──────────────
# Tônica por contexto (Hz) + graus de escala (semitons) → notas chiptune coerentes.
# Menor harmônica dá a cor "folk sombrio"; o ♭2 (frígio) entra nas fases mais densas.
SEMI = 2.0 ** (1.0 / 12.0)
NATURAL_MINOR = [0, 2, 3, 5, 7, 8, 10, 12]   # menor natural (eólio): sem sensível, escura
# Passada escura ("só escalas menores"): a menor harmônica (7ª maior sensível) e a
# dórica (6ª maior, cor morna) foram rebaixadas para menor natural. Os nomes seguem
# usados nos call-sites; só os GRAUS mudaram. Editado AQUI (antes de scale_note, l~510)
# porque o default `scale=MINOR_HARM` faz binding na definição da função.
MINOR_HARM = NATURAL_MINOR                   # antes: [0,2,3,5,7,8,11,12] (7ª sensível removida)
PHRYGIAN = [0, 1, 3, 5, 7, 8, 10, 12]        # frígio (♭2 = tensão/névoa) — já escura, mantida
DORIAN = NATURAL_MINOR                        # antes: [0,2,3,5,7,9,10,12] (6ª maior removida)


def note(root_hz, semitones):
    """Frequência de uma nota a 'semitones' da tônica."""
    return root_hz * (SEMI ** semitones)


def scale_note(root_hz, degree, scale=MINOR_HARM):
    """Nota pelo grau na escala (com oitavas para graus fora de 0..len-1)."""
    octs, idx = divmod(degree, len(scale) - 1)
    return note(root_hz, scale[idx] + 12 * octs)


# ─── Composição dos 7 SFX ──────────────────────────
def attack_wav():
    # Tensão antes do golpe: rufo curto de caixa + chiado de ganzá abrindo.
    layer_caixa = caixa(0.12, bright=0.3)
    layer_ganza = ganza(0.18, rising=True)
    return _normalize(_mix(layer_caixa, layer_ganza), 0.7)


def hit_wav():
    # Impacto carnudo: alfaia grave + estalo de caixa por cima. O lowshelf (v2)
    # engorda o corpo do tambor sem turvar o estalo.
    body = _mix(alfaia(0.18, base=64.0, punch=1.0), caixa(0.09, bright=0.4))
    return _normalize(biquad(body, "lowshelf", 110.0, gain_db=2.5), 0.95)


def dodge_wav():
    # Alívio aéreo: chocalho rápido + sopro de pulso descendente (whoosh 8-bit), crush leve.
    # S5: assovio ASPIRADO caindo — a respiração da esquiva (mais ar que tom).
    swoosh = pulse(0.12, 660.0, duty=0.5, vib=0.0, release=0.7)
    gasp = assovio(0.15, 1080.0, freq_end=740.0, breath=0.20)
    return _normalize(bitcrush(_mix(ganza(0.18, rising=False), [s * 0.3 for s in swoosh],
                                    [s * 0.4 for s in gasp]), bits=7), 0.55)


def timing_perfect_wav():
    # Recompensa híbrida: ding de agogô + arpejo ascendente de pulso (o "8-bit ding").
    # S5: assovio curto SUBINDO por baixo — a Caipora aprova o golpe (contorno, não volume).
    bell = agogo(0.22, freq=1320.0, bend=0.05)
    arp = _seq(
        (pulse(0.05, 880.0, duty=0.25, release=0.5), 0.0, 0.5),
        (pulse(0.05, 1108.0, duty=0.25, release=0.5), 0.04, 0.5),
        (pulse(0.10, 1760.0, duty=0.25, release=0.6), 0.08, 0.55),
    )
    whistle = assovio(0.18, 1175.0, freq_end=1568.0, breath=0.03)
    return _normalize(bitcrush(_mix(bell, arp, [s * 0.45 for s in whistle]), bits=7), 0.7)


def timing_alert_wav():
    # Vulnerabilidade: gonguê em duas batidas ("agora!") + blip de pulso p/ legibilidade.
    first = gongue(0.08, freq=560.0)
    gap = [0.0] * int(SAMPLE_RATE * 0.02)
    second = gongue(0.10, freq=760.0)  # 2ª mais aguda = sobe
    metal = first + gap + second
    blip = pulse(0.06, 988.0, duty=0.125, release=0.5)
    return _normalize(bitcrush(_mix(metal, blip), bits=7), 0.7)


def death_wav():
    # Terror: alfaia sub-grave + growl descendente (saw com pitch caindo) +
    # cauda de ruído modulado. Sem suavizar o gore.
    n = int(SAMPLE_RATE * 0.45)
    growl = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 190.0 * (1.0 - 0.72 * (i / n))
        phase = (t * freq) % 1.0
        saw = 2.0 * phase - 1.0
        tremolo = 0.7 + 0.3 * math.sin(2 * math.pi * 28.0 * t)
        e = _env(i, n, 0.02, 0.5)
        growl.append((0.6 * saw + 0.3 * _noise() * tremolo) * e * 0.6)
    # v2: LP ressonante escurece o growl (gore, não fanfarra) + cauda curta de reverb.
    growl = biquad(growl, "lp", 2400.0, q=1.1)
    return _normalize(schroeder(_mix(alfaia(0.45, base=52.0, punch=0.7), growl),
                                mix=0.10, decay=0.6, tail=0.25), 0.9)


def ui_click_wav():
    # Micro-feedback: rim de caixa seco + blip de pulso curtíssimo (toque 8-bit de menu).
    blip = pulse(0.03, 1320.0, duty=0.125, attack=0.001, release=0.4)
    return _normalize(bitcrush(_mix(caixa(0.045, bright=0.35), [s * 0.4 for s in blip]), bits=6), 0.5)


def step_grass_wav():
    # Passo na serrapilheira: folha esmagada (ruído LP curto) + sombra de ganzá.
    # O nível "baixo" é dado no play (volume_db), não no asset (o fiscal normaliza).
    n = int(SAMPLE_RATE * 0.07)
    crush = [_noise() * _env(i, n, 0.004, 0.6) for i in range(n)]
    crush = biquad(crush, "lp", 1600.0 * _jit(0.15), q=0.9)
    return _normalize(_mix(crush, [s * 0.35 for s in ganza(0.06, rising=False)]), 0.6)


def step_stone_wav():
    # Passo na laje da igreja: tock seco de caixa + nó grave curtíssimo. Sem cauda —
    # o espaço (reverb da igreja) vem do bus, não do asset.
    knock = pulse(0.035, 190.0 * _jit(0.1), duty=0.5, attack=0.001, release=0.5)
    tock = caixa(0.04, bright=0.45)
    return _normalize(biquad(_mix(tock, [s * 0.5 for s in knock]), "hp", 140.0), 0.6)


def hurt_caipora_wav():
    # A guardiã sangra: alfaia no corpo + respiro rasgado descendente. Mais curto e
    # mais "carne" que o hit (que é o impacto NO inimigo); nada de heroísmo.
    n = int(SAMPLE_RATE * 0.22)
    gasp = []
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 240.0 * (1.0 - 0.55 * (i / n))
        phase = (t * freq) % 1.0
        saw = 2.0 * phase - 1.0
        e = _env(i, n, 0.008, 0.55)
        gasp.append((0.45 * saw + 0.55 * _noise()) * e * 0.6)
    gasp = biquad(gasp, "lp", 1900.0, q=1.0)
    return _normalize(_mix(alfaia(0.16, base=58.0, punch=0.9), gasp), 0.9)


def ui_hover_wav():
    # Tick de foco: agogô ultracurto e abafado — menor que o ui_click em tudo
    # (duração, brilho, presença). O volume final baixo vem do play (-14 dB).
    tick = agogo(0.045, freq=1980.0, bend=0.02)
    return _normalize(biquad(bitcrush(tick, bits=6), "lp", 5200.0), 0.4)


def herb_pickup_wav():
    # Colher a erva: chocalho de ganzá subindo + folha amassada (ruído LP curto).
    n = int(SAMPLE_RATE * 0.10)
    crush = [_noise() * _env(i, n, 0.006, 0.5) for i in range(n)]
    crush = biquad(crush, "lp", 1800.0, q=0.8)
    return _normalize(_mix(ganza(0.14, rising=True), [s * 0.6 for s in crush]), 0.6)


def pipe_smoke_wav():
    # Tragada no cachimbo: sopro grave (ruído LP com swell de uma tragada) +
    # crepitar de brasa (estalos esparsos agudos) aceso pela sucção.
    n = int(SAMPLE_RATE * 0.40)
    breath = []
    for i in range(n):
        swell = math.sin(math.pi * i / n)  # cresce e morre
        breath.append(_noise() * swell * 0.6)
    breath = biquad(breath, "lp", 900.0, q=0.9)
    ember = []
    for i in range(n):
        pop = _noise() if random.random() < 0.004 else 0.0
        ember.append(pop * _env(i, n, 0.2, 0.4))
    ember = biquad(ember, "hp", 1200.0)
    return _normalize(_mix(breath, [s * 0.5 for s in ember]), 0.7)


def mata_event_wav():
    # Evento raro da mata (S7): a floresta se mexe LONGE — ave agourenta, galho
    # quebrando ou sussurro respirado. O caráter muda com a seed da variante;
    # o eco de mata empurra tudo para trás. Volume baixo vem do play (-10 dB).
    kind = random.random()
    if kind < 0.34:
        # ave agourenta: dois gritos curtos descendo, o segundo mais fraco
        core = _seq(
            (assovio(0.16, 1400.0 * _jit(0.1), freq_end=960.0, breath=0.12), 0.0, 0.7),
            (assovio(0.20, 1280.0 * _jit(0.1), freq_end=840.0, breath=0.16), 0.26, 0.55),
        )
    elif kind < 0.67:
        # galho quebrando: estalo seco de madeira + folhas caindo
        n = int(SAMPLE_RATE * 0.30)
        leaves = biquad([_noise() * _env(i, n, 0.05, 0.6) for i in range(n)], "lp", 2200.0)
        core = _seq(
            (caixa(0.06, bright=0.6), 0.0, 0.9),
            (leaves, 0.05, 0.5),
        )
    else:
        # sussurro respirado: ar grave modulado devagar, quase voz — quase
        n = int(SAMPLE_RATE * 0.50)
        whisper = []
        for i in range(n):
            t = i / SAMPLE_RATE
            am = 0.55 + 0.45 * math.sin(2 * math.pi * 3.3 * t + 1.0)
            whisper.append(_noise() * am * _env(i, n, 0.2, 0.5))
        core = biquad(whisper, "lp", 1100.0, q=1.2)
    out = echo(core, time_s=0.3, feedback=0.3, mix=0.35, taps=3)
    # Cama de ar contínua sob o evento: preenche os vãos (o fiscal exige corpo
    # RMS mesmo em som esparso) e cola o grito na respiração da mata.
    n_total = len(out)
    bed = biquad([_noise() * 0.55 * _env(i, n_total, 0.25, 0.4) for i in range(n_total)],
                 "lp", 750.0)
    return _normalize(_mix(out, bed), 0.5)


def dpad_tap_wav():
    # Toque nas garras do D-pad de combate: tock surdo de madeira (caixa abafada +
    # nó grave curtíssimo). Mais escuro, mais curto e menos brilhante que o ui_click
    # — é feedback tátil de dedo, não clique de menu. O nível baixo vem do play
    # (AudioDirector.DPAD_TAP_VOLUME_DB), não do asset (o fiscal normaliza).
    knock = pulse(0.028, 220.0 * _jit(0.1), duty=0.5, attack=0.001, release=0.5)
    body = biquad(caixa(0.035, bright=0.5), "lp", 1500.0, q=0.9)
    return _normalize(_mix(body, [s * 0.6 for s in knock]), 0.5)


def combat_miss_wav():
    # ERROU a janela de timing: whiff seco e ABAFADO, caindo de tom — o golpe que
    # passa raspando, sem carne. Negativo e visceral (NUNCA o blip de menu): ar com
    # peso (ruído LP) + um nó grave que despenca. Lê de ouvido como "furou".
    n = int(SAMPLE_RATE * 0.16)
    air = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # tom despencando: a tensão do golpe que não conecta.
        freq = 300.0 * (1.0 - 0.6 * (i / n))
        phase = (t * freq) % 1.0
        saw = 2.0 * phase - 1.0
        e = _env(i, n, 0.004, 0.65)
        air.append((0.25 * saw + 0.75 * _noise()) * e * 0.5)
    air = biquad(air, "lp", 1400.0 * _jit(0.12), q=0.9)
    thud = alfaia(0.10, base=70.0, punch=0.5)  # corpo surdo, sem estalo
    return _normalize(bitcrush(_mix(air, [s * 0.5 for s in thud]), bits=7), 0.55)


def hit_heavy_wav():
    # CRÍTICO: o impacto do hit, porém MAIOR — alfaia mais grave e longa, estalo de
    # caixa mais brilhante e um clangor de gongue por cima (o "brilho" do crítico).
    # Acima do hit normal na escada de impacto: o ouvido lê "este foi pesado".
    body = _mix(
        alfaia(0.26, base=52.0, punch=1.0),
        caixa(0.11, bright=0.45),
        [s * 0.5 for s in gongue(0.14, freq=480.0)],
    )
    # Passada escura: peso vem só do corpo grave (lowshelf). O highshelf +2dB @4.2kHz
    # que dava o "brilho" do crítico foi removido — era o agudo de combate mais audível.
    return _normalize(biquad(body, "lowshelf", 120.0, gain_db=4.0), 0.97)


def combat_block_wav():
    # APAROU (faixa GOOD): aparada seca e curta — o golpe bate na guarda da Caipora e
    # morre. POSITIVA (não é o whiff do erro) e mais LEVE que o crítico (hit_heavy):
    # estalo de caixa + corpo curto + um tinido metálico abafado de gongue. Low-pass
    # mantém na passada escura.
    body = _mix(
        caixa(0.07, bright=0.6),
        alfaia(0.08, base=96.0, punch=0.5),
        [s * 0.4 for s in gongue(0.10, freq=560.0)],
    )
    return _normalize(biquad(body, "lp", 3200.0 * _jit(0.1), q=0.8), 0.85)


def erva_vida_wav():
    # Colher a Erva da Vida (pickup de HP máx.): som ORGÂNICO, agradável e ÚNICO —
    # a planta cede (folha amassada + chocalho de ganzá subindo) sob um sopro
    # ASPIRADO que floresce pra cima (a vida entrando), coroado por um agogô doce e
    # abafado; cauda curta de reverb que "floresce". Nada de baque percussivo de
    # combate — é acolhimento, não impacto. Distinto do herb_pickup do cachimbo.
    n = int(SAMPLE_RATE * 0.10)
    leaf = [_noise() * _env(i, n, 0.004, 0.6) for i in range(n)]
    leaf = biquad(leaf, "lp", 1500.0, q=0.9)
    rustle = ganza(0.16, rising=True)
    breath = assovio(0.30, 480.0, freq_end=900.0, breath=0.05)  # a vida subindo
    bloom = agogo(0.22, freq=1046.0, bend=0.06)                 # ding doce que floresce
    body = _mix(
        [s * 0.45 for s in leaf],
        [s * 0.5 for s in rustle],
        [s * 0.6 for s in breath],
        [s * 0.5 for s in bloom],
    )
    return _normalize(schroeder(body, mix=0.18, decay=0.6, tail=0.35), 0.7)


# ─── Moves nomeados (PRD docs/PRD-moves-nomeados.md) ───────────────────────
# Som PRÓPRIO por golpe (modelo Pokémon), 1 variante só (budget de browser).
# Tocados por SfxSystem.play_named em _start_enemy_turn. Curtos (~0.2-0.4s),
# fiéis ao caráter descrito no PRD. NÃO substituem o tell de timing (timing_alert),
# que segue por hit — isto é identidade, não interrompe a dinâmica reativa.

def _noise_burst(dur, lp=None, hp=None, attack=0.004, release=0.5, amp=0.6):
    n = int(SAMPLE_RATE * dur)
    out = [_noise() * _env(i, n, attack, release) * amp for i in range(n)]
    if lp:
        out = biquad(out, "lp", lp)
    if hp:
        out = biquad(out, "hp", hp)
    return out

def _moan(dur=0.22, freq=180.0, drop=0.4, vib=5.0):
    # Gemido frio: saw caindo de tom com tremolo + ar, LP escuro.
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq * (1.0 - drop * (i / n))
        ph = (t * f) % 1.0
        saw = 2.0 * ph - 1.0
        trem = 0.8 + 0.2 * math.sin(2 * math.pi * vib * t)
        e = _env(i, n, 0.02, 0.5)
        out.append((0.5 * saw * trem + 0.3 * _noise()) * e * 0.5)
    return biquad(out, "lp", 1200.0, q=1.0)

def _swirl(dur, center, amp=0.6):
    # Rajada giratória: ruído banda-passa com AM rápida (redemoinho).
    n = int(SAMPLE_RATE * dur)
    out = []
    for i in range(n):
        t = i / SAMPLE_RATE
        am = 0.5 + 0.5 * math.sin(2 * math.pi * 22.0 * t)
        out.append(_noise() * am * _env(i, n, 0.02, 0.5) * amp)
    return biquad(out, "bp", center, q=1.2)

# Assombração
def mv_assovio_cova():
    cry = assovio(0.30, 1000.0, freq_end=300.0, breath=0.28)
    snap = _noise_burst(0.05, lp=2600.0, hp=600.0, attack=0.001, release=0.4, amp=0.8)
    return _normalize(_seq((cry, 0.0, 0.7), (snap, 0.27, 0.7)), 0.6)

def mv_maos_alem():
    knock = lambda: biquad(alfaia(0.12, base=70.0, punch=0.7), "lp", 900.0)
    return _normalize(_seq((knock(), 0.0, 0.8), (knock(), 0.16, 0.8)), 0.7)

def mv_procissao_almas():
    chain = _seq(
        (_moan(0.20, 200.0), 0.0, 0.7),
        (_moan(0.20, 170.0), 0.16, 0.6),
        (_moan(0.20, 220.0), 0.32, 0.6),
        (_moan(0.20, 160.0), 0.48, 0.5),
    )
    return _normalize(echo(chain, time_s=0.18, feedback=0.25, mix=0.3, taps=3), 0.6)

# Criatura / Boss-criatura
def mv_dilacerar():
    tear = _noise_burst(0.12, lp=3000.0, hp=800.0, attack=0.001, release=0.55, amp=0.7)
    body = alfaia(0.14, base=66.0, punch=0.9)
    return _normalize(_mix(tear, [s * 0.7 for s in body]), 0.8)

def mv_mordida_dobrada():
    bite = lambda b: _mix(caixa(0.06, bright=b), _noise_burst(0.05, hp=1200.0, amp=0.5))
    # Cama grave contínua sob as duas mordidas: enche o vão (o fiscal exige corpo RMS).
    n = int(SAMPLE_RATE * 0.20)
    growl = biquad([_noise() * _env(i, n, 0.02, 0.5) * 0.4 for i in range(n)], "lp", 800.0)
    return _normalize(_seq((growl, 0.0, 0.5), (bite(0.5), 0.0, 0.8), (bite(0.6), 0.14, 0.8)), 0.75)

def mv_furia_carnica():
    g = lambda f: _mix(_moan(0.12, f, drop=0.2, vib=8.0), alfaia(0.10, base=60.0, punch=0.8))
    return _normalize(_seq((g(160), 0.0, 0.7), (g(200), 0.16, 0.8), (g(260), 0.32, 0.9)), 0.85)

def mv_investida():
    stomp = alfaia(0.18, base=52.0, punch=1.0)
    gore = lambda: _noise_burst(0.06, lp=2600.0, hp=700.0, amp=0.6)
    return _normalize(_seq((stomp, 0.0, 0.9), (gore(), 0.14, 0.7), (gore(), 0.24, 0.7)), 0.85)

def mv_esmaga_ossos():
    crack = _noise_burst(0.03, hp=2500.0, attack=0.001, release=0.3, amp=0.7)
    hitb = lambda: _mix(alfaia(0.16, base=50.0, punch=1.0), [s * 0.6 for s in crack])
    return _normalize(_seq((hitb(), 0.0, 0.95), (hitb(), 0.20, 0.95)), 0.9)

def mv_frenesi():
    # Estalos mais contidos (menos picudos) sobre uma cama densa e contínua: o rosnado
    # raivoso que não pausa. Crest factor menor => RMS sobe sem estourar o pico.
    snap = lambda: _mix(caixa(0.05, bright=0.45), _noise_burst(0.04, hp=1400.0, amp=0.35))
    n = int(SAMPLE_RATE * 0.34)
    bed = biquad([_noise() * _env(i, n, 0.04, 0.4) * 0.7 for i in range(n)], "bp", 1000.0, q=0.6)
    return _normalize(_seq((bed, 0.0, 0.9), (snap(), 0.0, 0.6), (snap(), 0.09, 0.6),
                           (snap(), 0.18, 0.7), (snap(), 0.27, 0.8)), 0.8)

# Mula sem Cabeça
def mv_galope_sem_cabeca():
    hoof = lambda: biquad(pulse(0.05, 150.0 * _jit(0.1), duty=0.5, attack=0.001, release=0.5), "lp", 1200.0)
    return _normalize(_seq(
        (hoof(), 0.0, 0.6), (hoof(), 0.12, 0.6), (hoof(), 0.22, 0.7), (hoof(), 0.30, 0.8),
        (alfaia(0.16, base=56.0, punch=1.0), 0.36, 0.9),
    ), 0.8)

def mv_coice_brasa():
    kick = alfaia(0.14, base=60.0, punch=1.0)
    hiss = _noise_burst(0.22, hp=1500.0, attack=0.01, release=0.4, amp=0.5)
    n = int(SAMPLE_RATE * 0.22)
    ember = biquad([(_noise() if random.random() < 0.02 else 0.0) for _ in range(n)], "hp", 2500.0)
    return _normalize(_seq((kick, 0.0, 0.9), (_mix(hiss, [s * 0.6 for s in ember]), 0.08, 0.6)), 0.75)

# Boitatá
def mv_brasa_rasteira():
    n = int(SAMPLE_RATE * 0.28)
    breath = biquad([_noise() * math.sin(math.pi * i / n) * 0.6 for i in range(n)], "lp", 800.0)
    crackle = biquad([(_noise() if random.random() < 0.015 else 0.0) for _ in range(n)], "hp", 1800.0)
    return _normalize(_mix(breath, [s * 0.7 for s in crackle]), 0.6)

def mv_labareda_viva():
    n = int(SAMPLE_RATE * 0.34)
    roar = biquad([_noise() * _env(i, n, 0.05, 0.5) * 0.7 for i in range(n)], "bp", 1500.0, q=0.7)
    up = assovio(0.34, 300.0, freq_end=1200.0, breath=0.4)
    return _normalize(_mix(roar, [s * 0.4 for s in up]), 0.7)

def mv_fogo_fatuo():
    n = int(SAMPLE_RATE * 0.26)
    flick = []
    for i in range(n):
        t = i / SAMPLE_RATE
        am = 0.5 + 0.5 * math.sin(2 * math.pi * 18.0 * t)
        ph = (t * 620.0) % 1.0
        flick.append((2 * ph - 1) * am * _env(i, n, 0.02, 0.5) * 0.4)
    flick = biquad(flick, "lp", 2000.0)
    snap = _noise_burst(0.05, hp=1500.0, attack=0.001, release=0.4, amp=0.8)
    return _normalize(_seq((flick, 0.0, 0.7), (snap, 0.24, 0.8)), 0.6)

def mv_cobra_fogo():
    n = int(SAMPLE_RATE * 0.38)
    sear = biquad([_noise() * _env(i, n, 0.04, 0.4) * 0.7 for i in range(n)], "hp", 2200.0)
    hot = pulse(0.38, 1320.0, duty=0.15, vib=6.0, release=0.4)
    return _normalize(bitcrush(_mix(sear, [s * 0.3 for s in hot]), bits=7), 0.7)

# Curupira
def mv_pe_virado():
    leaves = _noise_burst(0.16, lp=2200.0, attack=0.02, release=0.5, amp=0.5)
    whip = assovio(0.12, 600.0, freq_end=1600.0, breath=0.3)  # sobe: direção errada
    return _normalize(_seq((leaves, 0.0, 0.6), (whip, 0.10, 0.7)), 0.6)

def mv_trilha_falsa():
    step = lambda: biquad(_noise_burst(0.05, lp=1500.0, amp=0.4), "lp", 1200.0)
    strike = _mix(caixa(0.06, bright=0.5), alfaia(0.10, base=64.0, punch=0.8))
    return _normalize(_seq((step(), 0.0, 0.5), (step(), 0.10, 0.5),
                           (step(), 0.20, 0.6), (strike, 0.30, 0.9)), 0.7)

# Saci
def mv_assovio_mato():
    # Assobio curto e cortante + cauda de ar suave: o tom puro sozinho fica HOT demais
    # (RMS acima da faixa); o ar baixa o RMS sem perder o corte.
    cry = assovio(0.16, 1700.0, freq_end=2100.0, breath=0.06)
    tail = _noise_burst(0.12, lp=1600.0, attack=0.02, release=0.6, amp=0.18)
    return _normalize(_seq((cry, 0.0, 0.7), (tail, 0.13, 0.5)), 0.6)

def mv_redemoinho():
    return _normalize(_seq((_swirl(0.14, 1200.0), 0.0, 0.6),
                           (_swirl(0.14, 1500.0), 0.12, 0.7),
                           (_swirl(0.16, 1900.0), 0.24, 0.8)), 0.6)

def mv_travessura():
    blip = lambda f: pulse(0.05, f, duty=0.25, release=0.5)
    dark = _mix(caixa(0.06, bright=0.4), _noise_burst(0.05, hp=900.0, amp=0.5))
    return _normalize(_seq((blip(880.0), 0.0, 0.6), (blip(1100.0), 0.10, 0.6),
                           (blip(1320.0), 0.20, 0.6), (dark, 0.30, 0.8)), 0.6)

def mv_ventania():
    whip = lambda up: assovio(0.10, 700.0 if up else 1500.0,
                              freq_end=1500.0 if up else 700.0, breath=0.35)
    return _normalize(_seq((whip(True), 0.0, 0.6), (whip(False), 0.10, 0.6),
                           (whip(True), 0.20, 0.7), (whip(False), 0.30, 0.7)), 0.6)

# Jesuíta
def mv_catequese():
    toll = lambda f: gongue(0.18, freq=f)
    chain = _seq((toll(330.0), 0.0, 0.8), (toll(330.0), 0.22, 0.7), (toll(440.0), 0.44, 0.8))
    return _normalize(schroeder(chain, mix=0.25, decay=0.7, tail=0.4), 0.7)

def mv_espada_fe():
    clink = lambda f: _mix(agogo(0.10, freq=f, bend=0.03), _noise_burst(0.03, hp=3000.0, amp=0.3))
    return _normalize(_seq((clink(1980.0), 0.0, 0.7), (clink(2200.0), 0.10, 0.7),
                           (clink(1760.0), 0.20, 0.8), (clink(2480.0), 0.30, 0.9)), 0.7)

# Caçador
def mv_emboscada():
    cock = pulse(0.03, 1200.0, duty=0.125, attack=0.001, release=0.3)
    shot = lambda: _mix(_noise_burst(0.06, hp=400.0, attack=0.001, release=0.5, amp=0.8),
                        alfaia(0.10, base=58.0, punch=0.9))
    return _normalize(_seq((cock, 0.0, 0.5), (shot(), 0.10, 0.95), (shot(), 0.20, 0.8)), 0.85)

# Caipora (herói)
def mv_garra_rubra():
    swipe = assovio(0.10, 1800.0, freq_end=700.0, breath=0.25)
    impact = _mix(caixa(0.07, bright=0.55), alfaia(0.10, base=62.0, punch=0.9))
    return _normalize(_seq((swipe, 0.0, 0.6), (impact, 0.07, 0.9)), 0.8)

def mv_acoite_cipo():
    whip = lambda: assovio(0.10, 1500.0, freq_end=500.0, breath=0.3)
    snap = _noise_burst(0.03, hp=2000.0, amp=0.4)
    return _normalize(_seq((whip(), 0.0, 0.7), (snap, 0.08, 0.5),
                           (whip(), 0.16, 0.7), (snap, 0.24, 0.5)), 0.65)


# Catálogo de moves: stem do WAV (= audio_event no .tres) -> gerador.
MOVES = {
    "mv_assovio_cova": mv_assovio_cova,
    "mv_maos_alem": mv_maos_alem,
    "mv_procissao_almas": mv_procissao_almas,
    "mv_dilacerar": mv_dilacerar,
    "mv_mordida_dobrada": mv_mordida_dobrada,
    "mv_furia_carnica": mv_furia_carnica,
    "mv_investida": mv_investida,
    "mv_esmaga_ossos": mv_esmaga_ossos,
    "mv_frenesi": mv_frenesi,
    "mv_galope_sem_cabeca": mv_galope_sem_cabeca,
    "mv_coice_brasa": mv_coice_brasa,
    "mv_brasa_rasteira": mv_brasa_rasteira,
    "mv_labareda_viva": mv_labareda_viva,
    "mv_fogo_fatuo": mv_fogo_fatuo,
    "mv_cobra_fogo": mv_cobra_fogo,
    "mv_pe_virado": mv_pe_virado,
    "mv_trilha_falsa": mv_trilha_falsa,
    "mv_assovio_mato": mv_assovio_mato,
    "mv_redemoinho": mv_redemoinho,
    "mv_travessura": mv_travessura,
    "mv_ventania": mv_ventania,
    "mv_catequese": mv_catequese,
    "mv_espada_fe": mv_espada_fe,
    "mv_emboscada": mv_emboscada,
    "mv_garra_rubra": mv_garra_rubra,
    "mv_acoite_cipo": mv_acoite_cipo,
}


def finisher_cortejo_wav():
    # Clímax do Golpe Carregado (Cortejo): os espíritos ESQUARTEJAM o inimigo.
    # Três camadas: (1) coro/uivo espectral grave SUSTENTADO — cama contínua que
    # garante corpo RMS (à la mata_event); (2) DILACERAÇÃO carnuda no impacto
    # (alfaia grave + estalo de caixa + rasgo de ruído filtrado, na escada do
    # hit_heavy); (3) cauda de CHAMA verde-fantasma crepitando + sopro de espírito
    # que floresce. Echo dá o caráter de cortejo (mata responde).
    dur = 0.7
    n = int(SAMPLE_RATE * dur)

    # (1) Coro fantasma: drone detunado grave + quinta + ar respirado com AM lenta.
    choir = []
    for i in range(n):
        t = i / SAMPLE_RATE
        drone = (math.sin(2 * math.pi * 98.0 * t)
                 + math.sin(2 * math.pi * 99.5 * t)          # detune -> batimento
                 + 0.6 * math.sin(2 * math.pi * 147.0 * t))  # quinta acima
        am = 0.6 + 0.4 * math.sin(2 * math.pi * 5.5 * t + 0.7)
        breath = _noise() * 0.55 * am
        e = _env(i, n, 0.04, 0.8)
        choir.append((0.5 * drone + breath) * e * 0.72)
    choir = biquad(choir, "lp", 1000.0, q=1.1)

    # (2) Dilaceração: carne/osso cedendo no ataque (transiente domado para não
    #     estourar o crest factor — o corpo RMS vem da cama, não do baque).
    rip = _noise_burst(0.26, lp=2600.0, hp=300.0, attack=0.006, release=0.85, amp=0.65)
    tear = _mix(
        alfaia(0.30, base=48.0, punch=0.55),
        caixa(0.12, bright=0.5),
        [s * 0.7 for s in rip],
        [s * 0.4 for s in gongue(0.18, freq=440.0)],
    )

    # (3) Chama verde-fantasma: crepitar filtrado decaindo + sopro que sobe.
    n_fl = int(SAMPLE_RATE * 0.5)
    crackle = []
    for i in range(n_fl):
        t = i / SAMPLE_RATE
        spark = _noise() * (0.6 + 0.4 * math.sin(2 * math.pi * 30.0 * t * _jit(0.2)))
        crackle.append(spark * _env(i, n_fl, 0.05, 0.7) * 0.7)
    crackle = biquad(crackle, "lp", 2400.0)
    wail = assovio(0.5, 520.0, freq_end=820.0, breath=0.2)  # espírito subindo

    body = _seq(
        (choir, 0.0, 1.0),
        (tear, 0.04, 0.8),
        (crackle, 0.2, 0.95),
        (wail, 0.18, 0.45),
    )
    # Cama de ar contínua sob o evento (padrão mata_event): preenche os vãos para
    # o fiscal achar corpo RMS mesmo com transiente forte, e cola tudo na
    # respiração da mata.
    n_total = len(body)
    bed = biquad([_noise() * 0.55 * _env(i, n_total, 0.06, 0.45) for i in range(n_total)],
                 "lp", 800.0)
    mixed = echo(_mix(body, bed), time_s=0.26, feedback=0.32, mix=0.32, taps=4)
    # Soft-clip (tanh): comprime o pico isolado que o echo pode construir e adensa
    # o corpo — mantém o RMS dentro da faixa em TODAS as variantes (seeds), sem
    # depender só da saturação progressiva do _conform_sfx.
    mixed = [math.tanh(s * 1.6) for s in mixed]
    return _normalize(mixed, 0.6)


def cortejo_charge_wav():
    # Chamado (SEGURAR): assobio espectral que SOBE de pitch conforme a carga enche
    # (~CHAMADO_CHARGE_SEC = 1.1s) — a mata respondendo à mão erguida — sobre uma cama
    # contínua de ar grave (corpo RMS, à la mata_event). Toca 1x ao abrir o medidor;
    # o release corta o clima com o timing_alert (banda) e a barragem.
    dur = 1.1
    n = int(SAMPLE_RATE * dur)
    # Assobio espectral subindo (170 -> 560 Hz): a resposta da floresta ao chamado.
    rise = assovio(dur, 170.0, freq_end=560.0, breath=0.4)
    # Cama grave contínua: drone detunado + ar filtrado com AM lenta (garante o corpo).
    bed = []
    for i in range(n):
        t = i / SAMPLE_RATE
        drone = math.sin(2 * math.pi * 66.0 * t) + 0.6 * math.sin(2 * math.pi * 99.0 * t)
        am = 0.6 + 0.4 * math.sin(2 * math.pi * 3.2 * t + 0.5)
        bed.append((0.5 * drone + _noise() * 0.4 * am) * _env(i, n, 0.1, 0.45) * 0.7)
    bed = biquad(bed, "lp", 720.0)
    return _mix(rise, bed)


GENERATORS = {
    "attack": attack_wav,
    "hit": hit_wav,
    "dodge": dodge_wav,
    "timing_perfect": timing_perfect_wav,
    "timing_alert": timing_alert_wav,
    "death": death_wav,
    "ui_click": ui_click_wav,
    "step_grass": step_grass_wav,
    "step_stone": step_stone_wav,
    "hurt_caipora": hurt_caipora_wav,
    "ui_hover": ui_hover_wav,
    "herb_pickup": herb_pickup_wav,
    "pipe_smoke": pipe_smoke_wav,
    "mata_event": mata_event_wav,
    # NOVOS geradores entram sempre no FIM do dicionário: a seed da variante é
    # única por passada e cada gerador consome o stream — inserir no meio mudaria
    # os bytes de todos os SFX seguintes.
    "dpad_tap": dpad_tap_wav,
    "combat_miss": combat_miss_wav,
    "hit_heavy": hit_heavy_wav,
    "erva_vida": erva_vida_wav,
    "combat_block": combat_block_wav,
    "finisher_cortejo": finisher_cortejo_wav,
    "cortejo_charge": cortejo_charge_wav,
}


# ─── Ambiência (loops costurados) ──────────────────
def _loopify(render, n, fade):
    """Costura um loop sem emenda com crossfade de coseno (zero artefatos de emenda)."""
    out = list(render[:n])
    for i in range(fade):
        w = 0.5 - 0.5 * math.cos(math.pi * i / fade)  # cosine fade-in
        out[i] = render[i] * w + render[n + i] * (1.0 - w)
    return out


def amb_forest(dur=10.0):
    """Floresta amazônica: hum grave + insetos filtrados (mais leve) + rio +
    assovio-leitmotif âncora em dois pontos do loop. Bed da exploração."""
    fade = int(SAMPLE_RATE * 0.6)
    n = int(SAMPLE_RATE * dur)
    total = n + fade
    out = [0.0] * total
    hp = 0.0
    lp = 0.0
    # assovio entra em 20% e 70% do loop como âncora melódica distante (não estridente):
    # grave e baixo no mix p/ soar como assobio longínquo da mata, nunca como apito/sirene.
    whistle_a = int(n * 0.20)
    whistle_b = int(n * 0.70)
    # v2: eco de mata no assovio (aplicado ao SAMPLE antes de embutir — efeitos no
    # buffer inteiro quebrariam a emenda do loop). Repetições somem na distância.
    whistle = echo(assovio(1.8, freq=480.0), time_s=0.26, feedback=0.3, mix=0.22, taps=3)
    for i in range(total):
        t = i / SAMPLE_RATE
        hum = 0.10 * math.sin(2 * math.pi * 70.0 * t) + 0.06 * math.sin(2 * math.pi * 112.0 * t)
        hum *= 0.8 + 0.2 * math.sin(2 * math.pi * 0.12 * t)
        raw = _noise()
        lp = lp * 0.5 + raw * 0.5
        hp = raw - lp
        # insetos: amplitude reduzida (×0.6) para textura menos saturada
        insects = hp * (0.03 + 0.03 * abs(math.sin(2 * math.pi * 7.0 * t))) * (0.6 + 0.4 * math.sin(2 * math.pi * 0.4 * t))
        river = lp * 0.06 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.2 * t + 1.0))
        s = hum + insects + river
        pos = i % n  # posição no loop (ignora overhang para colocar assobios)
        if whistle_a <= pos < whistle_a + len(whistle):
            s += whistle[pos - whistle_a] * 0.045
        if whistle_b <= pos < whistle_b + len(whistle):
            s += whistle[pos - whistle_b] * 0.045
        out[i] = s
    return _normalize(_loopify(out, n, fade), 0.5)


def amb_dread(dur=8.0):
    """Arena: drone grave com batimento hipnótico + saw escuro + pulso sub de
    respiração. Cintilação reduzida para continuidade. Opressivo."""
    fade = int(SAMPLE_RATE * 0.6)
    n = int(SAMPLE_RATE * dur)
    total = n + fade
    out = [0.0] * total
    lp = 0.0
    for i in range(total):
        t = i / SAMPLE_RATE
        # batimento 2.5 Hz (55.0 + 57.5): mais lento = mais hipnótico
        drone = 0.16 * math.sin(2 * math.pi * 55.0 * t) + 0.14 * math.sin(2 * math.pi * 57.5 * t)
        # pulso sub grave: respiração lenta do ambiente
        sub_pulse = 0.05 * math.sin(2 * math.pi * 0.08 * t)
        # saw escuro filtrado
        phase = (t * 41.0) % 1.0
        saw = (2.0 * phase - 1.0)
        lp = lp * 0.92 + saw * 0.08
        dark = lp * 0.12
        # shimmer reduzido (×0.4) para não quebrar continuidade
        shimmer = _noise() * 0.008 * max(0.0, math.sin(2 * math.pi * 0.07 * t))
        out[i] = drone + sub_pulse + dark + shimmer
    return _normalize(_loopify(out, n, fade), 0.6)


def amb_fire(dur=9.0):
    """Fase 2 (floresta em chamas): crepitar de fogo (estalos de ruído aleatórios) +
    rugido grave filtrado + brasas agudas esparsas. Quente e inquieto."""
    fade = int(SAMPLE_RATE * 0.6)
    n = int(SAMPLE_RATE * dur)
    total = n + fade
    out = [0.0] * total
    lp = 0.0
    for i in range(total):
        t = i / SAMPLE_RATE
        raw = _noise()
        lp = lp * 0.85 + raw * 0.15
        roar = lp * 0.12 * (0.7 + 0.3 * math.sin(2 * math.pi * 0.15 * t))
        # estalos: bursts curtos e aleatórios (crepitar da lenha)
        crackle = 0.0
        if random.random() < 0.06:
            crackle = _noise() * 0.5 * math.exp(-random.uniform(20.0, 60.0) * 0.0)
        ember = (raw - lp) * 0.04 * abs(math.sin(2 * math.pi * 3.0 * t))
        out[i] = roar + crackle + ember
    return _normalize(_loopify(out, n, fade), 0.55)


def amb_fog(dur=9.0):
    """Fase 3 (névoa): drone abafado e detuneado, sopro de vento grave e sussurros
    filtrados. Opressivo e desorientador (lowpass pesado)."""
    fade = int(SAMPLE_RATE * 0.6)
    n = int(SAMPLE_RATE * dur)
    total = n + fade
    out = [0.0] * total
    lp = 0.0
    lp2 = 0.0
    for i in range(total):
        t = i / SAMPLE_RATE
        # drone detuneado (batimento lento, dissonância de névoa)
        drone = 0.12 * math.sin(2 * math.pi * 98.0 * t) + 0.10 * math.sin(2 * math.pi * 100.7 * t)
        drone += 0.06 * math.sin(2 * math.pi * 146.5 * t)  # 5ª turva
        wind = _noise()
        lp = lp * 0.97 + wind * 0.03  # vento muito abafado
        breath = lp * 0.18 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.09 * t))
        # sussurros: ruído de banda média pulsando devagar
        lp2 = lp2 * 0.8 + wind * 0.2
        whisper = (lp2 - lp) * 0.05 * max(0.0, math.sin(2 * math.pi * 0.13 * t))
        out[i] = drone * (0.8 + 0.2 * math.sin(2 * math.pi * 0.05 * t)) + breath + whisper
    return _normalize(_loopify(out, n, fade), 0.55)


def amb_church(dur=10.0):
    """Fase 5 (A Igreja na Mata): pingar d'água no batistério, círios crepitando,
    sussurro de reza distante e fantasma de órgão em C2 (tônica do frígio da fase).
    Frio, úmido, profano."""
    fade = int(SAMPLE_RATE * 0.6)
    n = int(SAMPLE_RATE * dur)
    total = n + fade
    out = [0.0] * total
    lp = 0.0
    lp2 = 0.0
    # pingo: seno curto com queda de pitch (900→550 Hz) e decay rápido
    drip_n = int(SAMPLE_RATE * 0.08)
    drip = []
    for i in range(drip_n):
        t = i / SAMPLE_RATE
        f = 900.0 - 350.0 * (i / drip_n)
        drip.append(math.sin(2 * math.pi * f * t) * math.exp(-40.0 * t))
    # ~6 pingos em pontos fixos do loop (âncoras determinísticas, à la amb_forest)
    drip_at = [int(n * p) for p in (0.08, 0.23, 0.41, 0.55, 0.72, 0.90)]
    for i in range(total):
        t = i / SAMPLE_RATE
        # fantasma de órgão: C2 + quinta, com batimento lento (parente do amb_dread)
        organ = 0.05 * math.sin(2 * math.pi * 65.41 * t) + 0.04 * math.sin(2 * math.pi * 65.85 * t)
        organ += 0.03 * math.sin(2 * math.pi * 98.0 * t)
        organ *= 0.7 + 0.3 * math.sin(2 * math.pi * 0.06 * t)
        raw = _noise()
        lp = lp * 0.97 + raw * 0.03
        lp2 = lp2 * 0.8 + raw * 0.2
        # sussurro de reza: banda média (amb_fog) com vai-e-vem + cadência silábica
        prayer = (lp2 - lp) * 0.06 * max(0.0, math.sin(2 * math.pi * 0.11 * t)) \
            * (0.6 + 0.4 * abs(math.sin(2 * math.pi * 2.3 * t)))
        # círios: estalos secos e esparsos (crepitar do amb_fire, bem mais raro)
        crackle = _noise() * 0.2 if random.random() < 0.02 else 0.0
        s = organ + prayer + crackle + lp * 0.08
        pos = i % n
        for d0 in drip_at:
            if d0 <= pos < d0 + drip_n:
                s += drip[pos - d0] * 0.12
        out[i] = s
    return _normalize(_loopify(out, n, fade), 0.55)


def heartbeat(dur=2.0):
    """Coração da Caipora (HP crítico, 'modo coração'): lub-dub de alfaia surda a
    60 BPM. Loop limpo sem costura — o tambor decai a zero antes da virada."""
    n = int(SAMPLE_RATE * dur)
    out = [0.0] * n
    for beat_at in (0.0, 1.0):
        lub = alfaia(0.16, base=55.0, punch=0.5)
        dub = alfaia(0.13, base=50.0, punch=0.3)
        for i, s in enumerate(lub):
            out[(int(beat_at * SAMPLE_RATE) + i) % n] += s
        for i, s in enumerate(dub):
            out[(int((beat_at + 0.32) * SAMPLE_RATE) + i) % n] += s * 0.7
    return _normalize(biquad(out, "lp", 320.0, q=0.9), 0.7)  # surdo: bate no peito


AMBIENCES = {
    "amb_forest": amb_forest,
    "amb_dread": amb_dread,
    "amb_fire": amb_fire,
    "amb_fog": amb_fog,
    "amb_church": amb_church,
    "heartbeat": heartbeat,
}


# ─── Música por contexto (loops híbridos: maracatu + chiptune) ─────
# Cada faixa é um loop ÚNICO (não mais 3 stems): percussão orgânica do baque virado
# somada a canais chiptune (lead em pulso, baixo em triângulo, ruído NES). Renderizada
# em SAMPLE_RATE e gravada a MUSIC_RATE (grão lo-fi 8-bit + arquivo leve).
# Grid de semicolcheias em 4/4; o loop é periódico (caudas dão wrap = sem emenda).

# Tônicas graves por contexto (Hz) — registro de baixo; o lead sobe uma 8ª (grau +7).
A2, AS2, G2, F2, E2, ES2, D2, C2, DS2 = 110.0, 116.54, 98.0, 87.31, 82.41, 77.78, 73.42, 65.41, 146.83


def _new_buf(bpm, bars):
    step = (60.0 / bpm) / 4.0
    n = int(round(SAMPLE_RATE * step * 16 * bars))
    return [0.0] * n, step


def _put(buf, sample, step_idx, step_dur, gain=1.0):
    """Soma um som no grid de semicolcheias, com wrap (loop sem emenda)."""
    n = len(buf)
    at = int(step_idx * step_dur * SAMPLE_RATE)
    for i, s in enumerate(sample):
        buf[(at + i) % n] += s * gain


def _drums(buf, step_dur, voice, events, humanize=False):
    """events: lista de (step, gain). voice() é zero-arg (ex.: lambda: alfaia(...)).
    humanize=True passa os eventos pelo jitter de velocity/timing (mão de tocador)."""
    if humanize:
        events = _humanize_events(events)
    for st, g in events:
        _put(buf, voice(), st, step_dur, g)


def _melody(buf, step_dur, root, scale, voice, notes):
    """notes: lista de (step, degree, len_steps, gain). voice(dur, freq)->samples."""
    for st, deg, ln, g in notes:
        f = scale_note(root, deg, scale)
        _put(buf, voice(ln * step_dur * 0.92, f), st, step_dur, g)


def _shaker_run(bars, sub=1):
    """Ganzá em semicolcheias com acento no tempo. sub>1 rareia (1 a cada sub)."""
    ev = []
    for st in range(16 * bars):
        if st % sub != 0:
            continue
        ev.append((st, 0.7 if st % 4 == 0 else 0.36))
    return ev


def _samba_shaker(bars, swing=0.28):
    """Ganzá em semicolcheias com balanço: as 'fracas' (índice ímpar) atrasam um tico
    (swing de samba/lofi) e o ataque do tempo recebe leve acento. Orgânico, nunca robótico."""
    ev = []
    for st in range(16 * bars):
        pos = st + (swing if st % 2 == 1 else 0.0)  # _put aceita passo fracionário
        g = 0.42 if st % 4 == 0 else (0.26 if st % 2 == 0 else 0.18)
        ev.append((pos, g))
    return ev


def _humanize_events(events, vel=0.08, time=0.25):
    """Humaniza eventos (step, gain): jitter de velocity (±vel) e de timing
    (±time de semicolcheia — _put aceita passo fracionário). Mata o grid robótico
    dos loops longos sem perder o baque."""
    return [(st + random.uniform(-time, time), g * _jit(vel)) for st, g in events]


def _ghost_fill(bars, every=2):
    """Fill de virada: ghost notes de caixa no fim de cada 'every'-ésimo compasso.
    Quebra a repetição interna do loop — o terreiro respira, a máquina não."""
    ev = []
    for b in range(every - 1, bars, every):
        base = b * 16
        ev += [(base + 13.0, 0.22), (base + 13.5, 0.18), (base + 14.5, 0.26), (base + 15.5, 0.2)]
    return ev


def _chord(buf, step_dur, root, scale, voice, chords):
    """Comping de acordes: chords = (step, [graus], len_steps, gain). Reparte o ganho
    entre as vozes do acorde p/ não estourar ao empilhar."""
    for st, degs, ln, g in chords:
        for deg in degs:
            f = scale_note(root, deg, scale)
            _put(buf, voice(ln * step_dur * 0.92, f), st, step_dur, g / max(1, len(degs)))


def _baque_alfaia(bars):
    """Marcação do baque virado: compasso par = base, ímpar = virada densa."""
    base = [(0, 1.0), (6, 0.7), (10, 0.8), (12, 0.6)]
    turn = [(0, 1.0), (4, 0.4), (6, 0.7), (8, 0.45), (10, 0.8), (12, 0.6), (14, 0.55), (15, 0.75)]
    ev = []
    for b in range(bars):
        pat = turn if b % 2 == 1 else base
        ev += [(st + b * 16, g) for st, g in pat]
    return ev


# Vozes melódicas reutilizáveis (lead em pulso, baixo em triângulo).
def _lead(duty=0.25, vib=0.0):
    return lambda d, f: pulse(d, f, duty=duty, vib=vib, release=0.3)


def _bass():
    return lambda d, f: triangle(d, f, release=0.15)


# ─── Tijolos de arranjo (PRD-audio-v5) ─────────────
# A lacuna do estudo Pokémon: faltava a 2ª voz de pulso (contra-melodia) e a forma
# longa. _counter() é o Pulse 2 — timbre oco (duty largo), registro mais baixo que o
# lead, para RESPONDER a melodia nos vãos (call-and-response), nunca dobrá-la.
def _counter(duty=0.5, vib=0.0):
    return lambda d, f: pulse(d, f, duty=duty, vib=vib, attack=0.006, release=0.22)


# Violão/pluck de terreiro: arpejo curto p/ a cama harmônica (sem sustentar = sem
# sirene). Reaproveitado por _chord nas faixas v5.
def _pluck(attack=0.01, release=0.32):
    return lambda d, f: triangle(d, f, attack=attack, release=release)


def _shift(events, steps):
    """Desloca uma lista de eventos (step, ...) por `steps` semicolcheias. O step é
    sempre o 1º elemento (vale p/ drums (st,g) e melody (st,deg,ln,g)). Monta forma
    longa (A/B, intro+loop) compondo motivos curtos — o que falta hoje."""
    return [(e[0] + steps,) + tuple(e[1:]) for e in events]


def _tarol(bars, accent_every=4):
    """Tarol/caixa aguda do maracatu: esteira estalada em síncope, mais miúda que a
    caixa. Adensa o baque sem encher o tempo forte (que é do surdo)."""
    ev = []
    for st in range(16 * bars):
        if st % 2 == 0:
            continue  # deixa o tempo e a contra-tempo p/ surdo/caixa; tarol nas frações
        g = 0.30 if st % accent_every == 3 else 0.18
        ev.append((st, g))
    return ev


def _poly3(bars, gain=0.22):
    """Polirritmia 3-contra-4: um agogô/sino a cada 3 semicolcheias sobre o grid de
    4 — o 'balanço' que faz o terreiro respirar (hemíola). Eventos (step, gain)."""
    return [(st, gain) for st in range(0, 16 * bars, 3)]


def _music_air(buf, root, gain=0.04, pulse_hz=0.11):
    """Cama organica discreta para loops musicais: ar lowpass + sub muito baixo.
    Entra antes do bitcrush para colar os eventos sem virar ruido constante."""
    lp = 0.0
    for i in range(len(buf)):
        t = i / SAMPLE_RATE
        raw = _noise()
        lp = lp * 0.985 + raw * 0.015
        breath = lp * (0.55 + 0.45 * math.sin(2 * math.pi * pulse_hz * t + 0.7))
        earth = math.sin(2 * math.pi * root * 0.5 * t) * 0.18
        buf[i] += (breath + earth) * gain


def _bone_clicks(buf, step, events):
    """Madeira/osso seco no arranjo: ocupa o medio sem soar como beep melodico."""
    _drums(buf, step, lambda: caixa(0.045, bright=0.42), events, humanize=True)


def _arena_layers(bpm, root, scale, density):
    """Baque virado de combate em 3 STEMS verticais sincronizados (mesmo grid,
    mesmo tamanho): base = chão (alfaia + gonguê no 1 + baixo, sempre toca),
    mid = miudezas (caixa/ganzá/hats, combate ativo), top = melodia (lead
    ostinato + agogô, alta intensidade). O AudioDirector abre/fecha mid/top.
    bitcrush POR STEM: é não-linear (crush(a+b) != crush(a)+crush(b))."""
    base, step = _new_buf(bpm, 4)
    mid, _ = _new_buf(bpm, 4)
    top, _ = _new_buf(bpm, 4)
    # BASE — o coração que nunca para
    _drums(base, step, lambda: alfaia(0.18, base=root * 0.5, punch=0.9), _baque_alfaia(4),
           humanize=True)
    _drums(base, step, lambda: gongue(0.14, 420.0), [(b * 16, 0.38) for b in range(4)])
    bass_notes = []
    for b in range(4):
        deg = 0 if b % 2 == 0 else 4
        bass_notes += [(b * 16, deg, 4, 0.8), (b * 16 + 8, deg, 4, 0.7)]
    _melody(base, step, root, scale, _bass(), bass_notes)
    # MID — caixa, ganzá e hats (a luta esquenta)
    _drums(mid, step, lambda: caixa(0.08, bright=1.0),
           [(st, 0.55) for b in range(4) for st in (b * 16 + 4, b * 16 + 12)],
           humanize=True)
    _drums(mid, step, lambda: caixa(0.06, bright=0.8), _ghost_fill(4, every=2))  # viradas
    _drums(mid, step, lambda: ganza(0.06, rising=False), _shaker_run(4))
    if density >= 2:
        _drums(mid, step, lambda: nes_noise(0.05, decay=55.0, lp=0.4, gain=0.35),
               [(st, 0.4) for st in range(64) if st % 2 == 1])
    # TOP — lead ostinato (8ª acima) + agogô de brilho
    lo, hi, md, tp = 7, 11, 9, 14
    base_pat = [(0, hi, 2), (2, lo, 2), (4, hi, 2), (6, tp, 2), (8, lo, 2), (10, hi, 2), (12, md, 2), (14, tp, 2)]
    var_pat = [(0, hi, 2), (2, md, 2), (4, tp, 2), (6, lo, 2), (8, md, 2), (10, hi, 2), (12, lo, 2), (14, md, 2)]
    lead_notes = []
    for b in range(4):
        pat = var_pat if b == 2 else base_pat
        lead_notes += [(st + b * 16, deg, ln, 0.4) for st, deg, ln in pat]
    _melody(top, step, root, scale, _lead(duty=0.25), lead_notes)
    _drums(top, step, lambda: agogo(0.12, freq=1320.0, bend=0.0),
           [(b * 16 + 4, 0.22) for b in (1, 3)])
    return {"base": bitcrush(base, bits=7), "mid": bitcrush(mid, bits=7),
            "top": bitcrush(top, bits=7)}


# ─── Faixas: telas ─────────────────────────────────
def mus_menu():
    """Menu: lento e sombrio. Leitmotif da Caipora em pulso; alfaia esparsa como
    coração lento; baixo em triângulo descendo a tríade menor."""
    buf, step = _new_buf(76, 2)
    _drums(buf, step, lambda: alfaia(0.24, base=A2 * 0.5, punch=0.7),
           [(0, 0.7), (16, 0.7), (24, 0.4)])
    _drums(buf, step, lambda: ganza(0.05, rising=False), _shaker_run(2, sub=4))
    _melody(buf, step, A2, MINOR_HARM, _bass(),
            [(0, 0, 8, 0.8), (8, 2, 8, 0.7), (16, 3, 8, 0.8), (24, 0, 8, 0.7)])
    _melody(buf, step, A2, MINOR_HARM, _lead(duty=0.5, vib=0.01),
            [(2, 9, 3, 0.42), (6, 7, 2, 0.36), (10, 11, 4, 0.48),
             (16, 10, 2, 0.4), (20, 9, 2, 0.38), (24, 7, 7, 0.46)])
    return _normalize(bitcrush(buf, bits=7), 0.8)


def mus_hub():
    """Acampamento: samba lofi morno e tranquilo — descanso entre fases. Surdo macio
    no '2 e 4', ganzá com swing, tamborim abafado nas síncopes, violão de dedilhado
    (arpejo de triângulo, oitava acima do baixo) em Dórico e um lead-pluck grave e
    esparso. REGRA ANTI-SIRENE: nenhuma dupla de vozes sustentadas perto do mesmo
    pitch — o detune por nota (_jit) faz tons longos simultâneos baterem em poucos
    Hz (uí-uí de sirene; o pad antigo sustentava 4 vozes E o grau 0 em uníssono com
    o baixo). Aqui o acorde existe só como arpejo, nota a nota, e o baixo é a única
    voz longa — sozinho, sem par para bater."""
    buf, step = _new_buf(84, 4)
    root = A2
    # Surdo de marcação: boom redondo no 2 e no 4 de cada compasso + ghost leve no 1/3.
    _drums(buf, step, lambda: alfaia(0.22, base=root * 0.5, punch=0.4),
           [(b * 16 + st, g) for b in range(4) for st, g in ((4, 0.5), (12, 0.55))])
    _drums(buf, step, lambda: alfaia(0.12, base=root, punch=0.25),
           [(b * 16 + st, g) for b in range(4) for st, g in ((0, 0.2), (8, 0.18))])
    # Ganzá com swing (chiado contínuo e leve) + tamborim/teleco-teco macio nas síncopes.
    _drums(buf, step, lambda: ganza(0.05, rising=False), _samba_shaker(4))
    _drums(buf, step, lambda: caixa(0.045, bright=0.5),
           [(3, 0.3), (6, 0.26), (11, 0.3), (14, 0.26),
            (19, 0.3), (22, 0.24), (27, 0.3), (30, 0.26),
            (35, 0.3), (38, 0.26), (43, 0.3), (46, 0.24),
            (51, 0.3), (54, 0.26), (59, 0.3), (62, 0.22)])
    # Violão de terreiro: i7 (compassos 1-2) e IV (3-4) DEDILHADOS — pluck curto,
    # nota a nota, sobe e responde descendo. Oitava acima do baixo (sem uníssono).
    violao = lambda d, f: triangle(d, f, attack=0.01, release=0.5)
    _melody(buf, step, root * 2.0, DORIAN, violao,
            [(0, 0, 1, 0.3), (2, 2, 1, 0.26), (4, 4, 1, 0.28), (6, 6, 1, 0.26),
             (11, 4, 1, 0.24), (14, 2, 1, 0.22),
             (17, 6, 1, 0.26), (20, 4, 1, 0.24), (23, 2, 1, 0.26), (26, 0, 2, 0.28),
             (32, 3, 1, 0.3), (34, 5, 1, 0.26), (36, 7, 1, 0.28), (38, 9, 1, 0.26),
             (43, 7, 1, 0.24), (46, 5, 1, 0.22),
             (49, 9, 1, 0.26), (52, 7, 1, 0.24), (55, 5, 1, 0.26), (58, 3, 2, 0.28)])
    # Baixo redondo seguindo os acordes (tônica/quinta) com a antecipação da bossa.
    # Única voz sustentada da faixa — uma voz só não tem com quem bater.
    _melody(buf, step, root, DORIAN, _bass(),
            [(0, 0, 6, 0.6), (7, 4, 2, 0.45), (10, 4, 3, 0.45),
             (16, 0, 6, 0.55), (23, 4, 2, 0.42), (26, 4, 3, 0.45),
             (32, 3, 6, 0.6), (39, 7, 2, 0.45), (42, 7, 3, 0.45),
             (48, 3, 6, 0.55), (55, 0, 2, 0.42), (60, 0, 4, 0.5)])
    # Lead-pluck esparso, grave e doce (era 2 oitavas acima — virava bip de alarme):
    # responde o violão nos vãos, release curtíssimo = pluck, nunca sustain.
    pluck = lambda d, f: pulse(d, f, duty=0.25, attack=0.004, release=0.12)
    _melody(buf, step, root * 2.0, DORIAN, pluck,
            [(8, 4, 2, 0.26), (12, 7, 2, 0.26), (28, 6, 3, 0.26),
             (40, 5, 2, 0.26), (44, 7, 2, 0.24), (60, 4, 3, 0.26)])
    return _normalize(bitcrush(buf, bits=7), 0.7)


def mus_explore_p1():
    """Fase 1 — mata noturna (PRD-audio-v5, faixa-piloto): forma longa A-B de 8
    compassos com HOOK melódico + contra-melodia (Pulse 2 respondendo nos vãos) +
    BAIXO QUE ANDA sobre cama harmônica (i–♭VI–♭VII–iv | i–♭VII–♭VI–v) + maracatu
    mais denso (surdo/baque + tarol + ganzá + polirritmia 3-contra-4 na seção B).
    Mi menor natural, grave, noturno — mais notas e mais terreiro sem virar alarme.
    Codec OGG: o loop longo cabe no budget."""
    buf, step = _new_buf(92, 8)
    root = E2
    _music_air(buf, root, gain=0.035, pulse_hz=0.09)

    # ── Percussão de terreiro (8 compassos) ──
    _drums(buf, step, lambda: alfaia(0.2, base=root * 0.5, punch=0.78),
           _baque_alfaia(8), humanize=True)              # surdo/baque virado par-ímpar
    _drums(buf, step, lambda: gongue(0.14, 300.0),
           [(b * 16, 0.34) for b in range(8)], humanize=True)  # gonguê no tempo 1
    _drums(buf, step, lambda: ganza(0.05, rising=False), _samba_shaker(8))
    _drums(buf, step, lambda: caixa(0.045, bright=1.25), _tarol(8), humanize=True)  # tarol
    _drums(buf, step, lambda: caixa(0.05, bright=0.8), _ghost_fill(8, every=2))      # viradas
    _bone_clicks(buf, step, [(b * 16 + s, 0.16) for b in range(8) for s in (7, 13)])
    # Seção B (compassos 4-7): o "balanço" 3-contra-4 levanta a energia.
    _drums(buf, step, lambda: agogo(0.12, freq=880.0, bend=0.0), _shift(_poly3(4, 0.18), 64))

    # ── Baixo que anda (raiz → quinta → terça de passagem por compasso) ──
    bar_roots = [0, 5, 6, 3, 0, 6, 5, 4]  # i ♭VI ♭VII iv | i ♭VII ♭VI v
    bass_notes = []
    for b, r in enumerate(bar_roots):
        o = b * 16
        bass_notes += [(o, r, 6, 0.6), (o + 8, r + 4, 3, 0.44), (o + 13, r + 2, 2, 0.38)]
    _melody(buf, step, root, MINOR_HARM, _bass(), bass_notes)

    # ── Cama harmônica: tríades dedilhadas curtas (sem sustentar = sem sirene) ──
    chords = []
    for b, r in enumerate(bar_roots):
        o = b * 16
        triad = [r, r + 2, r + 4]
        chords += [(o, triad, 2, 0.22), (o + 8, triad, 2, 0.18)]
    _chord(buf, step, root, MINOR_HARM, _pluck(release=0.30), chords)

    # ── HOOK (lead, Pulse 1): motivo cantável; A apresenta, B varia subindo ──
    lead_a = [(0, 7, 2, 0.30), (2, 9, 1, 0.28), (3, 11, 1, 0.30), (4, 10, 4, 0.32),
              (8, 11, 1, 0.28), (9, 12, 1, 0.30), (10, 11, 2, 0.30), (12, 9, 4, 0.30),
              (16, 9, 2, 0.28), (18, 10, 1, 0.26), (19, 9, 1, 0.28), (20, 7, 4, 0.30),
              (24, 8, 1, 0.26), (25, 9, 1, 0.26), (26, 8, 2, 0.28), (28, 7, 4, 0.30)]
    lead_b = [(64, 7, 1, 0.30), (65, 9, 1, 0.30), (66, 11, 1, 0.32), (67, 12, 1, 0.32),
              (68, 14, 4, 0.34),
              (80, 12, 2, 0.32), (82, 11, 1, 0.28), (83, 9, 1, 0.28), (84, 10, 4, 0.32),
              (96, 11, 1, 0.30), (97, 9, 1, 0.28), (98, 7, 2, 0.30), (100, 9, 2, 0.28),
              (112, 8, 1, 0.26), (113, 9, 1, 0.26), (114, 8, 1, 0.26), (116, 7, 6, 0.32)]
    _melody(buf, step, root, MINOR_HARM, _lead(duty=0.25, vib=0.006), lead_a + lead_b)

    # ── Contra-melodia (Pulse 2): responde nos vãos do hook, registro mais baixo ──
    counter = [(6, 4, 2, 0.18), (14, 2, 2, 0.18), (22, 4, 2, 0.18), (30, 4, 2, 0.20),
               (72, 5, 3, 0.20), (88, 4, 3, 0.20), (104, 5, 3, 0.20), (122, 4, 4, 0.22)]
    _melody(buf, step, root, MINOR_HARM, _counter(duty=0.5, vib=0.008), counter)

    # ── Assovio-leitmotif (a voz da mata) ecoa uma vez por seção ──
    for at in (34, 98):
        _put(buf, echo(assovio(1.1, freq=note(root, 19), breath=0.08),
                       time_s=0.22, feedback=0.22, mix=0.18, taps=2), at, step, 0.20)
    return _normalize(bitcrush(buf, bits=7), 0.78)


def mus_explore_p2():
    """Fase 2 — floresta em chamas: urgente, frígio, com brasas irregulares. O
    baixo corre, mas a frase respira em 3 compassos para nao virar alarme."""
    buf, step = _new_buf(108, 3)
    root = F2
    _music_air(buf, root, gain=0.026, pulse_hz=0.16)
    _drums(buf, step, lambda: alfaia(0.16, base=root * 0.5, punch=0.9),
           [(0, 0.88), (6, 0.48), (8, 0.72), (14, 0.5),
            (16, 0.84), (21, 0.42), (24, 0.78), (30, 0.58),
            (32, 0.9), (38, 0.52), (40, 0.7), (44, 0.36), (46, 0.62)],
           humanize=True)
    _drums(buf, step, lambda: nes_noise(0.045, decay=68.0, lp=0.32, gain=0.36),
           [(st + random.uniform(-0.08, 0.08), 0.28 + 0.12 * ((st + 1) % 4 == 0))
            for st in range(48) if st % 2 == 1])
    _drums(buf, step, lambda: ganza(0.05, rising=False), _shaker_run(3))
    _bone_clicks(buf, step, [(5, 0.16), (13, 0.18), (23, 0.18), (31, 0.16),
                             (37, 0.18), (43, 0.16), (47, 0.20)])
    _melody(buf, step, root, PHRYGIAN, _bass(),
            [(0, 0, 2, 0.68), (4, 1, 2, 0.6), (8, 0, 2, 0.64), (12, 2, 2, 0.56),
             (16, 1, 2, 0.62), (20, 0, 2, 0.62), (24, 3, 2, 0.58), (28, 1, 2, 0.56),
             (32, 0, 2, 0.68), (36, 2, 2, 0.58), (40, 1, 2, 0.62), (44, 0, 2, 0.64)])
    _melody(buf, step, root, PHRYGIAN, _lead(duty=0.25, vib=0.012),
            [(0, 7, 1, 0.34), (2, 8, 1, 0.30), (4, 10, 1, 0.34), (7, 11, 1, 0.28),
             (10, 8, 1, 0.30), (14, 7, 2, 0.34), (19, 10, 1, 0.30), (22, 12, 1, 0.32),
             (26, 8, 2, 0.32), (33, 7, 1, 0.32), (36, 11, 1, 0.34),
             (41, 10, 1, 0.32), (45, 8, 2, 0.34)])
    return _normalize(bitcrush(buf, bits=7), 0.8)


def mus_explore_p3():
    """Fase 3 — névoa: dissonante sem sirene. Tons longos viram sopros quebrados,
    o b2 aparece em lampejos, e o assovio some na lama."""
    buf, step = _new_buf(72, 3)
    root = DS2
    _music_air(buf, root, gain=0.052, pulse_hz=0.07)
    _drums(buf, step, lambda: alfaia(0.28, base=root * 0.25, punch=0.55),
           [(0, 0.56), (17, 0.38), (32, 0.5), (43, 0.32)], humanize=True)
    _drums(buf, step, lambda: ganza(0.08, rising=False),
           [(3, 0.16), (11, 0.13), (20, 0.15), (29, 0.12), (37, 0.14), (46, 0.16)],
           humanize=True)
    _melody(buf, step, root, PHRYGIAN, _bass(),
            [(0, 0, 7, 0.58), (10, 1, 3, 0.34), (16, 0, 5, 0.52),
             (24, 2, 3, 0.34), (32, 0, 6, 0.56), (41, 1, 3, 0.34)])
    fog_voice = lambda d, f: pulse(d, f, duty=0.5, vib=0.018, attack=0.05, release=0.45)
    _melody(buf, step, root, PHRYGIAN, fog_voice,
            [(4, 8, 2, 0.26), (9, 7, 2, 0.22), (15, 9, 2, 0.24),
             (22, 8, 2, 0.22), (30, 7, 2, 0.22), (36, 10, 2, 0.24),
             (44, 8, 2, 0.24)])
    _put(buf, echo(assovio(1.0, freq=note(root, 18), freq_end=note(root, 17), breath=0.16),
                   time_s=0.31, feedback=0.26, mix=0.18, taps=2), 25, step, 0.18)
    return _normalize(bitcrush(buf, bits=6), 0.76)


def mus_explore_p4():
    """Fase 4 — ossos e ruína: frio e minimo, mas nao vazio. O drone sustentado
    virou passos graves e sinos quebrados para evitar batimento de sirene."""
    buf, step = _new_buf(66, 3)
    root = C2
    _music_air(buf, root, gain=0.05, pulse_hz=0.06)
    _drums(buf, step, lambda: alfaia(0.30, base=root * 0.5, punch=0.58),
           [(0, 0.58), (19, 0.34), (32, 0.52), (45, 0.28)], humanize=True)
    _drums(buf, step, lambda: agogo(0.15, freq=820.0, bend=0.0),
           [(6, 0.22), (14, 0.18), (25, 0.24), (38, 0.2), (47, 0.16)],
           humanize=True)
    _drums(buf, step, lambda: gongue(0.18, 360.0),
           [(11, 0.18), (29, 0.16), (41, 0.18)], humanize=True)
    _bone_clicks(buf, step, [(5, 0.14), (13, 0.16), (21, 0.13), (34, 0.16), (44, 0.14)])
    _melody(buf, step, root, MINOR_HARM, _bass(),
            [(0, 0, 7, 0.56), (9, 5, 3, 0.34), (16, 3, 5, 0.46),
             (24, 5, 4, 0.38), (32, 0, 6, 0.52), (42, 3, 3, 0.36)])
    bone_lead = lambda d, f: pulse(d, f, duty=0.125, vib=0.006, attack=0.008, release=0.22)
    _melody(buf, step, root, MINOR_HARM, bone_lead,
            [(8, 7, 1, 0.22), (18, 10, 1, 0.2), (27, 8, 1, 0.18),
             (36, 11, 1, 0.22), (46, 7, 1, 0.18)])
    return _normalize(bitcrush(buf, bits=6), 0.76)


# ─── Faixas: arenas (stems; intensidade crescente por fase) ───
def mus_arena_p1():
    return _arena_layers(100, A2, MINOR_HARM, density=1)


def mus_arena_p2():
    return _arena_layers(106, AS2, PHRYGIAN, density=2)


def mus_arena_p3():
    return _arena_layers(104, G2, PHRYGIAN, density=2)


def mus_arena_p4():
    return _arena_layers(112, F2, PHRYGIAN, density=3)


# ─── Faixas: bosses (tema próprio) ─────────────────
def mus_boss_mula():
    """Mula Sem Cabeça (stems): galope (kick em tercinas) e lead agressivo. Jatos
    de fogo no canal de ruído. base=galope+baixo, mid=fogo+ganzá, top=lead."""
    base, step = _new_buf(120, 4)
    mid, _ = _new_buf(120, 4)
    top, _ = _new_buf(120, 4)
    gallop = [(st, 0.9 if st % 4 == 0 else 0.55) for b in range(4) for st in (b * 16, b * 16 + 3, b * 16 + 4, b * 16 + 8, b * 16 + 11, b * 16 + 12)]
    _drums(base, step, lambda: alfaia(0.14, base=D2 * 0.5, punch=1.0), gallop, humanize=True)
    _drums(base, step, lambda: gongue(0.14, 420.0), [(b * 16, 0.36) for b in range(4)])
    _melody(base, step, D2, MINOR_HARM, _bass(),
            [(st, 0, 2, 0.8) for st in range(0, 64, 4)])
    _drums(mid, step, lambda: nes_noise(0.06, decay=40.0, lp=0.2, gain=0.4),
           [(b * 16 + 6, 0.45) for b in range(4)] + [(b * 16 + 14, 0.4) for b in range(4)])
    _drums(mid, step, lambda: ganza(0.05, rising=False), _shaker_run(4))
    _melody(top, step, D2, MINOR_HARM, _lead(duty=0.25),
            [(st, deg, 1, 0.42) for b in range(4) for st, deg in
             ((b * 16, 7), (b * 16 + 2, 10), (b * 16 + 4, 11), (b * 16 + 6, 10),
              (b * 16 + 8, 7), (b * 16 + 10, 12), (b * 16 + 12, 11), (b * 16 + 14, 9))])
    return {"base": bitcrush(base, bits=7), "mid": bitcrush(mid, bits=7),
            "top": bitcrush(top, bits=7)}


def mus_boss_boitata():
    """Boitatá (stems): serpenteante e veloz. base=baque+baixo-semicolcheia,
    mid=fogo denso+caixa, top=lead cromático com vibrato (a cobra desliza)."""
    base, step = _new_buf(132, 4)
    mid, _ = _new_buf(132, 4)
    top, _ = _new_buf(132, 4)
    _drums(base, step, lambda: alfaia(0.12, base=E2 * 0.5, punch=0.95), _baque_alfaia(4),
           humanize=True)
    _drums(base, step, lambda: gongue(0.14, 440.0), [(b * 16, 0.34) for b in range(4)])
    _melody(base, step, E2, PHRYGIAN, _bass(),
            [(st, (st // 4) % 3, 1, 0.7) for st in range(0, 64, 2)])
    _drums(mid, step, lambda: nes_noise(0.04, decay=80.0, lp=0.35, gain=0.4),
           [(st, 0.4) for st in range(64) if st % 2 == 1])
    _drums(mid, step, lambda: caixa(0.07, bright=1.1),
           [(b * 16 + 4, 0.5) for b in range(4)] + [(b * 16 + 12, 0.55) for b in range(4)],
           humanize=True)
    _drums(mid, step, lambda: caixa(0.05, bright=0.9), _ghost_fill(4, every=2))
    serp = [0, 1, 2, 1, 3, 2, 4, 3]  # subir e escorregar
    _melody(top, step, E2, PHRYGIAN, _lead(duty=0.25, vib=0.04),
            [(b * 16 + i * 2, 7 + serp[i], 1, 0.42) for b in range(4) for i in range(8)])
    return {"base": bitcrush(base, bits=7), "mid": bitcrush(mid, bits=7),
            "top": bitcrush(top, bits=7)}


def mus_boss_curupira():
    """Curupira (stems): tribal e telúrico. base=alfaia pesada+baixo,
    mid=agogô ritualístico+ganzá, top=assovio-leitmotif com eco + lead."""
    base, step = _new_buf(116, 4)
    mid, _ = _new_buf(116, 4)
    top, _ = _new_buf(116, 4)
    _drums(base, step, lambda: alfaia(0.16, base=A2 * 0.5, punch=1.0),
           [(st, 0.9 if st % 8 == 0 else 0.6) for b in range(4) for st in (b * 16, b * 16 + 3, b * 16 + 6, b * 16 + 8, b * 16 + 11, b * 16 + 14)],
           humanize=True)
    _drums(base, step, lambda: gongue(0.14, 400.0), [(b * 16, 0.36) for b in range(4)])
    _melody(base, step, A2, MINOR_HARM, _bass(),
            [(b * 16, 0, 8, 0.8) for b in range(4)])
    _drums(mid, step, lambda: agogo(0.14, freq=1100.0, bend=0.0),
           [(b * 16 + st, 0.4) for b in range(4) for st in (2, 10)])
    _drums(mid, step, lambda: ganza(0.05, rising=False), _shaker_run(4))
    # leitmotif do assovio (a voz da floresta) em dois pontos — v2 com eco de mata
    # (aplicado ao sample antes do _put: o wrap do grid mantém o loop sem emenda).
    for at in (0, 32):
        _put(top, echo(assovio(1.0, freq=note(A2, 19)), time_s=0.24, feedback=0.3,
                       mix=0.25, taps=3), at, step, 0.34)
    _melody(top, step, A2, MINOR_HARM, _lead(duty=0.25),
            [(b * 16 + st, deg, 2, 0.36) for b in range(4) for st, deg in ((4, 9), (12, 11))])
    return {"base": bitcrush(base, bits=7), "mid": bitcrush(mid, bits=7),
            "top": bitcrush(top, bits=7)}


def mus_boss_saci():
    """Saci (stems): redemoinho travesso e épico-dark. base=baque+baixo-motor,
    mid=vento+caixa+ganzá, top=lead frenético frígio."""
    base, step = _new_buf(126, 4)
    mid, _ = _new_buf(126, 4)
    top, _ = _new_buf(126, 4)
    _drums(base, step, lambda: alfaia(0.13, base=C2 * 0.5, punch=1.0), _baque_alfaia(4),
           humanize=True)
    _drums(base, step, lambda: gongue(0.14, 410.0), [(b * 16, 0.34) for b in range(4)])
    _melody(base, step, C2, PHRYGIAN, _bass(),
            [(st, 0 if (st // 8) % 2 == 0 else 1, 1, 0.78) for st in range(0, 64, 2)])
    _drums(mid, step, lambda: caixa(0.05, bright=1.0), _ghost_fill(4, every=2))
    _drums(mid, step, lambda: nes_noise(0.08, decay=18.0, lp=0.5, gain=0.35),
           [(b * 16, 0.45) for b in range(4)])  # varredura de vento por compasso
    _drums(mid, step, lambda: caixa(0.06, bright=1.2),
           [(st, 0.45) for st in range(64) if st % 4 == 2])
    _drums(mid, step, lambda: ganza(0.05, rising=False), _shaker_run(4))
    whirl = [7, 8, 10, 11, 12, 11, 10, 8]
    _melody(top, step, C2, PHRYGIAN, _lead(duty=0.125, vib=0.02),
            [(b * 16 + i * 2, whirl[(i + b) % 8], 1, 0.44) for b in range(4) for i in range(8)])
    return {"base": bitcrush(base, bits=7), "mid": bitcrush(mid, bits=7),
            "top": bitcrush(top, bits=7)}


def mus_ending():
    """Final: contemplativo, pôr do sol. Resolve a tensão — assovio-leitmotif sereno,
    pulso doce, baixo morno, batida-coração desacelerando. Esperança."""
    buf, step = _new_buf(70, 2)
    _drums(buf, step, lambda: alfaia(0.26, base=A2 * 0.5, punch=0.5), [(0, 0.5), (20, 0.35)])
    _drums(buf, step, lambda: ganza(0.05, rising=False), _shaker_run(2, sub=4))
    _melody(buf, step, A2, MINOR_HARM, _bass(),
            [(0, 0, 8, 0.7), (8, 4, 8, 0.6), (16, 3, 8, 0.65), (24, 4, 8, 0.6)])
    _melody(buf, step, A2, MINOR_HARM, _lead(duty=0.5),
            [(2, 7, 3, 0.34), (8, 9, 3, 0.34), (14, 11, 4, 0.38), (24, 9, 3, 0.34)])
    # v2: o assovio sereno ecoa na mata que sobreviveu (eco no sample, loop-safe)
    _put(buf, echo(assovio(1.6, freq=note(A2, 19)), time_s=0.3, feedback=0.28,
                   mix=0.22, taps=3), 4, step, 0.3)
    return _normalize(bitcrush(buf, bits=7), 0.76)


def mus_explore_p5():
    """Fase 5 — A Igreja na Mata: orgao quebrado, pedra, agua e reza. O sagrado
    corrompido pulsa em blocos curtos; nada fica sustentado tempo suficiente para
    virar sirene."""
    buf, step = _new_buf(58, 3)
    root = C2
    _music_air(buf, root, gain=0.045, pulse_hz=0.05)
    _drums(buf, step, lambda: alfaia(0.32, base=root * 0.5, punch=0.55),
           [(0, 0.56), (16, 0.42), (31, 0.34), (32, 0.5), (45, 0.32)],
           humanize=True)
    _drums(buf, step, lambda: gongue(0.24, 300.0),
           [(0, 0.44), (17, 0.34), (33, 0.38)], humanize=True)
    _drums(buf, step, lambda: agogo(0.16, freq=740.0, bend=0.0),
           [(8, 0.22), (23, 0.18), (37, 0.22), (46, 0.16)], humanize=True)
    _bone_clicks(buf, step, [(6, 0.12), (13, 0.10), (27, 0.12), (41, 0.12)])
    organ = lambda d, f: triangle(d, f, attack=0.06, release=0.55)
    _melody(buf, step, root, PHRYGIAN, organ,
            [(0, 0, 5, 0.5), (7, 4, 3, 0.34), (12, 1, 3, 0.34),
             (16, 0, 4, 0.46), (24, 5, 4, 0.34), (32, 1, 5, 0.48),
             (40, 4, 3, 0.32), (44, 0, 3, 0.38)])
    chant = lambda d, f: pulse(d, f, duty=0.5, vib=0.018, attack=0.08, release=0.45)
    _melody(buf, step, root, PHRYGIAN, chant,
            [(4, 7, 2, 0.24), (10, 8, 1, 0.22), (18, 11, 2, 0.24),
             (28, 8, 2, 0.22), (36, 7, 2, 0.22), (46, 10, 1, 0.20)])
    _put(buf, echo(assovio(1.2, freq=note(root, 19), freq_end=note(root, 18), breath=0.12),
                   time_s=0.34, feedback=0.22, mix=0.16, taps=2), 20, step, 0.16)
    return _normalize(bitcrush(buf, bits=6), 0.76)


def mus_arena_p5():
    """Arena da Fase 5: a mais intensa do jogo. Baque virado denso em frígio grave."""
    return _arena_layers(120, C2, PHRYGIAN, density=3)


def mus_boss_jesuita():
    """Jesuíta Bandeirante Catequizador (boss FINAL): o moveset reúne todos os
    chefes — a música também. Baque virado denso + sino de igreja (gonguê/agogô)
    dobrando como condenação, varredura de ruído (aspersão de água benta),
    baixo-motor e um lead frenético em frígio. O sagrado colonial em fúria total."""
    base, step = _new_buf(128, 4)
    mid, _ = _new_buf(128, 4)
    top, _ = _new_buf(128, 4)
    root = C2
    _drums(base, step, lambda: alfaia(0.13, base=root * 0.5, punch=1.0), _baque_alfaia(4),
           humanize=True)
    _drums(base, step, lambda: gongue(0.18, 320.0), [(b * 16, 0.5) for b in range(4)])  # condenação
    _melody(base, step, root, PHRYGIAN, _bass(),  # baixo-motor
            [(st, 0 if (st // 8) % 2 == 0 else 1, 1, 0.78) for st in range(0, 64, 2)])
    _drums(mid, step, lambda: caixa(0.05, bright=1.0), _ghost_fill(4, every=2))
    _drums(mid, step, lambda: caixa(0.06, bright=1.2),
           [(st, 0.48) for st in range(64) if st % 4 == 2])
    _drums(mid, step, lambda: ganza(0.05, rising=False), _shaker_run(4))
    _drums(mid, step, lambda: nes_noise(0.08, decay=16.0, lp=0.5, gain=0.34),  # aspersão
           [(b * 16, 0.42) for b in range(4)])
    _drums(top, step, lambda: agogo(0.14, freq=990.0, bend=0.0), [(b * 16 + 8, 0.34) for b in range(4)])
    zeal = [7, 8, 10, 11, 12, 11, 10, 8]
    _melody(top, step, root, PHRYGIAN, _lead(duty=0.125, vib=0.03),  # lead frenético
            [(b * 16 + i * 2, zeal[(i + b) % 8], 1, 0.44) for b in range(4) for i in range(8)])
    return {"base": bitcrush(base, bits=7), "mid": bitcrush(mid, bits=7),
            "top": bitcrush(top, bits=7)}


# Faixas de música já migradas para OGG (PRD-audio-v5). Fora da lista = WAV legado.
# A migração é incremental: a Fase 1 expande este conjunto até cobrir tudo.
OGG_MUSIC = {"mus_explore_p1"}

# Loops únicos (telas sem intensidade dinâmica).
MUSIC = {
    "mus_menu": mus_menu,
    "mus_hub": mus_hub,
    "mus_explore_p1": mus_explore_p1,
    "mus_explore_p2": mus_explore_p2,
    "mus_explore_p3": mus_explore_p3,
    "mus_explore_p4": mus_explore_p4,
    "mus_explore_p5": mus_explore_p5,
    "mus_ending": mus_ending,
}

# Stems verticais (arena/bosses): geradores devolvem {"base","mid","top"} e o
# loop único correspondente NÃO existe mais (o MusicStems mixa em runtime).
MUSIC_STEMS = {
    "mus_arena_p1": mus_arena_p1,
    "mus_arena_p2": mus_arena_p2,
    "mus_arena_p3": mus_arena_p3,
    "mus_arena_p4": mus_arena_p4,
    "mus_arena_p5": mus_arena_p5,
    "mus_boss_mula": mus_boss_mula,
    "mus_boss_boitata": mus_boss_boitata,
    "mus_boss_curupira": mus_boss_curupira,
    "mus_boss_saci": mus_boss_saci,
    "mus_boss_jesuita": mus_boss_jesuita,
}


# ─── Stingers de estado (one-shot) ─────────────────
def _seq(*events):
    """Monta um one-shot a partir de (som, atraso_s, ganho)."""
    rendered = [(s, int(d * SAMPLE_RATE), g) for s, d, g in events]
    n = max(off + len(s) for s, off, g in rendered)
    out = [0.0] * n
    for s, off, g in rendered:
        for i, v in enumerate(s):
            out[off + i] += v * g
    return out


def sting_arena_enter():
    # Chamada à batalha: gonguê grave + tríade rápida de agogô + alfaia.
    # v2: cauda curta de reverb — a clareira responde à chamada.
    return _normalize(schroeder(_seq(
        (gongue(0.16, 520.0), 0.0, 0.8),
        (agogo(0.16, 990.0), 0.10, 0.6),
        (agogo(0.16, 1320.0), 0.18, 0.6),
        (alfaia(0.24, 58.0), 0.26, 1.0),
    ), mix=0.18, decay=0.68, tail=0.5), 0.85)


def sting_victory():
    # Resolução luminosa: agogô ascendente + assovio-leitmotif sobindo.
    # v2: eco de mata no assovio + reverb suave no conjunto.
    return _normalize(schroeder(_seq(
        (agogo(0.18, 990.0), 0.0, 0.6),
        (agogo(0.18, 1320.0), 0.12, 0.6),
        (agogo(0.30, 1760.0), 0.24, 0.7),
        (echo(assovio(0.7, 1320.0), time_s=0.22, feedback=0.3, mix=0.25, taps=3), 0.30, 0.4),
    ), mix=0.2, decay=0.7, tail=0.6), 0.8)


def sting_game_over():
    # Queda: alfaia sub + gonguê descendente + cauda escura. v2: o reverb mais
    # longo do catálogo de combate — a morte ressoa no vazio.
    # Alfaia contida e gonguês cheios: o sustain carrega o peso (crest controlado
    # na fonte — senão nem a saturação alcança o alvo de loudness).
    return _normalize(schroeder(_seq(
        (alfaia(0.35, 50.0), 0.0, 0.6),
        (gongue(0.5, 300.0), 0.05, 0.9),
        (gongue(0.6, 180.0), 0.30, 0.85),
    ), mix=0.25, decay=0.72, tail=0.45), 0.85)


def sting_chest():
    # Brilho de recompensa: cintilação de agogô com ar curto de reverb (v2).
    return _normalize(schroeder(_seq(
        (agogo(0.16, 1320.0), 0.0, 0.6),
        (agogo(0.16, 1760.0), 0.07, 0.6),
        (agogo(0.24, 2093.0), 0.14, 0.5),
    ), mix=0.15, decay=0.65, tail=0.4), 0.7)


def sting_boss_intro():
    # Revelação do boss (estilo Mega Man): gonguê grave de ameaça + acorde de pulso
    # crescente + alfaia de impacto. Tensão antes do nome aparecer.
    chord = _mix(
        pulse(0.45, 220.0, duty=0.5, attack=0.05, release=0.4),
        pulse(0.45, note(220.0, 3), duty=0.5, attack=0.08, release=0.4),
        pulse(0.45, note(220.0, 7), duty=0.5, attack=0.11, release=0.4),
    )
    # v2: reverb após o crush — corpo granulado, cauda limpa de ameaça.
    # S5: assovio de CAÇA — longo, plano, grave, com eco de mata: a Caipora marca a
    # presa antes do nome aparecer. Nasce sob o gonguê, não compete com o impacto.
    hunt = echo(assovio(0.85, 640.0, freq_end=605.0, breath=0.10),
                time_s=0.22, feedback=0.28, mix=0.22, taps=3)
    return _normalize(schroeder(bitcrush(_seq(
        (gongue(0.4, 300.0), 0.0, 0.8),
        (hunt, 0.05, 0.4),
        (chord, 0.06, 0.5),
        (alfaia(0.3, 48.0, punch=1.0), 0.34, 1.0),
        (agogo(0.2, 1320.0), 0.40, 0.4),
    ), bits=7), mix=0.2, decay=0.72, tail=0.6), 0.86)


def sting_chama():
    # Elemento CHAMA (raro): sopro de fogo no canal de ruído + arpejo de pulso
    # ascendente brilhante (ganho de poder).
    # S5: assovio QUENTE subindo devagar — a Caipora sente o fogo aderir à espada.
    warm = assovio(0.45, 880.0, freq_end=1046.0, breath=0.07)
    return _normalize(schroeder(bitcrush(_seq(
        (nes_noise(0.3, decay=10.0, lp=0.4, gain=0.5), 0.0, 0.5),
        (pulse(0.08, 880.0, duty=0.25, release=0.5), 0.04, 0.5),
        (pulse(0.08, 1320.0, duty=0.25, release=0.5), 0.10, 0.5),
        (pulse(0.18, 1760.0, duty=0.25, release=0.6), 0.16, 0.55),
        (warm, 0.12, 0.4),
    ), bits=7), mix=0.12, decay=0.65, tail=0.4), 0.78)


def _sino_igreja(dur, freq):
    """Sino de bronze de torre: parciais do gonguê com cauda longa (decay lento).
    O gonguê seco (decay=22) morre em ~0,15s — sino de igreja precisa ressoar."""
    return _inharmonic(
        dur, freq,
        [(1.0, 0.5), (2.4, 0.28), (3.9, 0.14), (5.4, 0.06)],
        decay=2.6, fm=0.003,
    )


def sting_sino_igreja():
    # Fase 5 — revelação do Jesuíta: duas badaladas graves de torre, com a alfaia
    # como o baque do badalo. Condenação, não recompensa.
    # v2: o reverb mais fundo do catálogo — a torre de pedra responde.
    return _normalize(schroeder(bitcrush(_seq(
        (_sino_igreja(1.5, 130.0), 0.0, 1.0),
        (alfaia(0.35, 46.0), 0.0, 0.5),
        (_sino_igreja(1.7, 130.0), 0.85, 0.9),
        (alfaia(0.35, 46.0), 0.85, 0.5),
    ), bits=7), mix=0.3, decay=0.8, predelay=0.03, tail=1.2), 0.88)


def sting_orgao_estertor():
    # Fase 5 — vitória sobre o Jesuíta: acorde de órgão (C3/G3/C4) que colapsa um
    # semitom abaixo (estertor cromático) com fole de ruído e o corpo caindo no altar.
    organ = _mix(
        pulse(1.6, note(C2, 12), duty=0.5, attack=0.25, release=0.55),
        pulse(1.6, note(C2, 19), duty=0.5, attack=0.25, release=0.55),
        pulse(1.6, note(C2, 24), duty=0.5, attack=0.25, release=0.55),
    )
    collapse = _mix(
        pulse(1.6, note(C2, 11), duty=0.5, attack=0.30, release=0.65),
        pulse(1.6, note(C2, 18), duty=0.5, attack=0.30, release=0.65),
        pulse(1.6, note(C2, 23), duty=0.5, attack=0.30, release=0.65),
    )
    # v2: nave de pedra — reverb fundo no estertor; o órgão morre ecoando.
    return _normalize(schroeder(bitcrush(_seq(
        (organ, 0.0, 0.5),
        (nes_noise(1.4, decay=2.0, lp=0.85, gain=0.18), 0.2, 0.6),
        (collapse, 0.8, 0.45),
        (alfaia(0.4, 44.0), 2.1, 0.9),
    ), bits=6), mix=0.28, decay=0.78, predelay=0.04, tail=1.0), 0.84)


def sting_agua_benta():
    # Fase 5 — telegraph do especial do Jesuíta: sibilo de aspersão de água benta
    # + pingo final. Pico contido: é cue de leitura, não pode mascarar o timing_alert.
    return _normalize(_seq(
        (nes_noise(0.45, decay=7.0, lp=0.25, gain=0.5), 0.0, 0.6),
        (ganza(0.25, rising=False), 0.02, 0.4),
        (agogo(0.12, 1980.0), 0.30, 0.35),
    ), 0.6)


def fragment_bag_drop():
    # Corpse run — a perda: queda grave (alfaia + gonguê descendo) e os fragmentos
    # âmbar se espalhando no chão (cintilação metálica caindo de registro).
    return _normalize(schroeder(_seq(
        (alfaia(0.30, 48.0, punch=0.9), 0.0, 0.85),
        (gongue(0.35, 240.0), 0.04, 0.7),
        (agogo(0.10, 1760.0), 0.16, 0.45),
        (agogo(0.10, 1320.0), 0.26, 0.4),
        (agogo(0.14, 990.0), 0.36, 0.35),
    ), mix=0.22, decay=0.7, tail=0.5), 0.85)


def fragment_bag_recover():
    # Corpse run — o alívio contido: chocalho de reencontro + assovio curto de
    # retorno. Sem fanfarra: a mata segue hostil, só a bolsa voltou.
    return _normalize(schroeder(_seq(
        (ganza(0.18, rising=True), 0.0, 0.6),
        (agogo(0.14, 1320.0), 0.08, 0.5),
        (echo(assovio(0.45, 1100.0), time_s=0.18, feedback=0.25, mix=0.2, taps=2), 0.16, 0.45),
    ), mix=0.15, decay=0.6, tail=0.4), 0.75)


# ─── Cicatrizes de chefe (S6) — cada um morre com a própria voz ─────────────
def boss_death_mula():
    # Mula sem Cabeça: o galope tropeça (alfaias desacelerando) e o jato de fogo
    # do pescoço morre num sopro — a brasa apaga relinchando grave.
    return _normalize(schroeder(bitcrush(_seq(
        (alfaia(0.16, 70.0, punch=1.0), 0.0, 0.8),
        (alfaia(0.16, 66.0, punch=0.9), 0.16, 0.75),
        (alfaia(0.20, 60.0, punch=0.8), 0.38, 0.7),
        (alfaia(0.28, 52.0, punch=0.6), 0.68, 0.65),
        (nes_noise(1.0, decay=2.5, lp=0.7, gain=0.4), 0.25, 0.6),
        (gongue(0.5, 170.0), 0.95, 0.6),
    ), bits=7), mix=0.2, decay=0.7, tail=0.6), 0.85)


def boss_death_boitata():
    # Boitatá: o silvo da serpente de fogo colapsa e afunda na água do igarapé —
    # vapor, depois pingos esparsos no silêncio.
    n = int(SAMPLE_RATE * 0.7)
    hiss = [_noise() * _env(i, n, 0.02, 0.7) for i in range(n)]
    hiss = biquad(hiss, "hp", 2800.0)
    return _normalize(schroeder(bitcrush(_seq(
        (hiss, 0.0, 0.7),
        (nes_noise(0.8, decay=3.0, lp=0.8, gain=0.4), 0.35, 0.6),
        (gongue(0.4, 140.0), 0.5, 0.6),
        (agogo(0.08, 2093.0), 1.05, 0.3),
        (agogo(0.08, 1760.0), 1.30, 0.25),
        (agogo(0.10, 2349.0), 1.55, 0.2),
    ), bits=7), mix=0.3, decay=0.75, tail=0.7), 0.85)


def boss_death_curupira():
    # Curupira: as batidas de madeira da mata tocam REVERTIDAS — os pés ao
    # contrário desandam o ritmo; a floresta desaprende o protetor que perdeu.
    knocks = _seq(
        (caixa(0.10, bright=0.5), 0.0, 0.8),
        (caixa(0.10, bright=0.5), 0.22, 0.7),
        (caixa(0.12, bright=0.45), 0.40, 0.75),
        (alfaia(0.25, 56.0, punch=0.8), 0.62, 0.9),
    )
    reverse = list(reversed(knocks))  # ataques viram sucções: madeira ao contrário
    return _normalize(schroeder(bitcrush(_seq(
        (reverse, 0.0, 0.8),
        (gongue(0.5, 220.0), 0.85, 0.6),
        (nes_noise(0.5, decay=4.0, lp=0.5, gain=0.3), 0.9, 0.5),
    ), bits=7), mix=0.22, decay=0.7, tail=0.6), 0.85)


def boss_death_saci():
    # Saci: o redemoinho desenrola — vento que gira cada vez mais devagar (pulso
    # com vibrato caindo) até soltar o assovio que ele roubou da mata.
    n = int(SAMPLE_RATE * 1.1)
    wind = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        spin = 6.0 * (1.0 - 0.8 * (i / n))  # rotação desacelerando
        f = 320.0 * (1.0 - 0.45 * (i / n)) * (1.0 + 0.05 * math.sin(2 * math.pi * spin * t))
        phase += f / SAMPLE_RATE
        e = _env(i, n, 0.05, 0.5)
        wind.append((0.5 * math.sin(2 * math.pi * phase) + 0.5 * _noise()) * e * 0.6)
    wind = biquad(wind, "lp", 1600.0, q=0.9)
    return _normalize(schroeder(bitcrush(_seq(
        (wind, 0.0, 0.8),
        (ganza(0.4, rising=False), 0.1, 0.5),
        (echo(assovio(0.5, 990.0, freq_end=740.0, breath=0.12),
              time_s=0.2, feedback=0.25, mix=0.2, taps=2), 0.75, 0.45),
    ), bits=7), mix=0.2, decay=0.7, tail=0.6), 0.85)


def boss_death_jesuita():
    # Jesuíta: o sino racha (duas parciais desafinadas batendo), o órgão solta o
    # último acorde torto e a água benta ferve no chão profano.
    cracked = _mix(_sino_igreja(1.4, 130.0), [s * 0.6 for s in _sino_igreja(1.4, 136.5)])
    last_chord = _mix(
        pulse(0.9, note(C2, 11), duty=0.5, attack=0.2, release=0.6),
        pulse(0.9, note(C2, 17), duty=0.5, attack=0.2, release=0.6),
    )
    return _normalize(schroeder(bitcrush(_seq(
        (cracked, 0.0, 0.9),
        (alfaia(0.35, 44.0), 0.0, 0.6),
        (last_chord, 0.5, 0.4),
        (nes_noise(0.7, decay=5.0, lp=0.3, gain=0.4), 1.0, 0.5),
    ), bits=6), mix=0.3, decay=0.8, predelay=0.04, tail=1.0), 0.86)


STINGERS = {
    "sting_arena_enter": sting_arena_enter,
    "sting_victory": sting_victory,
    "sting_game_over": sting_game_over,
    "sting_chest": sting_chest,
    "sting_boss_intro": sting_boss_intro,
    "sting_chama": sting_chama,
    "sting_sino_igreja": sting_sino_igreja,
    "sting_orgao_estertor": sting_orgao_estertor,
    "sting_agua_benta": sting_agua_benta,
    "fragment_bag_drop": fragment_bag_drop,
    "fragment_bag_recover": fragment_bag_recover,
    "boss_death_mula": boss_death_mula,
    "boss_death_boitata": boss_death_boitata,
    "boss_death_curupira": boss_death_curupira,
    "boss_death_saci": boss_death_saci,
    "boss_death_jesuita": boss_death_jesuita,
}


def main(only=None):
    """Gera o catálogo. `only` limita a uma categoria (protocolo A/B da E2:
    regenerar e commitar categoria por categoria)."""
    if only in (None, "sfx"):
        print("Gerando SFX de combate (maracatu / Amazônia)...")
        for variant, seed in enumerate(VARIANT_SEEDS):
            random.seed(seed)
            suffix = "" if variant == 0 else f"_{variant + 1}"
            for name, gen in GENERATORS.items():
                _write(f"{name}{suffix}.wav", gen())

    if only in (None, "moves"):
        print("Gerando sons de golpes nomeados (1 variante cada)...")
        random.seed(20260618)
        for name, gen in MOVES.items():
            _write(f"{name}.wav", gen())

    if only in (None, "ambience"):
        print("Gerando ambiências (loops)...")
        for name, gen in AMBIENCES.items():
            random.seed(7)
            _write(f"{name}.wav", gen(), subdir="ambience")

    if only in (None, "music"):
        print("Gerando música por contexto (maracatu 8-bits dark)...")
        for name, gen in MUSIC.items():
            random.seed(11)
            if name in OGG_MUSIC:
                _write(f"{name}.ogg", gen(), subdir="music", rate=MUSIC_RATE)
                _remove_stale(f"{name}.wav", "music")  # legado substituído pelo OGG
            else:
                _write(f"{name}.wav", gen(), subdir="music", rate=MUSIC_RATE, width=1)
        print("Gerando stems de arena/boss (música adaptativa)...")
        for name, gen in MUSIC_STEMS.items():
            random.seed(11)
            _write_stems(name, gen())

    if only in (None, "stingers"):
        print("Gerando stingers de estado...")
        for name, gen in STINGERS.items():
            random.seed(13)
            _write(f"{name}.wav", gen(), subdir="stingers")
    print("Pronto.")


if __name__ == "__main__":
    arg = None
    if len(sys.argv) > 2 and sys.argv[1] == "--only":
        arg = sys.argv[2]
        if arg not in ("sfx", "moves", "ambience", "music", "stingers"):
            sys.exit(f"--only deve ser sfx|moves|ambience|music|stingers (recebido: {arg})")
    main(arg)
