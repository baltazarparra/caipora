# Conceito — O Cortejo dos Encantados (Golpe Perfeito)

> Sistema de combate novo. Um **terceiro tipo de ataque** da Caipora, somado ao
> tap de crítico e ao ataque duplo já existentes. Desbloqueado ao libertar o
> primeiro chefe; cresce a cada encantado libertado.
>
> **Status:** REDESENHADO 2× e agora na 3ª forma, VIGENTE = **Golpe Perfeito**
> (2026-06-18). As duas primeiras foram rejeitadas pelo jogador: CARGA (segurar ↑,
> soltar no cheio — ponto invisível) e BATUQUE direcional (tocar ↑→↓← no tempo —
> hostil ao dedão, abstrato, vazio com 1 espírito). A forma vigente é à la
> **Expedition 33/Sekiro**: UMA janela única e apertada (um toque `ui_up`, o mesmo do
> ataque normal — pensado pro **dedão em retrato**); acerto → **BARRAGEM** (todos os
> chefes libertados desabam de uma vez, dano escala com nº deles); erro → whiff +
> **contra-ataque** (custo souls). Lead-in com slow-mo telegrafa o golpe. Disparado
> por roll no turno, MESMA chance do duplo. Referências: Expedition 33, Sekiro,
> The Legend of Dragoon. Pendente: os .wav dedicados (hoje em fallback canônico).
> **NOTA:** as seções 3/6/7 abaixo descrevem as mecânicas ANTIGAS (carga/batuque) e
> estão historicamente desatualizadas; a fonte da mecânica vigente é este cabeçalho.
> Escopo deste doc: mecânica, integração com o sistema vigente, narrativa,
> direção de arte AAA e direção de áudio/música AAA.

---

## 1. A ideia em uma frase

A Caipora não mata os chefes P1–P4 — ela os **liberta** (Santuário dos
Encantados). De vez em quando, no calor da luta, ela pode **convocar** os
espíritos que já soltou: segura a seta **para cima** para chamar cada um, e o
encantado responde com um golpe. Quantos mais libertados, **mais longa a
corrente do cortejo**.

É a recompensa narrativa do Santuário virando poder mecânico: você sente, na
mão, cada amarra que desfez na floresta.

---

## 2. Por que isto encaixa no jogo (âncoras existentes)

Nada aqui é inventado solto — o sistema cola em estruturas que já existem:

| Âncora existente | Como o Cortejo usa |
|---|---|
| `MetaProgression.freed_bosses` (`FREEABLE_BOSS_PHASES = [1,2,3,4]`) | **É o contador da corrente.** `freed_bosses.size()` = nº de elos (teto natural 4). |
| `free_boss(phase)` chamado em vitória de chefe (`arena_manager.gd`) | Ganhar o ataque acontece "ao libertar o primeiro boss" — sem código novo de unlock. |
| Ataque duplo (`_is_double_attack = randf() < TIMING_DOUBLE_CHANCE`) | **Precedente arquitetural.** O Cortejo é outro "turno especial da Caipora" sorteado no início do turno. |
| Turnos de bolha de timing (`TimingSystem` + `TimingBubble`) | O Cortejo reusa a UI de bolha, mas em modo **carga (hold)** em vez de tap. |
| Jesuíta (P5) não é encantado, nunca entra no Santuário | Coerente: derrotar o chefe FINAL não estende a corrente. Teto é 4, e é 4 de propósito. |
| Cores dos chefes em `Constants` (`COLOR_AURA_MULA`, `COLOR_TELEGRAPH_BOITATA`…) | Cada elo já tem paleta e identidade sonora prontas. |

**Ordem da corrente = ordem das fases libertadas** (`freed_bosses` é mantido
`sort()`ado): o primeiro elo é sempre a **Mula** (P1, o primeiro chefe), depois
**Boitatá** (P2), **Curupira** (P3) e **Saci** (P4). A corrente cresce
*pela frente preservada e uma cauda nova* — o jogador reconhece os elos antigos
e aprende o novo no fim.

---

## 3. Mecânica

### 3.1 Disponibilidade (gatilho)

No início de cada **turno da Caipora** (`_start_caipora_turn`), antes do roll do
ataque duplo:

```
se freed_bosses não está vazio E randf() < CORTEJO_CHANCE:
    → turno vira CORTEJO (corrente de N elos)
senão:
    → fluxo atual (roll de ataque duplo, senão tap normal)
```

- `CORTEJO_CHANCE` proposto: **0.30** (espelha `TIMING_DOUBLE_CHANCE`).
- Cortejo e ataque duplo são **mutuamente exclusivos** no mesmo turno (Cortejo
  tem precedência; se não sair, o duplo ainda rola normalmente).
- `N = mini(freed_bosses.size(), CORTEJO_MAX_LINKS)` com `CORTEJO_MAX_LINKS = 4`.

> Regra de ouro: o Cortejo **só existe depois do primeiro chefe**. Antes disso o
> turno da Caipora é exatamente o de hoje. Zero impacto na Fase 1 pré-Mula.

### 3.2 O elo (anel de carga)

Cada elo é uma **bolha de carga** ancorada acima do inimigo (mesmo ponto da
bolha de ataque atual, `_enemy_head_top_y() - BUBBLE_HEAD_GAP`):

```
segura UP ─────────────► anel preenche em CORTEJO_HOLD_SEC (0.8s)
  anel CHEIO + solta   = GOLPE landa  → 2 hits de dano (✓ elo)
  solta ANTES do cheio = elo perdido  → 0 dano        (✗ elo)
  nunca pressiona      = elo perdido  → 0 dano        (✗ elo, após timeout)
```

- O anel é radial e enche de **0% a 100%** em `CORTEJO_HOLD_SEC = 0.8s`.
- **Janela de tolerância no topo:** soltar entre 100% e `CORTEJO_HOLD_SEC +
  CORTEJO_RELEASE_GRACE` (≈ +0.18s) ainda conta como acerto — segurar
  *de leve a mais* não pune (evita frustração de "soltei 1 frame tarde").
  Segurar **muito** além disso (overcharge) também perde o elo: o espírito
  "escapa" da mão. Isso dá teto à janela e mantém ritmo.
- **Timeout do elo:** se o jogador não começar/concluir a carga em
  `CORTEJO_LINK_TIMEOUT` (≈ 1.6s) o elo é dado como perdido e a corrente avança.
  A corrente **nunca trava** esperando input — é a regra "errar não interrompe".

### 3.3 Encadeamento e a regra "errar não interrompe"

```
ELO 1 (Mula)    → acerto/erro → pequeno beat (CORTEJO_LINK_GAP ≈ 0.22s)
ELO 2 (Boitatá) → acerto/erro → beat
ELO 3 (Curupira)→ acerto/erro → beat
ELO 4 (Saci)    → acerto/erro → FIM da corrente → turno do inimigo
```

- Errar um elo **não** encerra o Cortejo: ele só **não soma o dano daquele elo**
  (o espírito daquele encantado se dissipa sem golpear). O próximo elo abre
  normalmente. Isto é o requisito central do design.
- Cada elo acertado executa o golpe imediatamente (dano aplicado na hora, com
  feedback), para a corrente ter **cadência percussiva** (cada acerto é uma
  batida). Não há "acumula e solta tudo no fim".
- Se o inimigo **morre no meio** da corrente (golpe matador num elo), a corrente
  encerra na hora e cai no fluxo de morte (`_on_actor_died` + killing-blow zoom).
  Os elos restantes não disparam.

### 3.4 Dano

Cada elo acertado = **2 hits** de dano:

```
dano_do_elo = CORTEJO_LINK_HITS (2) × base_attack_damage_da_Caipora
```

- `base_attack_damage` já embute Fúria + CHAMA (`MetaProgression.get_damage_bonus`),
  então a corrente **escala com os upgrades** como qualquer golpe — sem número
  paralelo. Mantém a fonte numérica única do `PRD-economia-v2`.
- Teto: 4 elos × 2 hits = **8 instâncias de dano-base** num turno. É um pico
  alto, mas (a) é um roll de 30%, (b) exige acertar 4 cargas seguidas, e
  (c) só existe no fim do jogo, contra inimigos de HP alto. **A balancear**: se
  ficar dominante, baixar `CORTEJO_CHANCE` ou os dois hits do primeiro elo.
- Cada um dos 2 hits aplica `take_damage` separadamente (dois números de dano,
  duas faíscas) — leitura clara de "bateu duas vezes".

### 3.5 Constantes propostas (`Constants`)

```gdscript
# ─── Cortejo dos Encantados ──────────────────────
const CORTEJO_CHANCE: float = 0.30          # roll no turno da Caipora
const CORTEJO_MAX_LINKS: int = 4            # teto = encantados libertáveis (P1–P4)
const CORTEJO_HOLD_SEC: float = 0.8         # tempo de carga por elo
const CORTEJO_RELEASE_GRACE: float = 0.18   # tolerância no topo do anel
const CORTEJO_LINK_TIMEOUT: float = 1.6     # elo perdido se não concluir
const CORTEJO_LINK_GAP: float = 0.22        # beat entre elos
const CORTEJO_LINK_HITS: int = 2            # hits de dano por elo acertado
```

> Fase NÃO encurta a carga. Diferente das janelas de tap (`timing_window_for_phase`),
> a carga é uma **promessa tátil estável** ("segurei 0.8s e soltei") — encurtá-la
> por fase quebraria a leitura. A dificuldade já vem de encadear N elos.

---

## 4. Integração técnica (mapa para a implementação)

### 4.1 `HoldTimingSystem` (novo, irmão do `TimingSystem`)

O `TimingSystem` atual só lê `is_action_pressed` (tap). A carga precisa de um nó
irmão dedicado — **não** sobrecarregar o `TimingSystem` (regra: uma classe, uma
responsabilidade). Esqueleto conceitual:

```gdscript
class_name HoldTimingSystem
extends Node

signal link_charging(progress: float)   # 0..1 por frame, alimenta o anel
signal link_landed                       # soltou no cheio (dentro da graça)
signal link_missed                       # soltou cedo, overcharge ou timeout

func open_link(action := "ui_up") -> void
func _process(delta) -> void  # acumula carga enquanto a ação está pressionada
func _input(event) -> void    # detecta o release → avalia landed/missed
```

- A carga acumula em `_process` enquanto `Input.is_action_pressed(action)`; o
  release (`is_action_released`) fecha o elo. Timeout via `_process` (relógio do
  elo independente do hold).
- Reusa o `TimingBubble` em um **modo carga** (anel radial preenchendo) — ou um
  `ChargeBubble` derivado. A bolha já sabe se posicionar e respeitar o D-pad
  (`_is_under_dpad`).

### 4.2 `ArenaManager` — o turno do Cortejo

- Em `_start_caipora_turn`: inserir o roll do Cortejo **antes** do
  `_is_double_attack`. Se Cortejo, chamar `_start_cortejo_turn()`.
- `_start_cortejo_turn()` resolve `links := freed_bosses` (ordenado, cortado em 4)
  e dispara os elos em sequência via `await` (um `HoldTimingSystem.open_link` por
  vez), aplicando dano/feedback por elo acertado, beat entre elos, e ao fim
  cai em `_start_enemy_turn()` (ou na morte, se matou no meio).
- Reaproveita tudo do pipeline de golpe atual: `execute_attack`, `take_damage`,
  `is_killing_blow`, `_play_killing_blow_zoom`, `_feedback.*`, `_animator.strike`.
- **Teardown:** `_teardown_combat` precisa fechar o `HoldTimingSystem` e
  desconectar seus sinais (mesma disciplina dos handlers de timing atuais).

### 4.3 Touch (contrato de controles — não quebrar)

- Na arena o D-pad é o diamante de garras (`CombatArrowButton`). **Segurar** a
  garra de CIMA mantém `ui_up` pressionado (o `ControlsHud` já injeta via
  `Input.action_press`/`action_release` em `_on_pressed/_on_released`). Soltar o
  dedo = release. **A carga funciona no touch sem contrato novo** — só é preciso
  garantir que o press/release do wedge UP atravesse limpo enquanto a bolha de
  carga está aberta.
- Haptics: pulso curto (`navigator.vibrate`/`Input.vibrate_handheld`) a cada elo
  **landado**, e um pulso mais forte no último elo da corrente.
- Rodar `/validate-controls` e `/validate-platforms` antes de commitar a
  implementação (mexe em input + arena + timing).

### 4.4 Persistência

Nenhum estado novo de save. O unlock e a contagem derivam de `freed_bosses`, que
já é meta-persistente. O Cortejo "some" num save resetado junto com os libertos —
coerente.

---

## 5. Narrativa & nome

**O Cortejo dos Encantados.** Cada chefe libertado é uma dívida da floresta
quitada — e dívida de encantado se paga em mão. Quando a Caipora ergue a mão
(segura UP), ela **chama** o espírito pelo nome antigo; ele cruza a arena como
uma aparição, golpeia o invasor e se desfaz de volta para o acampamento.

- **1 liberto (Mula):** o galope sem cabeça atravessa o quadro em fogo.
- **2 (+Boitatá):** a serpente de brasa se enrola no inimigo.
- **3 (+Curupira):** os pés-ao-contrário arrancam o chão sob o invasor.
- **4 (+Saci):** o redemoinho de fuligem fecha o cortejo.

Errar um elo é o espírito **hesitando** — ele aparece, mas a Caipora não segurou
o chamado por tempo bastante, e ele se dissolve sem bater. Coerente com o tom: os
encantados são aliados relutantes, não invocações domesticadas. **Sem suavizar o
horror** — cada aparição é gore e hostil, não fofa.

> Microcópia in-game (pop ao desbloquear, após libertar a Mula):
> *"A mata te deve. Ergue a mão — ela responde."*

---

## 6. Direção de Arte AAA

Regra-marca acima de tudo (`.agents/skills/visual-identity/SKILL.md`): **a Caipora
laranja continua sendo a âncora**. Os espíritos são APARIÇÕES translúcidas, em
suas próprias paletas já canônicas — eles entram, golpeiam e somem. Verde segue
mínimo (só Fúria/Curupira); nada compete com a juba.

### 6.1 O anel de carga (a "mão erguida")

- Anel radial em torno do ponto da bolha, nos tons da juba/CHAMA
  (`COLOR_JUBA #ff4500` → `COLOR_CHAMA_HOT #ffb032` no topo), 1px outline escuro,
  preenchimento chapado (sem gradiente suave — pixel art chapada).
- Conforme enche, a **silhueta do próximo encantado** coalesce atrás do anel
  (fantasma em sua cor de aura), ganhando opacidade de 0→~0.8. No cheio, "estala".
- Estados: vazio · enchendo (pulsa no ritmo) · **cheio** (flash + borda viva) ·
  **landado** (anel estoura em faíscas da cor do espírito) · **perdido** (anel
  some em fumaça morta `COLOR_PARTICLE_FAIL`, espírito se dissolve sem bater).

### 6.2 Sprites de aparição por elo (4 conjuntos)

Cada espírito é um **sprite de golpe único** (não um boss completo): pose de
investida + rastro + impacto. Translúcido (≈0.7), aditivo no glow
(`Constants.ADDITIVE_MATERIAL`), 1px outline, leitura forte em 32px. Canvas
sugerido 128×128, alinhado aos contact sheets dos chefes.

| Elo | Espírito | Pose de golpe | Paleta-âncora (já em `Constants`) |
|---|---|---|---|
| 1 | **Mula sem Cabeça** | galope lateral, jato de fogo do toco do pescoço | `COLOR_AURA_MULA`, `COLOR_TELEGRAPH_MULA` |
| 2 | **Boitatá** | serpente de brasa que se enrola no alvo | `COLOR_AURA_BOITATA`, `COLOR_TELEGRAPH_BOITATA_WHITE` |
| 3 | **Curupira** | investida baixa, terra/raízes erguidas, verde-mata | `COLOR_AURA_CURUPIRA`, `COLOR_TELEGRAPH_CURUPIRA` |
| 4 | **Saci** | redemoinho de fuligem em salto de uma perna | `COLOR_AURA_SACI`, `COLOR_TELEGRAPH_SACI` |

- **Proibições** (herdadas da skill): não usar os olhos brancos puros da Caipora
  nas aparições; não usar o laranja exato da juba como cor do espírito (a juba é
  só o anel/a mão da Caipora); manter cada espírito na SUA paleta de chefe.
- Pipeline: gerados por script Python no padrão `gen_bosses.py` (procedural,
  reprodutível, com contact sheet + `*_sprite_frames.tres` + teste de assets em
  `tests/unit/`). Assim a arte fica versionada e testável, como o resto.

### 6.3 VFX da corrente

- **Trilha de cortejo:** ao acertar elos seguidos, um fio de luz liga os pontos
  de impacto (acende a cada acerto, esmaece nos erros) — leitura visual de
  "corrente" se formando.
- **Crescendo de tela:** a vinheta `Atmosphere` escurece levemente as bordas a
  cada elo landado (o mundo encolhe em torno do cortejo); volta no fim.
- **Killing blow dentro da corrente:** reaproveita o zoom + câmera lenta já
  existente (`_play_killing_blow_zoom`, `Engine.time_scale`).

---

## 7. Direção de Áudio & Música AAA

Encaixa no `AudioDirector` (stems de maracatu, stingers, ducking, beat-sync) e no
`SfxSystem`/`FeedbackSystem`. Tudo passa pelo fiscal `make` (`check_audio`,
normalização de loudness).

### 7.1 SFX da carga (por elo)

- **Charge loop:** sopro grave que **sobe de pitch** conforme o anel enche
  (0→0.8s), com um sussurro espectral por baixo (a mata "respondendo"). Corta no
  release.
- **Cheio (armado):** um "trinco" curto no topo do anel (clique de gatilho do
  chamado) — sinal claro de "agora pode soltar".
- **Landado:** **stinger curto e distinto por espírito** (4 variações), reusando
  a identidade sônica de cada chefe — casco/fogo (Mula), assobio de brasa
  (Boitatá), estalo de mata/madeira (Curupira), assovio-redemoinho (Saci). Vivem
  em `assets/audio/stingers/` (alvo de loudness emocional).
- **Perdido:** sopro que se dissolve, sem impacto — o espírito recua. Tom morto,
  sem brilho (parente do `COLOR_PARTICLE_FAIL` no áudio).

### 7.2 Música (stems)

- A corrente **acende o stem `STEM_TOP`** do tema de combate (camada de maracatu
  mais aguda/percussiva) durante o Cortejo, e fade-out ao fim — o cortejo "sobe"
  a música por cima do loop base.
- Cada elo landado dá um **`PERFECT_DUCK`** curto (`PERFECT_DUCK_DB`/`SECS`) — a
  música "respira" a cada batida, deixando o stinger do espírito brilhar.
- Se a corrente fecha com **TODOS os elos acertados** (full chain), um
  **acento de maracatu** marca o feito (uma "virada" no tambor). Erros tiram o
  acento — a recompensa sonora premia o cortejo perfeito.

### 7.3 Mix & haptics

- Ducking de ambiência durante o Cortejo (`DUCK_AMOUNT_DB`), restaurado ao fim.
- Cada stinger de espírito ocupa faixa própria (sem mascarar) — espalhar no
  campo estéreo por elo (Mula esq. → Saci dir., p.ex.) reforça a "passagem" do
  cortejo pela arena.
- Haptics sincronizados aos landados (§4.3).

---

## 8. Casos de borda & decisões fechadas

- **0 chefes libertos:** Cortejo não existe (turno normal). ✔ regra de unlock.
- **1 chefe:** corrente de 1 elo (só a Mula). É o "tutorial" natural do sistema.
- **Erro em todos os elos:** turno "passa em branco" (0 dano), mas **não** é
  punido além disso — o turno do inimigo vem normalmente. Sem dano de retorno.
- **Inimigo morre no elo K<N:** corrente encerra, elos K+1..N não disparam.
- **Fase 5 (chefes-monstro convertidos + Jesuíta):** o Cortejo funciona contra
  eles também (são inimigos comuns/boss roteados normalmente). Narrativamente
  potente: a Caipora vira os próprios libertos contra quem os escravizou.
- **Overcharge (segurar demais):** perde o elo (o espírito escapa). Dá teto à
  janela e evita "segurar eternamente para garantir".
- **Não há custo de recurso** (sem medidor): é um roll, decidido por design.
  O custo é a dificuldade de encadear N cargas.

---

## 9. Plano de implementação (sessões futuras, uma tarefa por sessão)

1. **Núcleo mecânico (headless-testável):** `HoldTimingSystem` + constantes +
   testes GUT (carga, release no cheio, release cedo, overcharge, timeout). Sem
   arte ainda. (Lembrar: `class_name` novo exige `godot --headless --import`
   antes do `make test`.)
2. **Integração no turno:** roll no `_start_caipora_turn`, `_start_cortejo_turn`,
   encadeamento, dano por elo, killing-blow no meio, teardown. `/validate-controls`.
3. **Anel de carga (visual) + touch:** `ChargeBubble`/modo carga do `TimingBubble`,
   wedge UP segurável, haptics, preview tool sob Xvfb. `/validate-platforms`.
4. **Sprites das 4 aparições:** `gen_*` procedural + contact sheets +
   `*_sprite_frames.tres` + testes de assets. (Usar a skill `visual-identity`.)
5. **VFX da corrente:** trilha de cortejo, crescendo de vinheta, integração com
   o killing-blow.
6. **Áudio:** charge loop, stinger por espírito, perdido, stem TOP do combate,
   ducking, full-chain accent, espacialização. (Hooks dormentes até os `.wav`,
   padrão `AudioDirector`.)

---

**Estado da implementação — VIGENTE (Batuque do Cortejo, redesenho 2026-06-17):**

A mecânica de CARGA (itens históricos abaixo) foi APOSENTADA por ilegibilidade.
A versão atual é a **sequência direcional rítmica**:

- **Mecânica:** chamado direcional fixo por fase (`Constants.CORTEJO_CALL_FOR_PHASE`:
  Mula ↑, Boitatá →, Curupira ↓, Saci ←; `cortejo_calls_for()` monta a sequência das
  fases libertadas). Turno = count-in de tambor → uma nota direcional por batida
  (anel convergente via `TimingSystem`+`TimingBubble`, reusando o tap conhecido) →
  acerto invoca a aparição (entra pela direção do chamado) + 2 hits; erro hesita, a
  corrente segue. Sequência perfeita → FEVER (acento de maracatu + último golpe
  crítico). Arquivos: `arena_manager._start_cortejo_turn/_run_cortejo_note`,
  `CortejoBeatTrack` (faixa de leitura), `TimingSystem.cancel_window` (destrava o
  await no teardown).
- **Legibilidade:** nota convergente (metáfora dominada) + metrônomo audível
  (`AudioDirector.play_cortejo_beat`) + faixa de pips com preview da sequência.
- **Aparições/trilha:** `CortejoApparition` (mantido) — o boss libertado retorna como
  espírito translúcido na aura, + fio de luz ligando os impactos.
- **Áudio:** `play_cortejo_beat/link/full_chain` + `set_cortejo_active` (STEM_TOP+duck),
  com fallback canônico. _Pendente:_ .wav dedicados via `gen_sfx.py`.

_Histórico (CARGA, aposentada): 1. `HoldTimingSystem`; 2. integração de elos; 3. anel
`ChargeBubble`; 4–6 aparições/VFX/áudio. Os itens 4–6 foram preservados; 1–3 trocados._

## 10. Pendências a balancear (registrar em PLAN.md ao implementar)

- `CORTEJO_CHANCE` (0.30) vs. dominância do pico de dano.
- `CORTEJO_BEAT_SECS` (~0.62) e a janela perfeita por fase (`CORTEJO_WINDOW_BASE`) —
  calibrar no playtest (direção+tempo é mais difícil que o tap simples).
- Recompensa do FEVER (último golpe crítico) vs. teto de dano (4 chamados × 2 hits,
  o último crítico, escalando com Fúria/CHAMA) contra o HP dos chefes da Fase 5.
- `.wav` dedicados do Cortejo (metrônomo/stingers) via `gen_sfx.py`.
