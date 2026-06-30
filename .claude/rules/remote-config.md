---
paths:
  - "scripts/utils/enemy_stats.gd"
  - "scripts/core/remote_config.gd"
  - "scripts/core/remote_patterns.gd"
  - "site/admin.html"
  - "site/sequences.html"
  - "site/sequence.html"
  - "site/js/sequences_shared.js"
---

# Regra de edição — balanceamento & ritmo remotos (Supabase)

- HP/dano (`enemy_stats.gd`) e ritmo de ataque (`.tres`) são **sobrepostos em
  runtime** por `RemoteConfig`/`RemotePatterns` via Edge Function `caipora-api`,
  editáveis nos painéis `site/admin.html` e `site/sequences.html`.
- O fetch só ocorre em **build EXPORTADO** (`OS.has_feature("template")`) — no editor
  e em `make test`/`make smoke` valem os valores **baked**; testes usam o seam
  `_set_overrides_for_test`. Rodar do editor nunca mostra os valores remotos.
- `enemy_stats.gd` é a **fonte única + fallback**; `site/js/sequences_shared.js` é o
  catálogo baked e deve **espelhar os `.tres`**.
- O banco é **produção COMPARTILHADA** com outro app — leia a skill `supabase-db`
  antes de qualquer DDL/escrita.

Fonte canônica: `AGENTS.md` (gotchas de balanceamento e de sequências de ataque).
