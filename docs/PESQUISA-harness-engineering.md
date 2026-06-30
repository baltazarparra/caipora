# PESQUISA — Harness Engineering (Claude Code / Opus)

> Revisão da **camada de harness** do caipora — como `AGENTS.md`/`CLAUDE.md`,
> skills, hooks, MCP, permissões e Makefile guiam o agente — comparada ao
> **estado atual da engenharia de harness** (docs oficiais Anthropic + padrão
> AGENTS.md + segurança MCP). Data: 2026-06-30.
>
> Esta auditoria foi disparada com `/code-review`-style fan-out: 3 subagentes de
> pesquisa em paralelo (context engineering, mecânica do Claude Code, MCP/padrões).
> **Durante a própria revisão um evento de segurança ocorreu** (ver Achado #1) —
> uma demonstração ao vivo do risco que a pesquisa apontou.

---

## 0. Sumário executivo

A camada de harness do caipora é **madura e acima da média**: fonte única via
symlink (`CLAUDE.md→AGENTS.md`, `.mcp.json` canônico), guardrail determinístico
(`make gate` em hook), memória institucional densa (20 gotchas), skills com
`disable-model-invocation` para gates de validação. Está alinhada com a maioria
dos princípios atuais.

Os problemas são de **dois tipos**: (a) **segurança de permissões** — auto-aprovações
amplas demais, uma das quais expôs uma chave privada nesta sessão; e (b) **orçamento
de contexto** — `AGENTS.md`/`PLAN.md` carregam muito sempre-presente, contra o
princípio de "context é finito; recupere just-in-time".

**Corrigido nesta sessão** (itens de baixo risco): drift de skills, bloat de
permissões, hook que não bloqueava, escopo de `Read`. **Recomendado** (precisa de
decisão): downgrade das permissões de escrita do Supabase, migração dos gotchas de
subsistema para `.claude/rules/`, slim do `session-orient`.

---

## 1. Estado da arte — síntese (2025–2026)

Fontes primárias: engenharia da Anthropic + docs do Claude Code (migraram para
`code.claude.com`) + spec do MCP + padrão `agents.md`. Princípios de maior alavancagem:

1. **Context é orçamento finito, não despejo.** Modelos sofrem *context rot* — a
   recall degrada conforme os tokens crescem. Mire "o menor conjunto de tokens de
   alto sinal". `CLAUDE.md` bloated (>200 linhas) faz o Claude **ignorar** as regras
   que importam. ([context-engineering], [memory])
2. **"Right altitude" nas instruções.** Nem lógica rígida e frágil, nem vago. O
   mínimo que especifica o comportamento esperado — heurísticas, não scripts.
   ([context-engineering])
3. **Recuperação just-in-time > pré-carregar.** O agente segura identificadores
   leves (paths, queries) e puxa o conteúdo com ferramentas. Procedimentos
   multi-passo viram **skills** (corpo carrega só quando usado); regras por-arquivo
   viram **`.claude/rules/*.md`** path-scoped. ([context-engineering], [skills])
4. **Comece simples; só adicione complexidade quando melhora medível.** Workflow >
   agente quando o caminho é previsível. Multi-agente custa ~15× os tokens de um
   chat — use só para *breadth* paralelizável (pesquisa/auditoria), não para coding
   linear. ([building-agents], [multi-agent])
5. **A Interface Agente-Computador (ACI) merece tanto cuidado quanto o prompt.**
   Poucas ferramentas consolidadas, namespaced, com saída de alto sinal e mensagens
   de erro que *ensinam o próximo passo*. ([writing-tools])
6. **Verificação determinística e inescapável.** O agente dizer "pronto" é
   **não-confiável**. Amarre gates (testes/build/screenshot) em **hooks**, não em
   prosa do CLAUDE.md (que é advisory). Sessão começa verificando, não implementando.
   ([effective-harnesses])
7. **Hooks são determinísticos; CLAUDE.md é advisory.** Para bloqueio duro, use
   **hook (`exit 2`)** ou **`permissions.deny`** — nunca confie na prosa. ([hooks])
8. **Segurança = "lethal trifecta".** O agente vira ferramenta de exfiltração quando
   tem, ao mesmo tempo: (1) acesso a dado privado, (2) exposição a conteúdo não
   confiável, (3) canal de saída. **Nunca auto-aprovar ferramenta que escreve/deleta/
   deploya/paga/roda shell.** Least-privilege em escopos MCP. ([lethal-trifecta],
   [rule-of-two], [mcp-security])

---

## 2. Inventário da nossa camada de harness

| Componente | Estado |
|---|---|
| Instruções | `AGENTS.md` canônico (raiz + `scripts/`+`scenes/`+`assets/`); `CLAUDE.md`→symlink. **Raiz ≈ 5.170 tok** sempre-carregados; `assets/` +1.922 tok ao entrar na pasta. |
| Skills | 5 em `.agents/skills/` (canônico): `session-orient`, `supabase-db`, `validate-controls`, `validate-platforms`, `visual-identity`. 4 com `disable-model-invocation`. |
| Hooks | 1 — `PreToolUse(Bash)` → `make gate` antes de `git commit`. |
| MCP | `godot` (wrapper local, **todas** as tools em autoApprove) + `supabase` (http). |
| Permissões | `settings.local.json` (gitignored). Era ~95 entradas. |
| Comandos build | `Makefile` fonte única: `smoke`/`test`/`export`/`gate`/`audio*`. |
| Subagents | **Nenhum** (`.claude/agents/` não existe). |
| `.claude/rules/` | **Não usado.** |
| Versão | Build-stamped do git (`alpha-X.Y.Z`). |

---

## 3. Comparação ponto-a-ponto

| Dimensão | Prática recomendada (SOTA) | Nosso estado | Ação |
|---|---|---|---|
| Fonte única de instruções | symlink ou `@import`, sem duplicação | ✅ `CLAUDE.md→AGENTS.md`, `.mcp.json` canônico | manter |
| Tamanho do CLAUDE.md | <200 linhas/arquivo; cortar o que o Claude infere | ⚠️ raiz ~5.2K tok, gotchas de subsistema sempre-on | **migrar #15–20 p/ `.claude/rules/`+skills** |
| Procedimentos multi-passo | viram **skills** (corpo on-demand) | ⚠️ vários gotchas são procedimentos em prosa always-on | mover p/ skills/rules |
| Regras por-arquivo | `.claude/rules/*.md` com `paths:` | ❌ não usado | adotar (audio/combate/arte) |
| Pré-carga vs just-in-time | puxar contexto sob demanda | ⚠️ `session-orient` lê **PLAN.md inteiro (~17K tok)** toda sessão | ler só o milestone atual |
| Skills: fonte única | uma cópia física; symlink p/ cada tool | ✅ **corrigido** (era duplicata; `visual-identity` faltava) | verificar descoberta |
| Skills: side-effecting | `disable-model-invocation: true` | ✅ nos 4 gates | manter |
| Gate determinístico | hook que **bloqueia** (`exit 2`) | ✅ **corrigido** (saía 1 = não bloqueava) | — |
| Verificação de "done" | Stop hook / assert objetivo | ⚠️ só pre-commit; gotcha #12 (GUT mente verde) é manual | Stop hook que confere contagem de testes |
| Permissões: least-privilege | só read idempotente em auto; write/deploy pedem | ❌ Supabase DDL/deploy/SQL auto-aprovados em **prod compartilhada** | downgrade p/ `ask` |
| Permissões: escopo de Read | negar segredos; escopar ao projeto | ❌→✅ era `Read(//home/baltz/**)` (expôs `~/.ssh`); **corrigido** + `deny` | rotacionar a chave |
| Allow-list limpa | poucos comandos known-safe; preferir auto/sandbox | ✅ **corrigido** (~95→41, consolidado) | — |
| MCP: aprovação por servidor | allowlist só as tools usadas | ✅ **reconciliado** — `.mcp.json` só read-only; `add_node` removido do allow local | manter; revisar se entrar servidor remoto |
| Subagents | reviewer adversarial read-only; Explore p/ pesquisa | ❌ nenhum definido | adicionar (alavancagem com Opus) |
| ACI / saída de erro | erro ensina próximo passo | ⚠️ `make gate` despeja stack; gotcha #12 silencioso | gate que afirma "contagem subiu" |

---

## 4. Achados, por severidade

### 🔴 #1 — `Read(//home/baltz/**)` expôs a chave SSH privada *(SEGURANÇA — demonstrado)*
Durante esta sessão, conteúdo injetado disparou uma leitura de `~/.ssh/id_rsa` que
foi **auto-aprovada** pela regra `Read(//home/baltz/**)` — a "lethal trifecta" ao
vivo (dado privado + conteúdo não confiável da pesquisa web + canais de saída
disponíveis). O material da chave **não foi propagado, salvo nem transmitido**.
- **Corrigido:** `Read` escopado a `//home/baltz/caipora/**`; bloco `deny`
  adicionado (`.ssh`, `.aws`, `.gnupg`, `.config/gcloud`, `.netrc`, `.claude.json`,
  `*.env`, `*.pem`, `id_rsa`, `id_ed25519`, `cat ~/.ssh/*`). `deny` vence `allow`.
- **Recomendação ao usuário:** tratar a chave como **potencialmente exposta** e
  **rotacionar** (novo par, atualizar `authorized_keys`/GitHub, remover a antiga).
- Refs: [lethal-trifecta], [rule-of-two], [mcp-security], [cc-security].

### 🔴 #2 — O hook de pre-commit não bloqueava de fato
`pre-commit-gate.sh` rodava `make gate` e saía com o código do `make` (1 em falha).
No Claude Code atual, **só `exit 2` bloqueia** um `PreToolUse`; `exit 1` é
não-bloqueante → **o commit passava mesmo com o gate vermelho**.
- **Corrigido:** o hook agora sai com `2` + mensagem em stderr quando o gate falha;
  comandos que não são `git commit` passam direto (`exit 0`). Ref: [hooks].
- **Observação:** o `timeout` do hook em `settings.json` é 120s; se `make gate`
  (smoke+test) passar disso, o hook é morto e vira não-bloqueante — considere subir.

### 🟠 #3 — Tools de escrita do Supabase auto-aprovadas em banco de **produção compartilhado**
`mcp__supabase__{execute_sql,apply_migration,deploy_edge_function}` estão em `allow`.
A própria skill `supabase-db` avisa que o schema `public` tem **tabelas de terceiros**
que "NUNCA" devem ser tocadas. Auto-aprovar DDL/deploy/SQL arbitrário contraria o
princípio "nunca auto-aprove write/deploy" ([mcp-security A7]).
- **Recomendação (não aplicado — é trade-off de fluxo):** mover esses três para
  prompt por chamada (remover do `allow`, ou pôr em `ask`). Manter só os read-only
  (`get_project_url`, `get_publishable_keys`) em auto. Posso aplicar se você topar.

### 🟠 #4 — `AGENTS.md` raiz bloated; procedimentos de subsistema sempre-on
Gotchas #15–20 (balanceamento remoto, sequências de ataque, moves nomeados, Cortejo,
3 tiers, áudio OGG) são **procedimentos longos** amarrados a subsistemas específicos
(combate, áudio). Hoje custam ~tokens em **toda** sessão, mesmo editando arte.
- **Recomendação:** migrar para `.claude/rules/*.md` com `paths:` (carrega só ao
  tocar `scripts/entities/**`, `scripts/tools/gen_sfx.py`, etc.) e/ou skills
  (`combat-remote-config`, `audio-pipeline`). Manter no `AGENTS.md` só os fatos
  always-on (display, headless, UID, `.import`, tom, esquema de versão). Alvo: raiz
  enxuta < ~200 linhas. Ref: [memory], [skills], [context-engineering].

### 🟡 #5 — `session-orient` pré-carrega `PLAN.md` inteiro (~17K tok)
Contra "just-in-time". O passo 1 deveria puxar **só a seção do milestone atual**
(grep do header + range), não o arquivo todo. Ref: [context-engineering].

### 🟢 #6 — Auto-approve do Godot MCP *(reconciliado nesta sessão)*
`.mcp.json` foi enxugado para **5 tools read-only** (`get_debug_output`,
`stop_project`, `get_godot_version`, `list_projects`, `get_project_info`) — as
scene-mutating (`create_scene`/`add_node`/`save_scene`/`load_sprite`/
`export_mesh_library`/`update_project_uids`) saíram do auto-approve, alinhado ao
`AGENTS.md` ("Scene-mutating MCP tools are not auto-approved") e ao gotcha #7.
Restava um furo: `settings.local.json` ainda tinha `mcp__godot__add_node` no
`allow` (permissões **merge** entre escopos, aditivo) → **re-concederia** add_node
e anularia o `.mcp.json`. **Removido.** Padrão "blanket server approval" agora
fechado. Ref: [mcp-security A5/A7], gotcha #7.

### 🟢 #7 — Drift de skills *(corrigido)*
`.claude/skills/*` eram **cópias** (não symlinks) e **faltava `visual-identity`** —
ou seja, a skill da identidade visual não estava registrada para o Claude Code.
Agora são symlinks p/ `.agents/skills/`. **Verificar na próxima sessão** que
`/visual-identity` aparece na lista — alguns tools não seguem diretório symlinkado
([agents-md B6]); se não aparecer, o fallback é copiar ou usar `@import`.

### 🟢 #8 — Bloat de allow-list *(corrigido)*
~95 → 41 entradas; one-offs (screenshots com path fixo, zips versionados) removidos,
coringas seguros consolidados.

### 🟢 #9 — Sem subagents definidos *(oportunidade)*
Com Opus, subagents de **breadth paralelizável** rendem muito: um `reviewer`
adversarial **read-only** (sem Edit/Write) p/ revisar diff em contexto fresco, e um
`Explore` p/ pesquisa. Definir em `.claude/agents/*.md`. Ref: [sub-agents],
[multi-agent].

### ⚪ #10 — Cosméticos
Gotchas **#19 e #20 estão fora de ordem** no `AGENTS.md` (20 antes de 19). Links da
doc Anthropic no projeto apontam para `docs.anthropic.com` (agora 301 →
`code.claude.com`).

---

## 5. O que foi corrigido nesta sessão

| # | Mudança | Arquivo | Tracked? |
|---|---|---|---|
| 1 | `Read` escopado ao projeto + `deny` de segredos | `.claude/settings.local.json` | gitignored |
| 2 | Hook sai com `exit 2` (bloqueia de fato) | `.claude/hooks/pre-commit-gate.sh` | ✅ versionado |
| 3 | Skills viram symlink p/ `.agents/skills/` + registra `visual-identity` | `.claude/skills/*` | ✅ versionado |
| 4 | Allow-list ~95→40, consolidada | `.claude/settings.local.json` | gitignored |
| 5 | Removido `mcp__godot__add_node` do allow (alinha ao `.mcp.json` + gotcha #7) | `.claude/settings.local.json` | gitignored |
| 6 | **Downgrade Supabase**: `execute_sql`/`apply_migration`/`deploy_edge_function` saem do allow → prompt-por-chamada (prod compartilhada); só read-only em auto (Achado #3) | `.claude/settings.local.json` | gitignored |
| 7 | **Slim do `session-orient`**: lê só a seção de milestones do `PLAN.md` via grep de header, não o arquivo (~1000 linhas) — just-in-time (Achado #5) | `.agents/skills/session-orient/SKILL.md` | ✅ versionado |
| 8 | **`.claude/rules/`** path-scoped (Claude-only, não fragmenta o `AGENTS.md` cross-harness): `combat-timing`, `remote-config`, `audio` — auto-surgem ao tocar os arquivos do subsistema (Achado #4, parcial) | `.claude/rules/*.md` | ✅ versionado |
| 9 | **Guard do gotcha #12** reframado de Stop hook → **teste GUT** `test_every_test_file_compiles` (roda no gate; valida: verde no limpo, vermelho com arquivo quebrado) | `tests/unit/test_suite_integrity.gd` | ✅ versionado |

> **Sobre `.claude/rules/` vs mover os gotchas:** o mapeamento confirmou que o
> `.codex/` (Codex) lê o `AGENTS.md` nativamente mas **não** lê `.claude/rules/`.
> Logo, mover conteúdo dos gotchas para `.claude/rules/` **fragmentaria** a fonte
> única cross-harness. Decisão: `AGENTS.md` continua canônico/cross-harness; as
> `.claude/rules/` são **enhancement só do Claude Code** (ponteiros estáveis +
> comandos a rodar, sem números de gotcha porque a numeração está em fluxo).

---

## 6. Recomendações pendentes (priorizadas)

1. **Rotacionar a chave SSH** (Achado #1) — ação do usuário.
2. **Enxugar o `AGENTS.md` raiz** (Achado #4, parte restante) — **adiado de propósito**:
   o `AGENTS.md` está sendo editado ao vivo nesta sessão (gotchas renumerados p/ 1–21,
   #18 reescrito). Fazer agora colidiria. As `.claude/rules/` já surgem o essencial em
   edit-time; quando a curadoria dos gotchas estabilizar, condensar os blocos de
   subsistema (#15–20) para entradas curtas + ponteiro para os PRDs.
3. **Definir subagents** (`reviewer` read-only) (Achado #9) — opcional; hoje
   `/code-review` cobre o caso.
4. **Cosméticos**: reordenar gotchas #19/#20; atualizar links → `code.claude.com`
   (provavelmente já resolvido na curadoria em andamento do `AGENTS.md`).
5. **`.codex/` (Codex)**: o hook gêmeo sempre sai 0 (não bloqueia). Verificar se o
   protocolo de hook do Codex suporta bloqueio — fora do escopo desta revisão (você
   está editando `.codex/` em paralelo).

---

## Fontes

- [context-engineering] https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- [building-agents] https://www.anthropic.com/engineering/building-effective-agents
- [writing-tools] https://www.anthropic.com/engineering/writing-tools-for-agents
- [effective-harnesses] https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- [multi-agent] https://www.anthropic.com/engineering/multi-agent-research-system
- [skills] https://code.claude.com/docs/en/skills · https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
- [memory] https://code.claude.com/docs/en/memory
- [hooks] https://code.claude.com/docs/en/hooks
- [sub-agents] https://code.claude.com/docs/en/sub-agents
- [settings] https://code.claude.com/docs/en/settings
- [cc-security] https://code.claude.com/docs/en/security
- [mcp-security] https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices
- [lethal-trifecta] https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/
- [rule-of-two] https://ai.meta.com/blog/practical-ai-agent-security/
- [agents-md] https://agents.md/ · https://www.ssw.com.au/rules/symlink-agents-to-claude
