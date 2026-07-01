# PRD — O Chamado do Cortejo (Golpe especial em SEGURAR → SOLTAR)

> **Status:** PROPOSTA (2026-07-01). 4ª forma do golpe especial "Cortejo dos
> Encantados". Substitui a forma vigente "Golpe Perfeito" (toque único em `ui_up`,
> idêntica ao ataque normal).
>
> **Escopo:** redefinir a MECÂNICA do golpe especial para ter gramática própria
> (segurar → soltar, com o momento do release influenciando o dano), com FEEDBACK
> VISUAL PREMIUM que torne o alvo do release inequívoco, e REFATORAR 100% a tela de
> explicação pós-boss.
>
> **Fonte da mecânica vigente até aqui:** cabeçalho de
> `docs/CONCEITO-corrente-encantados.md` + gotcha #18 do `AGENTS.md`. Este PRD
> **supera** ambos — ver §8 (Reconciliação de docs/harness).

---

## 1. Problema

O golpe especial já foi redesenhado 3× e a forma atual, embora legível, é fraca
**porque não tem mecânica própria**:

- Hoje o "Golpe Perfeito" é **um toque `ui_up` numa janela** — o **mesmo verbo do
  ataque normal** (`arena_manager.gd:_start_cortejo_turn`, l.638–674). O único
  diferencial é o desfecho (barragem × contra-ataque). Na mão, não *sente* como um
  golpe especial: é um tap a mais.
- É um golpe que **escala no late game** (a barragem cresce com `freed_bosses`:
  1→4 espíritos, `Constants.cortejo_spirits_for`) e é a **recompensa narrativa do
  Santuário**. Um golpe com esse peso precisa de uma gramática de input que o
  distinga — hoje ele não tem.
- A tela de explicação pós-boss (`cortejo_unlock_screen.gd`) está ruim: painel
  "Mega Man Weapon Get" com uma demo passiva que **só repete um tap**. Não ensina
  nada que o jogador não faça no combate comum, e agora ensinará a coisa errada.

**Decisão de produto:** o golpe especial passa a ser **SEGURAR → SOLTAR na hora
certa**, com o momento do release definindo o tier de dano. Simples de explicar,
premium de ver, e finalmente com identidade mecânica própria.

---

## 2. Diagnóstico — por que a CARGA falhou antes, e por que agora é diferente

A 1ª forma do golpe (2026, "Golpe Carregado") **também** era segurar→soltar e foi
**rejeitada pelo jogador**. Registrado em KI-018 e no CONCEITO:

> *"A 1ª versão usava CARGA (segurar ↑, soltar no cheio): **ponto de soltar
> invisível** + **segunda metáfora de timing** → o jogador não entendia o tempo."*

As duas causas-raiz — e como este PRD as elimina:

| Causa da falha antiga | Correção neste PRD |
|---|---|
| **Alvo do release invisível** (soltar "no cheio", sem marca) | O alvo é uma **banda dourada DESENHADA e pulsante** ("SOLTE!") no medidor, larga o bastante para perdoar, com **cue sonoro + háptico** ao entrar nela. O jogador vê, ouve e sente o momento. |
| **Binário** (cheio = acerto, resto = 0) — sem tolerância | Reusa o modelo **3-tier** já ensinado no combate (PERFEITO / GOOD / ERRO): soltar na banda = FEVER; soltar no "ombro" GOOD = barragem normal; cedo demais = fraco; segurar demais = QUEIMA (contra-ataque). |
| **Segunda metáfora de timing abstrata** | O vocabulário do desfecho é **idêntico ao do combate normal** (PERFEITO/GOOD/ERRO, gotcha #19). O ÚNICO conceito novo é o verbo **SEGURAR** em vez de **TOCAR** — e a tela pós-boss ensina isso interativamente (§6). |
| Escala pobre com 1 espírito | Os espíritos **materializam um a um** enquanto o medidor enche — o jogador **vê** a corrente crescer. No late game o medidor fica visivelmente mais "povoado"; a recompensa escala aos olhos, não só no número. |

**Ativo recuperado (barateia a execução):** o `TimingBubble` **ainda tem o modo
carga inteiro e bom** — `show_bubble(..., charge: bool, ...)`, `_process_charge`,
`_draw_charge`, `_draw_charge_glyph(progress, in_release, overcharge, flick)`:
medidor de fogo radial, **banda "SOLTE!" em `COLOR_CHAMA_HOT` desenhada**, arco de
overcharge em `COLOR_BLOOD`, anel pulsante de release, glifo-garra enchendo de
baixo pra cima. O `SignalBus` guarda `cortejo_charge_opened/closed`. Só o nó de
input `HoldTimingSystem` foi deletado (última versão em `b04ace3^`). **O primitivo
visual do release já existe e já resolve o pecado antigo** — falta ligá-lo de volta
e elevá-lo a "premium".

---

## 3. A mecânica — "O Chamado"

> **Uma frase (o pitch de ensino):** *Ergue a mão e SEGURA para reunir o cortejo —
> os espíritos que você libertou vêm chegando um a um. SOLTA na zona dourada para
> desabar todos de uma vez. Segura demais e eles escapam da tua mão.*

### 3.1 Gatilho (inalterado)

No início do turno da Caipora, antes do roll do ataque duplo:

```
se freed_bosses não vazio E randf() < CORTEJO_CHANCE (0.30):
    → turno vira O CHAMADO
```

- Precedência sobre o ataque duplo; mutuamente exclusivos no turno.
- `N = min(freed_bosses.size(), CORTEJO_MAX_LINKS=4)` espíritos na barragem.
- Só existe depois do 1º chefe libertado. Zero impacto pré-Mula.

### 3.2 O input: SEGURAR `ui_up`

- **Mesma tecla/garra do ataque normal** (`ui_up` / wedge de CIMA do diamante de
  garras), pensada pro dedão em retrato. O jogador **segura** em vez de tocar.
- No touch, segurar a garra de CIMA mantém `ui_up` pressionado
  (`ControlsHud._on_pressed/_on_released` já injeta `Input.action_press/release`);
  soltar o dedo = release. **Sem contrato de input novo** — só é preciso garantir
  que o press/release do wedge UP atravesse limpo com o medidor aberto
  (`/validate-controls`).

### 3.3 O medidor (a "mão erguida")

Um medidor radial ancorado acima do inimigo (mesmo ponto da bolha de ataque,
`_enemy_head_top_y() - BUBBLE_HEAD_GAP`) que **enche de 0→100% em
`CHAMADO_CHARGE_SEC`** enquanto `ui_up` está pressionado:

```
0% ───────────── ombro GOOD ──[ BANDA DOURADA "SOLTE!" ]── QUEIMA (overcharge) ──► 100%
     (fraco)        (barragem)     (FEVER: barragem+crit)     (espíritos escapam)
```

- Enquanto enche, os **N espíritos libertados coalescem um a um** em marcas
  (notches) ao longo do arco — leitura visível da corrente crescendo. No late game
  o arco fica visivelmente mais povoado.
- Perto do topo há a **banda dourada "SOLTE!"** (`COLOR_CHAMA_HOT`), pulsante,
  **larga o bastante para perdoar** (o pecado antigo era mira apertada). Antes dela,
  um **ombro GOOD** em âmbar (`COLOR_GOOD`).
- Passando a banda → **QUEIMA / overcharge**: o arco vira vermelho-sangue
  (`COLOR_BLOOD`), os espíritos recuam e trincam — **penhasco visível**. Não dá para
  "segurar eternamente para garantir".

### 3.4 O release → tiers de dano (reusa PERFEITO / GOOD / ERRO)

O **momento do release** define o tier, exatamente no vocabulário que o jogador já
aprendeu no combate (gotcha #19):

| Solta em… | Tier | Efeito |
|---|---|---|
| **Banda dourada** (`CHAMADO_RELEASE_START..END`) | **PERFEITO → FEVER** | Barragem COMPLETA dos N espíritos + **último crita** (florição) + clímax de tela (zoom/flash/acento). Dano máximo. |
| **Ombro GOOD** (logo antes da banda) | **GOOD** | Barragem COMPLETA dos N espíritos, **sem** florição de crítico. Dano padrão da corrente. |
| **Cedo demais** (antes do ombro) | **FRACO** | O chamado hesita: **barragem parcial** — só `k` espíritos vêm (`k` proporcional à fração carregada, mín. 1). **Sem** contra-ataque (foi cautela, não exposição). |
| **QUEIMA** (segurou além da banda) | **ERRO** | Os espíritos escapam da mão → a Caipora se expõe → **contra-ataque do inimigo** (custo souls, fórmula canônica `_enemy_counter_damage()`). |

**Escala de late-game preservada e amplificada:**
- A barragem PERFEITO/GOOD já escala com `freed_bosses` (1→4 espíritos) — a força de
  late-game é automática, como hoje.
- O FEVER multiplica **por cima** (crítico no último elo). Late-game + release
  perfeito = o grande pagamento; early-game (1 espírito) é modesto de propósito.
- **Fonte numérica única** mantida: o dano por hit segue `Constants.CORTEJO_HIT_DAMAGE`
  / a fórmula da barragem atual (`_apply_cortejo_hits`) — sem número paralelo.

### 3.5 Por que agora é um golpe ESPECIAL de verdade

- **Verbo distinto:** SEGURAR (não TOCAR). Gramática própria na mão.
- **Alvo móvel + penhasco de queima:** decisão de risco a cada uso ("solto agora
  no ouro ou arrisco mais um instante?") — o tap normal não tem isso.
- **Escala visível:** os espíritos entram um a um; o medidor conta a história do
  Santuário na tela.
- **Sem vocabulário novo:** o desfecho é PERFEITO/GOOD/ERRO — o jogador já sabe ler.

### 3.6 Constantes propostas (`Constants`) — substituem as de janela única

```gdscript
# ─── O Chamado do Cortejo (SEGURAR → SOLTAR) ───────
const CORTEJO_CHANCE: float = TIMING_DOUBLE_CHANCE   # 0.30 (inalterado)
const CORTEJO_MAX_LINKS: int = 4                     # teto = encantados P1–P4 (inalterado)

# Carga: duração até 100% (fase NÃO encurta — a carga é promessa tátil estável;
# a dificuldade vem de acertar o release, não de encher mais rápido).
const CHAMADO_CHARGE_SEC: float = 1.10               # 0→100% segurando ui_up
const CHAMADO_GOOD_START: float = 0.66               # fração: início do ombro GOOD
const CHAMADO_RELEASE_START: float = 0.80            # fração: início da banda dourada
const CHAMADO_RELEASE_END: float = 0.94              # fração: fim da banda (largura ~0.14 = perdão)
# > CHAMADO_RELEASE_END → QUEIMA (overcharge). Timeout (não soltar nunca) = QUEIMA.

# Barragem / dano: REUSAR os já existentes (sem número paralelo).
const CORTEJO_LINK_HITS: int = 2                     # hits por espírito (inalterado)
const CORTEJO_HIT_DAMAGE: float = 1.0                # dano fixo por hit (inalterado)
const CORTEJO_MISS_COUNTER_MULT: float = 1.0         # contra-ataque na QUEIMA (inalterado)
```

> **Aposentar na Etapa 3** (quando os call sites mudarem — não antes, senão o build
> quebra): `CORTEJO_PERFECT_START/END`, `CORTEJO_WINDOW_BASE/FLOOR`,
> `cortejo_window_for_phase()` (eram da janela-única de tap). O medidor usa frações
> absolutas de `CHAMADO_CHARGE_SEC`, não `timing_window_for_phase`.

---

## 4. Feedback visual premium (o coração do PRD)

Regra-marca acima de tudo (`.agents/skills/visual-identity/SKILL.md`): a Caipora
laranja é a âncora; os espíritos são aparições nas suas próprias paletas; verde
mínimo. Pixel-art chapada, 1px outline, sem gradiente suave.

### 4.1 O medidor (eleva o `_draw_charge` existente a "premium")

Base já pronta (`timing_bubble.gd:267–333`), a elevar:

1. **Notches de espírito.** Ao longo do arco, N marcas nas cores de aura dos chefes
   libertados (`COLOR_AURA_MULA/BOITATA/CURUPIRA/SACI`). Conforme a carga cruza cada
   notch, a **silhueta do espírito coalesce atrás do medidor** (opacidade 0→~0.8),
   "estala" ao completar. Reusa `CortejoApparition` (mantido) para os fantasmas.
2. **Banda dourada inequívoca.** A banda "SOLTE!" já é desenhada
   (`COLOR_CHAMA_HOT`, arco + anel pulsante). Elevar: **flash de entrada** na banda
   + o texto/cue "SOLTE!" (reusa `TimingBubble.vulnerable_entered` → `timing_alert`).
3. **Penhasco de QUEIMA.** O overcharge já vira `COLOR_BLOOD`; elevar com **trinco
   visual** (o medidor "racha", os espíritos recuam) para o penhasco ser óbvio.
4. **Estados legíveis:** vazio · enchendo (cintila no ritmo) · ombro GOOD (âmbar) ·
   **banda (dourado vivo + "SOLTE!")** · soltou-PERFEITO (estoura em faíscas
   douradas) · soltou-GOOD (estoura âmbar) · soltou-FRACO (fumaça morta
   `COLOR_PARTICLE_FAIL`) · QUEIMA (espíritos se dissolvem trincando).

### 4.2 A barragem (clímax — reusa o pipeline atual)

Inalterado do que já funciona (`_cortejo_barrage`, `_apply_cortejo_hits`): cada
espírito investe (`CortejoApparition.strike`), 2 hits, escada de hit-stop/shake
crescente, florição no último; killing-blow no meio reusa
`_play_killing_blow_zoom`; a morte pelo Cortejo dispara o esquartejamento espectral
(`_killed_by_cortejo` → `spawn_cortejo_finisher_vfx`). **FEVER** (release perfeito)
liga a florição do último elo; **GOOD** desliga a florição.

### 4.3 VFX da corrente (mantidos/reusados)

- Fio de luz ligando os pontos de impacto (a "corrente" se formando).
- Vinheta `Atmosphere` escurece de leve a cada elo (mundo encolhe no cortejo);
  volta no fim.
- `spawn_move_name` (tag sutil, estilo Expedition 33) no lead-in — sem banner
  central (decisão do PRD-moves-nomeados / gotcha #17).

---

## 5. Áudio & haptics

Encaixa no `AudioDirector` (já tem os hooks do Cortejo) + `SfxSystem`/`FeedbackSystem`.
Novo SFX entra **SEMPRE no fim** de `GENERATORS` em `gen_sfx.py` (seed por variante —
inserir no meio muda os bytes seguintes; regra do `.claude/rules/combat-timing.md`).

### 5.1 A carga (o release audível — anti-pecado-antigo)

- **Charge loop:** sopro grave que **sobe de pitch** conforme o medidor enche
  (0→banda), sussurro espectral por baixo (a mata respondendo). Corta no release.
  Ligar em `cortejo_charge_opened` (SignalBus, dormente).
- **Entrada na banda ("armado"):** um **"trinco" curto e claro** — o ouvido também
  diz "AGORA". Reusa `AudioDirector.play_approach_tick` (padrão Patapon do combate)
  disparado por `TimingBubble.vulnerable_entered`.
- **QUEIMA:** sopro que se dissolve, tom morto (`play_cortejo_miss` já existe).

### 5.2 Desfecho (hooks já existem)

- PERFEITO/GOOD: `play_cortejo_summon` (lead-in) → `play_cortejo_link` por espírito
  → `play_cortejo_full_chain` (acento de maracatu) no FEVER completo.
- `set_cortejo_active(true/false)` acende o `STEM_TOP` (camada percussiva aguda)
  durante o Chamado. Tudo já wired; falta só os `.wav` dedicados (hoje fallback).

### 5.3 Haptics (`ControlsHud`)

- Pulso leve ao **entrar na banda** (`cortejo_charge_opened`/`vulnerable_entered` →
  háptico de antecipação, padrão `_pulse_good_haptic`).
- Pulso forte no **release PERFEITO** (`attack_result_perfect`, já existe).
- Buzz curto na **QUEIMA** (`attack_result_miss`, já existe).

---

## 6. Refatoração 100% da tela pós-boss (`cortejo_unlock_screen.gd`)

A tela atual (split "Mega Man" + demo passiva de tap) some. Nova filosofia:
**mostrar, não contar** — e ensinar o VERBO novo (segurar→soltar) de forma que o
jogador **faça** uma vez.

### 6.1 Primeira liberação (após a Mula, P1) — teach interativo

Sequência premium, curta:

1. **Revelação:** a Mula libertada surge como espírito (aura), tag "O CORTEJO DOS
   ENCANTADOS", microcópia narrativa: *"A mata te deve. Ergue a mão — ela responde."*
2. **Demonstração (ghost hand):** o medidor abre sozinho, uma **mão-fantasma**
   segura, o arco enche, o espírito coalesce, e no **ouro** solta → FEVER (flash).
   Repete 1×, agora com legenda: **"SEGURA ↑ · SOLTA no ouro"**.
3. **Sua vez (uma rep real):** o medidor reabre e **entrega o controle ao jogador**
   ("SEGURA agora…"). Acerto na banda = celebração e avança. **Nunca prende:**
   após 2 tentativas OU `~6s`, auto-passa com uma dica ("no combate, solte no
   dourado"). É tutorial, não portão.

### 6.2 Liberações seguintes (P2–P4) — celebração incremental

Sem re-ensinar. Curto: **"+1 ESPÍRITO NO CORTEJO"**, a nova silhueta (Boitatá /
Curupira / Saci) **entra na corrente** (o contador de notches cresce de N-1→N),
acento sonoro, e sai. 2–3s, skdppável.

### 6.3 Copy (i18n — reescrever `cortejo.unlock.*`)

Substituir as chaves em `lang_pt.gd`/`lang_en.gd` (contrato travado por
`test_i18n_parity`):

```
cortejo.unlock.title          "O CORTEJO DOS ENCANTADOS"
cortejo.unlock.teach.verb     "SEGURA ↑ para chamar o cortejo"
cortejo.unlock.teach.release  "SOLTA na zona dourada — todos desabam de uma vez"
cortejo.unlock.teach.risk     "Segura demais e os espíritos escapam"
cortejo.unlock.teach.try      "Tua vez: SEGURA agora"
cortejo.unlock.grow           "+1 ESPÍRITO NO CORTEJO"      # P2–P4
cortejo.unlock.narrative      "A mata te deve. Ergue a mão — ela responde."
cortejo.unlock.hint           "pressione para continuar"
```

> Aposentar `cortejo.unlock.subtitle.first/hit`, `desc.first/hit`, `demo` (eram do
> tap). Atualizar `test_i18n_parity` + `test_cortejo_finisher_sprite_assets` se
> referenciam chaves antigas.

---

## 7. Integração técnica (mapa de implementação)

### 7.1 `HoldTimingSystem` (reconstruir — irmão do `TimingSystem`)

O `TimingSystem` só lê tap (`is_action_pressed` num frame). A carga precisa de um nó
dedicado (uma classe, uma responsabilidade). Última versão em `b04ace3^` — usar como
referência, mas alinhar ao modelo 3-tier deste PRD:

```gdscript
class_name HoldTimingSystem
extends Node

signal charge_progress(progress: float)   # 0..1 por frame (alimenta o medidor)
signal charge_released(tier: int)          # PERFEITO / GOOD / FRACO / QUEIMA

func open_charge(action := "ui_up", charge_sec := CHAMADO_CHARGE_SEC,
    good_start := ..., release_start := ..., release_end := ...) -> void
func cancel_charge() -> void               # teardown destrava o await pendente
```

- Acumula em `_process` enquanto `Input.is_action_pressed(action)`; o release
  (`is_action_released`) fecha e avalia o tier pela fração do progresso. Timeout
  (progresso 100% sem soltar) = QUEIMA.
- Emite `charge_progress` para o `TimingBubble` (modo carga) e `charge_released`
  com o tier para o `ArenaManager`.

### 7.2 `TimingBubble` (elevar o modo carga já existente)

- Já tem `show_bubble(..., charge=true, ...)`, `_draw_charge`, overcharge, banda.
  Adicionar: notches de espírito (§4.1), flash de entrada na banda, ombro GOOD
  visível, faíscas por tier no burst (`burst_success`/`burst_good`/`burst_fail`).
- `vulnerable_entered` (já emitido ao entrar em `[perfect_start, perfect_end]`) vira
  o cue "SOLTE!" — mapear `perfect_start/end` = `RELEASE_START/END`.

### 7.3 `ArenaManager._start_cortejo_turn` (reescrever o miolo)

Trocar a janela-única de tap por:

```
lead-in (slow-mo, já existe) →
open_charge(ui_up, CHAMADO_*) + timing_bubble.show_bubble(..., charge=true, ...) →
tier := await hold_timing.charge_released →
match tier:
    PERFEITO → _cortejo_barrage(spirits, pos, fever=true)   # florição no último
    GOOD     → _cortejo_barrage(spirits, pos, fever=false)  # sem florição
    FRACO    → _cortejo_barrage(spirits.slice(0, k), fever=false)  # k = espíritos parciais (mín. 1)
    QUEIMA   → _cortejo_whiff(pos)                          # contra-ataque (já existe)
→ _end_cortejo() → _start_enemy_turn()
```

- Reusar íntegros: `_cortejo_lead_in`, `_cortejo_barrage`, `_apply_cortejo_hits`,
  `_cortejo_whiff`, `_enemy_counter_damage`, `_end_cortejo`, `_killed_by_cortejo`.
- `_cortejo_barrage` ganha param `fever: bool` (liga/desliga a florição do último
  elo). Hoje ele sempre crita o último — passa a depender do tier.

### 7.4 Teardown (`_teardown_combat`) e touch

- Fechar o `HoldTimingSystem` (`cancel_charge`) e desconectar sinais — mesma
  disciplina do `TimingSystem.cancel_window` atual (l.1100–1108). Restaurar
  `Engine.time_scale` e `set_cortejo_active(false)`.
- Touch: garantir press/release limpo do wedge UP com o medidor aberto; emitir
  `cortejo_charge_opened(action, duration)` (SignalBus, dormente) para o `ControlsHud`
  gerenciar háptico/estado do D-pad enquanto segura. Reativar `cortejo_charge_closed`
  no release/teardown.

---

## 8. Reconciliação de docs/harness (OBRIGATÓRIO — gotcha #21)

Instruções duráveis que **proíbem** hold hoje e conflitam com este PRD. Ao
implementar, atualizar ANTES de codar o comportamento:

1. **`AGENTS.md` gotcha #18** — hoje: *"O Cortejo antigo de SEGURAR→SOLTAR foi
   aposentado… Não reintroduza hold, carga…"*. **Reescrever** para descrever o
   Chamado (segurar→soltar 3-tier com banda desenhada). Sem isso, o próximo agente
   segue a instrução velha ao pé da letra e regride.
2. **`.claude/rules/combat-timing.md`** — hoje: *"o golpe carregado em HOLD continua
   binário (PERFEITO/MISS)"*. **Atualizar** para 3-tier + QUEIMA.
3. **`docs/CONCEITO-corrente-encantados.md`** — cabeçalho aponta a 3ª forma como
   vigente. **Atualizar** para a 4ª (este PRD é a fonte da mecânica).
4. **`gen_sfx.py`** — se entrar `.wav` dedicado (charge loop, trinco, queima), no
   FIM de `GENERATORS`; `check_audio.py` exige RMS [-12,-9].

---

## 9. Balanceamento & números (a calibrar em playtest)

- `CHAMADO_CHARGE_SEC = 1.10` — longo o bastante para ler o arco encher e os
  espíritos entrarem; curto o bastante para não arrastar o turno.
- Banda de release largura `~0.14` (de `0.80` a `0.94`) — **generosa de propósito**
  (o pecado antigo era mira apertada). Ombro GOOD de `0.66` a `0.80`.
- **Teto de dano** (inalterado da barragem atual): 4 espíritos × 2 hits = 8
  instâncias de dano-base + florição no FEVER. É pico alto, mas: (a) roll de 30%,
  (b) exige release perfeito, (c) só no late game contra HP alto. Se dominar, baixar
  `CORTEJO_CHANCE` ou os hits do 1º elo — **nunca** subir `CORTEJO_HIT_DAMAGE` (quebra
  a fonte única do PRD-economia-v2).
- **FRACO = barragem parcial** (travado, §12): `k` espíritos proporcional à fração
  carregada no release, mínimo 1 — recompensa "quase certo cedo" sem zerar o turno.
- **RemoteConfig:** hoje o balanceamento remoto (`enemy_stats`, `attack_patterns`)
  não cobre o Cortejo. Fora de escopo — as constantes ficam baked. Se quisermos tunar
  ao vivo depois, é um follow-up no painel.

---

## 10. Testes (GUT)

- **`test_hold_timing_system.gd` (novo):** progresso acumula segurando; release na
  banda → PERFEITO; no ombro → GOOD; cedo → FRACO; overcharge/timeout → QUEIMA;
  `cancel_charge` destrava o await. (Lembrar: `class_name` novo exige
  `godot --headless --import` antes do `make test`; confira a contagem SUBIR.)
- **`test_cortejo_barrage.gd` (atualizar):** FEVER (PERFEITO) crita o último elo;
  GOOD não; QUEIMA dispara `_enemy_counter_damage`; FRACO aplica barragem parcial/fizzle
  conforme a decisão §12.
- **`test_timing_bubble.gd` (atualizar):** modo carga desenha banda/ombro/overcharge;
  `vulnerable_entered` emite ao entrar na banda; notches = N espíritos.
- **`test_i18n_parity.gd` (atualizar):** novas chaves `cortejo.unlock.*` em pt/en.
- **`test_cortejo_vfx.gd` / `test_cortejo_finisher_sprite_assets.gd`:** manter os
  elos dado↔asset (aparições, finisher).
- Gate: `/validate-controls` (input+arena+timing) + `/validate-platforms` (UI/medidor
  em retrato E paisagem) + `make gate`.

---

## 11. Plano de implementação (uma tarefa por sessão)

1. **Reconciliação de docs (§8) + constantes (§3.6).** Reescreve gotcha #18, rule
   file, cabeçalho do CONCEITO; **adiciona** `CHAMADO_*` e marca as de janela-única
   como `# DEPRECATED (removidas na Etapa 3)` — NÃO remover ainda, pois
   `arena_manager._start_cortejo_turn` ainda as usa (o build quebraria). Sem mudança
   de comportamento. Barato e destrava o resto.
2. **`HoldTimingSystem` (núcleo headless) + testes.** `open_charge`/`charge_released`/
   `cancel_charge`, 3-tier + QUEIMA + timeout. `make import` → `make test`.
3. **Integração no turno.** Reescreve `_start_cortejo_turn` (hold), `_cortejo_barrage`
   ganha `fever`, teardown, touch/SignalBus. `/validate-controls` + `make gate`.
4. **Medidor premium (`TimingBubble`).** Notches de espírito, banda inequívoca, ombro
   GOOD, faíscas por tier, cue "SOLTE!" + háptico. Preview sob Xvfb
   (`preview_combat_dpad.gd` como molde). `/validate-platforms`.
5. **Refatorar a tela pós-boss (§6).** Teach interativo (1ª) + celebração incremental
   (P2–P4) + i18n. `test_i18n_parity`.
6. **Áudio (§5).** `.wav` dedicados (charge loop, trinco, queima) no fim de
   `GENERATORS`; wire nos hooks já existentes; `check_audio.py`; `--import`.

---

## 12. Decisões TRAVADAS (dono do produto, 2026-07-01)

1. **FRACO (soltar cedo demais) = barragem PARCIAL.** `k` espíritos proporcional à
   fração carregada no release (mín. 1), sem contra-ataque. Recompensa "quase certo
   cedo" sem zerar o turno.
2. **QUEIMA = CONTRA-ATAQUE** do inimigo (fórmula canônica `_enemy_counter_damage`).
   Mantém o risco e dá peso à decisão de soltar.
3. **Barragem = SEMPRE todos os N espíritos libertados** (a PERFEITO/GOOD). O release
   define o TIER de dano, não a contagem — a contagem escala com `freed_bosses`.
   (FRACO é a única exceção: parcial por ser cedo.) Simples de explicar.
4. **Tela pós-boss = TEACH INTERATIVO** com uma rep real do jogador (ghost-hand
   demonstra → jogador faz), com rede de segurança (auto-passa em ~6s / 2 tentativas).

---

## 13. Casos de borda

- **0 chefes libertos:** Chamado não existe (turno normal). Regra de unlock intacta.
- **1 chefe:** corrente de 1 elo (Mula) — o "tutorial natural". A banda/queima já
  ensina o release mesmo com 1 espírito.
- **Inimigo morre no elo K<N:** corrente encerra, elos restantes não disparam
  (comportamento atual, `_cortejo_barrage` já checa `is_alive`).
- **Fase 5 (chefes convertidos + Jesuíta):** o Chamado funciona contra todos —
  narrativamente potente (virar os libertos contra quem os escravizou).
- **Combate acaba no meio da carga:** `_teardown_combat` → `cancel_charge` destrava
  o await, restaura `time_scale` e `set_cortejo_active(false)`.
- **Segurar e nunca soltar:** timeout em 100% = QUEIMA (a corrente nunca trava
  esperando input).
```
