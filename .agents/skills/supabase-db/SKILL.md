---
name: supabase-db
description: Como usar o Supabase via MCP e o banco de dados do caipora. Consulte sempre que mexer em banco de dados, tabela, schema caipora, migration, Edge Function, telemetria ou cloud save.
---

# Banco de Dados do caipora (Supabase via MCP)

Backend do jogo: **telemetria** e **cloud save**. Acessado pelas
ferramentas MCP do Supabase. Leia esta skill antes de qualquer mudança no banco.

## 1. Projeto & escopo

- **project_ref:** `mlykeulezzfwljriytuf`
- **URL:** `https://mlykeulezzfwljriytuf.supabase.co`
- ⚠️ **Banco COMPARTILHADO com outro app.** O schema `public` tem tabelas de terceiros
  (`reviews`, `association_suggestions`, `prescription_suggestions`,
  `analytics_pageviews_daily`, `site_visit_stats`) e funções (`track_pageview`,
  `increment_site_visit`, `get_analytics_summary`). **NUNCA** alterar, dropar ou
  inserir nessas tabelas/funções.
- ✅ **Tudo do jogo vive no schema `caipora`.** Não criar nada do jogo no `public`.

## 2. Convenções

- Schema dedicado `caipora`; `snake_case`; `timestamptz default now()`.
- **RLS sempre ON** em toda tabela do jogo, **sem policies** para `anon`/`authenticated`.
- O schema `caipora` **NÃO é exposto na Data API** (só `public`/`graphql_public` são).
  Manter assim: é uma camada extra — o cliente não alcança as tabelas via REST mesmo
  com a anon key vazada. O acesso é só pela Edge Function (conexão Postgres direta).
- Lints `rls_enabled_no_policy` (INFO) nas tabelas `caipora.*` são **esperados e
  corretos** (anon bloqueado de propósito). **Não** criar policies para "resolver".

## 3. Aplicar mudanças via MCP

1. `mcp__supabase__list_tables` (schemas `["caipora"]`) **antes** de mexer.
2. **DDL só por `apply_migration`** (nome em `snake_case`). **Nunca** `execute_sql` para DDL.
3. `execute_sql` apenas para **leitura/inspeção** e limpeza de dados de teste.
4. Depois de DDL, rodar `mcp__supabase__get_advisors` (security + performance) e corrigir
   só issues reais (índice faltando etc.) — ignorar os INFO esperados acima.

## 4. Edge Function `caipora-api`

- Tooling: `list_edge_functions`, `get_edge_function`, `deploy_edge_function`.
- Acessa o schema `caipora` por **conexão Postgres direta** (`SUPABASE_DB_URL`) com
  `npm:postgres` — NÃO via `supabase-js`, porque o schema não é exposto na Data API.
- `verify_jwt: true` → o cliente envia a **anon key (JWT legado)** no header
  `Authorization: Bearer <anon>` e `apikey: <anon>`. A autorização do jogo é o
  `player_token` (custom), validado dentro da função.
- Endpoint: `POST /functions/v1/caipora-api`, corpo JSON com campo `action`.

### Contrato (ações)

| action | request | response |
|--------|---------|----------|
| `check_tag` | `{ tag }` | `{ available, reason? }` |
| `register_tag` | `{ tag }` | `{ player_id, player_token, tag }` ou 409 `tag_taken` |
| `log_events` | `{ player_id?, session_id?, client_version?, events: [{ event_type, payload }] }` (máx 50) | `{ inserted }` |
| `get_save` | `{ player_id, player_token }` | `{ data, save_version, updated_at }` (data `null` se não existe) |
| `put_save` | `{ player_id, player_token, data, save_version }` | `{ ok: true }` |

Exemplo:

```bash
curl -s https://mlykeulezzfwljriytuf.supabase.co/functions/v1/caipora-api \
  -H "Authorization: Bearer <ANON_JWT>" -H "apikey: <ANON_JWT>" \
  -H "Content-Type: application/json" \
  -d '{"action":"log_events","events":[{"event_type":"run_start","payload":{}}]}'
```

## 5. Tabelas do jogo (schema `caipora`)

- **`players`** — registro de tags (identidade). `id uuid pk`, `tag`
  (`^[A-Za-z0-9_]{4,12}$`), `tag_lower` (único, unicidade ignora case), `token_hash`
  (SHA-256 do `player_token`; nunca o segredo), `created_at`, `last_seen_at`.
- **`events`** — telemetria. `player_id?`, `session_id?`, `event_type`, `payload jsonb`,
  `client_version`, `created_at`.
- **`saves`** — cloud save. `player_id` (PK, FK→players), `data jsonb` (espelha
  `user://savegame.json`), `save_version`, `updated_at`. Upsert last-write-wins.

## 6. Identidade & tag (estilo fliperama)

- Sem login. A **tag É a identidade** (4–12 chars, alfanumérico + `_`, única ignorando case).
- Fluxo: `check_tag` (enquanto digita) → `register_tag` → o cliente guarda
  `player_id` + `player_token` no `user://`. Toda escrita exige os dois.
- Banco guarda só o **hash** do token. Trocar de device / limpar cache = perde a tag
  (comportamento arcade aceito). Recuperação/login fica fora do escopo.

## 7. Segurança

- A anon key fica **exposta no bundle web** → **nunca confiar no cliente**. Toda
  validação (formato, ranges, posse via token) acontece na Edge Function.
- **Nunca** expor `service_role`, `SUPABASE_DB_URL`, `token_hash` nem `player_id` de
  terceiros em respostas.
- Comparação de token em **tempo constante**.

## 8. Debug

- `mcp__supabase__get_logs` (serviço `edge-function`) e `get_advisors` antes de mudar.
- `generate_typescript_types` se precisar de tipos para algum cliente TS.
