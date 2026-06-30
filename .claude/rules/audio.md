---
paths:
  - "scripts/tools/gen_sfx.py"
  - "scripts/tools/check_audio.py"
  - "scripts/systems/audio_director.gd"
  - "scripts/systems/sfx_system.gd"
  - "assets/audio/**"
---

# Regra de edição — pipeline de áudio

- SFX novo entra **SEMPRE no fim** de `GENERATORS` em `gen_sfx.py` (seed por variante;
  inserir no meio muda os bytes dos sons seguintes).
- Música/ambiência migram para **OGG Vorbis** (set `OGG_MUSIC`); o roteamento em
  `AudioDirector` continua em nomes `.wav` **lógicos** — `_resolve_audio` prefere o
  irmão `.ogg` e cai pro `.wav`. Os testes comparam strings `.wav` e não mudam.
- **Sempre rode `godot --headless --import` após gerar um `.ogg` novo** (gera o
  `.ogg.import`+uid) antes de `make audio` / `make gate`.
- Fiscal de loudness: `check_audio.py` (padrão RMS). Categoria nova de som = nova
  entrada no fim de `GENERATORS`.

Fonte canônica: `docs/PRD-audio-v5-terreiro-profundo.md`, `AGENTS.md` (gotcha de áudio OGG).
