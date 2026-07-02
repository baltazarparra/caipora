# Report de Execução — Refactor de Performance Web

> **Status:** Em execução · **Data de início:** 2026-07-02
> **PRD de origem:** `docs/PRD-performance-refactor-web.md` (commit 57ef1d7)
> **Antecessor:** `docs/PLANO-performance-60fps.md` (auditoria 2026-06-10; Fase 0 concluída AQUI)
> **Protocolo de medição (RF-02):** overlay `?perf` (PerfHud: fps · med · p95 · draw calls · nodes,
> janela ~2s) + amostragem rAF de 240 frames (avg/p50/p95/worst/frames>20ms) via DevTools.
> No live: SEMPRE query-string nova ou banner "Atualizar" aceito (SW cache-first, gotcha #24e).

---

## 1. Objetivo

Cumprir os aceites do PRD §5: primeira carga ≤ 14MB no fio (pck ≤ 4,5MB); menu desktop
60fps com p95 ≤ 16,7ms e <1% frames >20ms; ≤ 20 primitivas/frame nos widgets da janela
de timing; decisão do grading web COM números de device; zero regressão de tom.

## 2. Matriz de medição (cenário × device)

Valores `med / p95` em ms (PerfHud) salvo indicação. ⏳ = pendente.

### 2.1 Baseline (build 642, pré-refactor, 2026-07-02)

| Cenário | Desktop Chrome (DPR 1) | Desktop CPU 4x | iPhone Safari | Android |
|---|---|---|---|---|
| Menu | 52,9fps · p50 16,7 · p95 33,4 · **13% frames >20ms** (rAF 240f) | 42fps · p95 33,4 · worst 50,1 | ⏳ (S3) | ⏳ (S3) |
| Hub parado | 59-60fps · med 16,7-17,1 · p95 16,7-18,1 · draw 162-176 | — | ⏳ | ⏳ |
| Hub andando | 55-57fps · p95 até 20,4 | — | ⏳ | ⏳ |
| Exploração P1 | ⏳ (loop manual S1) | — | ⏳ (S3) | ⏳ (S3) |
| Exploração P3 (fog) | ⏳ (loop manual S1) | — | ⏳ | ⏳ |
| Arena P1 em combate | ⏳ (loop manual S1) | — | ⏳ (S3) | ⏳ (S3) |
| Arena P5 + frame de crítico | ⏳ (loop manual S1) | — | ⏳ | ⏳ |

**Carga (build 642, GitHub Pages, cache frio):** wasm 9.575.393 B gz (35,95MB raw) +
pck 12.956.284 B gz (14.021.968 B raw, ~8% de compressão — conteúdo .ctex/QOA) +
index.js ~316KB ⇒ **~22,6MB no fio**. Draw calls: menu 145 · hub 162-176. Nodes: 98.

### 2.2 Após S1 (export enxuto) — 2026-07-02 ✅

| Métrica | Antes | Depois |
|---|---|---|
| `index.pck` (bytes) | 14.021.968 | **3.866.092 (−72%)** |
| Entradas reais de paths excluídos no pck (parser GDPC v3) | site 38 · gut ~271 · tests ~209 · tools 28 | **0** (989 entradas, todas runtime) |
| Primeira carga no fio (wasm gz + pck gz) | ~22,6MB | ⏳ confirmar no live pós-deploy (esperado ~13,6MB) |
| SW re-embrulha Responses (COOP/COEP com threads off) | sim | **não** (`ENSURE_CROSSORIGIN_ISOLATION_HEADERS=false`, sed pós-export no Makefile) |

Nota de método: o grep bruto por `res://<path>` no pck acha strings residuais nos blobs de
metadados (uid cache / cache de classes globais) — inofensivas. A auditoria válida é por
ENTRADAS do diretório GDPC v3 (script `pck_ls.py`, dir_offset no header). Smoke local
(porta nova, sem SW): menu e hub carregam com zero erros de console; matriz de plataformas
(393×852 / 852×393 / 820×1180) renderiza correta; manifest `orientation: any`. Loop
completo menu→arena→morte: checagem manual do usuário (servidor local em `:8765`).

### 2.3 Após S2 (glifo cacheado + menu sem redraw redundante)

| Métrica | Antes | Depois |
|---|---|---|
| Primitivas/frame na janela de timing (bolha + botão ativo) | ~120 (2× glifo célula-a-célula) | ⏳ (aceite: ≤ 20) |
| Menu desktop (rAF 240f) | p95 33,4 · 13% >20ms | ⏳ |
| Draw calls em combate (PerfHud) | ⏳ (capturar antes) | ⏳ (estável ou ↓) |

### 2.4 S3 — A/B do grading (Δp95 = grade1 − grade0, mesma cena/device)

| Cenário | iPhone Safari Δp95 | Android Δp95 |
|---|---|---|
| Menu | ⏳ | ⏳ |
| Exploração P1 | ⏳ | ⏳ |
| Arena P1 em combate | ⏳ | ⏳ |

**Régua pré-acordada:** Δp95 ≤ ~1,5ms nos dois devices e nenhum cenário < 55fps por
causa do grade ⇒ mantém. Senão: desligar; aproximação bounded só se o diff visual
(screenshots A/B) justificar.

### 2.5 Após S4/S5 e fechamento

⏳ — matriz final completa + repasse item a item do PRD §5.

## 3. Decisões tomadas durante a execução

1. **RF-E4 movido da Frente E para a S1** — o SW é regenerado a cada export; o patch
   é um `sed` idempotente pós-export no Makefile (mesmo alvo de arquivo da Frente A).
2. **RF-B2 corrigido: bake literal na paleta é inviável** — o grade remapeia por
   luminância do frame COMPOSITADO (LUT por fase; sprites compartilhados entre fases).
   Caminho real: desligar + aproximação bounded (~10 CanvasModulate + PHASE_STYLE +
   `FEEDBACK_GAIN_BY_PHASE` re-derivado), e só se o diff visual justificar.
3. **Frente C usa máscaras por papel (BRIGHT/DARK/OUTLINE + BODY)** — os 3 papéis do
   glifo são recoloridos independentemente e o alpha do papel escuro difere entre
   widgets; textura única com modulate não reproduz o tom.

## 4. Problemas encontrados

- (2026-07-02, auditoria) Aba do Chrome caiu 1x durante navegação automatizada no hub;
  não reproduzido. Vigiar em teste manual.

## 5. Commits

| Frente | Commit | Descrição |
|---|---|---|
| — | 57ef1d7 | PRD |
| S1 | ⏳ | baseline + REPORT; export enxuto + patch SW |

## 6. Referências

- `docs/PRD-performance-refactor-web.md` · `docs/PLANO-performance-60fps.md`
- Plano de execução: `~/.claude/plans/steady-popping-harbor.md` (aprovado 2026-07-02)
