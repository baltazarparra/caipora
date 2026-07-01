# PRD — Acampamento Premium & Paridade i18n

**Data:** 2026-06-30
**Status:** Proposta
**Norte visual:** `docs/CONCEITO-protagonista.md` + `.agents/skills/visual-identity/SKILL.md`
**Referência de qualidade:** Hollow Knight — HUD mínimo, legível, sem gordura.
**Alvo primário:** Android fraco, navegador, **modo retrato**.
**Escopo:**
- **Parte A (i18n, projeto inteiro):** `scripts/core/scene_transition.gd`,
  `scripts/utils/constants.gd`, `scripts/hub/exit_beacon.gd`,
  `scripts/arena/arena_manager.gd`, `scripts/ui/ending_screen.gd`,
  `scripts/ui/ending_sacrifice_screen.gd`, `scenes/ui/win.tscn`,
  `scripts/core/lang_pt.gd` / `lang_en.gd`, novo `tests/unit/test_i18n_parity.gd`.
- **Parte B (acampamento):** `scripts/hub/hub_shop.gd`, `scripts/hub/hub_card.gd`,
  `scripts/ui/fragment_counter.gd` (reuso), `scripts/core/lang_pt.gd` / `lang_en.gd`,
  testes de hub afetados.

**Relação com outras frentes:** coordena com `PRD-tela-inicial-v3.md` (o ícone de
SOM que substitui "Opções" no cabeçalho do acampamento — R8 de lá — divide o
cabeçalho com o contador de Terra Rara desta PRD). Herda a lei de HUD de
`PRD-fase-9-hub-jogavel.md` (cards na faixa superior, centro livre pro acampamento).

---

## 1. Visão

Duas dívidas atacam a mesma promessa — uma experiência premium e coerente:

1. **Vazamento de idioma.** O jogo tem um sistema de localização (`Lang`), mas
   frases user-facing estão **cravadas em português no código**, fora do `Lang` —
   então aparecem em pt-BR mesmo com o jogo em inglês. O caso reportado ("o
   acampamento respira...") é um de **nove**. Num produto premium, trocar o idioma
   e ver português vazando quebra a confiança na primeira tela.
2. **HUD amador no acampamento.** O cabeçalho escreve "Terra Rara: %d" em texto;
   as trilhas se chamam "FÚRIA · dano" / "CURA · vida"; os cards carregam nome de
   erva, ícone de erva, efeito e um custo "50 TR"; e trilhas sem card mostram
   legendas como "próxima: Chaga-da-Mata — na próxima fogueira". É informação
   demais, ruído demais, para uma decisão que é simples: *gastar Terra Rara em
   mais dano ou mais vida*.

> **Norte:** o jogador entende a tela em meio segundo. Um número com um ícone
> claro de Terra Rara; duas colunas, DANO e VIDA; um card que diz só o que
> importa — **+2 dano** e **quanto custa**. E, em qualquer idioma, **nada** de
> texto vazando na língua errada.

---

# Parte A — Paridade i18n (correção de projeto inteiro)

## A0. Diagnóstico

O `Lang` (`scripts/core/lang.gd`) carrega `STRINGS` de `lang_pt.gd` ou `lang_en.gd`
e resolve via `Lang.t(&"chave")` / `Lang.tf(&"chave", [args])`. Os **dois
dicionários já têm o mesmo conjunto de chaves** — a simetria de chaves não é o
problema. O problema é texto user-facing que **nunca vira chave**: fica hardcoded
e some do radar da tradução.

## A1. Achados da auditoria (9 casos)

**Tipo A — string hardcoded exibida, precisa de chave nova (pt + en):**

| # | Arquivo:linha | String | Onde aparece |
|---|---|---|---|
| 1 | `scene_transition.gd:16` | `"a mata se reorganiza..."` (`THEMED_TEXT`) | Flavor de transição entre fases |
| 2 | `scene_transition.gd:17` | `"o acampamento respira..."` (`CAMP_TEXT`) | Flavor de transição pro acampamento |
| 3 | `constants.gd:166` | `"Garra Rubra"` (`CAIPORA_MOVE_NORMAL.name`) | Nome do golpe na arena (`spawn_move_name`) |
| 4 | `constants.gd:167` | `"Açoite do Cipó"` (`CAIPORA_MOVE_DOUBLE.name`) | Nome do golpe na arena |
| 5 | `constants.gd:168` | `"Batuque do Cortejo"` (`CAIPORA_MOVE_CORTEJO.name`) | Nome do golpe na arena |
| 6 | `exit_beacon.gd:14` | `"rastro"` (`LABEL`, via `draw_string`) | Rótulo da seta pro rastro de saída do hub |
| 7 | `arena_manager.gd:574` | `"BOM"` (`spawn_move_name`) | Callout do acerto GOOD no combate |

**Tipo B — `const` morto que duplica chave existente (deletar o const):**

| # | Arquivo:linha | String | Chave que já existe |
|---|---|---|---|
| 8 | `ending_screen.gd:9` | `SKY_MESSAGE` | `&"ending.sky"` (a tela já usa a chave) |
| 9a | `ending_sacrifice_screen.gd:15` | `MESSAGE_1` | `&"sacrifice.msg1"` (já usa a chave) |
| 9b | `ending_sacrifice_screen.gd:16` | `MESSAGE_2` | `&"sacrifice.msg2"` (já usa a chave) |

**Inconsistência de cena:**

- `win.tscn:34` — `text = "Espaço para voltar ao acampamento"`, **texto morto**:
  em runtime `end_screen.gd` sobrescreve com `Lang.t(&"end.hint.key")` ("Espaço
  para voltar ao menu"). O `.tscn` fica com string errada e não localizada.

## A2. Requisitos

### RA1 — Rotear todo texto Tipo A pelo `Lang`

Criar chaves novas em **ambos** os dicionários e trocar o uso hardcoded por
`Lang.t`/`tf`. Chaves propostas:

| Chave | pt-BR | en-US (sugerido) |
|---|---|---|
| `transition.themed` | `"a mata se reorganiza..."` | `"the woods rearrange..."` |
| `transition.camp` | `"o acampamento respira..."` | `"the camp breathes..."` |
| `move.caipora.normal` | `"Garra Rubra"` | ver D1 (nome próprio) |
| `move.caipora.double` | `"Açoite do Cipó"` | ver D1 |
| `move.caipora.cortejo` | `"Batuque do Cortejo"` | ver D1 |
| `hub.exit.trail` | `"rastro"` | `"trail"` |
| `combat.timing.good` | `"BOM"` | `"GOOD"` |

- `scene_transition.gd`: `THEMED_TEXT`/`CAMP_TEXT` deixam de ser `const` e passam
  a resolver por `Lang.t` **no momento de exibir** (`_flavor_for`/`_run`), para
  respeitar troca de idioma em runtime.
- `constants.gd`: os nomes de golpe da Caipora vivem em `CAIPORA_MOVE_*` (gotcha
  #17). Guardar a **chave** i18n no dict (ex.: `"name_key": &"move.caipora.normal"`)
  e resolver via `Lang.t` no consumidor (`arena_manager` antes do
  `spawn_move_name`), mantendo o contrato do modelo Pokémon. Não reintroduzir
  mecânica do Cortejo (gotcha #18) — aqui é só o rótulo.
- `exit_beacon.gd`: `draw_string` passa a usar `Lang.t(&"hub.exit.trail")`;
  reagir a `language_changed` com `queue_redraw`.
- `arena_manager.gd:574`: `"BOM"` → `Lang.t(&"combat.timing.good")`.

**Aceite:** com o jogo em inglês, nenhuma das 7 strings aparece em português; a
troca de idioma em runtime reflete no próximo uso.

### RA2 — Remover consts mortos (Tipo B) e o texto morto da cena

- Deletar `SKY_MESSAGE` (`ending_screen.gd`), `MESSAGE_1`/`MESSAGE_2`
  (`ending_sacrifice_screen.gd`) — as telas já usam as chaves corretas.
- `win.tscn:34`: alinhar o texto do `.tscn` à chave que o runtime aplica
  (`end.hint.key`) **ou** limpar para vazio (o `end_screen.gd` seta em `_ready`).
  Edição de cena com `git diff` conferido (gotcha 7). Preferir esvaziar: menos
  chance de o `.tscn` divergir de novo.

**Aceite:** nenhum `const` de texto morto duplicando chave; `win.tscn` sem string
pt hardcoded divergente.

### RA3 — Trava de regressão: teste de paridade de chaves

Novo `tests/unit/test_i18n_parity.gd` (GUT):

- Carrega `STRINGS` de `lang_pt.gd` e `lang_en.gd`.
- Assert: **conjuntos de chaves idênticos** (diferença simétrica vazia — falha
  listando as chaves órfãs de cada lado).
- Assert: nenhum valor vazio em nenhum dos dois.
- (Opcional) Assert: as chaves novas de RA1 existem nos dois.

Impede que o bug volte: qualquer chave nova só em pt (ou só em en) quebra o gate.
Gotcha #12: rodar `make import` antes de `make test` e conferir que o total de
testes **subiu**.

**Aceite:** `test_i18n_parity` verde; remover uma chave de um dos lados quebra o
teste (verificado).

---

# Parte B — Acampamento Premium

## B0. Diagnóstico do HUD atual

| Elemento | Hoje | Problema |
|---|---|---|
| Contador de Terra Rara | `_frag_label` = `"Terra Rara: %d"` (texto) | Verboso; já existe `FragmentCounter` (ícone + número) usado no HUD de combate — o hub não o usa. |
| Trilhas | "FÚRIA · dano" / "CURA · vida" | Jargão + pontuação; a decisão é DANO vs VIDA. |
| Card | 2 linhas: [ícone erva + NOME] / [efeito + "50 TR"] | Informação demais para uma escolha simples; custo em texto "TR". |
| Trilha esgotada/travada | "próxima: Chaga-da-Mata — na próxima fogueira", "trilha completa" | Legenda técnica que ninguém precisa ler; polui a faixa. |

## B1. Requisitos

### RB1 — Contador de Terra Rara por ícone

Trocar o `_frag_label` (texto "Terra Rara: %d") pelo widget **`FragmentCounter`**
(`scripts/ui/fragment_counter.gd`) — ícone `terra_rara_icon.png` + número, com o
"pop" ao crescer. É o mesmo widget do HUD de combate: consistência e reuso, custo
zero de asset novo.

- `hub_shop.gd`: no cabeçalho, `FragmentCounter.new()` no lugar do `_frag_label`;
  `refresh()` chama `set_count(int(MetaProgression.fragments))` em vez de escrever
  a string; `configure_size()` acompanha o tamanho responsivo (`_apply_safe_margins`).
- Chave `hub.fragments` ("Terra Rara: %d") fica **sem uso** → remover dos dois
  dicionários (some o "%d" e o texto).

**Aceite:** o cabeçalho mostra o ícone de Terra Rara + o número, sem a palavra
"Terra Rara"; o número faz "pop" ao ganhar Terra Rara; largura ~constante.

### RB2 — Rótulos de trilha: DANO / VIDA

- `hub.track.furia`: `"FÚRIA · dano"` → **`"DANO"`** | en `"FURY · damage"` → `"DAMAGE"`.
- `hub.track.cura`: `"CURA · vida"` → **`"VIDA"`** | en `"HEAL · life"` → `"LIFE"`.
- `hub_shop.gd` já lê essas chaves nos headings — só muda o valor. Manter o
  âmbar/FONT_MD e a centralização.

**Aceite:** as duas colunas se chamam DANO e VIDA (DAMAGE/LIFE em inglês).

### RB3 — Card ultra-simples (uma linha)

Decisão do usuário (confirmada): **remover nome e ícone da erva**. O card vira
**uma linha**:

```
┌───────────────────────────┐
│  +2 dano        🟧 50      │   🟧 = ícone de Terra Rara
└───────────────────────────┘
```

- Esquerda: `MetaProgression.effect_short(key)` — já devolve `"+N dano"` / `"+N HP"`
  (chaves `card.effect.dmg.short`/`card.effect.hp.short`, intocadas).
- Direita: **ícone de Terra Rara** (`terra_rara_icon.png`) + o valor do custo
  (só o número). Substitui o `card.cost.short` ("%d TR") em texto.
- `hub_card.gd`: remover a linha de topo inteira (`_icon` da erva + `_name_label`);
  o `_content` passa a ter uma linha só: `[efeito]  ...spacer...  [ícone TR + custo]`.
  `CARD_HEIGHT` encolhe (uma linha) — ficha mais baixa e elegante.
- Estados mantidos: acessível = borda/custo âmbar + respiro pulsante; caro =
  borda apagada + custo em sangue (`set_affordable`); `consume()`/`deny()` iguais.
- Chaves órfãs após o refactor: `card.cost.short` ("%d TR") e provavelmente
  `card.cost` ("%d de Terra Rara") — **auditar uso e remover** as que ficarem sem
  consumidor (o custo agora é ícone + número puro).

**Aceite:** cada card é uma linha — efeito à esquerda, ícone de Terra Rara + custo
à direita; sem nome nem ícone de erva; sem a sigla "TR".

### RB4 — Remover as legendas de status de trilha

Quando uma trilha não tem card disponível, **não** mostrar legenda alguma.

- `hub_shop.gd`: remover `_add_status()`, `_trilha_status_text()` e as chamadas.
  A coluna vazia mostra só o heading (DANO/VIDA) — ou nada além dele.
- Chaves órfãs → remover dos dois dicionários: `hub.next.phase`, `hub.next.fire`,
  `hub.track.complete`. (`HINT_COLOR` e `FONT_SM` do status saem junto se não
  usados em outro lugar.)

**Aceite:** nenhuma legenda "próxima: … — na próxima fogueira" / "trilha completa"
em nenhuma orientação; trilha esgotada fica limpa.

### RB5 — Polimento premium do cabeçalho e composição

Fechar a experiência premium do HUB, coerente com a marca e com o alvo retrato:

- **Cabeçalho:** `[ 🟧 Terra Rara + número ]` à esquerda ··· `[ ícone de SOM ]` à
  direita (o ícone de mute vem do `PRD-tela-inicial-v3.md` R8, que remove o botão
  "Opções" do hub). Um cabeçalho de dois toques: recurso à esquerda, controle à
  direita. Respeitar `_apply_safe_margins` (notch/safe-area) e `_relayout`
  (retrato/paisagem).
- **Ritmo e leitura:** bordas duras, paleta da protagonista (âmbar/preto/branco
  sujo), sem cantos arredondados; a bandeja escura segura os cards acima do
  acampamento animado (contrato da Fase 9 mantido). Menos elementos, mais respiro.
- **Sem asset novo pesado:** ícone de TR e de SOM já existem/desenhados em código;
  orçamento ≤10MB e GPU fraca intactos.

**Aceite:** thumbnail do hub lê como "recurso + duas escolhas (DANO/VIDA)";
retrato e paisagem coerentes; nada compete com a decisão de compra.

---

## 2. Fora de escopo

- Balanceamento de custos/efeitos das ervas (`UPGRADE_DEFS`) — só muda a
  apresentação, não os números.
- A lógica de disponibilidade/pacing das ervas (`available_keys`,
  `next_pending_key`, regra "nasce na próxima fogueira") — continua igual; só
  **some a legenda** que a explicava.
- O ícone de SOM / mute (especificado no `PRD-tela-inicial-v3.md` R8) — aqui só
  reservamos o lugar dele no cabeçalho.
- Tradução literária dos diálogos/nomes próprios de chefe (já roteados por `Lang`).
- O HUD de combate (`hud.gd`) — o `FragmentCounter` de lá já é o padrão que o hub
  vai adotar; não muda.

## 3. Ordem de execução (uma tarefa por sessão)

| Sessão | Entrega | Gate |
|---|---|---|
| S1 | **RA1 + RA2** — rotear strings hardcoded + remover consts/texto mortos | `make gate` + jogo em inglês sem vazamento pt |
| S2 | **RA3** — `test_i18n_parity` (trava de regressão) | `make import` + `make test` (total subiu) |
| S3 | **RB1 + RB2** — contador por ícone + rótulos DANO/VIDA | `make gate` + captura do hub (pt/en) |
| S4 | **RB3 + RB4** — card de uma linha + remoção das legendas | `make gate` + `/validate-platforms` (retrato/paisagem) + testes de hub |
| S5 | **RB5** — polimento do cabeçalho/composição | `make gate` + `/validate-platforms` |

Dependências: S2 depois de S1 (chaves novas existem); S3–S5 independentes de A,
mas S4 depende de S3 (mesmos arquivos de hub). Um commit por sessão.

## 4. Critérios de aceite globais

- Em inglês, **nenhuma** frase user-facing aparece em português (as 9 fechadas);
  `test_i18n_parity` verde e sensível (remover uma chave de um lado falha).
- No acampamento: contador de Terra Rara por ícone; colunas DANO/VIDA; cards de
  uma linha (`+N dano` … `🟧 custo`), sem nome/ícone de erva, sem "TR"; zero
  legendas de status.
- Retrato (~393px) e paisagem coerentes; safe-area respeitada; 60fps mantido.
- `make gate` verde; `/validate-platforms` passa; nenhuma chave i18n órfã
  (nem sobrando, nem faltando); `git diff` de `.tscn` conferido.

## 5. Riscos e notas

- **Nomes de golpe são nomes próprios (gotcha #17).** Roteá-los pelo `Lang` é
  correto, mas a *tradução* é decisão de sabor (D1). Não reintroduzir mecânica do
  Cortejo (gotcha #18): mexer só no rótulo.
- **`RemotePatterns` sobrepõe `display_name` de golpes de chefe** (gotcha #16/#17)
  — os golpes da **Caipora** não têm `.tres` e não passam por lá; localizá-los é
  seguro, mas conferir que o override remoto de chefes continua intacto.
- **Chaves órfãs:** remover `hub.fragments`, `hub.next.*`, `hub.track.complete`,
  `card.cost.short` (e `card.cost` se morto) dos **dois** dicionários juntos —
  senão o `test_i18n_parity` (RA3) acusa assimetria. Auditar consumidores antes.
- **Edição de `.tscn` (gotcha 7):** `win.tscn` por editor/manual com `git diff`;
  nada de MCP em cena com autoload.
- **`draw_string` no `exit_beacon`:** precisa de fonte válida ao localizar;
  reagir a `language_changed` com `queue_redraw` para trocar "rastro"/"trail" ao
  vivo.
- **Testes de hub existentes** (`test_hub_shop.gd`) podem checar o texto do custo
  ("TR") ou a existência de status — atualizar junto do refactor (RB3/RB4).

## 6. Arquivos afetados

| Arquivo | Mudança |
|---|---|
| `scripts/core/scene_transition.gd` | RA1: flavor via `Lang.t` (sem `const` hardcoded). |
| `scripts/utils/constants.gd` | RA1: `CAIPORA_MOVE_*` guardam chave i18n do nome. |
| `scripts/arena/arena_manager.gd` | RA1: resolve nome de golpe e "BOM" via `Lang`. |
| `scripts/hub/exit_beacon.gd` | RA1: "rastro" via `Lang.t`; redraw no `language_changed`. |
| `scripts/ui/ending_screen.gd` | RA2: remove `SKY_MESSAGE` morto. |
| `scripts/ui/ending_sacrifice_screen.gd` | RA2: remove `MESSAGE_1`/`MESSAGE_2` mortos. |
| `scenes/ui/win.tscn` | RA2: esvazia/alinha o label hardcoded (`git diff`). |
| `scripts/hub/hub_shop.gd` | RB1/RB2/RB4: `FragmentCounter` no header; rótulos DANO/VIDA; remove status. |
| `scripts/hub/hub_card.gd` | RB3: card de uma linha; efeito + ícone TR + custo; sem nome/ícone de erva. |
| `scripts/ui/fragment_counter.gd` | RB1: reuso (sem mudança, ou `configure_size` no hub). |
| `scripts/core/lang_pt.gd` / `lang_en.gd` | Add chaves RA1; edita `hub.track.*`; remove órfãs. |
| `tests/unit/test_i18n_parity.gd` | **Novo:** paridade de chaves + valores não vazios. |
| `tests/unit/test_hub_shop.gd` | Atualizar asserts de custo/status ao refactor. |

## 7. i18n — resumo das chaves

**Adicionar (pt + en):** `transition.themed`, `transition.camp`,
`move.caipora.normal`, `move.caipora.double`, `move.caipora.cortejo`,
`hub.exit.trail`, `combat.timing.good`.

**Editar valor:** `hub.track.furia` → "DANO"/"DAMAGE"; `hub.track.cura` →
"VIDA"/"LIFE".

**Remover (dos dois lados):** `hub.fragments`, `hub.next.phase`, `hub.next.fire`,
`hub.track.complete`, `card.cost.short` (e `card.cost` se sem uso).

## 8. Decisões abertas

- **D1 — Tradução dos nomes de golpe.** `move.caipora.*` são nomes próprios (modelo
  Pokémon). Recomendação: **rotear pelo `Lang` mas manter o valor em português nos
  dois idiomas** (como os nomes de chefe: "MULA SEM CABEÇA" etc.) — o inglês então
  exibe o nome brasileiro de propósito, não por acidente. Alternativa: traduzir
  ("Red Claw", "Vine Lash", "Cortège Drum"). *Decisão antes de S1.*
- **D2 — "BOM" no combate.** Localizar como `combat.timing.good` ("BOM"/"GOOD").
  Conferir se não conflita com o label PNG de GOOD ("APAROU", gotcha #19) — são
  feedbacks distintos (texto de acerto vs. PNG de bloqueio). *Confirmar em S1.*
- **D3 — `card.cost` longo.** Se algum tooltip ainda usar `"%d de Terra Rara"`,
  manter a chave; senão remover. *Auditar em S4.*
