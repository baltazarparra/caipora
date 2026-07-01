# caipora — Roguelike Brasileiro de Horror Folclórico

> Browser-first roguelike built with Godot 4.6 + GDScript.  
> Published on itch.io as an HTML5 build.

---

## 1. Visão do Produto

**caipora** é um roguelike 2D em pixel art ambientado no horror folclórico brasileiro.

Você joga como a **Caipora**, guardiã da mata, despertando em uma floresta corrompida onde os antigos pactos entre humanos, bichos, mortos, rios e encantados foram quebrados.

A cada movimento no grid, o mundo responde. A Caipora avança por trilhas tortas, clareiras queimadas, rios escuros, capelas abandonadas e vilas tomadas por superstição. Cada passo é uma escolha. Cada encontro pode virar caça, punição, fuga ou encantamento.

Diferente de um herói tradicional, a Caipora não está ali para salvar a humanidade. Ela é uma entidade antiga, ambígua e perigosa: protetora dos animais, senhora dos rastros, espírito de assovio, armadilha e vingança. Sua missão é descobrir o que adoeceu a mata — e decidir se os humanos ainda merecem permanecer nela.

### Tom

**GORE / TERROR / SANGRENTO**

Inspirado pela tensão estratégica de roguelikes clássicos, pela estranheza ritual de *Sol Cesto* e pela atmosfera opressiva de *Bloodborne*. caipora troca o gótico europeu por um horror brasileiro de terra molhada, cipó, fumaça, olho brilhando no escuro e canto vindo do rio.

### Mecânica Central

O combate usa um sistema de **timing**:
- Pressione **Espaço** no frame correto para desferir um **ataque crítico** (2x–3x de dano).
- Pressione **Espaço** no frame correto para **esquivar perfeitamente** (zero dano) e **contra-atacar**.

Toda ação tem feedback visceral: screen shake, partículas de sangue, hit-stop e sons de impacto.

### Escopo do MVP

- 1 jogável: **Caipora**
- 1 inimigo: criatura folclórica (ex: Caboclo d'Água, Boto corrompido, ou entidade genérica da mata)
- 1 arena: clareira queimada ou capela abandonada na floresta
- Sistema de timing implementado e satisfatório

**Fora do escopo do MVP:**
- Steam / desktop builds
- Mobile builds
- Gamepad support
- Multiplayer
- ~~Cloud saves~~ → backend pronto pós-MVP (Supabase, schema `caipora`); falta integrar no cliente Godot
- Achievements
- ~~Música (SFX apenas no MVP)~~ → adicionada pós-MVP: maracatu adaptativo + ambiência + stingers (ver §12)

---

## 2. Plataforma Alvo

- **Primária:** Web / HTML5 (itch.io)
- **Renderizador:** Godot 2D (Compatibility mode para estabilidade WebGL)
- **Resolução:** 1280×720 (escalável)

---

## 3. Tech Stack

| Camada | Escolha |
|--------|---------|
| Engine | Godot 4.6.3 |
| Linguagem | GDScript |
| Renderização | 2D, OpenGL Compatibility |
| Distribuição | itch.io HTML5 export |
| Controle de Versão | Git |
| Agent Tools | `@coding-solo/godot-mcp` (MCP server) |

---

## 4. Arquitetura do Jogo

### 4.1 Loop de Gameplay

```
[Menu Principal]
    ↓
[Exploração]  ← grid-based, turn-based (floresta)
    ↓  (pisar no tile de arena)
[Combate na Arena] ← turnos + action command de timing
    ↓  (vitória / morte)
[Recompensas / Morte]
    ↓
[Hub / Meta-progressão]
    ↓
[Exploração]  ← próxima arena
```

**Exploração:**
- Movimento grid-based (4 direções)
- Turn-based: jogador move um tile → criaturas movem
- Visibilidade limitada / fog of war
- Pisar em um tile de arena dispara combate
- Ambientes: trilha torta, clareira queimada, rio escuro, capela abandonada

**Combate na Arena:**
- Combate por turnos com **action commands de timing** (no estilo *Legend of Dragoon* e *Clair Obscur: Expedition 33*) — não é ação em tempo real. O turno alterna entre jogador e inimigo; dentro de cada turno o jogador acerta o frame/janela correto para crítico ou esquiva.
- Jogador e inimigo têm cooldowns de ataque
- Inimigo telegrafa ataques com cue visual + janela de wind-up
- Jogador pressiona **Espaço** durante a janela de cue para esquivar + contra-atacar
- Jogador pressiona **Espaço** durante sua própria janela de ataque para crítico
- **Acerto em 3 tiers (PERFEITO / GOOD / ERRO).** Na **defesa**: PERFEITO = esquiva + contra-ataque (combo↑); **GOOD = bloqueia ~50% do dano, sem contra, combo preservado**; ERRO = dano cheio. No **ataque**: PERFEITO = crítico (combo↑); GOOD = golpe normal (combo preservado); ERRO = **whiff (0 dano)** — corrige a nota antiga "dano normal", o ataque que erra não fere. As faixas PERFEITO/GOOD têm largura **absoluta** (precisão fixa entre fases; só a antecipação encurta) — ver `docs/PRD-combate-refino.md` e `docs/PESQUISA-combate-acao.md`.

### 4.2 Sistemas Core

| Sistema | Responsabilidade |
|---------|------------------|
| `TurnManager` | Ordem de turnos na exploração |
| `ArenaManager` | Spawna inimigos, gerencia estado da arena, condições de vitória/derrota |
| `TimingSystem` | Detecta presses de espaço dentro das janelas de cue, emite hit/miss |
| `CombatSystem` | Aplica dano, lida com morte, dispara feedback |
| `FeedbackSystem` | Screenshake, partículas, hit-stop, sound cues |
| `MetaProgression` | Unlocks entre runs (persistido em `user://`) |

### 4.3 Estrutura de Entidades

```
Caipora (Player)
├── MovementController (exploração)
├── CombatActor (arena)
│   ├── Health
│   ├── AttackCooldown
│   └── TimingWindow
└── FeedbackReceiver

Criatura (Enemy)
├── CombatActor
│   ├── Health
│   ├── AttackPattern (telegraph → wind-up → strike)
│   └── TimingWindow (para esquiva do jogador)
└── FeedbackReceiver
```

---

## 5. Estrutura de Diretórios

```
caipora/
├── assets/
│   ├── sprites/          # todos os sprites: chars, inimigos, tiles, itens (.png)
│   ├── audio/
│   │   └── sfx/          # efeitos sonoros (.wav, jsfxr/sfxr)
│   ├── fonts/            # fonte pixelada (.ttf / .otf)
│   └── licenses/         # licenças CC0 e atribuições
├── scenes/
│   ├── ui/               # menus, HUD, telas
│   ├── exploration/      # mapa grid, fog, camadas de tile
│   ├── arena/            # arenas de combate
│   └── shared/           # componentes reutilizáveis (barra de vida, etc)
├── scripts/
│   ├── core/             # autoloads: GameState, SignalBus, MetaProgression
│   ├── systems/          # TimingSystem, CombatSystem, FeedbackSystem
│   ├── entities/         # Caipora, Criatura (classes base)
│   ├── exploration/      # lógica de grid, TurnManager
│   ├── arena/            # ArenaManager, padrões de ataque
│   └── utils/            # helpers, constants
├── tests/
│   └── unit/             # testes unitários GUT
├── docs/                 # documentos de design
└── export/               # saída do build HTML5 (gitignored)
```

---

## 6. Padrões de Código

### 6.1 Naming

| Tipo | Convenção | Exemplo |
|------|-----------|---------|
| Classes | PascalCase | `CombatActor`, `TimingSystem` |
| Variáveis / Funções | snake_case | `attack_damage`, `start_timing_window()` |
| Constantes | UPPER_SNAKE_CASE | `MAX_HEALTH`, `TIMING_WINDOW_FRAMES` |
| Signals | passado snake_case | `health_changed`, `timing_hit` |
| Arquivos | snake_case | `combat_actor.gd`, `arena_manager.gd` |

### 6.2 Layout de Script

```gdscript
class_name CombatActor
extends CharacterBody2D

# ─── Exports ───────────────────────────────────────
@export var max_health: int = 100
@export var attack_damage: int = 10

# ─── Signals ───────────────────────────────────────
signal health_changed(new_health: int)
signal died

# ─── Constants ─────────────────────────────────────
const TIMING_WINDOW_FRAMES := 6

# ─── State ─────────────────────────────────────────
var current_health: int
var is_timing_window_open: bool = false

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
    current_health = max_health

# ─── Public API ────────────────────────────────────
func take_damage(amount: int) -> void:
    current_health = clampi(current_health - amount, 0, max_health)
    health_changed.emit(current_health)
    if current_health <= 0:
        died.emit()

# ─── Private ───────────────────────────────────────
func _open_timing_window() -> void:
    is_timing_window_open = true
```

### 6.3 Princípios

- **Composition over inheritance:** Use `@export` nodes e componentes, evite árvores de herança profundas.
- **Signals para desacoplamento:** Sistemas se comunicam via `SignalBus` autoload ou signals diretos, não referências diretas.
- **State machines:** Use padrão `StateMachine` para Caipora e Criaturas (explorar → combater → morto).
- **Sem números mágicos:** Defina constantes no topo do script ou em `constants.gd` autoload.
- **Typed everything:** Use static typing (`-> void`, `-> int`, `: int`) em todas as funções e variáveis.
- **Uma classe por arquivo:** Não empilhe múltiplas classes em um único `.gd`.

---

## 7. Arquitetura de Cenas

### 7.1 Autoloads (`Project > Project Settings > Autoloads`)

| Nome | Script | Propósito |
|------|--------|-----------|
| `GameState` | `scripts/core/game_state.gd` | Tela atual, estado da run, pause |
| `SignalBus` | `scripts/core/signal_bus.gd` | Signals globais (comunicação desacoplada) |
| `MetaProgression` | `scripts/core/meta_progression.gd` | Unlocks, currency, stats entre runs |
| `FeedbackSystem` | `scripts/systems/feedback_system.gd` | Screenshake global, partículas, som |

### 7.2 Padrões de Scene Tree

- **Cena de Arena:** `ArenaManager` (Node2D) possui o background, spawna instâncias de `Caipora` e `Criatura`.
- **Cenas de UI:** Baseadas em CanvasLayer, ancoradas ao viewport, usam nós `Control` para layout.
- **Componentes reutilizáveis:** HealthBar, DamageNumber, TimingCue são cenas instanciáveis (`PackedScene`) exportadas como `@export var`.

---

## 8. MCP & Agent Harness

O projeto usa `@coding-solo/godot-mcp` instalado e configurado.

### 8.1 MCP Tools Disponíveis

| Tool | Quando usar |
|------|-------------|
| `create_scene` | Criar novo arquivo `.tscn` |
| `add_node` | Adicionar nó a uma cena existente |
| `save_scene` | Salvar alterações em uma cena |
| `run_project` | Rodar o jogo e capturar output |
| `get_debug_output` | Ler stdout/stderr do jogo rodando |
| `stop_project` | Parar o processo do jogo |
| `launch_editor` | Abrir o editor Godot |
| `get_godot_version` | Verificar versão do Godot instalado |

### 8.2 Workflow do Agente

1. **Orient:** Ler `PLAN.md`, checar `git status`, ler `AGENTS.md`.
2. **Verify:** Rodar `make smoke` antes de fazer mudanças.
3. **Implement:** Uma task por sessão. Usar MCP tools para criação de cenas.
4. **Test:** Rodar `make gate` (smoke + GUT). Se houver mudanças visuais, validar com screenshot.
5. **Update:** Commit com mensagem descritiva. Marcar task completa em `PLAN.md` se aplicável.

---

## 9. Build & Export Pipeline

### 9.1 Desenvolvimento Local

Os comandos do harness vivem no `Makefile` (fonte única). Rode da raiz do repo.
Sobrescreva o binário com `make test GODOT=/caminho/para/godot`.

```bash
make smoke    # sobe headless ~50 frames e sai (smoke test)
make test     # roda o gate GUT (tests/unit)
make export   # build HTML5 reproduzível em export/
make gate     # smoke + test (antes de cada commit)

# Rodar o jogo com display (WSLg fornece :0)
~/.local/bin/godot --path .
```

### 9.2 Exportar para HTML5

```bash
# O preset "Web" já está configurado em export_presets.cfg
make export
```

### 9.3 Deploy no itch.io

1. Zipar conteúdo de `export/`.
2. Fazer upload na página do projeto no itch.io.
3. Marcar "This file will be played in the browser" para `index.html`.

---

## 10. Testes & Validação

### 10.1 Camadas

| Camada | Tool | Gatilho |
|--------|------|---------|
| Smoke test | `run_project` | Após cada mudança |
| Unit tests | GUT (Godot Unit Test) | Antes do commit |
| Validação visual | Screenshot | Antes do commit |
| Playtest | Manual | Nos boundaries de milestone |

### 10.2 Critérios de Aceitação por Milestone

- **Fase 1:** Caipora se move no grid. Câmera segue. Não crasha.
- **Fase 2:** Arena carrega. Cue de timing aparece. Espaço registra hit/miss. Dano aplica.
- **Fase 3:** Criatura ataca com telegraph. Boss tem padrão único. Condições de vitória/derrota funcionam.
- **Fase 4:** Meta-progressão unlocks persistem. Polish: partículas, sons, screenshake.
- **Fase 5:** Export HTML5 roda no browser. Página do itch.io carrega e joga.

---

## 11. Milestones

### Fase 1: Grid + Movimento da Caipora ✅
- [x] Cena de exploração grid-based
- [x] Personagem Caipora com movimento 4-direcional
- [x] Câmera segue
- [x] Tile de arena dispara combate

### Fase 2: Arena + Sistema de Timing ✅
- [x] Cena de arena com background
- [x] Caipora combat actor (vida, dano)
- [x] Cue de timing UI (barra visual + janela)
- [x] Detecção de espaço dentro da janela
- [x] Ataque crítico no timing perfeito
- [x] Feedback: screenshake + partículas + som

### Fase 3: Criatura + Boss ✅
- [x] Criatura combat actor
- [x] Telegraph de ataque (animação de wind-up + cue)
- [x] Esquiva perfeita + contra-ataque no timing
- [x] Boss com padrão de ataque único
- [x] Condição de vitória (morte da criatura) / derrota (morte da Caipora)

### Fase 4: Meta-Progressão + Polish ✅
- [x] Cena de hub entre runs
- [x] Sistema de unlocks (personagens, modifiers)
- [x] Save persistente (`user://`)
- [x] Polish de partículas
- [x] Sound design (sfx para cada ação)
- [x] Tuning de screenshake
- [x] Hit-stop frames

### Fase 5: Export + Publish 🚧
- [x] Preset de export HTML5 configurado (`export_presets.cfg`, auditado)
- [x] Build HTML5 reproduzível via CLI (`make export`, 39MB, zero erros)
- [ ] Teste de export no browser (Chrome + Firefox)
- [ ] Página do itch.io criada
- [ ] Upload e verificação

### Fase 6: Grid Roguelike ✅
- [x] Inimigos no mapa
- [x] Sistema de turnos
- [x] Mapa de 3 salas

### Fase 3 Final: Curupira + Fog of War + Encerramento ✅
- [x] Novos Screens: EXPLORATION_PHASE3, ARENA_PHASE3, ENDING
- [x] Upgrades nível 3: forca_3 (Fúria Ancestral, 8 frags) e saude_3 (Raiz Viva, 12 frags)
- [x] phase_reached=3 ao derrotar Boitatá (upgrades disponíveis antes de entrar na Fase 3)
- [x] Fog of War: CanvasLayer + shader radial, raio 3 tiles (fog_reveal.gdshader)
- [x] Mapa "Ventre da Mata": corredores estreitos, sem fogo
- [x] Inimigo Assombração: espectro 12 HP, aura fantasmal cinza-azulada
- [x] Timing −0.15s na Fase 3 via _phase_window() em runtime (PHASE3_TIMING_REDUCTION)
- [x] Boss Curupira: 20 HP, pés-para-trás, aura verde-mata, padrões RASTRO (←→←→, 2.5x) e ASSOBIO (3x, janela mínima)
- [x] Diálogo pré-boss: "ninguém te deixou..." / "isso pouco importa agora"
- [x] EndingScreen: sequência cinematográfica com fade, texto, silhueta procedural andando pela floresta
- [x] Mensagem final: "a floresta vive... por enquanto"

### Fase 7: Identidade Visual & Padronização ✅
- [x] Paleta como fonte única (`constants.gd`) — ~60 `Color()` centralizados
- [x] Design system de UI (`theme.tres`): Button/Panel/Label/ProgressBar, bordas duras
- [x] Telas padronizadas (menu, game over, win, hub) com type scale consistente
- [x] Atmosfera unificadora: vinheta + grão (`atmosphere.gdshader`, sem screen-read)
- [x] Floresta amazônica: tiles redesenhados + flora (samambaia/cipó)
- [x] Vida ambiente decorativa: vaga-lumes (CPUParticles2D) + insetos (sem interação)
- [x] Personagens identificáveis: Caipora 96×96 (juba-capa laranja, olhos brancos,
      pés normais pra frente — o pé-pra-trás é do Curupira, parente, NÃO da Caipora;
      ela é PEQUENA, do tamanho de uma criança — a imponência é da silhueta),
      caçador e bruxo 112×112 (invasores humanos adultos, ~1.3× a altura dela;
      leis: `docs/CONCEITO-protagonista.md` e `docs/CONCEITO-inimigos.md`)
- [x] Geradores algorítmicos: `gen_tiles.py`, `gen_chars.py`; captura: `screenshot.gd`

### CHAMA — Espada com elemento fogo ✅
- [x] Depois da espada (`forca_3`, "Raiz-de-Ira"), a cada **10 monstros comuns** derrotados há
      **1 sorteio** (`MetaProgression.register_kill_for_chama()`); contador `kills_toward_chama`
      **acumulado entre runs** (persistido no save).
- [x] Chance de drop num único ponto de tuning: `MetaProgression.CHAMA_DROP_CHANCE` (default 0.5).
- [x] Ao ganhar, recebe a **CHAMA no lugar do fragmento** daquela morte (`arena_manager._on_actor_died`);
      `has_chama` é **permanente** (salvo). HUD mostra popup "CHAMA!" (`SignalBus.chama_gained`).
- [x] Efeito fogo: **+1 dano** (`get_damage_bonus()` soma `CHAMA_DAMAGE_BONUS`), **partículas de chama
      somadas às douradas** e **sprite flamejante** `weapon_forca3_fogo.png`
      (gerador `scripts/gen_weapon_forca3_fogo.py`) — em `weapon_visual.gd`, visível na **arena e na
      exploração** (ambas via `WeaponVisual.attach_to`).
      *(Superado: os sprites de arma foram removidos no redesign "Guardia da Mata" —
      a Fúria/CHAMA manifesta no cristal do cajado via `furia_visual.gd`; ver entrada
      "Fúria no cristal" abaixo.)*
- [x] Testes: `tests/unit/test_chama.gd`.

### Fase 8: Geração Procedural de Mapas 🚧

Hoje os 4 mapas são `MAP_LAYOUT` estáticos (strings 26×18) hardcoded em cada
`exploration_phaseN_manager.gd`. Objetivo: **todo mapa gerado proceduralmente a
cada run**, usando os estáticos como referência de feel (mesma topologia,
contagem de inimigos e densidade de hazard). Princípio: **estrutura garantida +
variação** — a topologia macro garante salas/boss/saída/conectividade; o
procedural varia detalhes, hazards e posicionamento.

Arquitetura: gerador PURO e determinístico (seed por run) separado da
apresentação, com pipeline em camadas (topologia → sala do boss → validação por
flood-fill → hazards → entidades) e gate de invariantes em GUT. O char-grid
(`W/F/E/R/S`) continua sendo a IR — plugável nos managers sem fricção.

- [x] **Etapa 0 — Fundação testável** (sem mudança no jogo):
  - `scripts/exploration/map_config.gd` (`MapConfig`, Resource): params por fase
    (topologia OPEN/CORRIDOR, contagem de inimigos, hazards, baú/chave, fog),
    factory `for_phase()` codificando a identidade das Fases 1–4.
  - `scripts/exploration/generated_map.gd` (`GeneratedMap`): container de dados
    (grid + spawn + saída + inimigos + baú/chave) com `reachable_from()` (BFS).
  - `scripts/exploration/map_generator.gd` (`MapGenerator`): gerador puro
    determinístico — OPEN (região aberta + pilares blue-noise + alcova do boss)
    e CORRIDOR (drunkard's walk). RNG semeado próprio (Fisher-Yates manual, não
    `Array.shuffle()` global). Regenera em falha de conectividade.
  - `tests/unit/test_map_generator.gd`: 10 testes de invariante × 4 fases × 10
    seeds (determinismo, conectividade saída↔spawn, paridade de contagem de
    inimigos, 1 boss, placement válido/único/fora do spawn, densidade de hazard,
    variação por seed, baú/chave condicionais). ~4676 asserts, gate verde.
- [x] **Etapa 1 — Plugar na Fase 1**:
  - `GameState.run_seed` (sorteado em `start_run()`) + `map_seed_for_phase(fase)`
    (mistura determinística): mapa novo por run, mas **idêntico ao voltar da arena**
    (mesma run+fase → mesmo mapa); inimigos derrotados seguem fora via
    `defeated_enemy_ids` (IDs determinísticos). Sem cache em `GameState` — regen
    determinística basta.
  - `exploration_manager.gd` (Fase 1) consome `GeneratedMap` no lugar de
    `MAP_LAYOUT`/`ENEMY_DEFS`/`DECO_DEFS`/`*_POS`. Fonte-única-de-verdade de
    walkability: `_is_walkable` lê o mapa gerado (mesma fonte que pinta o TileMap).
  - Decorações: posições no gerador (`decoration_count`), tipos sorteados da
    paleta `MapObject.DECO_TYPES` por RNG semeado (estáveis na volta da arena).
  - **Regras de placement** (pedido do design): contagem por fase 4/4/6/6; baú e
    chave sempre longe do jogador e longe um do outro; boss sempre na metade mais
    distante; sempre 1–2 guardas perto do boss.
  - Fases 2–4 **intactas** (ainda estáticas) — jogo segue jogável ponta-a-ponta.
  - Testes: `test_map_generator.gd` (15 invariantes) + `test_exploration_phase1.gd`
    (integração da cena). Gate verde: 120 testes / ~10.9k asserts.
- [x] **Etapa 2 — Topologia CORRIDOR + Fase 3** (com fog of war):
  - `exploration_phase3_manager.gd` consome `GeneratedMap` (CORRIDOR), preservando
    fog of war, aura de fogo, `_find_safe_spawn`, dano de fogo 2, roteamento
    Curupira/Assombração + diálogo e o `CanvasModulate` verde. Contagem 6.
  - **Correção:** a Fase 3 estática TEM fogo (o PLAN dizia "sem fogo"). Procedural
    mantém fogo (`hazard_chars=["R"]`) **+ garantia universal de rota até o boss
    sem fogo forçado** (`_ensure_clean_path`: limpa hazards sobre uma rota se a
    única passagem cruzar fogo).
  - `has_exit=false`: Fase 3 não tem tile `E` — progride ao **derrotar o Curupira**
    (boss na célula mais profunda). Boss carrega `boss_type` → sprite/aura certos.
  - Decoração modesta temática (raízes/musgo/cipó) via paleta `DECO_THEME`.
  - Tuning CORRIDOR: junções ocasionais (`CORRIDOR_JUNCTION_CHANCE`) p/ salinhas e
    rotas alternativas.
  - Testes: +invariantes (boss_type, rota limpa de fogo, `has_exit`/tile `E`) e
    `test_exploration_phase3.gd` (integração). Gate verde: 125 testes / ~10.8k asserts.
- [x] **Etapa 3 — Manager único + rollout Fases 2 e 4**:
  - Um único `exploration_manager.gd` dirigido por `@export var phase` substitui os
    4 managers (930 → ~430 linhas; deletados `exploration_phase{2,3,4}_manager.gd`).
    Comportamento por fase é DADO: `MapConfig.for_phase()` (geração) + `_build_profile()`
    (apresentação/rota: cenas de boss/regular, tela de arena, diálogo, e flags
    `hazard_damage`/`aura`/`safe_spawn`/`ambient_life`/`keep_position`/`has_fog`/
    `enhance_fire`/`exit_marker`/`phase_reached_on_enter`/paleta de decoração).
    As 4 `.tscn` apontam pro script único com `phase = N`; cor do `CanvasModulate`
    fica na cena.
  - **Fases 2 e 4 viram procedurais.** P4 `has_exit=false` (progride ao derrotar o
    Saci → ENDING; corrigida a inconsistência latente). Decoração modesta temática
    de fogo/morte (troncos queimados/ossos/árvores mortas) nas P2/P4 via `DECO_FIRE`.
  - **Sem regressão:** preservado fogo 1 (P1) vs 2 (P2/3/4), baú/chave só P1, fog só
    P3, manter-posição só P1, `phase_reached=2` ao entrar na P2, auras tocha/fogo,
    spawn seguro P3/P4. Fases 1 e 3 com comportamento idêntico.
  - Testes: integração das 4 fases (`test_exploration_phase{1,2,3,4}.gd`). Gate verde:
    smoke OK, 127 testes / ~9.4k asserts.
- [x] **Etapa 4 — Polish** (fecha o épico):
  - **Transição em toda troca de cena.** Autoload `SceneTransition` (CanvasLayer
    layer 100 — abaixo do `PortraitGuard` 128, acima do HUD) mascara o hard-cut do
    `change_scene_to_file` com fade preto curto (out 0.22s / in 0.28s). `GameState`
    resolve a cena em `_scene_path_for()` (ponto único de roteamento) e delega.
    Flavor **"a mata se reorganiza..."** só ao entrar numa exploração de fase NOVA
    (run start / avanço); volta de combate p/ a mesma fase e telas de menu usam fade
    limpo. `process_mode = ALWAYS` (roda pausado) e engole cliques durante a transição.
  - **Tuning de densidade guiado por preview.** Confirmado via `preview_map.gd` que
    P1/P2/P4 (OPEN) escalam bem o fogo (4%→11%→15%, dá pra contornar andando). Único
    desbalanceamento real: P3 (CORRIDOR largura 1) — fogo vira portão de dano forçado
    nas ramificações fora da rota-ao-boss. Fogo da Fase 3 baixado `0.06 → 0.04`;
    abertura mantida em 0.44 (labirinto é a identidade do Ventre da Mata).
  - **Ferramenta de preview** (`scripts/tools/preview_map.gd`): dump ASCII + densidades
    por fase×seed, headless — tuning de mapa sem display.
  - **Ajuste de povoamento:** 6 monstros em TODAS as fases (antes 4/4/6/6 → agora
    6/6/6/6), sempre com ≥1 guarda perto do boss (`BOSS_GUARD_MIN=1`, já imposto).
    Decorações ambientais mais densas em todas as fases (P1 40→60, P2 22→44,
    P3 18→30, P4 22→44) — só visual, não afeta walkability.
  - Testes: `test_scene_transition.gd` (lógica de flavor + roteamento de TODA tela do
    enum p/ uma cena .tscn única); contagem por fase atualizada para 6/6/6/6. Gate
    verde: smoke OK, 134 testes / ~12.6k asserts.
  - **Adiado (follow-up):** daily-seed; variar canto do boss.

### Fase 9: Hub de Aprimoramentos Jogável 🚧

Tira os aprimoramentos da tela de menu pré-jogo e os transforma num **Acampamento
jogável** pelo qual a Caipora caminha **ao iniciar a run e entre uma fase e outra**. As ervas
compráveis da fase aparecem como **cards grandes e clicáveis** (`HubShop`/`HubCard`), cada um
com ícone, nome, efeito derivado (ex: "Dano +1/hit (total 2)") e custo; **clicar/tocar** num
que dá pra pagar realiza o aprimoramento. A saída é um rastro no chão → próxima fase. **A run
começa pelo acampamento** (`main_menu` abre o HUB antes da Fase 1): a Caipora gasta os
fragmentos acumulados de runs anteriores antes de pisar na mata.
Roadmap completo: [docs/PRD-fase-9-hub-jogavel.md](docs/PRD-fase-9-hub-jogavel.md).

- [ ] **Etapa 0 — Roteamento via hub:** `GameState.pending_exploration` +
  `advance_phase_via_hub()`; `exploration_manager` (tile de saída) e `arena_manager`
  (morte de boss P2→P3, P3→P4) roteiam o **avanço de fase** pelo HUB — vitória comum,
  boss da P1, ENDING e GAME_OVER seguem diretos. `main_menu.gd` inicia a run e cai direto
  na Exploração da Fase 1. Hub de cards atual segue temporário, agora lendo
  `pending_exploration`. Testes de roteamento.
- [ ] **Etapa 1 — Hub jogável (grid + saída):** `scenes/hub/hub.tscn` +
  `scripts/hub/hub_manager.gd` (Node2D: TileMap + Caipora + saída pulsante), `heal_to_full()`
  na entrada, `_scene_path_for(HUB)` aponta pra cena nova. Anda → pisa na saída → próxima
  fase, com continuidade da run preservada.
- [ ] **Etapa 2 — Ervas no chão + compra ao pisar:** posiciona toda erva comprável da fase
  (gate `phase_reached` + `requires` + não-comprada) com ícone + custo; compra ao pisar via
  `MetaProgression.purchase_upgrade` (fonte única de verdade); HUD de fragmentos + resumo
  de bônus; feedback de sucesso/insuficiente.
- [ ] **Etapa 3 — Polish + limpeza:** identidade do acampamento (fogueira, cachimbo, vida
  ambiente, SFX de "fumar", número flutuante, brilho acessível/caro), flavor de transição,
  **aposentar** `scenes/ui/hub.tscn` + `scripts/ui/hub.gd` (mover `OptionsPanel` pro hub
  jogável), atualizar `test_hub_*`/`test_scene_transition`. Gate verde.

### Fase Final: A Igreja na Mata — O Catequizador 🚧

A quinta e **última** fase: o interior de uma igreja colonial dentro da floresta.
O chefe é o **Jesuíta Bandeirante Catequizador**, que abre a fase declarando que
*converteu* os antigos encantados — por isso os "monstros" da tela **são os outros
quatro chefes** (Mula, Boitatá, Curupira, Saci), agora a serviço do altar; no fundo
da nave, o próprio Jesuíta. Encadeia depois do Saci (P4) e substitui o caminho
direto P4→ENDING (agora P4→**P5**→ENDING). É a fase mais difícil do jogo.
Spec completa: [docs/PRD-fase-final-igreja.md](docs/PRD-fase-final-igreja.md).

**Decisões travadas:** janela de reação **a mais dura de todas** (−0.2s ALÉM da
P4 → `PHASE5_TIMING_REDUCTION=0.50`, piso 0.2s); mini-bosses com **HP cheio de
chefe** (12/22/30/36); assets **AAA via pipeline procedural** (gen_chars/tiles/sfx).

> **Status:** Etapas 0–3 **implementadas** nesta sessão. O `make gate` (smoke +
> GUT) ainda **não foi rodado** — o container remoto não tem o binário do Godot.
> Rodar o gate num ambiente com Godot antes do merge; rodar `/validate-controls`
> e `/validate-platforms` (input/arena/timing/UI novos).

- [x] **Etapa 0 — Fundação de dados:** telas `EXPLORATION_PHASE5`/`ARENA_PHASE5`,
  roteamento `_scene_path_for`, `MapConfig.for_phase(5)` (`enemy_count=5`,
  `common_types=[mula,boitata,curupira,saci]`, `boss_type=jesuita`, `has_exit=false`),
  constantes `PHASE5_*` + `COMMON_FRAGMENT_REWARD[5]`/`BOSS_FRAGMENT_BOUNTY[5]`/
  `JESUITA_MAX_HEALTH`. Testes do gerador para a Fase 5.
- [x] **Etapa 1 — Chefe final jogável:** `jesuita.gd` (`extends Saci`, sorteio
  UNIFORME dos 7 padrões de todos os chefes + telegraphs corretos), `jesuita.tscn`,
  `arena_phase5.tscn`, `_phase_window` caso 5 e bônus de dano P5 em
  `_on_defense_timing_result`. `test_jesuita.gd`.
- [x] **Etapa 2 — Exploração da igreja + gauntlet:** `exploration_phase5.tscn`, caso
  5 do `_build_profile`, mini-bosses como comuns (`REGULAR_SCENES` + flag
  `keep_own_hp` p/ preservar HP de chefe), render de mini-boss no `MapEnemy`,
  **diálogo de abertura da fase** ("converti todos eles com espelhos e água benta.
  a floresta pertence ao vaticano."), roteamento P4→P5→ENDING + `phase_reached=5`
  ao liberar a Igreja e `phase_reached=6` ao derrotar o Jesuíta.
  `test_exploration_phase5.gd` + update de `test_scene_transition`/roteamento.
- [x] **Etapa 3 — Assets & polish AAA:** sprite do Jesuíta + SpriteFrames
  (`gen_chars.py`: morrião + gibão sobre batina, espelho + aspersório), decoração de
  igreja (`DECO_CHURCH`: banco/cruz/espelho/pia de água benta/círio em `map_object.gd`),
  3 faixas de áudio (`gen_sfx.py`: `mus_explore_p5` órgão+frígio, `mus_arena_p5`,
  `mus_boss_jesuita` com sino de igreja) wiradas no `AudioDirector`, `CanvasModulate`
  frio. `test_church_props.gd` + `test_audio_director` (P5).

### Dois Finais: a Escolha Final — "Poupar ele?" ✅

Derrotar o Jesuíta não encerra mais o jogo direto: abre a **cena da escolha
final** (`FINAL_CHOICE`), uma cinemática AAA montada por código — a Caipora **de
costas** (pose `back` nova no `gen_caipora.py`), o Jesuíta **caído e respirando**
sob o facho do vitral, poça de sangue crescendo, letterbox, push-in lento, órgão
estertorando — e UMA pergunta com duas respostas:

- **NÃO (executar)** → `ENDING` (final canônico, intocado) + mensagem nova no
  céu do por do sol: **"a floresta segue respirando"**.
- **SIM (poupar)** → `ENDING_SACRIFICE` (final novo): a misericórdia é paga com
  água benta — **a Caipora morre e a floresta vira cristã**. Amanhecer alvejado,
  sol pálido de hóstia, treelines PARADAS (sway 0 — a mata não respira), cemitério
  de cruzes, o corpo dela (pose `dead`, sem olhos) ao pé de uma cruz com poça de
  sangue, sino da igreja dobrando, sem música.

- [x] Telas `FINAL_CHOICE`/`ENDING_SACRIFICE` no enum + `_scene_path_for`;
  `ArenaManager._resolve_next_screen` (P5 boss → FINAL_CHOICE) e
  `_do_screen_change` (caminho terminal não registra defeated_id).
- [x] `final_choice_screen.gd` (+ roteador puro `screen_for_choice`), com os dois
  beats de saída: execução (golpe seco, flash, shake, sangue) e poupar (a água
  benta branca engole a nave).
- [x] `ending_sacrifice_screen.gd` + mensagem no céu do `ending_screen.gd`.
- [x] Poses novas `back`/`dead` (+_chama) SOMENTE via `gen_caipora.py` (de costas:
  sem olhos, lâmina desponta da capa; morta: mortalha de juba, vazio fechado,
  cajado caído) + travas de marca em `test_caipora_sprite_assets.gd`.
- [x] Áudio: órgão estertor movido do ENDING para a FINAL_CHOICE (o momento da
  queda), ambiência/reverb de igreja na escolha, sino no sacrifício, silêncio
  musical nos dois (`test_audio_director`).
- [x] `test_final_choice.gd` (roteamento, contrato de cena, idempotência da
  escolha, end_run só nos finais) + `preview_final_scenes.gd` (capturas Xvfb,
  inclusive e2e dos dois desfechos com `--choose=sim|nao`).

### Economia & Aprimoramentos v2 ✅

Redefinição coerente da economia e da escala dos aprimoramentos para um roguelike
consistentemente **difícil**. Spec completa: [docs/PRD-economia-v2.md](docs/PRD-economia-v2.md).

- [x] **Fonte numérica única.** `UPGRADE_DEFS` ganha `dmg`/`hp`; `get_damage_bonus`/
  `get_health_bonus` são data-driven; o texto do efeito é DERIVADO via `effect_text()`
  (mata a classe de bug do KI-006 — campo `effect` removido).
- [x] **Trilha Fúria com teto.** Cada erva +1 dano (5/10/16/24 frags); dano vai de 1 a 5
  (6 com a CHAMA, agora +1 em vez de +2). Antes o teto era 8–10 e trivializava o late-game.
- [x] **Trilha Cura com incrementos crescentes.** +2/+3/+3/+4 HP (6/12/20/30 frags);
  HP máx. de 2 a 14. Antes era +2 fixo (retorno achatado).
- [x] **Snowball pela metade.** Kill comum dá **meio HP máx.** (acumula em
  `GameState.caipora_max_hp` float, materializa +1 coração a cada 2 kills) + cura 1;
  boss é marco (+1 HP máx. + cura 2). Antes: +1 HP máx. por kill (snowball forte).
- [x] **Currency inteira + boss bounty.** Kill comum 1/2/3/4 por fase; boss paga
  3/5/8/12 (antes boss = 0 e comuns davam 1.5/2.0/2.5 fracionários).
- [x] **HP de comum UNIFORME por banda de fase + dano da Caipora vindo da Fúria.**
  Todo comum (não-boss) tem o MESMO HP: `5` nas fases 1-2, `8` nas fases 3-5
  (`Constants.common_health_for_phase`, aplicado no `_spawn_enemy`). Cada golpe da
  Caipora parte de `1` em toda fase (`Constants.caipora_base_damage_for_phase`) e soma
  apenas ervas de Fúria/CHAMA no `_spawn_caipora`. Bosses mantêm HP próprio
  (12/22/30/36/44); na Fase 5, os 4 chefes convertidos mantêm HP próprio como mini-bosses.
- [x] **Crítico 2×–3× fica fora de escopo** (decisão deliberada, registrada no PRD): o
  burst por skill vem do ataque-duplo; subir o multiplicador estouraria o teto de dano.
- [x] Testes: literais de custo/HP/dano atualizados + `test_effect_text_matches_math`.
  Gate verde: smoke OK, 152 testes / ~12.7k asserts.

### Apresentação de Boss (estilo Mega Man) ✅

Toda boss fight abre com uma pré-tela curta de apresentação **antes do diálogo**:
fundo escuro, o **modelo do boss** surge em cena com um "pop" elástico e brilho de
aura, e abaixo o **nome estilizado** se revela letra a letra entre duas barras de
destaque (com o subtítulo "— CHEFE —"). Vale para os 4 bosses (Mula sem Cabeça,
Boitatá, Curupira, Saci).

- [x] `scripts/ui/boss_intro_screen.gd` (`BossIntroScreen`, CanvasLayer layer 15) +
  `scenes/ui/boss_intro_screen.tscn`. Cena montada por código (depende dos dados do
  boss em `start()`), no padrão de `ending_screen.gd`. Modelo normalizado a uma
  altura de exibição fixa; glow radial procedural (`GradientTexture2D`) na cor de
  aura.
- [x] **Nome sempre completo, nunca espremido.** Fonte grande e fixa (`FONT_TITLE`);
  quebra automática por PALAVRA (`AUTOWRAP_WORD`) em até 2 linhas quando o nome não
  cabe na largura (ex.: "MULA SEM CABEÇA" → "MULA SEM" / "CABEÇA"). A caixa reserva a
  altura do nome completo, então a revelação letra a letra não empurra as barras
  (alinhamento vertical TOP mantém a linha 1 fixa). As barras de destaque se
  reposicionam conforme 1 ou 2 linhas.
- [x] Animação: pop elástico do modelo → barras varrem do centro + subtítulo →
  revelação letra a letra do nome → hold → encerra. Bob ocioso do modelo e pulso
  do glow em loop. Auto-avança após o hold, ou **skip** por toque/tecla/clique
  (com carência anti-skip-acidental de 0.4s, igual ao diálogo).
- [x] Roteamento em `exploration_manager.gd`: combate de boss → `_show_boss_intro()`
  → `boss_intro_finished` → diálogo (ou direto à arena se a boss não tiver falas)
  → arena. Dados por fase no `_build_profile()` (`boss_frames` + `boss_aura`).
  Signal `boss_intro_finished` no `SignalBus` (par do já existente `boss_intro_started`).
- [x] Testes: `tests/unit/test_boss_intro_screen.gd` (15 testes: nome, modelo,
  signals start/finish, idempotência, revelação do nome, quebra de linha/word-wrap,
  caixa do nome limitada, eventos de skip). Gate verde: smoke OK, 179 testes /
  ~12.7k asserts. Verificação visual headless (Xvfb + harness de captura) confirmou
  os 4 bosses, incluindo a Mula em duas linhas.

### Bolsa de Fragmentos (Souls-like / Corpse Run) ✅

Ao **morrer**, a Caipora derruba **TODOS os fragmentos** numa **bolsa**, no lugar exato
da morte (fase + tile). A bolsa fica caída na mata; ao **pisar nela** numa run futura, a
Caipora reaver **todos** os fragmentos. **Morrer de novo** antes de chegar lá **perde
tudo** — a bolsa antiga é sobrescrita e segue com zero. Tensão souls-like sobre a moeda
de meta-progressão, coerente com o tom hostil da floresta.

- [x] Estado persistente em `MetaProgression` (`frag_bag_active/phase/pos/amount`, no save
  `v3`; migração v2→v3 no-op). API: `drop_fragment_bag(phase, pos)` (zera o saldo e
  sobrescreve qualquer bolsa anterior — só marca bolsa nova se havia fragmento),
  `has_bag_in_phase(phase)`, `recover_fragment_bag()` (devolve tudo + `fragment_gained`).
- [x] **Drop na morte** em ambos os caminhos: arena (`arena_manager._on_actor_died`, derrota,
  no tile do combate via `GameState.player_map_pos`) e hazard na exploração
  (`exploration_manager._apply_hazard_damage`, no tile atual).
- [x] **Bolsa no chão + recuperação ao pisar:** `MapObject.Type.BAG` (saco de couro em poça
  de sangue, estilhaços âmbar) + brilho âmbar pulsante. `exploration_manager._spawn_fragment_bag()`
  recria a bolsa na fase da morte; como o mapa é sorteado por run, o tile pode ter virado
  parede → `_nearest_walkable()` (BFS) reancora no caminhável mais próximo. Pisar reaver
  via `_recover_fragment_bag()` (HUD pulsa o ganho).
- [x] Testes: `tests/unit/test_fragment_bag.gd` (drop/recover/overwrite/save round-trip/reset).

### Redesign da Protagonista — A Predadora-Rainha da Mata ✅

A Caipora é o núcleo visual do jogo: só de olhar pra ela tem que dar vontade de
jogar. O boneco de retângulos da Fase 7 foi substituído por um design de
personagem alinhado à indústria (silhueta primeiro, acento único de cor, luz
própria, assimetria, atitude no idle) e fiel ao folclore (urucum, jenipapo,
vestes vivas de folha/cipó, pés normais pra frente). Bíblia visual:
[docs/CONCEITO-protagonista.md](docs/CONCEITO-protagonista.md) — **lei** para
todo asset futuro da protagonista.

- [x] Conceito: silhueta felina de predadora, **juba-cometa de fogo** (flui pra
  trás, eriça no windup, estica no strike), olhos de brasa em máscara de
  jenipapo, cipó-chicote com ponta em brasa, vestes vivas assimétricas.
- [x] Pipeline premium próprio (`scripts/tools/gen_caipora.py`, determinístico):
  desenho vetorial supersampled 8× → downsample → snap de paleta → **selout** →
  **rim light térmico procedural** (o fogo da juba ilumina o corpo) → dither de
  bandas no fogo. 6 frames (idle/walk×2/windup/strike/recover), 64×64.
- [x] `gen_chars.py` delega a protagonista ao `gen_caipora.py` (demais
  personagens intactos, byte a byte).
- [x] Linguagem corporal por pose preservando o contrato do `ActorAnimator` e
  do `caipora_sprite_frames.tres` (mesmos nomes/arquivos — zero mudança de cena).
- [x] **A CHAMA incendeia a Caipora:** com `has_chama` (permanente), os frames
  trocam para a variante incendiada (`player_*_chama.png` +
  `caipora_sprite_frames_chama.tres`): juba mais longa/quente, brasas orbitando
  (derivam entre os frames de walk; nunca caem no rosto), estalo do chicote
  maior. Seleção E aplicação em ponto único (`CaiporaSkin.frames_path/apply`,
  par do `WeaponVisual.attach_to`), por código (sem editar `.tscn`) na
  exploração, na arena e no `TitleWalker` (menu/ending). Conquista NO MEIO do
  combate incendeia na hora (`SignalBus.chama_gained` → re-apply preservando a
  pose). Mesmo contrato de animações — `ActorAnimator` não percebe. Testes:
  `test_caipora_chama_frames.gd`.

### Fúria no cristal + flash de janela perfeita ✅

Follow-up do redesign "A Guardia da Mata" (cajado com cristal verde embutido no
sprite 96×96 — o cajado se move por pose, então um overlay estático nunca alinha):

- [x] **Overlay de forca removido.** `weapon_visual.gd` → `furia_visual.gd`
  (`FuriaVisual`): Node2D ancorado no cristal (`CRYSTAL_ANCHOR` derivado do
  `staff_tip` do `gen_caipora.py` + `offset` do sprite lido em runtime), espelha
  com `flip_h`, re-attach idempotente. Tiers T1–T6 mantêm a identidade de lore
  via partículas (fumaça/aura/breu/osso/carne) + `CrystalGlow` verde que escala;
  CHAMA soma a chama viva — e agora aparece **mid-run** (re-attach no
  `_on_chama_gained`). Deletados os 12 `weapon_forca*.png`, `gen_weapons.py` e
  os geradores legados `gen_weapon_forca3*.py`. Testes: `test_furia_visual.gd`.
- [x] **Flash verde-cristal na janela perfeita** (`timing_bubble.gd`): ao entrar
  na zona perfeita o anel pisca `COLOR_CRYSTAL_GLOW` por 0.12s (sincronizado com
  o `timing_alert_sound`) e decai para a cor de modo (vermelho/azul/roxo
  intocados; barra âmbar do hub intocada). Hit-stop congela o flash junto.
  Curto e em outro tom do telegraph do Curupira (modulate sustentado no sprite
  do inimigo) — sem colisão de linguagem. Testes: `test_timing_bubble.gd`.

### Fase 10: PWA livre + 60fps + música do hub + loader "peleja" 🚧

Update de plataforma e polish. Quatro frentes independentes; **uma sessão por
frente** (Session Protocol), na ordem abaixo. Cada sessão fecha com `make gate`
+ skill de validação pertinente + commit.

#### 10.1 Orientação livre na PWA (sem trava de paisagem)

Estado atual: o jogo é retrato-primário internamente (viewport 750×1334,
`handheld/orientation=1`), mas o manifest PWA exportado trava
`"orientation":"landscape"` — porque no exporter web do Godot o enum de
`progressive_web_app/orientation` é **0=Any, 1=Landscape, 2=Portrait** (a doc
em `validate-platforms/SKILL.md` afirma `1=retrato`, o que está errado e
causou a trava acidental). O `PortraitGuard` (layer 128) ainda bloqueia
telefones em paisagem com "gire o dispositivo".

- [x] `export_presets.cfg`: `progressive_web_app/orientation=0` (Any). Conferir
  `export/index.manifest.json` gerado: `"orientation":"any"`.
- [x] `project.godot`: `window/handheld/orientation=6` (SENSOR — segue o giro
  do aparelho em qualquer build nativa; na web quem manda é o manifest).
- [x] Remover o autoload `PortraitGuard` (project.godot + script + testes que o
  referenciam). Com orientação livre não existe orientação "errada" — o layout
  já é responsivo (D-pad escala 1.5×/1.3× por orientação em `controls_hud.gd`,
  câmera contain-fit recalcula em `size_changed` no `arena_manager.gd`,
  `ACTION_LIFT_FRACTION` levanta a ação acima do D-pad).
- [ ] Auditar telefone em PAISAGEM (844×390) **num device real**, que era
  bloqueado e nunca foi exercitado de verdade: arena, exploração, hub (cards
  de aprimoramento), diálogos, menus, safe areas (notch lateral via CSS `env()`).
- [x] Tratar o giro **durante** o jogo: tudo que se posiciona por viewport deve
  reagir a `size_changed` (já é o padrão; conferido nos consumidores de
  `is_portrait`: D-pad, hub e câmera da arena).
- [x] Atualizar docs: gotcha #10 do `AGENTS.md`, `validate-platforms/SKILL.md`
  (corrigir o enum errado e o checklist de manifest), PRD se citado.
- [x] `/validate-platforms` + `make gate` + `make export` (export único no fim
  da Fase 10, para não rebuildar binário a cada frente).

#### 10.2 Loader "peleja" antes do combate

O início de combate hoje é seco: `_trigger_combat` → `change_screen(arena)` →
fade de 0.22s → `ArenaManager._ready()` chama `_start_caipora_turn()` no mesmo
frame. Não há feedback de "a luta vai começar" nem máscara de carregamento.

Design: TODA entrada em tela `ARENA_*` ganha um loader interno no próprio
`ArenaManager`, depois do fade global limpo. A arena nasce pronta por baixo,
mas o primeiro turno só abre quando o overlay libera — o jogador nunca perde
um cue de timing escondido atrás do texto:

- [x] Fade global preto (igual hoje, sem texto de luta) → loader interno da
  arena com **"PREPARE-SE"** → **"PELEJAR"** (`FONT_TITLE`, âmbar de cue) →
  fade-out do loader → primeiro turno.
- [x] Constantes no topo do `ArenaManager`: `COMBAT_LOADER_FADE`,
  `COMBAT_LOADER_PREPARE_HOLD` e `COMBAT_LOADER_FIGHT_HOLD`, sem número mágico.
- [x] Gate de início: `ArenaManager._ready()` spawna atores e chama
  `_run_combat_loader()`; `_start_caipora_turn()` só roda no final do tween.
- [x] Engolir input durante o loader (o fade usa `MOUSE_FILTER_STOP`; Space não
  buffera timing porque o TimingSystem só arma no primeiro turno, pós-loader).
- [x] Boss: a sequência vira BossIntro → diálogo → arena → loader interno. O loader é
  o feedback de carga já dentro do combate, que o BossIntro não cobre;
  ambos mantidos — linguagens diferentes (apresentação vs. carregamento).
- [x] Stinger: `sting_arena_enter` já toca na entrada da arena via
  `AudioDirector` (reage ao `screen_changed`) — soa junto do texto, sem
  pipeline novo.
- [x] Testes GUT: a transição global confirma que arena não mostra texto de luta;
  `test_controls_hud.gd` cobre o modo de arena com setas. O gate do loader visual
  não tem harness headless — validar no device junto com o checklist visual.
- [x] `/validate-controls` passo 1 (`make test` ✅ 317/317); passos 2–5 exigem
  display — checklist manual pendente no device.

#### 10.3 Música do hub (tela de aprimoramento) — matar a sirene de vez

Diagnóstico (gen_sfx.py:1056-1060): o comping de acordes usa **4 vozes de
triângulo sustentadas ~0.9s** e cada nota passa por `_jit(0.004)` (detune
aleatório de até ±0.4%). Quatro vozes sustentadas e detunadas batem entre si
em poucos Hz → **batimento lento de amplitude = uí-uí de sirene**, amplificado
pelo bitcrush de 7 bits e pelo loop curto de 2 compassos (~9s) que martela o
artefato. O lead pulse (duty 0.25) nos graus 7–12 com sustain de ~0.36s
contribui com o "bip" agudo.

- [x] Reescrever `mus_hub()`: o pad sustentado virou violão dedilhado (arpejo
  de triângulo, nota a nota, nunca vozes sustentadas juntas) **uma oitava
  acima do baixo** — o pad antigo ainda sustentava o grau 0 em UNÍSSONO com o
  baixo (cada um com seu detune), o pior par possível de batimento.
- [x] Onde restar tom sustentado: só o baixo, voz única — sozinho não tem com
  quem bater (detune inofensivo). Regra documentada no docstring.
- [x] Lead uma oitava abaixo (graus 4–7 sobre root×2, antes chegava a A5),
  envelope pluck mantido, mais esparso (responde o violão nos vãos).
- [x] Loop de 4 compassos com variação (era 2 compassos repetidos).
- [x] Regenerar e commitar `assets/audio/music/mus_hub.wav` (regen determinístico:
  `--only music` só alterou o mus_hub, faixas vizinhas byte-idênticas).
- [x] Verificação objetiva: leito harmônico sintetizado isolado (sem percussão),
  amplitude do parcial de 110 Hz via Goertzel no sustain — profundidade de
  modulação caiu de 0.19 (antiga, batimento real; dependente do sorteio de
  detune, no asset chegava a ~1.0) para 0.05 (nova, resíduo de envelope).
  Validação subjetiva no device fica com o Baltz.
- [x] Tom: continua samba lofi morno — o acampamento é o respiro ("o
  acampamento respira..."). Não virou horror; o horror mora lá fora.

#### 10.4 Performance: 60fps em Android modesto

Base já é enxuta (gl_compatibility, CPUParticles2D, pixel art, sem threads na
web). Os suspeitos de stutter são **picos de alocação** e overdraw, não custo
médio. Medir antes de mexer.

- [x] Overlay de debug de frame-time/FPS atrás de flag: autoload `PerfHud`
  (layer 127), liga com `?perf` na URL (web) ou `CAIPORA_PERF=1` (nativo);
  desligado não cria nó nem processa. Medir num Android classe Moto G em
  Chrome, cenário pior: arena com crítico.
- [x] **Pool de partículas no `FeedbackSystem`**: todos os efeitos
  (sangue/crítico/morte/spark/dodge/bolha/fail) reusam CPUParticles2D via
  `restart()` — zero `instantiate()`/`queue_free()`/timer por golpe.
  Round-robin de 2 nós por efeito: golpe duplo não mata o burst anterior em
  voo. Testes: `test_feedback_pool.gd`.
- [x] Fator de qualidade em telefone: `Constants.particle_amount_scale` corta
  `amount` pela metade quando o lado curto < 640. O gore não recua — decals
  de sangue ficam, são baratos e permanentes.
- [x] `BloodDecals`: auditado — já é barato (cap de 250 splats, um nó só,
  redraw apenas em splat novo ou secagem a cada 2s). Sem mudança.
- [x] Auditar `_process` quentes: `ambient_life` (poucos insetos, sem alocação
  por frame), `atmosphere` (constrói uma vez), HUD ok. 2026-06-11: grading
  LIGADO na web (`GRADING_ON_WEB=true`) — sem ele o mobile ficava chapado/sem
  contraste vs. desktop; validar FPS no iPhone com `?perf` e reverter se <60.
- [x] `application/run/max_fps=60`: telas de 120Hz queimam bateria e induzem
  throttle térmico — o vilão real de "60fps em device modesto".
- [ ] Registrar a medição no device real (antes/depois, device, cenário) nesta
  seção — pendente de hardware (usar o `?perf`).
- [x] `make gate` ✅ 321/321 + `make export` no fechamento da Fase 10; teste de
  carga da página (gotcha #5) junto da validação no device.

### Santuário dos Encantados — Bosses Pacíficos no Acampamento ✅

Mudança core no significado da vitória: a Caipora não mata os encantados — ela os
**liberta**. Ao derrotar um boss (P1–P4), o espírito dele se recolhe ao Acampamento e
passa a viver lá em paz; cada libertação aplica uma **grande transformação visual
cumulativa** na clareira (Mula → pira ritual + brasas; Boitatá → perímetro de
fogos-fátuos; Curupira → mata viva + vaga-lumes; Saci → vento + redemoinhos de folhas),
até o estado final de santuário. Meta-persistente (save v4), com rito de chegada único
por encantado. **A libertação é definitiva:** o boss sai da fase para sempre — em runs
novas a toca dele vira passagem (tile de saída na cela do boss nas fases P3/P4, que não
têm saída) — e só volta se o jogador resetar o progresso. O Jesuíta NUNCA entra (não é
encantado) e os mini-bosses da P5 viram canonicamente "cascas batizadas" — simulacros,
não os espíritos verdadeiros — então a fase final mantém a dificuldade cheia. Encantados
em repouso são presenças antigas e perigosas, não mascotes — o horror não suaviza.
Decisões travadas com o autor em 2026-06-11. Spec completa:
[docs/PRD-santuario-dos-encantados.md](docs/PRD-santuario-dos-encantados.md).

- [x] **Etapa 0 — Memória dos encantados:** `freed_bosses`/`spirits_seen` no
  `MetaProgression` (chamada direta no `arena_manager._on_actor_died` junto do
  bounty/`phase_reached` — NÃO listener de `boss_died`: testes emitem o sinal cru e um
  listener persistiria save como efeito colateral; ignora P5), save v4 + migração
  v3→v4 derivada de `phase_reached` (generosa com quem pulou Mula/Boitatá pela saída —
  trade-off documentado), `reset_save()` devolve os guardiões. 10 testes novos
  (free/idempotência/P5 fora/round-trip/migração/sanitização/reset).
- [x] **Etapa 1 — A fase sem guardião:** `MapConfig.boss_freed` (injetado pelo
  `exploration_manager` a partir do `MetaProgression`; gerador segue puro) — boss não
  spawna, cela dele segue RESERVADA na geração (guardas/baú/chave/decorações
  byte-idênticos com ou sem boss, classe KI-007) e vira `peace_pos`, renderizada como
  marca de paz (`TOTEM`). Descoberta que simplificou o plano: toda fase P1–P4 já tinha
  tile de saída (o boss só a guardava; só a P5 progride por morte de boss) — zero
  mudança de roteamento. Invariantes por `boss_freed`×fase×seed + integração da Fase 1
  com Mula libertada. `/validate-controls` passo 1 OK (passos manuais no device).
- [x] **Etapa 2 — Presenças:** `scripts/hub/camp_spirit.gd` (`CampSpirit`, data-driven
  via `DEFS` com os frames premium da arena) — idle 0.6×, respiração em tween, aura
  calma na cor canônica (`COLOR_AURA_*`), modulate abatido. `hub_manager._spawn_spirits()`
  posiciona um por boss libertado na moldura de mata (`_spirit_anchor` derivado de
  `_clearing`; walkability intocada). `test_camp_spirit.gd` (3) + `test_hub_camp` (3).
- [x] **Etapa 3 — Transformação da cena:** 4 camadas cumulativas data-driven no
  `hub_manager` (pira da Mula modifica a fogueira + brasas de clareira; aro de
  fogos-fátuos do Boitatá em pulso dessincronizado; flora determinística do Curupira;
  folhas em deriva do Saci) + **câmera-diorama** no hub (contain da clareira com snap
  por floor, quadro pinado, mata pintada além do grid — sem void; o santuário lê
  inteiro em retrato E paisagem) e luz própria nos espíritos. `preview_camp_spirits.gd`
  (capturas Xvfb validadas em 393×852 e 844×390, estados 0/1/4). `/validate-platforms`
  passos manuais pendentes no device.
- [x] **Etapa 4 — Rito de chegada + narrativa + áudio:** reveal único por encantado
  no hub (espírito pendente nasce invisível; a clareira escurece, fade-in + brasas na
  cor da aura + fala seca de `RITE_LINES`; fila para 2+ pendentes; skip por
  toque/tecla com carência 0.4s; movimento trava via `set_process(false)` e saída via
  `_locked`; `spirits_seen` persiste). Áudio: a cicatriz sonora do chefe volta EM PAZ
  (`AudioDirector.play_spirit_rite` reusa `boss_death_*` a −8 dB — memória, não
  ameaça; zero asset novo). Nota canônica das cascas batizadas no
  `PRD-fase-final-igreja.md`. Preview com `--rite` captura o beat. 3 testes novos.

---

## 11.1 Known Issues

Rastreador canônico de bugs/débitos conhecidos. O Session Protocol exige registrar
aqui qualquer bug descoberto (mesmo não relacionado) antes de seguir. IDs no formato
`KI-NNN`; referencie-os em commits e REPORTs.

| ID | Severidade | Status | Descrição |
|----|-----------|--------|-----------|
| KI-004 | Média | ✅ Resolvida (`5cdbd40`) | Beco sem saída no fim de combate — telas WIN/GAME_OVER placeholder fecham o loop |
| KI-005 | Baixa | ✅ Resolvida (pós-MVP) | SFX reescritos com síntese de instrumentos do maracatu (alfaia/caixa/ganzá/agogô/gonguê) em `scripts/tools/gen_sfx.py`, com variação anti-repetição. Identidade sonora própria — não são mais placeholders genéricos |
| KI-006 | Baixa | ✅ Resolvida | Label do aprimoramento desincronizava do bônus real. Corrigido de vez na Economia v2: o campo `effect` foi removido e o texto é **derivado** da fonte numérica única (`dmg`/`hp`) via `MetaProgression.effect_text()` — não há mais string solta a divergir. Guardado por `test_effect_text_matches_math` |
| KI-007 | Média | ✅ Resolvida | Mapa não voltava idêntico após o combate: o jogador renascia no spawn (exceto Fase 1) e TODOS os inimigos teleportavam de volta ao spawn (o movimento na exploração é não-determinístico, então a regeração do mapa não os reproduz). Corrigido com snapshot de posições no `_trigger_combat` (`GameState.map_enemy_positions` + `player_map_pos` em todas as fases), restaurado em `_spawn_enemies`/`_setup_player`. `safe_spawn` agora só vale na entrada fresca da fase, não na volta do combate. Flag `keep_position` (sempre-true) removida |
| KI-008 | Média | ✅ Resolvida | `GameState.heal_to_full()` preserva o `caipora_max_hp` ganho dentro da run e só sobe para o novo teto meta se uma erva de Cura comprada no hub tornar esse teto maior. |
| KI-009 | Média | ✅ Resolvida | `Constants.caipora_base_damage_for_phase()` voltou a ser base fixa (`1`) em toda fase; a arena soma apenas Fúria/CHAMA por cima, então o texto das ervas volta a ser o teto real comunicado ao jogador. |
| KI-010 | Média | ✅ Resolvida | A vitória terminal libera `phase_reached = 6`: matar o Jesuíta marca o marco no `ArenaManager`, e `GameState.end_run(true)` também garante o unlock pós-clear antes de salvar a vitória. |
| KI-011 | Baixa | ✅ Resolvida | O loop de hover do menu tipava `Button` num array que inclui o `GithubLink` (`LinkButton`, irmão de `Button`): o array tipado rejeitava o item (vira `null`) e o som de hover do link morria em silêncio com SCRIPT ERROR no console. Corrigido tipando `BaseButton`. |
| KI-012 | Baixa | Parcial | Hierarquia de escala dos bosses: a PROPORÇÃO na arena foi corrigida fiel à lore via `sprite_scale`/offset de pés por cena (Saci premium < Caipora ≈ Curupira < Jesuíta/machados 2.8 ≈ caçador < Boitatá < Mula; contrato em `test_boss_scale_proportions.gd`). **Curupira, Jesuíta, Boitatá, Saci e Mula já migraram** (2026-06): Curupira e Jesuíta no pipeline premium `gen_bosses.py` (canvas 128 arena a escala de nó 1.2 + variante de mapa 48 — leis em `docs/CONCEITO-curupira.md`/`docs/CONCEITO-jesuita.md`, contratos em `test_curupira_sprite_assets.gd`/`test_jesuita_sprite_assets.gd`); Boitatá em `gen_boitata.py` (arena 160×128, idle/windup, escala 1.2); Saci em `gen_saci.py` (arena 128×128, idle/windup, escala 1.2 — lei em `docs/CONCEITO-saci.md`, contrato em `test_saci_sprite_assets.gd`); Mula em `gen_mula.py` (arena 192×192, idle/windup, escala 0.9 para a altura da lore — lei em `docs/CONCEITO-mula.md`, contrato em `test_mula_sprite_assets.gd`). O redesign do Jesuíta também corrigiu o sprite dele no mapa da Fase 5: `map_enemy.gd` não tinha case `"jesuita"` e o boss final aparecia como o caçador-de-machados (`boss_idle.png`). Resta o caçador-de-machados (48×48 upscalado, texels maiores que os dos comuns) — resolve na sessão de redesign dele. No MAPA os bosses seguem ~48px visuais (Curupira/Jesuíta via variantes re-renderizadas; Saci/Mula/Boitatá via clamp interino — ver KI-016). |
| KI-013 | Baixa | Aberta | `shaders/enemy_outline.gdshader` usa comentários `##`; no renderer dummy/headless do GUT isso emite `SHADER ERROR: Unknown character #35` ao instanciar criaturas, embora a suíte siga verde. Corrigir antes/de junto da Etapa 3 do `PRD-visual-exploracao.md`, que vai reutilizar esse outline nos inimigos do mapa. |
| KI-014 | Baixa | ✅ Resolvida | `test_caipora_movement` flakava sob carga da suíte: o timer do teste (0.2s) e o tween de movimento (0.15s) avançam no mesmo relógio e, num hitch de frame, cruzavam o limiar no MESMO frame — o timer resumia o teste antes do passo final do tween (`63.67 != 64`). Margem ampliada para 0.35s + um `process_frame` de folga após o timer. |
| KI-015 | Média | ✅ Resolvida | O redesign do Boitatá (PR #58) criou `gen_boitata.py` mas esqueceu a delegação no entrypoint: `gen_chars.py` seguia chamando o `boitata()` legado, então qualquer regeneração (`python3 gen_chars.py`) sobrescreveria o `boitata_idle.png` premium 160×128 com o desenho 48×48 antigo (o gate pegaria via `test_boitata_sprite_assets`, mas só depois do estrago no working tree). Junto veio uma entry da Mula no teste de escala (0.9/-77) que não correspondia nem à cena (3.5/-18) nem ao sprite legado — `test_boss_scenes_keep_scale_and_offset` vermelho na main. Corrigidos no merge da PR #59: delegação `gen_boitata.generate_all()` + remoção do legado morto (regeneração completa confere zero diff de assets) e entry da Mula restaurada aos valores reais. (A entry 0.9/-77 era um adiantamento do redesign da Mula que só entrou depois, no PR #60 — quando entrou, o valor virou o correto.) |
| KI-016 | Média | Parcial | Os redesigns premium de Saci (PR #61) e Mula (PR #60) repetiram o padrão do KI-015 e ampliaram: (a) `gen_chars.py` seguia chamando `saci()` legado — regenerar sobrescreveria o `saci_idle.png` premium 128 com o 48 antigo (a Mula delegou certo); (b) nenhum dos dois (nem o Boitatá do PR #58) gerou **variante de mapa**: `map_enemy.gd` aplica o `*_idle.png` SEM escala, então Saci 128, Boitatá 160×128 e Mula 192 estouravam o tile de 32px no modo explorar (3–6 tiles de sprite; sem teste cobrindo). Resolvido no merge da PR #59: delegação `gen_saci.generate_all()` + remoção dos legados mortos, e **clamp interino** no `map_enemy.gd` (sprite de boss acima de 64px de altura é reduzido para ~48px visuais via scale do nó). Pendente: variantes de mapa re-renderizadas dos vetores (como `curupira_map`/`jesuita_map`) nas sessões de Saci/Mula/Boitatá, removendo o clamp. |
| KI-017 | Baixa | Aberta | `test_exploration_phase3.gd::test_phase3_loads_corridor_map_with_fog_and_curupira` é flaky: usa `GameState.start_run()` (seed aleatório) e afirma que o nº de inimigos spawnados == `enemy_count`. Para certos seeds o mapa gerado não tem tiles alcançáveis suficientes e spawna menos (visto `2 != 5`), falhando ~1 em N rodadas. Não é regressão — independe do código de combate. Fix: semear o teste com `map_seed` fixo (determinístico) ou afirmar `<= enemy_count`. |
| KI-018 | Média | ✅ Resolvida | **O Cortejo dos Encantados nunca chegou ao combate** e, quando chegou, a mecânica ficou ilegível. (a) A tela "OBTIDO" + o núcleo existiam, mas a integração no turno nunca foi feita — resolvido ligando o golpe ao combate. (b) A 1ª versão usava CARGA (segurar ↑, soltar no cheio): ponto de soltar invisível + segunda metáfora de timing → o jogador não entendia o tempo. **Redesenhado para o "Batuque do Cortejo"** (sequência direcional rítmica, refs Patapon/Guitar Hero/Expedition 33): cada chefe libertado tem um chamado direcional fixo (`Constants.CORTEJO_CALL_FOR_PHASE`: Mula ↑, Boitatá →, Curupira ↓, Saci ←); o turno toca count-in de tambor e uma nota direcional por batida (anel convergente via `TimingSystem`+`TimingBubble`, reusando o tap conhecido + o pipeline dos especiais de boss); acerto invoca a aparição (entra pela direção) + 2 hits; erro hesita, a corrente segue; sequência perfeita → FEVER (acento de maracatu + último golpe crítico). Legibilidade: nota convergente + metrônomo (`AudioDirector.play_cortejo_beat`) + `CortejoBeatTrack` (faixa de pips com preview). Mantidos: `CortejoApparition` + trilha de luz. Aposentados: `HoldTimingSystem`, `ChargeBubble` e constantes de carga. Novo seam testável: `Constants.cortejo_calls_for()`; `TimingSystem.cancel_window()` destrava o `await` por nota no teardown. Cobertura: `test_cortejo_sequence.gd` + `test_cortejo_vfx.gd` + `test_timing_system.gd`. **Pendente (não-bloqueante):** `.wav` dedicados via `gen_sfx.py` (hoje fallback canônico); calibrar `CORTEJO_BEAT_SECS`/janela/FEVER em playtest; `/validate-controls` em device. |
| KI-019 | Média | ✅ Resolvida | O Batuque (KI-018) também foi rejeitado pelo jogador ("não entendi como funciona, sem feedback, mecânica pobre") — direcional é hostil ao **dedão/retrato/navegador** e a mecânica ficava vazia com 1 só espírito após o 1º boss. **Redesenhado (3ª forma) para o "Golpe Perfeito"** (refs Expedition 33/Sekiro/Legend of Dragoon): UMA janela única e apertada com **um toque `ui_up`** (o mesmo do ataque normal — máxima familiaridade pro polegar); **lead-in com slow-mo** telegrafa o golpe; **acerto → BARRAGEM** (todos os chefes libertados desabam de uma vez, dano escala com nº deles, clímax com `spawn_finisher_vfx`+zoom+acento); **erro → contra-ataque** (custo souls, reusa a fórmula canônica de dano do inimigo via `_enemy_counter_damage()` extraída do erro de defesa). Disparo: roll no turno, `CORTEJO_CHANCE = TIMING_DOUBLE_CHANCE`. Aposentados: `CortejoBeatTrack`, `cortejo_calls_for`/`CORTEJO_CALL_FOR_PHASE`/`CORTEJO_BEAT_SECS`/`CORTEJO_COUNT_IN_BEATS`, `play_cortejo_beat`, `test_cortejo_sequence.gd`. Mantidos/reusados: `CortejoApparition` (barragem, `strike(from_left)`), `TimingSystem`/`TimingBubble` (janela única) + `cancel_window`. Novo seam: `Constants.cortejo_spirits_for()`. Cobertura: `test_cortejo_barrage.gd` + `test_cortejo_vfx.gd` + `test_timing_system.gd`. **Pendente:** `.wav` (summon/slam/miss) via `gen_sfx.py`; calibrar `CORTEJO_WINDOW_BASE`/`CORTEJO_MISS_COUNTER_MULT`/teto da barragem em playtest; `/validate-controls` em device. |
| KI-020 | Baixa | ✅ Resolvida | `make smoke`/`make gate` podiam crashar o Godot 4.6.3 headless quando stdin vinha de pipe/EOF (`ERROR: Failed to open 'user://logs/...'; signal 11`). Isso quebrou a simulação do hook Codex, que recebe JSON por stdin. Corrigido no harness: comandos Godot headless do `Makefile` agora rodam com `XDG_DATA_HOME=$(GODOT_USER_DATA_DIR)` (default `/tmp/caipora-godot-data`), isolando `user://` de logs/saves do usuário e mantendo `FileAccess.WRITE` funcional; o hook consome JSON e roda `make gate` com stdin fechado. |
| KI-021 | Baixa | Aberta | Detecção de "telefone" por `minf(vp) < Constants.PHONE_SHORT_SIDE_MAX` (640) é **código morto em retrato**: o stretch é `canvas_items`/`expand` com base 750×1334, então `get_visible_rect()` devolve unidades de canvas e o lado curto em retrato é sempre ~750 (medido: janela 393×852 → vp `(750, 1625)`), nunca `< 640`. Consequência: `Constants.particle_amount_scale()` NUNCA corta partículas pela metade no telefone em retrato (o corte de perf da Fase 10 não acontece onde mais importa). O HUD premium (2026-06) contornou usando `is_portrait(vp)` (ratio-invariante) em vez do limiar de px. Fix sugerido: basear o gatilho de telefone em px físicos (`DisplayServer.window_get_size()`/`PixelScale.device_scale`), não no `vp` de canvas. |

---

## 12. Diretrizes de Assets

- **Sprites:** pixel art autoral procedural (preferido), pack CC0 recolorido, ou **IA com pipeline de limpeza obrigatório** (paleta/grid/alpha). Escada de tamanhos: tiles/itens 32×32; bosses legados 48×48 (até redesign); Caipora 96×96; invasores comuns 112×112 (+ variante de mapa 56×56). .png, fundo transparente. Detalhes em `assets/AGENTS.md`.
- **Áudio:** Identidade sonora própria (maracatu / Amazônia / folk-horror), sintetizada proceduralmente em `scripts/tools/gen_sfx.py` (stdlib, reproduzível). Direção canônica: [docs/PRD-audio-v3.md](docs/PRD-audio-v3.md); norte de referência Ocarina: [docs/PRD-audio-v3-1-ocarina.md](docs/PRD-audio-v3-1-ocarina.md); execução: [docs/PLAN-audio-v3-1-execucao.md](docs/PLAN-audio-v3-1-execucao.md). Camadas:
  - **SFX de combate** (`assets/audio/sfx/`): .wav curtos, punchy, under 100KB cada, 3 variantes por som (round-robin no `SfxSystem`).
  - **Ambiência** (`assets/audio/ambience/`): loops por tela — floresta amazônica (exploração/hub), dread (arena).
  - **Maracatu adaptativo** (`assets/audio/music/`): stems sincronizados (alfaia/ganzá/agogô); agogô só entra no boss.
  - **Stingers** (`assets/audio/stingers/`): entrada de arena, vitória, game-over, baú.
  - Arquitetura: bus layout `Master→SFX/Music/Ambience` (`default_bus_layout.tres`), autoload `AudioDirector` (volume persistido em `user://settings.cfg`, ducking, cross-fade por tela, unlock de autoplay HTML5), overlay de Opções com sliders. **A regra "sem música no MVP" foi superada pós-MVP.**
- **UI:** Usar nós nativos do Godot (`Button`, `Panel`, `Label`, `ProgressBar`). Sem sprite sheets customizadas para UI.
- **Fontes:** Uma fonte pixelada com licença permissiva (ex: Kenney Fonts ou "Press Start 2P").
- **Licenças:** Copiar a licença de cada pack de assets para `assets/licenses/`.

### Paleta de Horror Folclórico Brasileiro

| Uso | Cor | Hex |
|-----|-----|-----|
| Fundo / Noite | Preto azulado | `#0d1117` |
| Terra / Trilha | Marrom avermelhado | `#3d1f1f` |
| Folhagem / Musgo | Verde podre | `#1a2f1a` |
| Sangue / Dano | Vermelho vivo | `#8b0000` |
| Destaque / Cue | Âmbar / Fogo | `#ff6b00` |
| Texto | Branco sujo | `#c9d1d9` |

---

## 13. Notas

- **Browser-first:** Evite shaders pesados, texturas grandes, física complexa. Teste tempo de load frequentemente.
- **Janelas de timing:** Comece generoso (12 frames), ajuste baseado no feel do playtest.
- **Feedback é rei:** Cada ação deve ser satisfatória. Priorize juice sobre conteúdo.
- **Save often:** Use commits do git como checkpoints. O agente deve commitar após cada task bem-sucedida.
- **Tom:** Nunca suavize o horror. A floresta é hostil. A Caipora é perigosa. O sangue é real.

### 13.1 Moves nomeados (modelo Pokémon)

Cada sequência de ataque (24 inimigas + golpes da Caipora) tem **nome, som e VFX
próprios**. Catálogo/fonte única: `docs/PRD-moves-nomeados.md`. A identidade aparece
1x por turno (tag sutil de nome + som + VFX), **sem** banner central — a leitura do
golpe vem do som/visual, não de texto, preservando o combate reativo (estilo
Expedition 33). Detalhes do seam: gotcha #17 do `AGENTS.md`.
