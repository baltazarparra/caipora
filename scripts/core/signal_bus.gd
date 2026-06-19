extends Node

# Global event bus. All systems emit and listen here.
# Keeps decoupling between gameplay modules.

# ─── Enums ─────────────────────────────────────────
enum Screen { MAIN_MENU, EXPLORATION, ARENA, GAME_OVER, WIN, HUB, EXPLORATION_PHASE2, ARENA_PHASE2, EXPLORATION_PHASE3, ARENA_PHASE3, EXPLORATION_PHASE4, ARENA_PHASE4, ENDING, EXPLORATION_PHASE5, ARENA_PHASE5, FINAL_CHOICE, ENDING_SACRIFICE }

# ─── Signals ───────────────────────────────────────
signal screen_changed(new_screen: Screen)
signal arena_entered(arena_id: String)
signal arena_exited(won: bool)

# Reservados p/ Fase 4 (HUD / GameOver) — ainda sem emissor no MVP atual.
signal caipora_died
signal caipora_health_changed(new_health: float, max_health: float)
signal enemy_health_changed(new_health: float, max_health: float)
signal fragment_gained(total: float, amount: float)
signal chama_gained
signal herb_collected(bonus: int)

# ─── Apresentação de boss (estilo Mega Man) + diálogo pré-boss ──
signal boss_intro_started
signal boss_intro_finished
signal dialogue_finished
## Wind-up de especial de chefe com cue de áudio próprio (Fase 5: água benta).
signal boss_special_telegraph(boss_type: String)
## Boss derrotado (fase identifica o chefe: 1=mula..5=jesuíta). Cicatriz sonora própria.
signal boss_died(phase: int)

# ─── Janela de defesa — feedback no D-pad de combate ──
## Janela de bloqueio/dodge abriu para esta ação direcional.
signal defense_window_opened(action: String)
## Janela fechou (resultado já foi processado — perfeito ou miss).
signal defense_window_closed()
## A bolha entrou na faixa GOOD: cue de aproximação "prepare → AGORA" (tique + háptico leve).
signal combat_approach_cue()
## Jogador acertou o timing perfeito.
signal defense_result_perfect()
## Jogador acertou a faixa GOOD (bloqueio parcial): dano reduzido, sem contra-ataque.
signal defense_result_good()
## Janela expirou sem input correto, ou input veio no timing errado.
signal defense_result_miss()

# ─── Golpe Carregado (Cortejo) — carga espelhada no D-pad ──
## Janela do golpe carregado abriu: a seta `action` deve "encher de fogo" ao longo de
## `duration` segundos (espelho visual da bolha de timing; só feedback, sem input).
signal cortejo_charge_opened(action: String, duration: float)
## Janela do golpe carregado fechou (soltou, estourou ou expirou): limpa o fogo do D-pad.
signal cortejo_charge_closed()

# ─── Resultado de ataque — háptico diferenciado no HUD ──
## Jogador acertou o timing perfeito do ATAQUE (crítico). Espelha o de defesa para o
## D-pad poder vibrar distinto por desfecho (a arena já dava feedback visual/sonoro).
signal attack_result_perfect()
## Jogador acertou a faixa GOOD do ataque (golpe normal, sem crítico; combo preservado).
signal attack_result_good()
## Jogador furou a janela do ataque.
signal attack_result_miss()

# ─── Balanceamento remoto (RemoteConfig / RemotePatterns) ─────────
## Há balanceamento de inimigo novo no servidor (version mais nova que a aplicada).
## O menu mostra o banner "Atualizar"; aplicar troca os overrides ativos.
signal remote_config_update_available(version: int)
## Há padrões de ataque novos no servidor. Mesmo banner — apply_pending() de
## RemotePatterns NÃO recarrega; RemoteConfig.apply_pending() recarrega depois.
signal remote_patterns_update_available(version: int)
## Há aprimoramentos (custo/valor de ervas) novos no servidor. Mesmo banner.
signal remote_upgrades_update_available(version: int)

# ─── Bolsa de fragmentos (corpse run) ──────────────
# Emitidos pelo MetaProgression; o AudioDirector (persistente) toca os one-shots —
# a cena que derruba a bolsa morre na transição para GAME_OVER e cortaria o som.
signal fragment_bag_dropped(amount: float)
signal fragment_bag_recovered(amount: float)
