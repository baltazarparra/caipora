# Pesquisa — Sistemas de batalha por turnos com ação (TLoD · Expedition 33 · Patapon)

> Estudo de referência para o refino do combate do caipora. O destilado vira decisões na
> PRD `docs/PRD-combate-refino.md`; este documento guarda o "porquê" de cada escolha.
> **Foco:** a janela onde o jogador aperta a seta (defesa) e como deixá-la **justa,
> padronizada e com ótimo feedback** sem facilitar demais.

---

## 0. Como o caipora funciona hoje (linha de base)

Turn-based com **comandos de timing**. A cada golpe do inimigo abre-se uma janela; apertar a
seta certa no instante perfeito = **esquiva + contra-ataque**; no ataque, o instante perfeito
= **crítico**. Uma bolha (`TimingBubble`) mostra um anel convergente que encontra o anel-alvo
no centro da janela perfeita — o **cue visual já está alinhado ao timing**.

Dois problemas que esta pesquisa ataca:
1. **Binário** (PERFEITO/ERRO): na defesa, quase-acerto = dano cheio.
2. **Precisão encolhe por fase** (faixa perfeita é fração da janela): fases altas ficam
   ~0.14s, e a latência de toque na web piora.

---

## 1. The Legend of Dragoon — *Additions*

**Como funciona.** O ataque vira um mini-jogo de timing: um quadrado se move/converge sobre
um quadro fixo; o jogador aperta no instante do alinhamento para **encadear** o próximo golpe
da "Addition". Acertar a sequência inteira maximiza dano e carrega SP (para os specials).
Errar **encerra a combinação** ali. Additions mais avançadas sobem a dificuldade com
**timing mais rápido, sequências maiores e janelas duplas** (counter-additions exigem reagir
ao ataque inimigo).

**O que funciona.**
- O **cue visual É o timing** — o alinhamento das caixas é, ao mesmo tempo, a informação e o
  momento de agir. Sem leitura escondida.
- **Recompensa escalonada**: cada elo acerta = mais dano + SP. O jogador sente a corrente
  crescer (gatilho de "mais um").
- Dificuldade vem de **velocidade/estrutura**, não de janelas invisíveis ou injustas.

**O que evitar.** Falha = combo zerado e turno "perdido"; sem crédito parcial, additions
longas punem muito o erro tardio (frustração clássica do jogo).

**→ Aplicação no caipora.**
- Manter o anel convergente **alinhado ao centro** do perfeito (já temos).
- Manter/valorizar a **escada de combo** (já temos: shake/hit-stop/pitch sobem com o streak).
- **Subir dificuldade encurtando a ANTECIPAÇÃO**, não a precisão do toque (ver Patapon).

---

## 2. Clair Obscur: Expedition 33 — defesa ativa em camadas

**Como funciona.** Turn-based, mas a **defesa é ativa e em tempo real**: durante o ataque
inimigo o jogador pode **esquivar** (dodge — janela generosa, evita o dano) ou **aparar**
(parry — janela mais apertada, evita o dano **e** abre contra-ataque/recursos). Há ainda
pulo para golpes baixos. Combos inimigos encadeiam vários tempos com **ritmos variados**, lidos
pela **animação + sting de áudio** (não por um medidor de UI). Ofensiva tem "hits" cronometrados
(apertar no impacto para dano extra), estilo Mario RPG.

**O que funciona.**
- **Camadas de sucesso**: existe a opção **segura** (dodge) e a **recompensada** (parry). O
  jogador menos preciso sobrevive; o preciso é premiado. Isso **remove a punição binária**
  sem trivializar a maestria.
- Tell **multimodal e diegético** (animação + áudio) ensina o ritmo de cada inimigo.
- Parry é deliberadamente **mais difícil** que dodge — a recompensa justifica o risco.

**O que evitar.** Sem nenhum medidor, jogadores novos podem demorar a ler tells; o caipora é
mobile/portrait e se beneficia de manter a **bolha** como apoio de leitura.

**→ Aplicação no caipora (decisão central).**
- **Tier GOOD = "dodge" parcial seguro** (bloqueia ~50%, sem contra, combo preservado);
  **PERFEITO = "parry"** (esquiva + contra-ataque + combo↑). Duas camadas, um só input.
- Reforçar o **tell sonoro** do golpe (já existe identidade por move; PR2 adiciona o cue de
  aproximação).

---

## 3. Patapon — ritmo, antecipação e feedback total

**Como funciona.** Jogo de ritmo: o jogador toca **comandos de tambor** (Pata/Pon/Chaka/Don)
**no compasso** 4/4. Acertar o beat repetidamente entra em **Fever** (potencializa o exército).
Errar o tempo quebra o combo. O beat é **constante e previsível**; o jogo o reforça com
**feedback massivo a cada batida**: a tela pulsa, o fundo "canta" a sílaba, os personagens
respondem em coro.

**O que funciona.**
- **Antecipação > reação.** Como o ritmo é fixo, o jogador **prevê** o instante em vez de
  reagir a um estímulo súbito — muito menos punitivo e mais "no controle".
- **Feedback multimodal** constante (visual + áudio + resposta dos personagens) torna o
  timing legível e **gostoso** mesmo em telas pequenas.
- Janela tolerante na base; a **precisão** é recompensada (Fever), não exigida para sobreviver.

**O que evitar.** Ritmo único pode ficar repetitivo; o caipora resolve variando os inimigos e
mantendo a defesa como leitura (não como metrônomo obrigatório).

**→ Aplicação no caipora.**
- **Cue de antecipação "prepare → AGORA"**: pulso/tique na aproximação da janela + pico claro
  no instante perfeito (visual + som + háptico). Treina antecipação.
- **Precisão fixa entre fases**: a largura do acerto (em segundos) é a **mesma** em toda fase;
  só a antecipação encurta. Um ritmo único aprendido uma vez.

---

## 4. Síntese — princípio → decisão → onde no código

| Princípio (origem) | Decisão no caipora | Onde |
|---|---|---|
| Cue visual = timing (TLoD) | Anel convergente alinhado ao centro do perfeito (manter) | `scripts/ui/timing_bubble.gd` |
| Recompensa escalonada (TLoD) | Escada de combo (manter); GOOD preserva o streak | `scripts/systems/feedback_system.gd` (`track_perfect`/`track_good`) |
| Camadas de sucesso (Expedition 33) | **Tier GOOD** = bloqueio ~50% sem contra; PERFEITO = contra/crit | `scripts/systems/timing_system.gd`, `scripts/arena/arena_manager.gd` |
| Tell multimodal (Expedition 33) | Identidade sonora por move + cue de aproximação | `sfx_system.gd`, `audio_director.gd` (PR2) |
| Antecipação > reação (Patapon) | Cue "prepare → AGORA" antes da janela | `timing_bubble.gd` (`approach_entered`) + `controls_hud.gd` (PR2) |
| Precisão fixa (Patapon) | Faixas absolutas sobre `D`; só o lead-in encurta por fase | `Constants.band_fractions()` |

---

## 5. Parâmetros derivados (ver PRD §5 e §9)

- Faixa **PERFEITO** = ±0.09s; **GOOD** = ±0.20s; **LATE_GRACE** = 0.04s (só no lado tardio,
  para absorver latência de toque/web). Constantes em `scripts/utils/constants.gd`.
- `GOOD_BLOCK_MULT` = 0.5 (bloqueio parcial). Tudo num lugar só → tuning trivial pós-playtest.
- O modelo NÃO mexe na duração total `D` por fase (mantém `action_windows`/`attack_duration`
  e o painel remoto intactos): só reposiciona as faixas dentro de `D`.

---

## 6. Referências

- *The Legend of Dragoon* (Sony/Japan Studio, 2000) — sistema de Additions.
- *Clair Obscur: Expedition 33* (Sandfall Interactive, 2025) — defesa ativa dodge/parry.
- *Patapon* (Pyramid/Japan Studio, 2007) — comando rítmico e Fever.
