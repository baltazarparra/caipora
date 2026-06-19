# PRD — Fase 9: Hub de Aprimoramentos Jogável

> **caipora** — Brazilian Folk Horror Roguelike
> **Fase:** 9
> **Status:** ✅ Concluído (Etapas 0–3 entregues; hub de cards aposentado)
> **Document Version:** 1.0
> **Depende de:** [PRD-fase-4.md](./PRD-fase-4.md) (Meta-Progression & Hub), Fase 8 (Geração Procedural)

---

## 1. Visão Geral

Hoje os aprimoramentos (as **ervas** que a Caipora fuma no cachimbo) vivem numa **tela
de menu** — `scenes/ui/hub.tscn` — aberta **uma única vez**, vinda do menu principal,
**antes da Fase 1**. É uma lista de cards com botão "Fumar". Depois disso, o jogador
**nunca mais passa pelo hub**: as fases encadeiam direto (exploração → arena → próxima
exploração).

Esta fase transforma o sistema de aprimoramentos num **hub jogável** — o **Acampamento**
— pelo qual a Caipora **caminha entre uma fase e outra**. No chão do acampamento ficam as
ervas disponíveis, cada uma com seu **valor em fragmentos**. Ao **pisar em cima** de uma
erva que o jogador **pode pagar**, o aprimoramento é realizado na hora. A saída é um
**rastro/portal** no chão: pisar nele leva à próxima fase.

### Mudança de fluxo

**Antes:**
```
MainMenu → HUB (menu de cards) → start_run → EXPLORAÇÃO(P1) → P2 → P3 → P4 → ENDING
                                              (sem hub entre as fases)
```

**Depois:**
```
MainMenu → start_run → EXPLORAÇÃO(P1)
   P1 vencida → HUB jogável → EXPLORAÇÃO(P2)
   P2 vencida → HUB jogável → EXPLORAÇÃO(P3)
   P3 vencida → HUB jogável → EXPLORAÇÃO(P4)
   P4 vencida → ENDING
```

**Decisões de design (alinhadas com o autor):**
1. **Itens no chão:** aparecem **todos os aprimoramentos compráveis da fase alcançada** —
   ou seja, todo aprimoramento já liberado por `phase`, com `requires` atendido e ainda
   não comprado. Cada um mostra seu valor. Segue **exatamente** a lógica atual de
   `MetaProgression.purchase_upgrade()`.
2. **Sem hub antes da Fase 1.** O menu principal passa a iniciar a run e cair direto na
   exploração da Fase 1. O hub só aparece **entre fases**.
3. **Saída pisando num tile.** O acampamento é um mini-grid jogável: anda, pega as ervas
   no caminho e pisa no **tile de saída** para entrar na próxima fase (reusa a mecânica de
   saída da exploração).

**Tom:** o Acampamento é o único lugar onde a floresta não alcança. Fogueira baixa,
cachimbo, o silêncio depois do sangue. As ervas estão no chão, ao redor do fogo. A Caipora
respira, escolhe o que vai fumar, e volta pra mata. **Não suavizar:** a calma do
acampamento é a calma antes de afundar mais fundo na corrupção.

---

## 2. Objetivos

| # | Objetivo | Sucesso |
|---|----------|---------|
| 1 | **Hub entre fases** | Toda transição de fase (P1→P2, P2→P3, P3→P4) passa pelo Acampamento jogável |
| 2 | **Sem hub antes da P1** | Menu → Iniciar cai direto na Exploração da Fase 1 |
| 3 | **Ervas no chão** | Cada aprimoramento comprável da fase aparece no chão com seu valor em fragmentos |
| 4 | **Compra ao pisar** | Pisar numa erva com fragmento suficiente realiza o aprimoramento (consome fragmentos), respeitando `requires`/custo |
| 5 | **Saída jogável** | Pisar no tile de saída leva à próxima fase, preservando a continuidade da run |
| 6 | **Cura no hub** | Entrar no acampamento recupera HP cheio (comportamento atual preservado) |
| 7 | **Sem regressão** | Loop ponta-a-ponta jogável; meta-progressão, save e CHAMA intactos |

---

## 3. Arquitetura — Centralizar a Transição de Fase

### 3.1 O problema

Hoje o avanço de fase dispara de **dois lugares diferentes**:

| Transição | Onde dispara hoje | Gatilho |
|-----------|-------------------|---------|
| P1 → P2 | `exploration_manager._on_player_moved` | pisa no tile de saída (`next_screen_on_exit`) |
| P2 → P3 | tile de saída **e/ou** morte do Boitatá (`arena_manager._resolve_next_screen`) | exit tile ou boss |
| P3 → P4 | `arena_manager._resolve_next_screen` | morte do Curupira (P3 não tem tile de saída) |
| P4 → ENDING | `arena_manager._resolve_next_screen` | morte do Saci |

> **Importante (não-regressão):** vitórias em combate **comum** e a morte do boss da Fase 1
> voltam para a **mesma** fase — **essas NÃO podem passar pelo hub**. Só transições que
> **avançam** de fase devem cair no acampamento.

### 3.2 A solução — um único ponto de avanço

Introduzir em `GameState` o conceito de **"próxima exploração pendente"** e rotear todo
avanço de fase pelo HUB:

```gdscript
# GameState
var pending_exploration: SignalBus.Screen = SignalBus.Screen.EXPLORATION

## Avança de fase passando OBRIGATORIAMENTE pelo acampamento.
func advance_phase_via_hub(next_exploration: SignalBus.Screen) -> void:
    pending_exploration = next_exploration
    change_screen(SignalBus.Screen.HUB)
```

- **`exploration_manager`** (tile de saída): onde hoje chama
  `change_screen(_profile["next_screen_on_exit"])`, passa a chamar
  `GameState.advance_phase_via_hub(_profile["next_screen_on_exit"])` quando o destino é uma
  exploração de fase nova.
- **`arena_manager._do_screen_change`**: quando o `next_screen` for uma exploração de fase
  **diferente** da atual (avanço por boss — P2→P3, P3→P4), roteia via
  `advance_phase_via_hub`. **ENDING** (boss da P4), **retorno à mesma fase** (vitória comum
  e boss da P1) e **GAME_OVER** continuam diretos.
- **HUB** (novo `hub_manager`): ao pisar no tile de saída, chama
  `change_screen(GameState.pending_exploration)`.

Isso mantém o `SceneTransition` e o roteamento de `_scene_path_for` intactos; só muda
**para onde** o avanço aponta.

### 3.3 Remover o hub antes da Fase 1

- `main_menu.gd`: trocar `change_screen(Screen.HUB)` por `GameState.start_run()` +
  `change_screen(Screen.EXPLORATION)`.
- O `start_run()` (que hoje roda dentro do hub, em `hub.gd::_on_enter_pressed`) passa a ser
  responsabilidade do menu, já que a primeira tela jogável vira a exploração.

---

## 4. Arquitetura — A Cena do Acampamento

Substitui o menu de cards por um **mini-grid jogável** (composição sobre o que já existe na
exploração).

### 4.1 Arquivos

| Arquivo | Papel |
|---------|-------|
| `scenes/hub/hub.tscn` | Cena do acampamento (Node2D: TileMap + Caipora + Objects + HUD) |
| `scripts/hub/hub_manager.gd` | Manager do hub: monta o grid, posiciona ervas, trata movimento/compra/saída |
| `scripts/hub/hub_pickup.gd` *(ou reuso de `MapObject`)* | Erva no chão: ícone + label de custo + estado (compravel/caro/comprado) |
| `scenes/ui/hub.tscn` + `scripts/ui/hub.gd` | **Aposentados** (menu de cards) ao fim da Fase 9 |

`GameState._scene_path_for(HUB)` passa a apontar para `res://scenes/hub/hub.tscn`.

### 4.2 Composição (reuso máximo)

- **TileMap** pintado de um layout pequeno e fixo (clareira do acampamento). Reusa
  `Constants.TILE_SIZE`, `tile_floor.png`/`tile_wall.png` e o setup de tileset já existente
  no `exploration_manager` (extraível para um helper compartilhado, se valer).
- **Caipora** com `MovementController`/`tilemap` (mesma entidade da exploração), movimento
  4-direções.
- **Cura:** `GameState.heal_to_full()` ao entrar (igual ao hub atual).
- **Saída:** tile de rastro/portal com o **exit marker pulsante** (reusa
  `_spawn_exit_marker`/`ForestLight`); pisar → `change_screen(pending_exploration)`.
- **Identidade do Acampamento:** fogueira (`FireEffect`), cachimbo (`cachimbo.png`), vida
  ambiente (`AmbientLife`/`ForestAmbience`) — o único respiro entre as caçadas.

### 4.3 Ervas no chão (compra ao pisar)

**Quais aparecem:** itera `MetaProgression.UPGRADE_DEFS` e coloca no chão toda key onde:
```
phase_reached >= def.phase   AND   requires atendido (ou vazio)   AND   ainda não comprada
```
(é o mesmo gate que o hub de cards já usa em `_build_section` + `_refresh_card`).

**Layout:** ervas dispostas de forma legível ao redor da fogueira — trilha da **Fúria** de
um lado, **Cura** do outro (ou uma fileira diante do fogo). Posições determinísticas a
partir do conjunto disponível na visita.

**Visual de cada erva:**
- Ícone da erva (`def.icon`, já existe por aprimoramento).
- Label de custo: `"<custo> ◆"` (fragmentos).
- **Acessível** (fragmentos ≥ custo): brilho/destaque âmbar.
- **Cara** (fragmentos < custo): esmaecida, custo em vermelho.

**Compra ao pisar:** em `hub_manager` no movimento do jogador, se o tile tem uma erva:
- Chama `MetaProgression.purchase_upgrade(key)` — **reuso direto** (já valida `requires`,
  custo, `max_level` e persiste o save).
- **Sucesso:** remove a erva do chão, SFX de "fumar", número flutuante `−custo`, atualiza
  HUD (fragmentos + resumo de bônus), e re-avalia o brilho das ervas restantes (comprar uma
  cara pode ter ficado inacessível; comprar a `forca` pode liberar `forca_2` na cadeia —
  mas a liberação por `requires` só vale **a partir da próxima visita**, já que o conjunto
  é montado na entrada; documentar essa escolha).
- **Sem fragmento:** SFX/shake curto de "insuficiente", a erva permanece.

> O `purchase_upgrade` continua sendo a **fonte única de verdade** da economia. O hub
> jogável é só uma **nova apresentação/entrada** — zero regra de combate ou custo
> reimplementada.

### 4.4 HUD do acampamento

`CanvasLayer` sobreposto: contador de **fragmentos**, resumo **"Fúria +X dano • Cura +Y
HP"** (de `get_damage_bonus()`/`get_health_bonus()`), e uma instrução curta ("piso na erva
pra fumar • rastro leva à mata"). Acesso a **Opções** preservado (botão de canto ou tile
dedicado), já que o menu de cards levava o `OptionsPanel`.

### 4.5 Casos de borda

- **Nenhuma erva disponível** (tudo comprado, ou a fase ainda não liberou nada novo): o
  acampamento aparece mesmo assim — serve de **cura + respiro narrativo**; só a fogueira e
  a saída.
- **`pending_exploration` é volátil** (não vai pro save). Se o jogador recarregar a aba
  **dentro** do hub (Web), o destino se perde. Mitigação: o `MetaProgression` já persiste
  `phase_reached`; derivar o `pending_exploration` de `phase_reached` na entrada do hub como
  fallback (registrar como risco menor, cobrir em teste).
- **P2 tem tile de saída E boss (Boitatá)** apontando ambos para P3. Os dois caminhos
  chamam `advance_phase_via_hub(EXPLORATION_PHASE3)` → o `change_screen(HUB)` idempotente do
  `SceneTransition` cuida do resto. Consistente.

---

## 5. Roadmap de Execução (etapas com gate)

Estilo incremental e test-gated (como a Fase 8). Cada etapa fecha com `make gate` verde e o
jogo jogável ponta-a-ponta.

### Etapa 0 — Roteamento via hub (sem cena nova ainda)
- `GameState.pending_exploration` + `advance_phase_via_hub()`.
- `exploration_manager` e `arena_manager` roteiam **avanços de fase** pelo HUB; vitória
  comum / boss P1 / ENDING / GAME_OVER seguem diretos.
- `main_menu.gd`: inicia a run e vai direto pra Exploração (sem hub antes da P1).
- O HUB **ainda** é o menu de cards atual, mas agora: (a) aparece entre fases, (b) seu botão
  "Entrar" lê `pending_exploration` em vez de `start_run()+EXPLORATION`.
- **Gate:** loop ponta-a-ponta com hub de cards aparecendo entre cada fase; sem hub antes da
  P1. Testes de roteamento (avanço → HUB + pending correto; comum/P1-boss/ENDING diretos).

### Etapa 1 — Hub jogável (grid + movimento + saída)
- `scenes/hub/hub.tscn` + `scripts/hub/hub_manager.gd`: grid pequeno, Caipora anda,
  `heal_to_full()`, tile de saída pulsante → `pending_exploration`.
- `_scene_path_for(HUB)` aponta para a cena nova; menu de cards desligado da rota.
- **Gate:** entra no acampamento, anda, pisa na saída e cai na próxima fase. Continuidade da
  run preservada.

### Etapa 2 — Ervas no chão + compra ao pisar
- Posiciona as ervas compráveis da fase (gate `phase_reached`+`requires`+não-comprada) com
  ícone e custo.
- Compra ao pisar via `purchase_upgrade`; HUD de fragmentos + resumo de bônus; feedback de
  sucesso/insuficiente.
- **Gate:** comprar funciona, custo/`requires` respeitados, fragmentos debitam, save
  persiste; pisar em erva cara não compra.

### Etapa 3 — Polish + identidade + limpeza
- Acampamento temático: fogueira, cachimbo, vida ambiente, SFX de "fumar", número
  flutuante, brilho acessível/caro.
- Flavor de transição do `SceneTransition` para o hub ("o acampamento respira...").
- **Aposentar** `scenes/ui/hub.tscn` + `scripts/ui/hub.gd`; mover `OptionsPanel` para o hub
  jogável.
- Atualizar testes: `test_hub_builds.gd` (reescrito para o hub jogável),
  `test_scene_transition.gd` (HUB como tela calma), e os de meta/upgrades seguem verdes.
- **Gate:** `make gate` verde; playtest do loop completo.

---

## 6. Impacto em Arquivos

| Arquivo | Mudança |
|---------|---------|
| `scripts/core/game_state.gd` | `pending_exploration` + `advance_phase_via_hub()`; rota do HUB |
| `scripts/core/signal_bus.gd` | (se preciso) sinais `upgrade_purchased` / `purchase_denied` p/ feedback |
| `scripts/exploration/exploration_manager.gd` | avanço por tile de saída via hub |
| `scripts/arena/arena_manager.gd` | avanço por boss (P2→P3, P3→P4) via hub; ENDING/mesma-fase diretos |
| `scripts/ui/main_menu.gd` | inicia run → Exploração (sem hub antes da P1) |
| `scenes/hub/hub.tscn` **(novo)** | acampamento jogável |
| `scripts/hub/hub_manager.gd` **(novo)** | manager do hub |
| `scripts/hub/hub_pickup.gd` **(novo, ou reuso de MapObject)** | erva no chão |
| `scenes/ui/hub.tscn`, `scripts/ui/hub.gd` | **aposentados** ao fim da Fase 9 |
| `tests/unit/test_hub_*.gd`, `test_scene_transition.gd`, `test_meta_progression.gd` | atualizar/estender |

---

## 7. Riscos & Mitigações

| Risco | Mitigação |
|-------|-----------|
| Avanço de fase passar a tratar vitória comum como troca de fase | Rotear via hub **só** quando o destino é exploração de fase **diferente** da atual; cobrir com teste |
| `pending_exploration` volátil em reload (Web) | Derivar fallback de `phase_reached` na entrada do hub |
| Liberação por `requires` no mesmo hub (comprar `forca` e querer `forca_2` na hora) | Conjunto montado na entrada; cadeia só libera na **próxima** visita — documentado e aceito (ou re-spawnar a erva liberada como melhoria opcional) |
| Quebra de continuidade da run no novo loop | Reusar `defeated_enemy_ids`, `map_enemy_positions`, snapshot; limpar ao entrar em fase nova como hoje |
| Tela de cards tinha Opções/áudio unlock | Mover `OptionsPanel` para o hub jogável |

---

## 8. Fora do Escopo (follow-ups)

- Acampamento progressivamente mais corrompido por fase (visual temático por `phase`).
- Re-spawn imediato da erva liberada por `requires` dentro do mesmo hub.
- Layout do acampamento gerado proceduralmente (hoje fixo basta).
- Daily-seed do loop novo.
</content>
</invoke>
