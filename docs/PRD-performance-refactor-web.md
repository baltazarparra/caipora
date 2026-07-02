# PRD — Refactor de Performance Web: carga enxuta, 60fps honesto

> **Status:** Proposta · **Autor:** baltz (com Claude) · **Data:** 2026-07-02
> **Sucede:** `docs/PLANO-performance-60fps.md` (auditoria 2026-06-10) — este PRD
> herda o que lá ficou pendente, corrige o que a re-auditoria de 2026-07-02
> reavaliou e incorpora gargalos NOVOS surgidos depois (UI unificada, grading).
> **Fontes verificadas no código:** `export_presets.cfg`,
> `scripts/utils/constants.gd`, `scripts/ui/atmosphere.gd`,
> `assets/shaders/gradient_map.gdshader`, `scripts/ui/timing_bubble.gd`,
> `scripts/ui/combat_arrow_button.gd`, `scripts/ui/title_treeline.gd`,
> `scripts/ui/title_walker.gd`, `scripts/ui/doom_fire.gd`,
> `scripts/exploration/ambient_life.gd`, `scripts/ui/health_bar.gd`,
> `scripts/hub/exit_beacon.gd`, `scripts/ui/perf_hud.gd`, `export/index.pck`.
> **Medições ao vivo:** `/play` em 2026-07-02, Chrome desktop DPR 1,
> `?perf` + amostragem de rAF (240 frames/cenário).

---

## 1. Contexto e problema

O caipora é **browser-first**: o alvo declarado é 60fps sustentado no export
HTML5 com piso de hardware Android de entrada + iPhone Safari (PLANO §1), e o
gotcha #5 manda manter o load pequeno. A auditoria de junho resolveu 6 dos 10
gargalos (pooling, backdrop estático, DPR cap, ambient 20Hz, god rays,
material aditivo único). Mesmo assim, a medição ao vivo de hoje mostra que
**ainda não cumprimos nenhuma das duas promessas**:

| Cenário medido (build `alpha-0.1.642`) | Resultado | Veredito |
|---|---|---|
| Menu, Chrome **desktop** | 53–58 fps · p95 33,4ms · **13% dos frames > 20ms** | reprova já no melhor hardware |
| Menu, CPU 4x (proxy Android médio) | 42 fps · pior frame 50ms | reprova |
| Hub parado / andando | 59–60 fps / 55–57 fps (p95 20,4ms) | passa raspando |
| Primeira carga | **~22,6MB no fio** (wasm 9,6MB gz + pck 13MB) | pesado para itch/4G |
| Exploração P3 · Arenas P1–P5 · frame de crítico | **sem medição** | Fase 0 do PLANO nunca foi concluída |

Os três problemas de fundo, por ordem de gravidade:

1. **O pck embarca ~71% de lixo não-runtime.** `export_presets.cfg` está com
   `export_filter="all_resources"` e `exclude_filter=""` (vazio). Dentro do
   `index.pck` (13,37MB): `site/assets` = **7,91MB** (38 screenshots/strips da
   landing — que o `deploy.yml` JÁ serve crus na raiz do Pages, ou seja,
   duplicados), `addons/gut` = **0,95MB** (fontes Lobster/AnonymousPro/Courier
   do framework de teste), `tests/` + `scripts/tools/` tokenizados, contact
   sheets de QA. O conteúdo é `.ctex` já-comprimido: gzip não ajuda — é
   transferência real desperdiçada em TODA primeira visita.
2. **O grading fullscreen com `SCREEN_TEXTURE` está ligado no web sem a
   medição que era pré-condição.** `Constants.GRADING_ON_WEB := true`
   (`constants.gd:34`) habilita o `gradient_map.gdshader`
   (`hint_screen_texture`, o passe mais caro que existe em GL
   Compatibility/GPU mobile tiled) como 2ª camada fullscreen em toda tela —
   3ª na exploração P3 (com `fog_reveal`). Foi ligado em 2026-06-11 com "medir
   FPS no iPhone" como pendência; a medição nunca aconteceu.
3. **Draw imediato redundante nos momentos errados.** Durante a **janela de
   timing** (o momento mais sensível a latência do jogo), `TimingBubble` e
   `CombatArrowButton` redesenham **o mesmo glifo Garra Tribal 16×16
   célula-a-célula** (~50 `draw_rect` cada, ~120 primitivas/frame somadas). No
   **menu** (sempre ligado, primeira impressão), `title_treeline.gd:68`
   re-grava ~284 primitivas/frame à toa — o scroll é por `position` e o vento
   é vertex shader; a geometria nunca muda — e o DoomFire pulsa a cada 5
   frames web, o que casa com os 13% de frames estourados medidos.

**Fatos confirmados na re-auditoria** (corrigem suposições do PLANO antigo):

- **G10 (áudio WAV) despencou de prioridade.** O Godot 4.6 importa WAV como
  **QOA**: os 8,39MB de WAV fonte viram **2,51MB** no pck. Migração OGG segue
  no PRD-audio-v5 por qualidade/loop — **não é mais item de perf**.
- **O hot path está limpo.** Zero alocação por frame, zero tween vazando,
  12 autoloads 100% event-driven (PerfHud desligado = `set_process(false)`),
  `JavaScriptBridge.eval` só por evento, boot sem preload pesado (áudio 100%
  lazy). Não gastar sessão re-auditando isso.
- **O wasm (36MB / ~9,6MB gz) é o template stock 4.6.3** já minimizado
  (`extensions_support=false`, `thread_support=false`). Corte real = template
  custom com build profile — projeto à parte, fora deste PRD.
- **O modo HD foi 100% revertido** (`8ef6682`); a baseline "leve" é a que
  reprova acima. Não há gordura de HD para cortar — o problema é estrutural.

## 2. Objetivos / Não-objetivos

**Objetivos**

- **O1 (carga).** Primeira visita ≤ **14MB no fio** (pck ≤ 4,5MB), sem perder
  nenhum asset de runtime. Repeat visit continua instantânea via PWA.
- **O2 (fps).** Menu a **60fps com p95 ≤ 16,7ms em desktop** (hoje 33,4ms) e
  mensurável ≥ 55fps sob CPU 4x. Janela de timing sem redraw de glifo
  célula-a-célula (~120 → ≤ 20 primitivas/frame nos dois widgets).
- **O3 (verdade sobre o grading).** Decidir `GRADING_ON_WEB` com medição A/B
  em device real — manter só se o custo couber no orçamento; senão, entregar o
  mesmo look por caminho barato (bake na paleta).
- **O4 (disciplina).** `docs/REPORT-performance.md` criado e preenchido
  (Fase 0 do PLANO, nunca concluída): menu, exploração P1/P3, arena P5, frame
  de crítico — desktop + iPhone Safari + Android de referência.
- **O5 (tom).** Zero regressão visual/tonal. O fogo continua queimando, o
  sangue continua espirrando — só que mais barato (princípio herdado do PLANO).

**Não-objetivos**

- Migração OGG de música/ambience (vive no PRD-audio-v5; motivação é áudio,
  não perf).
- Template wasm custom / build profile do engine (registrar como follow-up;
  não bloqueia nada deste PRD).
- Reintroduzir modo HD ou qualquer variação de qualidade por flag.
- Mexer em gameplay, timing de combate ou economia (as janelas/faixas do
  gotcha #19 são intocáveis aqui).
- Threads/COOP/COEP no Pages (impossível na plataforma; `thread_support`
  permanece `false`).

## 3. Decisões de design

| # | Decisão | Detalhe |
|---|---------|---------|
| D1 | **Export embarca só runtime** | `exclude_filter` explícito no preset Web. A landing (`site/`) já é servida crua pelo Pages; testes/addons/tools/QA-sheets nunca são carregados por `.gd`/`.tscn` de runtime. |
| D2 | **Nenhum passe `SCREEN_TEXTURE` no web sem medição que o aprove** | O grade só permanece se o A/B em device (O4) provar que cabe; senão o look é **cozido na paleta** — a arte é flat de paleta fechada (identidade visual), então o grade é pré-aplicável offline às cores das camadas, eliminando o passe inteiro. |
| D3 | **Glifo desenhado 1x, nunca por frame** | A Garra Tribal 16×16 vira `ImageTexture` gerada uma vez (mesmos pixels, mesma identidade); `TimingBubble`/`CombatArrowButton` passam a `draw_texture` + `modulate`. Pulso/rotação continuam por transform/cor — nada do feel muda. |
| D4 | **`queue_redraw()` só quando a geometria muda** | Transform (`position`, `modulate`, vertex shader) nunca justifica re-gravar `_draw`. Vale para treelines/walker do menu e é a regra permanente do projeto (candidata a gotcha). |
| D5 | **Toda partícula ambiente respeita `Constants.particle_amount_scale`** | O código novo (santuário, moves, fúria) já respeita; os legados que ignoram (`FIREFLY_COUNT=60`, auras fixas de inimigo 12–28) entram na regra. Densidade cheia em desktop, degradação digna em phone. |

## 4. Requisitos funcionais

**Frente A — Export enxuto (D1)**

- **RF-A1.** `export_presets.cfg` ganha
  `exclude_filter="site/*, addons/*, tests/*, scripts/tools/*, assets/sprites/*_contact_sheet.png, assets/sprites/*_value_sheet.png"`.
- **RF-A2.** `make export` continua verde; o export bota e roda (menu → hub →
  exploração → arena) servido localmente; **nenhum** load de runtime falha.
- **RF-A3.** pck resultante ≤ 4,5MB (medir e registrar no REPORT).
- **RF-A4.** O zip do itch (`export/` commitado) reflete o mesmo corte.

**Frente B — Grading web (D2)**

- **RF-B1.** Medir A/B com `?perf` em device real (iPhone Safari + Android de
  referência): mesma cena, `GRADING_ON_WEB` true vs false. Registrar no REPORT.
- **RF-B2.** Se o custo estourar o orçamento (p95 > 16,7ms atribuível ao
  passe): `GRADING_ON_WEB := false` **e** grade equivalente cozido na paleta
  por fase (offline, nos valores de cor das camadas/CanvasModulate). Diff
  visual A/B por screenshot arquivado — aprovação a olho antes do merge.
- **RF-B3.** O caminho `GRADING_ENABLED` nativo/desktop permanece intacto.
- **RF-B4.** Carona barata (item 2.2 do PLANO, ainda válido): vinheta do
  `atmosphere.gdshader` via textura radial pré-cozida (1 tap) no lugar de
  `distance()` por fragmento; grain via textura de ruído tileable scrollada
  por TIME no lugar de hash por pixel.

**Frente C — Draw do combate (D3)**

- **RF-C1.** Glifo 16×16 renderizado uma vez para `ImageTexture`
  (compartilhada; candidata a viver ao lado de `Constants.ADDITIVE_MATERIAL`).
- **RF-C2.** `TimingBubble._draw`/`_draw_charge` e `CombatArrowButton._draw`
  usam a textura; soma dos dois ≤ 20 primitivas/frame durante janela ativa.
- **RF-C3.** Comportamento intocado: mesmas cores por estado, mesmo pulso,
  mesmos sinais/haptics/SFX. `/validate-controls` obrigatório (gotcha #9/#19).

**Frente D — Menu 60fps (D4)**

- **RF-D1.** Remover `queue_redraw()` por frame de `title_treeline.gd:68` e
  `title_walker.gd:63` (geometria estática; scroll/bob são transform).
- **RF-D2.** DoomFire do menu: reduzir custo mantendo a leitura (opções em
  ordem de preferência: área de simulação menor atrás do skyline; cadência
  web 5→6/8 frames com crossfade; pausar quando coberto por painel). Aceite a
  olho: o fogo continua vivo e ameaçador.
- **RF-D3.** Menu desktop pós-frente: p95 ≤ 16,7ms, < 1% de frames > 20ms
  (amostragem de 240 frames, protocolo do REPORT).

**Frente E — Misc de custo baixo (D5 + sobras)**

- **RF-E1.** `ambient_life.gd`: `FIREFLY_COUNT` escalado por
  `particle_amount_scale`; auras fixas de inimigo idem (12–28 → escalado).
- **RF-E2.** `health_bar.gd`: pulso de HP baixo sem redesenhar ~35 `draw_line`
  por frame (ticks pré-gravados; pulso via `modulate`).
- **RF-E3.** `exit_beacon.gd`: `queue_redraw` só quando off-screen (o
  `draw_string` por frame sai do caminho on-screen).
- **RF-E4.** Service worker: desligar `ENSURE_CROSSORIGIN_ISOLATION_HEADERS`
  (threads off ⇒ reembrulho de toda Response é overhead puro).

**Frente 0 — Medição (transversal, primeira e última)**

- **RF-01.** Criar `docs/REPORT-performance.md` com a matriz do PLANO §3:
  cenários (menu / exploração P1 e P3 / arena P5 em combate / frame de
  crítico) × devices (desktop controle / iPhone Safari / Android de entrada,
  proxy CPU 4x–6x quando sem device). Preencher ANTES da primeira frente e
  DEPOIS de cada uma.
- **RF-02.** Protocolo padrão: `?perf` (PerfHud: fps/med/p95/draw calls) +
  amostragem rAF de 240 frames; no live, sempre com query-string ou SW
  atualizado (gotcha #24e).

## 5. Critérios de aceite (definition of done)

1. Primeira carga ≤ 14MB no fio; pck ≤ 4,5MB; export bota e completa um loop
   menu→hub→exploração→arena→morte sem erro de load.
2. Menu desktop: 60fps, p95 ≤ 16,7ms, < 1% frames > 20ms. Sob CPU 4x: ≥ 55fps.
3. Janela de timing: ≤ 20 primitivas/frame nos dois widgets; `draw calls` do
   PerfHud em combate estável ou menor; feel intacto (`/validate-controls`).
4. Decisão do grading tomada COM números de device no REPORT (manter ou bake);
   screenshots A/B arquivados provando equivalência visual.
5. `docs/REPORT-performance.md` preenchido baseline + pós-frentes.
6. `make gate` verde em todo commit; zero regressão de tom (O5).

## 6. Implementação por arquivo

| Frente | Arquivo | Mudança |
|---|---|---|
| A | `export_presets.cfg` | `exclude_filter` (RF-A1) |
| B | `scripts/utils/constants.gd:34` | `GRADING_ON_WEB` conforme A/B |
| B | `scripts/ui/atmosphere.gd` / paletas por fase | bake do grade se RF-B2 |
| B | `assets/shaders/atmosphere.gdshader` | vinheta/grain por textura (RF-B4) |
| C | novo helper (ex. `scripts/ui/kit/` ou `Constants`) | textura única do glifo |
| C | `scripts/ui/timing_bubble.gd`, `scripts/ui/combat_arrow_button.gd` | `draw_texture` no lugar dos loops 16×16 |
| D | `scripts/ui/title_treeline.gd:63-68`, `scripts/ui/title_walker.gd:60-63` | remover redraw por frame |
| D | `scripts/ui/doom_fire.gd`, `scripts/ui/main_menu.gd` | custo do fogo no menu (RF-D2) |
| E | `scripts/exploration/ambient_life.gd:150`, auras em `scripts/entities/*` | escala de partículas |
| E | `scripts/ui/health_bar.gd`, `scripts/hub/exit_beacon.gd` | redraw condicional |
| E | template/config do SW | RF-E4 |
| 0 | `docs/REPORT-performance.md` (novo) | matriz + números |

## 7. Rollout / faseamento (uma sessão por item — protocolo do projeto)

1. **S1 = Frente 0 (baseline) + Frente A.** Medir antes; aplicar
   `exclude_filter`; validar export; registrar pck/fio no REPORT. Maior ganho
   por linha de código do PRD; risco mínimo.
2. **S2 = Frente C** (glifo) + RF-D1 (redraws do menu, carona trivial).
   `/validate-controls` + `make gate`.
3. **S3 = Frente B** (A/B do grading em device → decisão → implementação).
   Exige device real; é a sessão com mais incerteza — por isso depois do
   baseline, antes das micro-otimizações.
4. **S4 = RF-D2/D3** (DoomFire do menu) — só se o menu ainda reprovar depois
   de S2/S3 (pode já ter passado).
5. **S5 = Frente E** (misc) + REPORT final preenchido.

Cada sessão: commit próprio, gate verde, números antes/depois no REPORT.

## 8. Riscos

| Risco | Mitigação |
|---|---|
| `exclude_filter` remover algo que um `.gd` carrega por string em runtime | RF-A2 exige loop completo de jogo no export; grep por `load("res://site`/`addons`/`tests` antes (hoje: zero) |
| Bake do grade divergir do look atual | Screenshots A/B por fase arquivados; aprovação a olho ANTES do merge; `GRADING_MIX` vira referência do bake |
| Glifo por textura mudar o feel do combate | Pixels idênticos por construção (mesma rotina gera a textura); `/validate-controls`; gotcha #19 intacto (faixas/sinais não são tocados) |
| Bake na paleta conflitar com `feedback_gain_for_phase` (recíproco do CanvasModulate) | Tratar o gain junto do bake na S3; teste visual nas fases 3–5 |
| DoomFire mais barato desidratar o menu | O5 é critério de aceite; iterar com screenshot lado a lado (é fundo atrás de céu com alpha) |
| Medição em WSL/desktop mentir sobre mobile | REPORT exige device real p/ decisões (grading); desktop é só controle |

## 9. Questões em aberto

1. **Qual é o Android de referência disponível?** (PLANO citava Moto G8/Redmi
   9 como classe-alvo; sem device físico, CPU 6x no Chrome é o proxy aceito.)
2. A aba do jogo **morreu uma vez** durante navegação no hub via automação
   (2026-07-02, não reproduzido). Vigiar em teste manual; se reproduzir, abrir
   Known Issue no PLAN.md.
3. Exploração P3 e arena P5 seguem sem número — a S1 fecha essa lacuna e pode
   reordenar S3/S4 se P3 (3 passes fullscreen) reprovar feio.
4. Follow-up fora do PRD: template wasm custom (build profile sem 3D/nav/
   multiplayer) para atacar os ~9,6MB gz restantes do engine.
