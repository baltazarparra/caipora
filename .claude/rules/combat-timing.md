---
paths:
  - "scripts/systems/timing_system.gd"
  - "scripts/systems/combat_system.gd"
  - "scripts/systems/feedback_system.gd"
  - "scripts/systems/arena_manager.gd"
  - "scripts/ui/timing_bubble.gd"
  - "scripts/ui/combat_arrow_button.gd"
  - "scripts/ui/controls_hud.gd"
  - "scripts/entities/attack_pattern.gd"
---

# Regra de edição — combate / timing (input-crítico)

Você está mexendo no núcleo de combate baseado em timing.

- **Antes de commitar: rode `/validate-controls` e `make gate`.** Os dois caminhos
  de input — teclado nativo (`Input.is_action_pressed`) e injeção do D-pad touch —
  precisam funcionar de forma idêntica.
- O acerto é **3-tier** (PERFEITO / GOOD / ERRO) com faixas absolutas sobre a janela.
- O golpe especial **Cortejo ("O Chamado")** é **SEGURAR → SOLTAR** (não tap): o
  release define o tier — banda dourada = PERFEITO/FEVER, ombro = GOOD, cedo = FRACO
  (barragem parcial), overcharge/timeout = QUEIMA (contra-ataque). Reusa o modo hold
  do `TimingSystem` (`open_window(..., hold=true, good_start, good_end)` +
  `window_progress()`); NÃO existe classe `HoldTimingSystem`. Frações em
  `Constants.CHAMADO_*`. Fonte: `docs/PRD-cortejo-o-chamado.md`.
- O ritmo é **remoto, em camadas com fallback** (`.tres` → `RemotePatterns` ←
  Supabase). Mexeu num `.tres`? Sincronize `site/js/sequences_shared.js`.
- SFX novo entra **SEMPRE no fim** de `GENERATORS` em `gen_sfx.py` (seed por variante —
  inserir no meio muda os bytes dos seguintes).

Fonte canônica: `AGENTS.md` (gotchas de combate), `docs/PRD-combate-refino.md`,
`docs/PESQUISA-combate-acao.md`.
