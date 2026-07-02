# AGENTS.md — caipora

This file guides the AI coding agent (Claude Code, Kimi Code, or Cursor) when working on the **caipora** project. It is the single source of truth — `CLAUDE.md` at each level is a symlink to the `AGENTS.md` beside it.

## Project Overview

**caipora** is a browser-first 2D pixel-art roguelike set in Brazilian folk horror.

You play as the **Caipora**, guardian of the forest, awakening in a corrupted woodland where ancient pacts between humans, beasts, the dead, rivers, and enchanted beings have been broken.

The core mechanic is **timing-based combat**:
- Press **Space** at the right frame to land a **critical hit** (2x–3x damage).
- Press **Space** at the right frame to **perfect dodge** an enemy attack and **counter-attack**.

The full product spec is in `PLAN.md`. Read it before every session.

**Tone:** GORE / TERROR / SANGRENTO. The forest is hostile. The Caipora is dangerous. Do not sanitize the horror.

### Visual Identity — The Caipora Is the Brand

The protagonist rebuild approved in 2026-06 defines the project's primary
visual mark. Treat `docs/CONCEITO-protagonista.md` and
`assets/sprites/caipora_pop_dark_contact_sheet.png` as canonical references for
the playable Caipora and as the north star for the wider art direction.

When a task touches protagonist art, character silhouettes, VFX, key art,
marketing images, UI motifs, palette, enemy readability, or scene mood, use the
local skill `.agents/skills/visual-identity/SKILL.md` before editing. The core
identity is:

- **Orange serrated cloak/juba as dominant silhouette** — the Caipora reads at
  32px as an orange hostile shape with white eyes.
- **Black void/body/horns/staff** — no facial features, no cute expression, no
  clothing detail that competes with the silhouette.
- **Two pure white eyes** — equal, round, readable, and unsettling.
- **Tiny green crystal core only as Furia anchor** — green is an accent, never
  the protagonist's dominant read.
- **Flat pixel-art finish** — closed palette, hard shapes, 1px dark outline,
  no soft gradients, no dither haze, no glossy rendering.
- **Horror stays physical** — blood, darkness, hostile forest shapes, ritual
  marks, and predatory poses are part of the brand.

---

## Harness Layer — Agent Interaction Model

This project uses the **Godot MCP Server** (`@coding-solo/godot-mcp`) to let the agent inspect scenes, control the Godot editor, and run the project programmatically.

Codex uses `.codex/config.toml` as its native MCP config. `.mcp.json` remains the
cross-agent config for Cursor/Kimi (`.cursor/mcp.json` and `.kimi-code/mcp.json`
are symlinks to it). Scene-mutating MCP tools are not auto-approved because
autoload-dependent scenes can be mangled when re-saved headlessly.

### Godot Path

- Executable: `/home/baltz/.local/bin/godot` (v4.6.3-stable)
- Project: `/home/baltz/caipora`
- Display: `:0` (WSLg — works for `run_project` and `launch_editor`)
- Headless mode is used automatically by MCP for scene operations.

---

## Directory Structure

Do not create new top-level folders without approval.

---

## Code Standards

### Principles

- **Composition over inheritance.** Export nodes as `@export var` components. Avoid deep inheritance.
- **Signals for decoupling.** Use `SignalBus` autoload or direct signals. Do not hardwire direct references between unrelated systems.
- **State machines.** Caipora and Criatura behaviors use `StateMachine` (explore → combat → dead).
- **No magic numbers.** Define constants at the top or in `scripts/utils/constants.gd`.
- **Static typing everywhere.** Use `-> void`, `-> int`, `: Type` on all functions and variables.
- **One class per file.** Do not stack multiple classes in a single `.gd` file.

---

## Scene Architecture

### Autoloads

Register these in `Project > Project Settings > Autoloads`:

| Name | Script | Purpose |
|------|--------|---------|
| `GameState` | `scripts/core/game_state.gd` | Screen state, pause, run state |
| `SignalBus` | `scripts/core/signal_bus.gd` | Global event bus |
| `MetaProgression` | `scripts/core/meta_progression.gd` | Unlocks, currency between runs |
| `FeedbackSystem` | `scripts/systems/feedback_system.gd` | Screenshake, particles, sound |

### Patterns

- **Arena scene:** `ArenaManager` (Node2D) owns background, spawns `Caipora` and `Criatura` instances.
- **UI scenes:** CanvasLayer-based, anchored to viewport.
- **Reusable components:** Export as `@export var reusable_scene: PackedScene` and instantiate.

---

## Development Commands

The harness commands live in the `Makefile` (single source of truth). Run them from
the repo root. Override the Godot binary with `make test GODOT=/path/to/godot`.
Headless targets isolate Godot `user://` under `/tmp/caipora-godot-data` by
default (`GODOT_USER_DATA_DIR=...`) so tests do not touch the developer save and
Godot does not crash when hooks provide piped stdin.

```bash
make smoke    # boot headless ~50 frames and exit (smoke test)
make test     # run the GUT regression gate (tests/unit)
make import   # refresh Godot import/class cache after adding class_name scripts
make export   # build the reproducible HTML5 release into export/
make gate     # smoke + test (run before every commit)
```

Run the game with a display (WSLg provides `:0`):

```bash
~/.local/bin/godot --path .
```

When modifying input, arena, exploration, or timing — run `/validate-controls` first.

---

## Common Gotchas

1. **Display required.** Godot needs a display for `run_project` and `launch_editor`. WSLg provides `:0`. If unavailable, use `Xvfb` or accept that only headless operations work. **Capturas (`capture_clips.gd`/`screenshot.gd`/`preview_*.gd`): `DISPLAY=:0` pode crashar (signal 11) no driver NVIDIA da WSLg (dlopen em `libnvwgf2umx.so`/d3d12), e sob `xvfb-run` o Godot cai para Wayland e crasha igual.** Receita que funciona: `XDG_DATA_HOME=/tmp/caipora-godot-data LIBGL_ALWAYS_SOFTWARE=1 WAYLAND_DISPLAY= xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 --rendering-method gl_compatibility --path . ... < /dev/null` (X11 forçado + GL por software + user:// isolado + stdin fechado, KI-020).
2. **Headless for MCP.** Scene creation via MCP uses `--headless`. Do not confuse this with running the game.
3. **UID files (Godot 4.4+).** Godot generates `.uid` files for resources. They should be committed to git.
4. **`.import` files.** Godot creates `.import` files and `.godot/` cache. These are in `.gitignore` and must stay ignored.
5. **Browser load time.** Keep assets small. Test HTML5 export load time frequently.
6. **Signal disconnection.** Godot does not warn about disconnected signals. Always verify signal connections in the scene inspector after node renames.
7. **Scene file corruption.** Manual edits to `.tscn` files can corrupt scenes. Prefer the Godot editor for scene modifications. **MCP `add_node`/`save_scene` are also unsafe on scenes whose scripts reference autoloads**: the MCP runner loads scenes without autoloads, scripts fail to compile, and the re-saved `.tscn` silently loses scripts/exports/UIDs (and writes broken property values). After ANY MCP scene operation that can write a scene, check `git diff` on the `.tscn` immediately and restore via git if mangled. For nodes only needed at runtime, prefer adding them from code (e.g. `ArenaBackdrop` adds the P1 `CanvasModulate` in `_ready()`).
8. **Tone consistency.** Do not sanitize horror. Blood, darkness, and hostility are intentional design choices.
9. **Dual input paths.** Two consumers, two sources: keyboard uses native Godot polling (`Input.is_action_pressed`); the touch D-pad injects via `Input.action_press` + `Input.parse_input_event` (`ControlsHud._on_pressed/_on_released` — unchanged contract). In exploration/HUB the touch pad is a **floating MOBA-style D-pad**: `ControlsHud` routes raw `InputEventScreenTouch/Drag` from `_unhandled_input` (so GUI-consumed touches never invoke it) to `FloatingDpad`, which resolves the drag offset into a cardinal action (small dead zone + axis hysteresis) and emits `direction_pressed/released`. In the arena (ARENA*) it is a **fixed diamond D-pad of claw-chevrons** (`CombatArrowButton`): four overlapping `BaseButton`s cover the whole cluster and `_has_point` routes each touch to its 90° wedge (small central dead zone) — the touch area is the full pad, much larger than the drawn plates. Visual press feedback lives in the widget; haptics (`navigator.vibrate`/`Input.vibrate_handheld`), the `dpad_tap` SFX (`AudioDirector.play_dpad_tap`) and input injection stay in `ControlsHud`. Always run `/validate-controls` before committing changes to input, arena, exploration, or timing.
10. **Free orientation, three target platforms.** Orientation is NOT locked (PWA manifest `orientation=any`; `handheld/orientation=6` SENSOR) — the player chooses by rotating the device, so every screen must work in portrait AND landscape, reacting to `size_changed`. Phone portrait Safari/Chrome (~393px wide), phone landscape (safe areas via CSS `env()` in `ControlsHud`), tablet+ (arena zoom capped at 2.0x in `arena_manager.gd`). Beware the web exporter enum: `progressive_web_app/orientation` is `0=Any, 1=Landscape, 2=Portrait` (a past misread of `1` as portrait shipped an accidental landscape lock). Run `/validate-platforms` before committing any UI, camera, or safe-area change.
11. **Version is build-stamped from git.** The scheme is `alpha-X.Y.Z`: the base `alpha-X.Y` lives in `project.godot`'s `config/version` (single source of truth — bump MAJOR/MINOR there) and `Z` is the git commit count, so it increments by itself on every commit. `make export` reads the base, stamps the full version into `scripts/core/build_info.gd` (gitignored) + `export/version.json`. The menu reads `build_info.gd` first and falls back to `config/version` (`"alpha-X.Y (dev)"`) only when run from the editor. Do NOT hand-edit a patch number expecting it to show up in the build — only the `alpha-X.Y` base in `project.godot` is editable; the rest comes from git at export time. `tests/unit/test_build_version.gd` locks the scheme.
12. **New `class_name` needs `make import`, and GUT can lie green.** After creating a script with a new `class_name`, run `make import` before `make test`/`make gate` — the global class cache in `.godot/` doesn't refresh on a plain test run, every script referencing the new class fails to parse, and **GUT silently skips test files that fail to parse** ("does not extend GutTest") while still reporting "All tests passed". After adding test files, confirm the total test count went UP in the GUT summary.
13. **`Atmosphere` (CanvasLayer 50) darkens every layer below it.** The vignette+grain overlay multiplies screen corners down ~65% — UI living in layers < 50 (old D-pad at 20) becomes mud exactly where thumbs rest. Input-critical UI goes ABOVE 50 (`ControlsHud.HUD_LAYER = 55`) but below `OptionsPanel` (60) and `SceneTransition` (100), so pause/transitions still cover the pad. Visual checks: `scripts/tools/preview_combat_dpad.gd` captures the combat pad (idle/pressed, any resolution) under Xvfb.
14. **Scripts `-s` (SceneTree) e autoloads: configure no frame 1, não em `_initialize`.** Em ferramentas de preview (`godot -s scripts/tools/preview_*.gd`), os autoloads só rodam `_ready()` DEPOIS do `_initialize()` do script — estado setado ali (ex.: `MetaProgression.freed_bosses`) é sobrescrito em silêncio pelo `load_progress()`. Configure tudo no frame 1 do `_process` (padrão de `preview_combat_dpad.gd`/`preview_camp_spirits.gd`) e redirecione `MetaProgression.SAVE_PATH` para um sandbox se o fluxo capturado persistir save. Bônus: atribuir a propriedades `Array[int]` de outro script exige array tipado (`assign()`); `duplicate()` e ternários destipam e estouram só em runtime — erro invisível se o stderr do preview estiver suprimido (`2>/dev/null`). Bônus 2: classes globais que referenciam autoloads por IDENTIFICADOR (ex.: `CaiporaSkin` → `MetaProgression.has_chama`) NÃO COMPILAM quando carregadas por script `-s` ("Identifier not found") — o erro aparece como "Nonexistent function em base GDScript" no call site. No preview, contorne sem a classe (carregue o resource direto) ou acesse via `root.get_node("Autoload")`.
15. **Balanceamento de inimigo é configurável remoto, mas só busca em build EXPORTADO.** HP/dano vivem em `scripts/utils/enemy_stats.gd` (fonte única + fallback), mas o autoload `RemoteConfig` sobrepõe por `<id>@<fase>` com valores do Supabase (Edge Function `caipora-api`, actions `get_enemy_stats`/`set_enemy_stats`), editáveis no painel `site/admin.html` (login `baltz`/`1987`, hash no servidor em `caipora.game_config` linha `admin`). `RemoteConfig._ready()` só faz o fetch quando `OS.has_feature("template")` — ou seja, **no editor e em `make test`/`make smoke` NÃO toca a rede** (CI determinístico/offline; testes usam o seam `_set_overrides_for_test`). Consequência: rodar do editor (`godot --path .`) sempre mostra os valores baked, nunca os remotos. O jogador aplica o balanceamento novo pelo banner "Atualizar" no menu (`main_menu._setup_update_banner`), que no web recarrega a página. Mexeu em HP/dano de inimigo? É em `enemy_stats.gd` (defaults) E/OU no painel (ao vivo) — `bonus_damage_for(id, phase)` já soma fixo + delta de fase.

16. **Sequências de ataque: ritmo de combate é remoto, em camadas, com fallback.** O ritmo de cada pattern vive nos `.tres` (`scripts/entities/attack_pattern.gd`) e é sobreposto pelo autoload `RemotePatterns` (`get_attack_patterns`/`set_attack_patterns`, mesma Edge Function/painel). Vocabulário do painel → runtime: **janela de transição** (início "Pelejar" → 1º turno) é GLOBAL, chave reservada `__global__.transition_window`, default = `ArenaManager.COMBAT_LOADER_FINAL_HOLD` (0.50), lida por `RemotePatterns.transition_window()`; **janela de ação** (tempo de reação) é EXPLÍCITA por fase em `action_windows: {"1".."5"}` — quando presente o `ArenaManager._defense_window` usa direto (valor FINAL, já com o `+0.2` de touch), senão cai na fórmula `Constants.timing_window_for_phase(attack_duration, fase)`; **intervalo entre hits** é independente por golpe em `strike_intervals[]` (fallback no `strike_delay` único); **último hit → próximo turno** é `next_turn_delay` (sentinela `< 0` cai em `cooldown_duration`). Edição: `site/sequences.html` (lista de cards + barra global) → clique abre `site/sequence.html?key=<pattern>` (detalhe por sequência; variações por fase ficam na seção "janela de ação por fase"). Catálogo único em `site/js/sequences_shared.js` (valores baked = `.tres`; mexeu num `.tres`, atualize o catálogo). `RemotePatterns` NÃO sobrescreve `is_special`/`idle_duration`/`jump_telegraph` — editar `input_sequence` só vale para patterns já `is_special = true`. Mesma regra do #15: fetch só em build exportado; testes via `_set_overrides_for_test`.

17. **Moves nomeados: cada golpe tem nome, som e VFX próprios (modelo Pokémon).** Catálogo em `docs/PRD-moves-nomeados.md` (fonte única). `AttackPattern` carrega `display_name` (nome no jogo), `audio_event` (stem do WAV em `sfx/`, tocado por `SfxSystem.play_named`) e `vfx_id` (chave de VFX). `RemotePatterns` sobrepõe `display_name`/`audio_event` (em `apply()` **e** `_sanitize()` — esqueceu o segundo e o override some); **`vfx_id` é baked** (não remoto). `ArenaManager._start_enemy_turn` dispara os três 1x por turno (NÃO por hit): tag sutil de nome (`FeedbackSystem.spawn_move_name`, Label de texto — NÃO o `spawn_result_label`, que é PNG por chave fixa), som e `spawn_attack_vfx`. O tell reativo por-hit (`timing_alert`) fica intacto — identidade não interrompe a dinâmica (decisão: estilo Expedition 33, sem banner central). Sons: categoria `MOVES` em `gen_sfx.py` (1 variante, `--only moves`); o fiscal `check_audio.py` exige RMS [-12,-9] (som esparso precisa de cama contínua, à la `mata_event`). VFX: `FeedbackSystem._VFX_BY_ID` (vfx_id→[arquétipo,cor]) + `_VFX_ARCH`, construído em código (padrão `FuriaVisual`), sem `.tscn`/PNG. Golpes da Caipora (sem `.tres`) vivem em `Constants.CAIPORA_MOVE_*`. Testes travam os elos dado↔asset: `test_sfx_variants` (audio_event tem WAV) e `test_attack_vfx` (vfx_id no registro).

18. **Cortejo dos Encantados = "O Chamado" (SEGURAR → SOLTAR). Fonte da mecânica: `docs/PRD-cortejo-o-chamado.md` (4ª forma).** O golpe especial da Caipora foi redesenhado 4×. A forma VIGENTE POR DESIGN é o **Chamado**: o jogador SEGURA `ui_up` (mesma garra do ataque normal), um medidor enche e os chefes libertados (`Constants.cortejo_spirits_for()`, teto `CORTEJO_MAX_LINKS`) coalescem um a um; **SOLTAR** define o tier reusando o modelo 3-tier do combate — banda dourada = PERFEITO/FEVER (barragem completa + crítico no último), ombro = GOOD (barragem sem crit), cedo demais = FRACO (barragem parcial), segurar além da banda/timeout = QUEIMA (contra-ataque, `_enemy_counter_damage`). Disparo: roll no turno (`CORTEJO_CHANCE = TIMING_DOUBLE_CHANCE`), lead-in com slow-mo. Frações de release em `Constants.CHAMADO_*` (não `cortejo_window_for_phase`, que é DEPRECATED). **O hold/carga foi RE-APROVADO neste redesign** — o pecado antigo era o *ponto de soltar invisível*, resolvido com banda desenhada + cue sonoro/háptico (não "reintroduza hold" — isso ERA a proibição velha, agora obsoleta). **Não existe classe `HoldTimingSystem`**: o próprio `TimingSystem` já tem modo hold (`open_window(..., hold=true, good_start, good_end)` — press inicia a carga, release avalia `_grade()` 3-tier por `window_progress()`); o `TimingBubble` já tem o medidor (`show_bubble(..., charge=true)`, `_draw_charge`), o `CombatArrowButton.start_cortejo_charge` acende o wedge, e `ControlsHud` roteia `cortejo_charge_opened/closed`. A lógica dos 4 desfechos (FEVER/GOOD/FRACO/QUEIMA) vive na orquestração do `arena_manager._start_cortejo_turn`, que lê o resultado 3-tier + `TimingSystem.window_progress()` (< `CHAMADO_GOOD_START` = FRACO; senão = QUEIMA) e os seams puros `Constants.chamado_miss_is_weak/chamado_partial_count`. As constantes de TAP antigas (`CORTEJO_PERFECT_*`/`WINDOW_*`, `cortejo_window_for_phase`) foram REMOVIDAS — não reintroduza janela-única de tap. Segue APOSENTADO (Batuque direcional, morto de vez): `CortejoBeatTrack`, `cortejo_calls_for`, `CORTEJO_CALL_FOR_PHASE`, `CORTEJO_BEAT_SECS`, `play_cortejo_beat`. Mexeu nisso? `/validate-controls` + `make gate`.

20. **Música/ambiência migram para OGG Vorbis (PRD-audio-v5); SFX/stingers seguem WAV.** O codec de loops longos é OGG (`gen_sfx._write` despacha por extensão: `name.endswith(".ogg")` → `_encode_ogg` via `soundfile`+libvorbis, JÁ presentes no ambiente — sem ffmpeg/oggenc). A migração é **incremental**, declarada no set `OGG_MUSIC` em `gen_sfx.py` (hoje só `mus_explore_p1`); fora dele = WAV legado, e `_remove_stale` apaga o `.wav` substituído. **Regra de ouro do runtime: o roteamento (`AudioDirector._music_for_screen`, `AMB_*`) continua em nomes `.wav` lógicos** — os testes (`test_audio_director`) comparam strings `.wav` e NÃO mudam. Quem resolve a extensão real é `_resolve_audio(path)` (prefere o irmão `.ogg`, cai pro `.wav`), usado em `_music_stream_path`/`_has_stems`/`_play_stems`/`_play_ambience`. Carga: `_load_music_stream` trata `.ogg` (`load()` com `.import` no editor/export; `AudioStreamOggVorbis.load_from_file()` no headless/CI, pois `*.import` é gitignored). `_force_loop` força `loop=true`/`loop_offset=0.0` no `AudioStreamOggVorbis` (o loop é o arquivo inteiro — grid periódico costurado pelo wrap do gerador). O fiscal `check_audio.py` lê `.ogg` (`read_audio` → `read_ogg` via soundfile) e detecta stem por nome agnóstico de ext. **Sempre rode `godot --headless --import` após gerar um `.ogg` novo** (gera `.ogg.import`+uid) antes de `make gate`. Tijolos de arranjo novos (modelo Pokémon Pulse 2 + forma longa): `_counter()` (contra-melodia), `_chord()` (cama harmônica, antes inerte), `_shift()`/`_section`, `_tarol()`/`_poly3()` (maracatu denso). Ver `docs/PRD-audio-v5-terreiro-profundo.md`.

19. **Acerto em 3 tiers (PERFEITO/GOOD/ERRO) + faixas absolutas sobre a janela.** O combate NÃO é mais binário: `TimingSystem.TimingResult` tem `{PERFECT, GOOD, MISS}`. **Defesa:** PERFEITO = esquiva+contra+combo↑; **GOOD = bloqueia ~50% (`Constants.GOOD_BLOCK_MULT`), SEM contra, combo preservado (`FeedbackSystem.track_good()` — nem soma nem zera)**; ERRO = dano cheio. **Ataque:** PERFEITO = crítico; GOOD = golpe normal (`execute_attack(false)` — lembre que o ERRO de ataque WHIFFA, 0 dano, NÃO "dano normal"); ERRO = whiff. O modelo de janela é **"faixas absolutas sobre `D`"** (`Constants.band_fractions(duration)`): a duração total `D` por fase continua vindo de `timing_window_for_phase`/`action_windows` (painel remoto e `sequences_shared.js` **intactos**), mas as faixas PERFEITO (`±PERFECT_HALF_SPAN`) e GOOD (`±GOOD_HALF_SPAN`) têm largura **absoluta** (segundos), então a PRECISÃO é constante entre fases e só o lead-in encurta. `LATE_GRACE` alarga só o lado tardio (lag de toque/web); `MIN_ACTION_DURATION` é o piso de `D` (o arena faz `maxf(window, MIN_ACTION_DURATION)` ao passar para `band_fractions` E `open_window`/`show_bubble`, senão as frações não batem com o progresso). **`open_window`/`show_bubble` recebem `good_start/good_end`; default 0.0 ⇒ `good = perfect` ⇒ binário** — por isso janelas especiais sem GOOD explícito continuam PERFEITO/MISS. Feedback do GOOD é âmbar (`COLOR_GOOD`): `TimingBubble` halo + `burst_good()`, `CombatArrowButton.flash_good()`, `SfxSystem.Outcome.BLOCK` (`combat_block.wav`, fallback `dodge`), `SignalBus.defense_result_good/attack_result_good` → `ControlsHud._pulse_good_haptic`, label `result_bloqueio.png` ("APAROU" — a fonte 5×7 de `gen_feedback_sprites.py` não tem B/L). Cue de antecipação (Patapon): `TimingBubble.approach_entered` (entra no GOOD) → `AudioDirector.play_approach_tick` + `SignalBus.combat_approach_cue` → háptico leve. Novo SFX entra SEMPRE no fim de `GENERATORS` em `gen_sfx.py` (seed por variante; inserir no meio muda os bytes dos seguintes). Mexeu nisso? `/validate-controls` + `make gate`. Ver `docs/PRD-combate-refino.md` e `docs/PESQUISA-combate-acao.md`.

21. **Stale `AGENTS.md` is a harness bug.** Codex/GPT-5.5 follows durable instructions literally; if `AGENTS.md` conflicts with `PLAN.md` or current code, fix the stale instruction before implementing related behavior. Do not carry old mechanics forward just because they remain in project guidance.

22. **Inimigo fraco FOGE na exploração.** Quando o ataque base do jogador (`Constants.caipora_base_damage_for_phase(phase) + MetaProgression.get_damage_bonus()`) `>=` o HP total do inimigo (`EnemyStats.max_hp_for(enemy.stats_id(), phase)` — respeita override remoto), `ExplorationManager._run_enemy_turns` passa `fearful=true` a `MapEnemy.take_turn`, que corre na direção OPOSTA (`_flee`, espelho de `_chase` maximizando a distância) com um tremor de pânico (`_shudder`) e **retorna `false` de propósito** (apavorado nunca inicia combate — o jogador ainda encurrala e mata). **Bosses nunca fogem** (`not enemy.is_boss` — guardam a saída). Não "conserte" o `return false` do ramo `fearful` achando que é bug. Mexeu em exploração? `/validate-controls` + `make gate`. Testes: `tests/unit/test_map_enemy_flee.gd`.

23. **UI vive no UiRoot, não nas cenas — e captura de tela precisa de `--screen=`.** As telas de gameplay (EXPLORATION*, ARENA*, HUB) NÃO constroem header próprio: o autoload `UiRoot` (`scripts/ui/ui_root.gd`, `MIGRATED_PREFIXES`) compõe o `HudHeader` (kit `scripts/ui/kit/`) ao ouvir `screen_changed`, e o `hud.gd` embutido nas cenas se recolhe (`UiRoot.owns()`). O chrome é o **BrandFrame v2 "Juba viva"** (crista sólida em degraus de pixel, borda em camadas por RECTS — `draw_line` com butt cap deixa mossas nos degraus; NUNCA reintroduzir diagonais anti-aliased). Consequências: (a) `screenshot.gd` instanciando cena direto NÃO passa por `change_screen` — sem `--screen=NOME` o header não aparece na captura; (b) conteúdo que muda de largura dentro do header (ex.: contador de Terra Rara) exige `relayout()` ou a placa serrilhada fica stale (por isso `set_currency` re-abraça); (c) quem se ancora abaixo do header usa `HudHeader.top_row_height(vp)` + `plate_pady()` (ex.: bandeja do hub), nunca constante mágica; (d) `purchase_upgrade` emite `fragment_gained` com amount NEGATIVO (débito atualiza contador; popup de ganho só com amount > 0).

24. **Deploy do Pages: o que está no ar é o que o CI builda, e a fila engasga.** O workflow (`.github/workflows/deploy.yml`) monta `site/` na raiz + um `make export` FRESCO em `/play/` — o `export/` commitado no repo NÃO é servido pelo Pages (existe para o zip do itch e histórico). Diagnóstico de deploy: (a) run preso em `deployment_queued` = fila do Pages do lado do GitHub, não bug do repo — cheque o componente Pages em `https://www.githubstatus.com/api/v2/summary.json`; o `actions/deploy-pages` CLAMPA o timeout em 10 min/tentativa (valores maiores viram warning) — a proteção do job é 1 retry (2×10 min de janela); (b) para re-rodar só o job morto use `gh api -X POST repos/baltazarparra/caipora/actions/runs/<id>/rerun-failed-jobs` (o `gh` local é antigo, sem `run rerun --failed`); (c) o checkout do job `build` precisa de `fetch-depth: 0` — raso, o `git rev-list --count HEAD` do `make export` conta 1 e todo build publicado sai `alpha-X.Y.1` (foi o sintoma que mascarou um deploy velho em 2026-07-02); (d) `cancel-in-progress: false` é intencional (PR #87 — pushes rápidos se auto-cancelavam); (e) o service worker do PWA cacheia agressivo: valide o live com query-string (`?v=...`) ou aba limpa.

---

## Session Protocol

Run `/session-orient` at the start of each session (skill in `.agents/skills/session-orient/`).

**Rules:**
- One task per session. Do not batch unrelated changes.
- Commit after every successful task.
- If the agent discovers a bug (even unrelated), document it in `PLAN.md` under a "Known Issues" section, then fix or leave for a future session.
- Update `AGENTS.md` if a new gotcha is discovered.
- **Never soften the horror.** The forest is hostile. The Caipora is dangerous. The blood is real.
