# AGENTS.md — assets/

This folder contains all game assets.

## Philosophy

**Coesão acima de tudo.** A identidade visual é um horror folclórico amazônico,
sombrio e hostil. A coesão vem de uma **paleta única forçada** (`scripts/utils/constants.gd`)
+ uma **camada de atmosfera** (vinheta/grão/color-grade) que faz arte de origens
diferentes parecer do mesmo mundo.

**Fontes de arte permitidas:**
- **Pixel art autoral procedural** (geradores em `scripts/tools/gen_*.py`) — abordagem
  atual: determinística, na paleta, zero dependência externa. Caipora, caçador, bruxo
  e tiles foram gerados assim.
- **Packs CC0** (ex. Kenney) como base, recoloridos na paleta. Copie a licença para
  `assets/licenses/`.
- **IA permitida no core** (personagens/props), desde que passe pelo **pipeline de
  limpeza obrigatório** (ver Rules). IA também serve a material promocional (capa,
  banner, ícone).

## Structure

```
assets/
  sprites/     — All sprites: characters, enemies, tiles, items (.png)
  shaders/     — Shaders de atmosfera/efeito (.gdshader)
  audio/sfx/   — Sound effects (.wav, generated with jsfxr / sfxr)
  fonts/       — Pixel font (.ttf / .otf) + theme.tres (design system da UI)
  licenses/    — Licenses and attribution for CC0 assets
```

## Rules

1. **Sprites:** autoral procedural (preferido), CC0 recolorido, ou IA limpa (ver pipeline).
   Sempre `snake_case`, fundo transparente, na paleta.
2. **Tamanho — escada de escala (lore-correta):** a Caipora é PEQUENA, do
   tamanho de uma criança; os invasores humanos se agigantam sobre ela.
   | Asset | Canvas |
   |-------|--------|
   | Tiles/itens | 32×32 (grid lógico = 32) |
   | Bosses/minibosses legados | 48×48 (até a sessão de redesign de cada um — KI-012) |
   | Curupira (boss redesenhado) | 128×128 arena (corpo ~82px ≈ a Caipora, escala de nó 1.2) + mapa 48×48 |
   | Jesuíta (boss final redesenhado) | 128×128 arena (corpo ~103px, escala de nó 1.2) + mapa 48×48 |
   | Boitatá premium | 160×128 arena (`gen_boitata.py`; escala 1.2) |
   | Saci premium | 128×128 arena (`gen_saci.py`; escala 1.2) |
   | Mula premium | 192×192 arena (`gen_mula.py`; escala 0.9 — altura da lore) |
   | Caipora | 96×96 (corpo ~75px; a imponência é da silhueta, não do tamanho) |
   | Invasores comuns (caçador/bruxo) | 112×112 arena (~1.3× ela) + variante de mapa 56×56 |
   Sprites maiores que o tile transbordam pra cima (pés na base, offset.y
   negativo no sprite). Na arena, Caipora e invasores usam a MESMA escala de
   nó (1.2) — texels uniformes; a hierarquia vem do canvas/desenho, nunca de
   escala fracionária diferente por ator. Background transparente.
   **Exceção interina (KI-012):** os bosses legados 48×48 usam `sprite_scale`
   por cena para ler na proporção da lore (Saci premium < Caipora ≈ Curupira <
   Jesuíta / caçador-de-machados 2.8 ≈ caçador comum < Boitatá <
   Mula sem Cabeça), com offset de pés na mesma linha de chão dela —
   contrato travado em `tests/unit/test_boss_scale_proportions.gd`. O redesign
   premium de cada chefe (canvas ≥128) deve herdar essas ALTURAS VISUAIS e
   voltar a escala de nó para 1.2 — já migraram o **Curupira** e o **Jesuíta**
   (`gen_bosses.py`, `docs/CONCEITO-curupira.md`/`docs/CONCEITO-jesuita.md`),
   o **Boitatá** (`gen_boitata.py`), o **Saci** (`gen_saci.py`,
   `docs/CONCEITO-saci.md`) e a **Mula** (`gen_mula.py`,
   `docs/CONCEITO-mula.md`; 192×192 a escala 0.9 para a altura da lore);
   resta o caçador-de-machados na exceção.
2b. **Pipeline de limpeza para IA (obrigatório):** quantizar para a paleta
   (`constants.gd`), alinhar ao grid, garantir alpha limpo (sem halos), ≤ 64×64.
   Sprite que não passar por isso não entra.
2c. **Protagonista é especial:** os `player_*.png` saem SOMENTE de
   `scripts/tools/gen_caipora.py` (pipeline premium: supersample 8× — **formas +
   selout de oclusão/realce inset ≥1px, 3–4 tons/material** — → downsample BOX →
   threshold de alpha → snap de **paleta fechada por variante (base/CHAMA)** →
   outline 1px preto; sem rim light suave, sem gradiente, sem dither). NUNCA
   editar esses PNGs à mão nem recriá-los pelo `gen_chars.py`. O design é lei:
   `docs/CONCEITO-protagonista.md`.
2d. **Inimigos comuns idem:** `enemy_*.png` e `bruxo_*.png` saem SOMENTE de
   `scripts/tools/gen_inimigos.py` (mesma receita premium; 112×112 arena +
   56×56 mapa re-renderizados dos mesmos vetores, paleta fechada por
   personagem; travas de marca e contrato de tamanho cobrados por
   `tests/unit/test_inimigos_sprite_assets.gd`). O design é lei:
   `docs/CONCEITO-inimigos.md`.
2e. **Bosses redesenhados idem:** `curupira_*.png` e `jesuita_*.png` saem
   SOMENTE de `scripts/tools/gen_bosses.py` (mesma receita premium; 128×128
   arena + 48×48 mapa re-renderizados dos mesmos vetores; travas de marca e
   contrato cobrados por `tests/unit/test_curupira_sprite_assets.gd` e
   `test_jesuita_sprite_assets.gd`). O design é lei: `docs/CONCEITO-curupira.md`
   e `docs/CONCEITO-jesuita.md`. Demais chefes entram aqui a cada redesign.
2f. **Saci idem:** `saci_*.png` saem SOMENTE de `scripts/tools/gen_saci.py`
   (128×128 arena, idle/windup, escala de nó 1.2; travas de marca e contrato
   cobrados por `tests/unit/test_saci_sprite_assets.gd`). O design é lei:
   `docs/CONCEITO-saci.md`.
2g. **Mula idem (v3 — traço da protagonista):** `mula_*.png` E o
   `mula_sprite_frames.tres` saem SOMENTE de `scripts/tools/gen_mula.py`
   (192×192 arena a escala 0.9 para a altura da lore; corpo preto-vazio +
   coroa de fogo serrilhada, encarando a ESQUERDA; set completo de vida:
   idle 5f, windup 3f, strike/recover/hurt 2f, death 3f — o `.tres` é emitido
   por código; variante de mapa `mula_map.png` 48×48 re-renderizada dos mesmos
   vetores). Contratos cobrados por `tests/unit/test_mula_sprite_assets.gd` e
   `test_mula_sprite_frames.gd`. O design é lei: `docs/CONCEITO-mula.md`.
3. **Audio:** Generate with [jsfxr](https://sfxr.me/) or [sfxr](https://www.drpetter.se/project_sfxr.html). Export as `.wav`. Short, punchy, under 100KB each.
4. **No music in MVP.** SFX only. Music adds complexity and file size we don't need for the first Web build.
5. **UI:** Use Godot's native UI nodes (`Button`, `Panel`, `Label`, `ProgressBar`). Do not create custom UI sprite sheets.
6. **Fonts:** One pixel font with a permissive license. Kenney Fonts or "Press Start 2P" (Google Fonts).
7. **Import settings:** For every `.png`, set Filter to **Nearest**, Compress to **Lossless**, Mipmaps to **Off**.
8. **Licenses:** Every asset pack downloaded must have its license copied into `assets/licenses/`.

## Horror Folk Palette

A fonte de verdade em runtime é `scripts/utils/constants.gd` (`COLOR_*`); a tabela abaixo
é referência. A UI segue `assets/fonts/theme.tres` (bordas duras, sem cantos arredondados).

The visual identity is **dark, humid, and hostile**. Pixel art should evoke:

| Use | Color | Hex |
|-----|-------|-----|
| Background / Night | Deep blue-black | `#0d1117` |
| Earth / Trail | Reddish brown | `#3d1f1f` |
| Foliage / Moss | Rotten green | `#1a2f1a` |
| Blood / Damage | Blood red | `#8b0000` |
| Highlight / Cue | Amber / Fire | `#ff6b00` |
| Text | Dirty white | `#c9d1d9` |

## Kenney Pack Recommendations

| Pack | Use For |
|------|---------|
| Tiny Dungeon | Tileset (floor, wall, arena), items |
| Tiny Town | Environment variations |
| 1-Bit Pack | Minimalist fallback, prototyping |
| RPG Urban | Additional tiles if needed |
| Character packs | Caipora sprite (idle/walk) |
| Monster/Enemy packs | Creature sprite (skeleton, slime, goblin) |

## SFX Checklist (MVP)

Generate these with jsfxr/sfxr:

- [ ] `attack.wav` — Caipora slash/strike
- [ ] `hit.wav` — Damage impact
- [ ] `dodge.wav` — Quick whoosh/swish
- [ ] `timing_perfect.wav` — Reward ding/chime
- [ ] `death.wav` — Defeat/explosion
- [ ] `ui_click.wav` — Menu interaction

## Asset Size Limits (Browser)

- Single sprite: ≤ 64×64 pixels (upscale in-engine if needed)
- Tileset atlas: ≤ 512×512 pixels
- SFX: ≤ 100KB each
- Total project: ≤ 10MB for fast web load (MVP target)
