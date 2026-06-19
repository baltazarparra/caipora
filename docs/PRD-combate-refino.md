# PRD — Refino do Combate: janela de ação justa, padronizada e com feedback rico

> **Status:** Proposta · **Autor:** baltz (com Claude) · **Data:** 2026-06-19
> **Fontes verificadas no código:** `scripts/systems/timing_system.gd`,
> `scripts/arena/arena_manager.gd`, `scripts/ui/timing_bubble.gd`,
> `scripts/utils/constants.gd`, `scripts/systems/sfx_system.gd`,
> `scripts/core/signal_bus.gd`, `scripts/ui/controls_hud.gd`,
> `scripts/systems/feedback_system.gd`, `site/js/sequences_shared.js`.

---

## 1. Contexto e problema

O combate é turn-based com **ações de timing**: a cada golpe do inimigo o jogador aperta a
seta (toque) / Espaço (teclado) no frame certo para **esquivar + contra-atacar**; no próprio
ataque, acerta o frame para **crítico**. A base funciona, mas a **janela de defesa** é
**punitiva demais**:

1. **Resultado binário PERFEITO/ERRO.** Na defesa, um quase-acerto toma **dano cheio** —
   não há crédito parcial. É a maior fonte da sensação de injustiça.
2. **Precisão encolhe com a fase.** A faixa perfeita é uma fração fixa da janela (65–85%),
   então nas fases altas ela encolhe junto com a janela (Fase 5 ≈ 0.14s), e a latência de
   toque/web come parte disso.
3. **Feedback assimétrico.** A recompensa é suculenta (combo, shake, hit-stop, duck), mas a
   falha e a *aproximação* da janela têm pouca leitura multimodal.

**Fatos confirmados no código** (corrigem suposições comuns):
- O anel convergente da bolha já encontra o alvo no **centro** da janela perfeita
  (`timing_bubble.gd:104-113`) → o cue visual já está alinhado. **Mantemos.**
- **Ataque ERRO = whiff (0 dano)** — `_on_attack_timing_result` não chama `take_damage`
  no ramo MISS (`arena_manager.gd:525-533`). (A nota antiga do PLAN.md "dano normal" está
  errada e deve ser corrigida.)
- **Defesa ERRO = dano cheio** (`arena_manager.gd:768-785`) → alvo nº 1 do tier GOOD.
- **Especiais de boss** abrem uma janela por golpe, todas no mesmo handler de defesa.
- **Cortejo** usa hold-mode com zona larga e é binário (intencional) — fica fora do tier.

## 2. Objetivos / Não-objetivos

**Objetivos**
- **O1.** Tornar a defesa **menos punitiva** com um tier intermediário **GOOD** (bloqueio
  parcial) sem trivializar o PERFEITO.
- **O2.** **Padronizar a precisão** entre todas as fases (mesma janela absoluta de acerto);
  só o tempo de **antecipação** muda com a dificuldade.
- **O3.** **Feedback tri-modal coerente** (visual + sonoro + háptico) para 4 momentos: janela
  abre → **aproxima** → **AGORA** (perfeito) → resultado (PERFEITO/GOOD/ERRO).
- **O4.** Aplicar o mesmo modelo a ataque normal, ataque duplo e defesa (normal e especial).

**Não-objetivos**
- Redesenhar o **Cortejo** (hold-to-charge) — permanece como está.
- Mudar a economia/HP/dano base (só revisar pós-feel-test no painel admin).
- Tornar o combate ação em tempo real — segue turn-based com comandos de timing.

## 3. Decisões de design (aprovadas)

| # | Decisão | Detalhe |
|---|---------|---------|
| D1 | **Tier GOOD = bloqueio parcial** | PERFEITO = crítico/contra-ataque + combo↑; **GOOD = bloqueia ~50%, sem contra, NÃO quebra combo**; ERRO = dano cheio. |
| D2 | **Precisão fixa entre fases** | Faixas PERFEITO/GOOD em tempo **absoluto** igual em toda fase; só a **antecipação (lead-in)** encurta. |
| D3 | **Cue de antecipação (Patapon)** | Sinal "prepare → AGORA": pulso/tique na aproximação + pico no instante perfeito. |

## 4. Pesquisa de referência → princípios aplicados

| Jogo | Mecânica-chave | Princípio | Aplicação no caipora |
|------|----------------|-----------|----------------------|
| **The Legend of Dragoon** (Additions) | Caixa que converge sobre um quadro fixo; acertar continua o combo; dificuldade por velocidade/sequência | O **cue visual é o timing**; recompensa **escalonada**; dificuldade não vem de janela invisível | Mantém anel convergente alinhado ao centro + escada de combo; **sobe dificuldade encurtando antecipação, não precisão** (D2) |
| **Clair Obscur: Expedition 33** | Defesa em camadas: dodge (generoso, seguro) vs parry (apertado, contra-ataque total); tell por animação + áudio | **Camadas de sucesso** (seguro vs recompensado) | **GOOD = "dodge" parcial seguro**, PERFEITO = "parry" recompensado (D1); reforça o tell sonoro |
| **Patapon** | Ritmo constante e antecipável; feedback massivo a cada beat | **Antecipação > reação**; multimodalidade | **Cue "prepare → AGORA"** (D3) + **precisão fixa** = um ritmo único aprendido |

> O `docs/PESQUISA-combate-acao.md` aprofunda cada estudo; esta PRD carrega o destilado.

## 5. Modelo proposto — "faixas absolutas sobre a janela existente"

Mantém a **duração total `D`** já calculada por fase (`_defense_window` / ataque normal /
`Constants.timing_window_for_phase`). Só muda **onde** ficam as faixas dentro de `D`, com
meios-spans **absolutos** → precisão constante e **lead-in (`D − banda`) encurta sozinho**
por fase. Vantagem decisiva: **não toca** `action_windows`, `RemotePatterns._sanitize`,
dados remotos salvos nem `sequences_shared.js`.

```
PERFECT_HALF_SPAN := 0.09   # perfeito = ±0.09s (~0.18s de largura)
GOOD_HALF_SPAN    := 0.20   # GOOD = ±0.20s (flanco GOOD ~0.11s de cada lado)
LATE_GRACE        := 0.04   # tolerância só no lado TARDIO (lag de toque/web)
ACTION_TAIL       := 0.06   # rabo de colapso após a banda
MIN_ACTION_DURATION := 0.55 # piso de D p/ a banda absoluta sempre caber
GOOD_BLOCK_MULT   := 0.5    # GOOD na defesa bloqueia ~50% do dano

Constants.band_fractions(duration) -> { perfect_start, perfect_end, good_start, good_end }
  d       = maxf(duration, MIN_ACTION_DURATION)
  center  = d - ACTION_TAIL - GOOD_HALF_SPAN        (clamp p/ caber)
  perfect = [center - PERFECT_HALF, center + PERFECT_HALF + LATE_GRACE]  (÷ d → frações 0..1)
  good    = [center - GOOD_HALF,    center + GOOD_HALF    + LATE_GRACE]  (÷ d → frações 0..1)
```

Régua de resultado (defesa):

```
  ERRO        GOOD     PERFEITO    GOOD       ERRO
 |--------|=========|########|=========|--------|
  dano       bloqueia  crit +    bloqueia   dano
  cheio      ~50%      contra    ~50%       cheio
  combo--    combo ok  combo++   combo ok   combo--
```

**Efeito por fase** (a precisão PERFEITO ±0.09s e GOOD ±0.20s é **igual** em toda fase; só o
lead-in cai conforme `D` encolhe — ex.: F1 lead-in ~0.54s, F5 ~0.24s).

## 6. Requisitos funcionais

- **RF1 (tier).** `TimingSystem` classifica PERFEITO / **GOOD** / ERRO. Default
  `good = perfect` ⇒ chamadas atuais e o **hold/Cortejo permanecem binários**.
- **RF2 (defesa).** GOOD na defesa: dano × `GOOD_BLOCK_MULT`, **sem** contra-ataque, **combo
  preservado**; ERRO e PERFEITO inalterados. Vale por-hit nos especiais de boss.
- **RF3 (ataque).** GOOD no ataque normal/duplo: `execute_attack(false)` (golpe normal — hoje
  o ERRO whiffa), combo preservado; PERFEITO = crítico; ERRO = whiff.
- **RF4 (precisão fixa).** Largura absoluta de PERFEITO/GOOD **constante** entre fases; só o
  lead-in varia (via `D`).
- **RF5 (cue de antecipação).** A bolha emite ao entrar na faixa GOOD (`approach_entered`) e
  no perfeito (`vulnerable_entered`, já existe).
- **RF6 (padronização).** `band_fractions` usado por ataque normal, duplo (1ª/2ª bolha) e
  defesa (normal/especial).

## 7. Matriz de feedback (visual · sonoro · tátil)

| Momento | Visual | Sonoro | Tátil |
|---------|--------|--------|-------|
| Janela abre | bolha + faixa GOOD (âmbar) + alvo perfeito | (nome do golpe 1×/turno) | — |
| **Aproxima** (entra GOOD) | pulso suave no anel | **tique curto** (`AudioDirector`) | tique leve |
| **AGORA** (entra perfeito) | flash verde-cristal (já existe) | `timing_alert` (já existe) | — |
| Resultado PERFEITO | `burst_success` branco + label `perfeito`/`critico` | `Outcome.CRIT/DODGE` + duck −14dB | `HAPTIC_REWARD` [14,36,26] |
| Resultado **GOOD** | **`burst_good` âmbar** + label `bloqueio` | **`Outcome.BLOCK`** (duck leve) | **`HAPTIC_GOOD`** (pulso médio) |
| Resultado ERRO | `burst_fail` vermelho + label `errou` | `Outcome.MISS` | `HAPTIC_FAIL` [26] |

## 8. Implementação por arquivo

- `scripts/utils/constants.gd`: constantes da §5 + `band_fractions()`.
- `scripts/systems/timing_system.gd`: `enum {PERFECT, GOOD, MISS}`; `open_window` +
  `good_start/good_end` (default→perfect); `_in_good_zone`; `_evaluate_timing` com GOOD;
  hold-mode segue binário; duplo engata o 1º hit em PERFEITO ou GOOD.
- `scripts/arena/arena_manager.gd`: usar `band_fractions(window)` em todas as bolhas/janelas
  (ataque `:366-389`, 2ª bolha `:420-426`, duplo `:374-379`, defesa `:741-742`); ramos GOOD
  em `_on_defense_timing_result` (`:745`), `_on_attack_timing_result` (`:497`) e
  `_on_double_final_result` (`:456`); ligar o cue de aproximação. **Cortejo intacto.**
- `scripts/ui/timing_bubble.gd`: `show_bubble` + `good_start/good_end`; desenho da faixa
  GOOD; `burst_good`; `signal approach_entered` em `good_start`.
- `scripts/systems/feedback_system.gd`: `LABEL_PATHS[&"bloqueio"]`; `track_good()` (combo
  neutro — nem incrementa nem zera).
- `scripts/ui/combat_arrow_button.gd`: `flash_good()` (âmbar).
- `scripts/systems/sfx_system.gd`: `Outcome.BLOCK` em `play_outcome`
  (`play_named("combat_block")` + fallback, duck leve).
- `scripts/core/audio_director.gd`: tique de aproximação (reusa `play_dpad_tap`).
- `scripts/core/signal_bus.gd`: `defense_result_good`, `attack_result_good`,
  `combat_approach_cue`.
- `scripts/ui/controls_hud.gd`: `HAPTIC_GOOD` + `_pulse_good_haptic`; tique de aproximação.

## 9. Parâmetros de tuning (defaults, ajustáveis)

`PERFECT_HALF_SPAN 0.09` · `GOOD_HALF_SPAN 0.20` · `LATE_GRACE 0.04` · `ACTION_TAIL 0.06` ·
`MIN_ACTION_DURATION 0.55` · `GOOD_BLOCK_MULT 0.5`. (`D` continua remoto via painel sem
mudança de semântica.)

## 10. Plano de teste

- `tests/unit/test_timing_system.gd`: atuais seguem válidos (good=perfect); **novos**: GOOD
  na faixa intermediária; perfeito; ERRO fora; `LATE_GRACE` só no lado tardio; hold nunca
  emite GOOD.
- `tests/unit/test_action_window.gd` (novo): `band_fractions` → largura perfect/good
  **constante** entre durações; faixas em [0,1]; `MIN_ACTION_DURATION` aplicado.
- `tests/unit/test_timing_bubble.gd`: faixa GOOD renderiza; `burst_good`; `approach_entered`.
- `tests/unit/test_sfx_variants.gd`: `Outcome.BLOCK` resolve `combat_block`.
- Gotcha #12: `godot --headless --import` antes de `make test`; conferir que a contagem subiu.

**Verificação manual:** `make gate`; `/validate-controls` (defesa verde=PERFEITO,
âmbar=GOOD bloqueia 50% sem contra/combo mantém, fora=ERRO; teclado + toque; especial
por-hit; Cortejo intacto); `/validate-platforms` (retrato/paisagem, cue/GOOD não colidem com
o D-pad); `preview_combat_dpad.gd`; jogar Fase 1 e 4/5 (precisão "sente igual"; near-miss
bloqueia).

## 11. Rollout / faseamento

- **PR 1 (mecânica):** `band_fractions` + tier GOOD + testes + `docs/PESQUISA-combate-acao.md`.
- **PR 2 (juice):** cue de antecipação + assets (`result_bloqueio.png`) + SFX
  (`combat_block`) + háptico distinto + gotcha no `AGENTS.md` + correção da nota no `PLAN.md`.

## 12. Riscos

- **Assets pendentes** (`result_bloqueio.png`, `combat_block.wav`): fallback de texto/som já
  previsto, não bloqueia o merge da mecânica.
- **Balanceamento:** GOOD ~50% baixa a pressão de dano → revisar HP/dano no `admin.html`
  após o feel-test.
- **Nenhum `.tscn` é tocado** (tudo em código) — evita o gotcha #7.

## 13. Questões em aberto

- **Q1.** GOOD deve **renovar** o timer de idle do combo ou ser totalmente neutro?
  (default: preserva sem renovar.)
- **Q2.** Cor da faixa GOOD: âmbar (`COLOR_AMBER`) vs azul-claro — decidir no preview visual.
- **Q3.** Exibir os spans absolutos no painel `sequences.html` (informativo)? — adiável.
