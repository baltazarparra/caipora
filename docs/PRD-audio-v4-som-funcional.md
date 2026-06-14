# PRD Audio v4 — Som Funcional (o modelo Pokémon Game Boy)

> caipora — virar o áudio de "camada atmosférica bonita" para **linguagem de estado
> jogável**: o jogador entende onde está, o que mudou e quão perto da morte está,
> **de ouvido**, sem olhar.
> Status: fonte canônica para a próxima rodada de áudio.
> Base técnica: `AudioDirector`, `SfxSystem`, `gen_sfx.py`, `check_audio.py`.
> Antecede: [PRD-audio-v3](PRD-audio-v3.md) (Batuque da Mata) — este não substitui a
> direção estética, **adiciona** a disciplina funcional por cima dela.

---

## Parte A — Como o Pokémon (Game Boy) usa som de forma funcional

Pokémon Vermelho/Azul/Amarelo roda em 4 canais (2 pulse, 1 wave, 1 noise). A
escassez **forçou** uma filosofia: nada de som decorativo — cada som carrega
informação. O jogador aprende um vocabulário e passa a **jogar de ouvido**. Os
princípios funcionais:

### A1. SFX rouba canal da música → "o som sempre vence"
No GB, tocar um efeito silencia um canal da trilha por um instante. A consequência
de design é uma lei: **eventos importantes interrompem o fundo**. O cérebro do
jogador aprende que "se o som cortou a música, algo aconteceu". É ducking nativo,
e ele treina atenção.

### A2. Cada input tem um som 1:1, curto e inconfundível
Mover cursor (blip), confirmar (A), cancelar/voltar (boop grave), rolar texto
(blip por caractere), ação inválida (buzz seco). O jogador **nunca** se pergunta
"registrou?". Num jogo decidido por timing, essa confirmação é parte do controle,
não enfeite.

### A3. Música é identidade de ZONA e de MODO
Cada cidade/rota tem tema próprio; entrar num prédio troca a trilha na hora; o
combate começa com um *sting* + a música de batalha (selvagem ≠ treinador). A
trilha responde à pergunta "onde estou / em que modo estou" antes de qualquer
texto.

### A4. O resultado do combate é AUDÍVEL
O som do golpe comunica a eficácia: "super efetivo" tem impacto maior e mais
brilhante; "pouco efetivo" é um baque abafado; errar é um som próprio. O jogador
sabe se foi bom **antes** de ler o texto. Som como leitura de outcome.

### A5. O perigo é um som que não te larga
O **beep de HP baixo** é o som mais funcional já feito: quando o HP entra no
vermelho, um bip insistente toca *por cima* da música até você curar ou desmaiar.
Ansiedade virou áudio. Estado contínuo de risco = som contínuo.

### A6. Identidade por "grito" (cry)
Cada espécie grita ao aparecer. É identidade + evento no mesmo instante: você
reconhece o inimigo de ouvido. Desmaio = grito descendente.

### A7. Jingles param o mundo para marcar marcos
Subir de nível, pegar item, ganhar insígnia, evoluir — fanfarras curtas que
**congelam** a ação. Marco inconfundível, impossível de perder.

**Tese:** no Pokémon o som é uma *UI de estado*. caipora já tem o material sonoro;
falta transformá-lo nessa UI — fechar o vocabulário, garantir 1 estado → 1 som
aprendível, e remover sons emprestados/ambíguos.

---

## Parte B — Diagnóstico: caipora hoje sob esse modelo

A base é **madura** e já cobre boa parte do modelo. O que falta é disciplina
funcional em pontos específicos.

### Já funcional (manter)
| Princípio Pokémon | Onde está em caipora |
|---|---|
| A1 (som vence o fundo) | `AudioDirector.duck()` + `PERFECT_DUCK_DB`; SFX no bus próprio |
| A3 (música = zona/modo) | `_music_for_screen` por fase/explore/arena/boss; reverb por espaço (`SPACE_PROFILES`) |
| A5 (perigo contínuo) | `heartbeat` + `_set_heart_mode` < 30% HP, com stem base baixando — **isto é o beep de HP do Pokémon** |
| A6 (cry de boss) | `sting_boss_intro` / `sino_igreja` na revelação; `boss_death_*` por chefe |
| A7 (jingles de marco) | `sting_victory`, `sting_chest`, `sting_chama` |

### Lacunas funcionais (o trabalho desta v4)

**L1 — O erro de combate não tem som próprio (CRÍTICO).**
`arena_manager.gd:420` e `:448`: ao **errar a janela de timing**, toca-se
`ui_click_sound` a −6 dB. O evento mais importante de aprendizado do jogador
(você furou o timing) usa o som de menu. Viola A4 e A2. Precisa de um **whiff/erro**
dedicado, seco e "negativo".

**L2 — Acerto normal e crítico compartilham `hit_sound`.**
`:382-384` (normal, double first hit) vs `:432-435` (crítico) — o crítico só se
distingue por `timing_perfect` empilhado em cima. Falta uma **escada de impacto
audível** (errou < normal < crítico < esquiva-contra) que o ouvido leia sozinho,
como o "super efetivo" do Pokémon (A4).

**L3 — Inimigo comum não tem "cry"/identidade ao entrar em combate.**
`sting_arena_enter` é genérico (`_apply_screen_audio`). Bosses têm identidade; as
criaturas comuns, não. Viola A6.

**L4 — O telegraph não ensina o ritmo (A4/Pilar 2 da v3).**
`timing_alert` (`:590`) é um aviso único. Num jogo de timing, o wind-up do inimigo
deveria ser um **metrônomo aprendível** — uma estrutura "tique → AGORA" cuja
cadência ensina quando apertar. Hoje não conta o tempo de forma legível.

**L5 — Hub: compra OK vs. sem-fragmentos sem vocabulário (A2).**
Fase 9 (PLAN §"Fase 9", Etapa 2) pede "feedback de sucesso/insuficiente". Falta o
par **confirmar (jingle de compra)** vs **negado (buzz seco)** — exatamente o par
"compra/erro" do balcão Pokémon. Reaproveitar `herb_pickup` para sucesso e criar
um `denied`.

**L6 — Exploração: mover-bloqueado sem o "bonk".**
Há `step_grass`/`step_stone`, mas (a verificar) não há som de **batida em parede**.
No Pokémon o bonk confirma "não dá pra ir". Confirmação de input negado (A2).

**L7 — Beat-sync desligado, mas é onde mora o "som = controle".**
`BEAT_SYNC_ENABLED=false`. Não reativar cegamente — mas L4 (telegraph metronômico)
entrega o mesmo valor (apertar no ritmo) sem amarrar a janela ao BPM.

---

## Parte C — Plano de reestruturação (uma etapa por sessão)

Restrições inegociáveis (todas já vigentes no projeto):
- **Síntese procedural only** em `scripts/tools/gen_sfx.py` (stdlib, determinística).
- **`make audio-check`** verde (loudness/pico/RMS) + orçamento `assets/audio` (teto
  revisado na v3 ~9 MB — checar antes de fechar cada etapa).
- **Tom horror** — "negativo" é seco/visceral, não fofo. Sem som infantil.
- `/validate-controls` em qualquer mexida que toque timing/arena/input.
- Cada novo SFX nasce com **3 variantes** (convenção `_2`/`_3`) p/ o round-robin.

### Etapa 1 — A escada de impacto do combate (L1 + L2) ★ prioridade
O coração funcional. Fechar 4 outcomes com assinatura sonora distinta e aprendível:

| Outcome | Hoje | Alvo |
|---|---|---|
| Errou janela | `ui_click` −6 dB | **`combat_miss`** novo: whiff seco, abafado, descendente |
| Acerto normal | `hit` | `hit` (mantém) |
| Crítico | `hit`+`timing_perfect` | `hit_heavy` (corpo maior/brilhante) + `timing_perfect` |
| Esquiva+contra | `dodge`+`timing_perfect` | mantém (já distinto) |

- `gen_sfx.py`: novos geradores `combat_miss_wav()` e `hit_heavy_wav()` (+3 variantes
  cada), adicionar ao `CATALOG`.
- `sfx_system.gd`: novos `@export` `miss_sound`, `hit_heavy_sound`.
- `arena_manager.gd`: trocar `ui_click_sound` dos misses (`:420`,`:448`) por
  `miss_sound`; usar `hit_heavy_sound` nos críticos (`:408`,`:435`).
- Testes: estender `test_*` de assets/áudio; `make audio-check`; `/validate-controls`.

### Etapa 2 — Cry da criatura comum (L3)
- 1 "grito" curto por arquétipo de inimigo comum (ou 1 família com pitch por tipo),
  tocado no `_start_combat`/entrada de arena comum (não-boss).
- `gen_sfx.py`: `cry_*` procedurais (assovio/inarmônico já existem — `assovio()`,
  `_inharmonic()`). `AudioDirector`/`arena_manager`: disparar no `sting_arena_enter`
  só quando `not active_combat_is_boss`.

### Etapa 3 — Telegraph metronômico (L4)
- Reestruturar `timing_alert` para "conta-tempo": pré-tique(s) + acento no instante
  da janela, cadência constante por tier de boss. **Janela de timing NÃO muda** —
  só a legibilidade auditiva do wind-up.
- Validar de ouvido que dá pra acertar com os olhos fechados após ~3 encontros.
- `/validate-controls` obrigatório.

### Etapa 4 — Vocabulário do Hub (L5) — casar com Fase 9 Etapa 2
- `herb_pickup` = sucesso de compra (já existe); novo **`denied`** (buzz seco,
  grave, curtíssimo) para "fragmentos insuficientes".
- Plugar no fluxo de compra do hub jogável (`MetaProgression.purchase_upgrade`
  retorno → som). Sem asset novo de UI além do `denied`.

### Etapa 5 — Bonk de parede na exploração (L6) — pequena
- Verificar se já existe; se não, `wall_bump_wav()` + disparo no movimento bloqueado
  do `exploration_manager`. Confirmação de input negado (A2).

### Fora de escopo / decisão consciente
- **Beat-sync (L7):** permanece OFF. A Etapa 3 entrega "apertar no ritmo" sem amarrar
  a janela ao BPM. Reabrir só se um playtest pedir.

---

## Ordem sugerida e por quê
1. **Etapa 1** — maior ganho funcional, isolada, testável (o miss emprestado é o
   pior débito).
2. **Etapa 4** — destrava junto da Fase 9 (já no PLAN), baixo custo.
3. **Etapa 2** → **Etapa 3** — identidade e ritmo, exigem escuta/iteração.
4. **Etapa 5** — polish curto, encaixa em qualquer sessão.

Cada etapa é commit próprio (Session Protocol: uma tarefa por sessão) e fecha com
`make audio-check` + `make gate`, e `/validate-controls` quando tocar timing/input.
