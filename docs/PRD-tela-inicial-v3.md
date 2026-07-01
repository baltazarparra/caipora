# PRD — Tela Inicial v3: Botão-Herói "O Rastro" e Composição Premium

**Data:** 2026-06-30
**Status:** Proposta
**Norte visual:** `docs/CONCEITO-protagonista.md` + `.agents/skills/visual-identity/SKILL.md`
**Referência de qualidade:** Hollow Knight (Team Cherry) — menu mínimo, atmosférico,
um único gesto interativo elegante.
**Alvo primário:** Android fraco, navegador, **modo retrato**. Tudo decide por esse
jogador. Paisagem e desktop são alvos secundários compatíveis (gotcha 10).
**Escopo:** `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`, novo
`scripts/ui/start_button.gd`, `scripts/ui/options_panel.gd` (refator),
`scripts/hub/hub_shop.gd` (troca o botão Opções por ícone de SOM),
`scripts/ui/speaker_button.gd` (reuso/ajuste), `scripts/core/audio_director.gd`
(mute master), `assets/fonts/theme.tres` (ajuste pontual),
`scripts/core/lang_pt.gd` / `lang_en.gd` (cópia), testes afetados.
**Supersede:** `PRD-tela-inicial-v2.md` R5 (altura fixa dos botões) e a
padronização de botões da Etapa 2 do `PLANO-marca-loader-menu-aaa.md` — só para
o botão Iniciar; o resto dos dois docs permanece lei.

---

## 1. Visão

A tela inicial é o aperto de mão do jogo. Hoje a abertura "Horizonte Infernal"
(fogo doom, treelines em parallax, brasas, a Caipora real atravessando o
horizonte) **já é cinema on-brand** — foi desenhada à mão em código e tunada
para 60fps. O que destoa é a camada de interface: dois botões retangulares
genéricos do tema, um deles ("Sair") sem sentido nenhum no navegador, empilhados
no centro morto da tela.

O salto de nível não é adicionar enfeite. É o oposto do que parece: **subtrair o
ruído e elevar um único gesto** — o botão de começar — ao status de objeto de
marca, com a mesma personalidade predatória da Caipora. Como em Hollow Knight, a
elegância vem de **restrição + atmosfera + um elemento interativo vivo**.

> **Norte:** ao reduzir a tela a uma miniatura, ela deve ler como a marca —
> mancha laranja serrilhada, vazio preto, dois olhos brancos — e o olho deve
> cair imediatamente sobre **um** ponto de ação, desenhado para o polegar.

A mesma disciplina se estende ao resto da interface: a **configuração** sai do
meio da run e mora na soleira (tela inicial), enxuta a dois itens (Volume +
Apagar progresso); o **acampamento** troca o botão "Opções" por um único gesto —
um liga/desliga de som. Cada tela passa a ter um foco claro, sem menu técnico
competindo com a experiência.

---

## 2. Diagnóstico do estado atual

| Elemento | Estado | Problema |
|---|---|---|
| Abertura "Horizonte Infernal" | DoomFire + treelines + brasas + `TitleWalker` | **On-brand, fica.** Só recebe re-tune de scrim para o novo layout. |
| Logo "CAIPORA" (wordmark, olhos piscando) | On-brand (`PLANO-marca-loader-menu-aaa`) | Fica. Reposicionado no novo ritmo vertical. |
| Botão **Iniciar** | `Button` do tema: retângulo, borda 2px âmbar, `144px` de altura | Genérico. É o botão mais importante do jogo e não tem personalidade nem presença. **Refator total.** |
| Botão **Sair** | `Button` do tema, `get_tree().quit()` | **Inútil no navegador** (não fecha aba). Ruído que compete com o botão principal. **Remover.** |
| Composição | `CenterContainer` → `VBox` centralizado, `Scrim` fixo 600×420 | Centro morto: em retrato alto o botão principal fica longe da zona do polegar; o scrim fixo não acompanha o viewport. |
| Rodapé (bandeiras, github, versão, banner update) | Disperso dentro/fora do VBox | Sem hierarquia. Compete com o herói. |
| Botão **Opções** no Acampamento | `Button` "Opções" no cabeçalho do `HubShop`, abre o `OptionsPanel` | Configuração não pertence ao meio da run; o acampamento só precisa de um atalho rápido. **Mover para a tela inicial; deixar só um liga/desliga de som.** |
| **OptionsPanel** | 4 sliders (Master/SFX/Música/Ambiência) + Idioma + Controles Touch + Apagar progresso + Fechar | Pesado e técnico demais para o jogador-alvo. **Enxugar para 1 slider "Volume" + "Apagar progresso".** |

---

## 3. Princípios (lei, não preferência)

1. **Retrato-primeiro, zona do polegar.** Em retrato o gesto principal vive no
   **terço inferior** (arco confortável do polegar), não no centro. O logo sobe,
   o botão desce, o rodapé encosta na borda. Em paisagem volta ao stack
   centralizado ≤30% de largura (contrato atual).
2. **Paleta fechada da protagonista.** Juba `#8b2a00 → #ff4500`, preto `#000000`,
   branco-osso dos olhos/texto `#c9d1d9`/`#ffffff`, sangue `#8b0000`. Verde
   **não** entra na marca (é âncora exclusiva da Fúria). Âmbar `#ff6b00` é o cue.
3. **Pixel art chapada.** Bordas duras, sem cantos arredondados, sem gradiente
   suave, sem blur, sem dither decorativo, sem glossy. A serrilha da juba é a
   assinatura de forma.
4. **Tudo montado em código, zero asset novo baixado.** O botão é desenhado em
   `_draw()` (padrão de `CombatArrowButton`/`FloatingDpad`/`title_*`). Nenhum PNG
   novo: protege o orçamento ≤10MB e a GPU do Android fraco.
5. **Performance é requisito de design.** Animação por `Tween` em propriedades
   (sem `_process` por frame quando evitável), sem shader obrigatório no menu. O
   menu **mantém 60fps** no Android de referência (validar com `?perf`).
6. **Horror físico permanece.** O botão é uma fauce/garra que acorda; o press é
   visceral (hit-stop, brasa, sangue). Sem suavizar.
7. **Configuração mora na soleira, não no meio da mata.** Ajustes (volume, apagar
   progresso) vivem na tela inicial. Dentro da run, o jogador só tem um gesto: um
   **liga/desliga de som** rápido. Menos opções, mais foco — disciplina de
   console premium.
8. **Menos itens, mais peso.** O painel de Opções perde o que é técnico (sliders
   por bus, modo de touch) e mantém só o essencial e legível: um Volume e um
   botão de perigo. Idioma já vive nas bandeiras da tela inicial.

---

## 4. Requisitos

### R1 — Remover o botão "Sair"

No navegador `get_tree().quit()` não fecha a aba: o botão não faz nada útil e só
divide a atenção com o gesto principal. Hollow Knight web também não oferece
"Quit" na tela inicial.

- Remover o nó `QuitButton` de `main_menu.tscn` (nó folha; editar pela **Godot
  editor** ou edição manual mínima com `git diff` conferido — gotcha 7: nada de
  MCP `add_node`/`save_scene` nesta cena com autoloads).
- Em `main_menu.gd`: remover `_quit_button`, `_on_quit_pressed()`, a linha de
  `_quit_button.text` em `_on_language_changed`, a referência no loop de
  hover/focus e a entrada no loop de `_relayout_buttons`.
- As chaves i18n `menu.quit` (pt/en) ficam órfãs: **remover** das duas tabelas
  para não deixar string morta.

**Aceite:** nenhum botão "Sair" na tela; `make gate` verde; nenhuma referência
pendente a `QuitButton`/`menu.quit` (grep limpo).

---

### R2 — Botão-Herói "O Rastro" (refator total do Iniciar)

O Iniciar deixa de ser um `Button` do tema e vira um **objeto de marca autoral**,
desenhado em código. Conceito: **"O Rastro"** — o limiar por onde a Caipora pisa
para entrar na mata (lore: a run começa pelo Acampamento, "pisa no rastro pra
entrar na mata"). A mata abre as fauces; o jogador atravessa.

#### Forma (silhueta antes de detalhe)

- **Placa escura** (`#0d1117` ~0.92 alpha) com **borda serrilhada** no topo e na
  base — dente de serra duro (sawtooth), eco direto da juba serrilhada da
  Caipora. A serrilha É a assinatura: a palavra repousa dentro da boca da mata.
- **Garras-chevron** (`⟩⟩ … ⟨⟨`) emoldurando o texto à esquerda e à direita —
  mesma linguagem dos `CombatArrowButton` da arena, costurando menu↔combate.
- **Outline 1–2px** na rampa da juba (`#8b2a00` dim → `#ff4500` aceso).
- **Linha de brasa** na base da placa: uma fileira fina de pixels âmbar chapados
  (`#ff6b00`) que **respira** lentamente — as brasas sob o limiar, eco do
  `DoomFire` lá embaixo. Sem blur: alpha pulsando em degraus, não glow suave.
- **Sem olhos no botão.** Os dois olhos brancos pertencem ao "O" do logo. O botão
  é a garra/limiar; o logo é o rosto. Separação limpa = leitura forte.

```
        ╲▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁╱        ← serrilha (juba) no topo
  ⟩⟩      D E S P E R T A R      ⟨⟨   ← texto + garras-chevron
        ╱▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔╲
        ▂▃▄▅▅ · brasa · ▅▅▄▃▂        ← linha de brasa respirando
```

#### Estados (a juba acorda)

| Estado | Leitura |
|---|---|
| **Idle** | Placa escura; outline `#8b2a00` (juba dormindo); garras dim; brasa respirando devagar (alpha 0.30↔0.60, período ~2.6s). |
| **Foco/Hover** | Outline acende para `#ff4500`; garras-chevron igniçam em âmbar; brasa intensifica; leve shimmer na serrilha. Como é o gesto único, **nasce focado** (`grab_focus`). |
| **Press** | Ignição total: núcleo da placa pisca para sangue `#8b0000`; **punch de escala** (hit-stop ~1.04→1.0); jato curto de brasas pra cima (vocabulário de `title_embers`); então o despertar começa (transição de cena). |

#### Cópia / rótulo

O rótulo atual "Iniciar" é correto, porém sem teeth. **Recomendação:** elevar
para **"DESPERTAR"** (EN **"AWAKEN"**) — é literalmente o que a ação faz (a
Caipora desperta no acampamento) e carrega a personalidade pedida. Mantém a chave
i18n `menu.start` (só muda o valor). Ver Decisão Aberta D1.

#### Implementação

- Novo `scripts/ui/start_button.gd`, `class_name StartButton`, estende
  `BaseButton` (padrão do `CombatArrowButton`): desenha placa + serrilha + garras
  + texto + brasa em `_draw()`; gerencia estados por `Tween`; emite `pressed`.
- Constantes de cor **de `Constants`** (`COLOR_JUBA`, `COLOR_JUBA_DARK`,
  `COLOR_AMBER`, `COLOR_BLOOD`, `COLOR_TEXT`) — nada de hex solto no script.
- Instanciado por código em `main_menu.gd::_ready()` no lugar do `StartButton`
  do tema (mesmo padrão do logo, que já é montado em código). `_on_start_pressed`
  conecta no `pressed` do novo botão; o resto do fluxo (`unlock_audio`,
  `disabled = true`, `_begin_run`) é intocado.
- **Sem `_process` por frame** para a respiração: um `Tween` em loop
  (`set_loops()`) animando a propriedade de alpha da brasa + `queue_redraw` no
  passo do tween. Redesenho extra só em troca de estado.

**Aceite:** o botão lê como garra/limiar serrilhado em retrato; em thumbnail
ainda lê como marca; idle respira, foco acende, press é visceral; 60fps no
Android de referência; nenhum hex fora de `Constants`.

---

### R3 — Composição da tela (ritmo vertical premium)

Reorganizar a tela em **três faixas** com hierarquia clara, desenhada para o
retrato alto e o polegar. Abandona o `CenterContainer` centro-morto.

```
┌──────────────────────────────┐  ← safe-area topo (env())
│        [ ⟳  Atualizar ]       │  (só quando há update remoto)
│                              │
│         C A I P O R A         │  ← FAIXA 1: logo (olhos piscam)
│            (o "O" olha)       │
│                              │
│   ～ treeline · brasas · fogo ～ │  ← Horizonte Infernal (fundo vivo)
│        🐾 Caipora anda  →      │
│                              │
│    ╲▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔╱        │
│   ⟩⟩     DESPERTAR     ⟨⟨      │  ← FAIXA 2: botão-herói (zona polegar)
│    ╱▁▁▁▁  brasa  ▁▁▁▁╲        │
│           OPÇÕES              │  ← entrada secundária (ghost, sob o herói)
│                              │
│   🇧🇷 🇺🇸        github    v.   │  ← FAIXA 3: rodapé quieto
└──────────────────────────────┘  ← safe-area base (env())
```

- **Faixa 1 (topo):** o wordmark CAIPORA, ancorado ao topo com folga generosa.
  Regra de escala inteira mantida (~85% da largura em retrato — intocada).
- **Faixa 2 (terço inferior):** o botão-herói, dominante, largura total menos
  margens, na altura confortável do polegar. **É o único ponto de ação grande.**
  Logo **abaixo** dele, a entrada secundária **OPÇÕES** (ver R6) — discreta,
  ghost/outline, deliberadamente menor para não competir com o herói.
- **Faixa 3 (borda inferior):** linha quieta e de baixo contraste — bandeiras de
  idioma + github + versão. Pequenos, discretos, **respeitando safe-area** via
  `env()` (já tratado no `ControlsHud`; aplicar a mesma disciplina aqui).
- **Scrim:** trocar o `Scrim` fixo 600×420 por um **scrim vertical** ancorado
  atrás das faixas 1 e 2 (degradê chapado de alpha, escurecendo o fogo só onde
  há texto, para legibilidade) — escurecer o **fundo** é permitido pela skill
  (clima vem da cena, não da Caipora). Acompanha `size_changed`.
- **Respiro (elegância Hollow Knight):** definir um ritmo vertical único
  (separações múltiplas de uma constante) e folga ampla. Menos elementos, mais
  ar. Nada compete com o herói.
- **Paisagem/desktop:** reverte ao stack centralizado ≤30% de largura (contrato
  atual de `_relayout_buttons`/`_fit_logo`); a lógica de zona-do-polegar é só
  retrato. Reagir a `size_changed` nas duas orientações (gotcha 10).

**Aceite:** em retrato (~393px), olho vai logo→herói→rodapé; herói na zona do
polegar; rodapé não colide com a barra do navegador nem com o notch; em paisagem,
layout centralizado intacto; thumbnail ainda lê como a marca.

---

### R4 — Micro-interação e game feel do "despertar"

O toque no herói é o primeiro "feel" do jogo — tem que prometer o combate.

- **Áudio:** hover/foco usa `AudioDirector.play_ui_hover` (contrato atual). O
  press dispara `unlock_audio()` (já existe) e um stinger de despertar — reusar
  um SFX existente coerente (ex.: cama grave/impacto) antes de criar um novo; se
  um som novo for necessário, entra no **fim** de `GENERATORS` em `gen_sfx.py`
  (gotcha #19 — seed por variante; nunca inserir no meio).
- **Háptico (web/Android):** vibração curta no press
  (`navigator.vibrate`/`Input.vibrate_handheld`) — mesma cozinha do `ControlsHud`.
- **Transição:** o press mascara a troca pelo `SceneTransition` (uma linguagem
  de transição só — `PLANO-marca-loader-menu-aaa` Etapa 3; sem fade duplicado no
  menu). A assinatura "dois olhos brancos abrem no breu" costura a saída.
- **Lockout:** `disabled = true` no press (já existe) evita duplo-toque
  disparando duas runs.

**Aceite:** press dá retorno tátil, sonoro e visual coeso em <100ms; sem
duplo-disparo; transição é a mesma linguagem do resto do jogo.

---

### R5 — Orçamento de performance e plataforma (trava do alvo)

O alvo é Android fraco no navegador em retrato. Inegociável:

- **Zero download novo:** botão 100% em `_draw()`; nenhuma textura/fonte nova.
- **Sem shader obrigatório** no menu (o `title_fire.gdshader` segue só como
  fallback de logo ausente). A respiração da brasa é `Tween` + `queue_redraw`,
  não shader por pixel.
- **Redesenho mínimo:** `_draw` roda em troca de estado + passos lentos do tween
  da brasa; não há `_process` por frame no botão.
- **DoomFire** mantém a grade reduzida no web (gotcha já no `doom_fire.gd`).
- **Meta:** menu segura **60fps** no aparelho de referência; medir com `?perf`
  antes/depois.

**Aceite:** FPS do menu não regride vs. baseline atual no Android de referência;
tamanho do `.pck`/projeto inalterado (sem asset novo).

---

### R6 — Entrada de "Opções" na tela inicial (secundária)

A configuração migra do acampamento para a tela inicial, **abaixo** do botão-herói.
Hierarquia é tudo: ela existe, mas não disputa atenção com o DESPERTAR.

- Controle **ghost/outline**, tier-2: sem placa cheia, só o rótulo **OPÇÕES** com
  um sublinhado/colchete fino na juba dim (`COLOR_JUBA_DARK`), que acende para
  `COLOR_AMBER` no foco/hover. Fonte menor que a do herói. Alvo de toque ainda
  confortável (≥48px de altura efetiva, mesmo com visual fino).
- Abre o `OptionsPanel` (refatorado em R7) por cima da tela, sem trocar de cena
  (mesmo contrato `open()`/`close()` atual; layer 60, acima do herói).
- `main_menu.gd` instancia **um** `OptionsPanel` por código (o menu hoje não tem
  um; o `HubShop` deixa de ter — ver R8) e liga o botão ao `open`.
- Áudio/foco: `play_ui_hover` no foco/hover (contrato atual).

**Aceite:** OPÇÕES aparece sob o herói, visivelmente secundária; abre/fecha o
painel sobre a tela inicial; em paisagem acompanha o stack centralizado.

---

### R7 — Refator do `OptionsPanel` (enxugar para o essencial)

O painel passa de 4 sliders + idioma + touch + reset para **dois itens**:

1. **Slider único "Volume"** — controla o bus **Master**
   (`AudioDirector.get/set_bus_volume("Master")`). Os buses SFX/Música/Ambiência
   mantêm a mistura baked (proporções de design); o jogador mexe num só número.
   Rótulo i18n novo `options.volume` ("Volume" / "Volume").
2. **"Apagar progresso"** — mantém a confirmação em dois passos no próprio botão
   (sem `ConfirmationDialog`, que tem foco ruim no mobile — contrato atual).
   **Mudança:** ao confirmar, além de `MetaProgression.reset_save()`, o jogo
   **reinicia numa sessão limpa**:
   - **Web (alvo):** `JavaScriptBridge.eval("location.reload()")` — refresh real
     da página, sessão nova de verdade (padrão já usado em `controls_hud`/`perf_hud`).
   - **Nativo/editor (fallback):** `get_tree().change_scene_to_file(<main_scene>)`
     recarregando a tela inicial (o `run/main_scene` é o próprio menu).
   - O reset roda **depois** do fade do `SceneTransition` para não piscar o
     estado antigo antes do refresh.

**Removidos do painel** (seguindo o pedido — manter só Volume + Apagar progresso):

- Os 3 sliders extras (SFX/Música/Ambiência) — colapsados no Volume = Master.
- O seletor de **Idioma** — já vive nas bandeiras BR/US da tela inicial (R3).
- O seletor de **Controles Touch** (Auto/Sempre/Nunca) — o padrão "auto" cobre o
  alvo (detecta toque). Ver Decisão Aberta D4.

- Limpeza i18n: remover `options.audio.sfx/music/ambience`, `options.audio.master`
  (→ vira `options.volume`), `options.language`, `options.touch*`. Manter
  `options.title`, `options.close`, `options.reset*`. Apagar os métodos/refs mortos
  (`_add_language_row`, `_add_touch_controls_row`, `_lang_option`, `_touch_option`,
  o loop de buses `ROWS`).
- Visual premium mantido: painel de borda dura, paleta da protagonista, título
  "OPÇÕES", botão de perigo em `DANGER`/sangue. Sem cantos arredondados.

**Aceite:** o painel mostra só Volume + Apagar progresso + Fechar; o Volume move o
Master e persiste; confirmar o reset apaga o save E reinicia numa sessão limpa
(refresh no web); nenhuma string/método órfão; `test_audio_director` e
`test_meta_progression` atualizados e verdes.

---

### R8 — Acampamento: ícone de SOM (mute total) no lugar de "Opções"

No `HubShop`, o botão "Opções" some e dá lugar a um **ícone de som** premium —
um liga/desliga rápido de **todo** o áudio, para o jogador no meio da run.

- **Widget:** reusar o `SpeakerButton` (`scripts/ui/speaker_button.gd`) já
  desenhado em código (corpo + trompa + ondas; estado `muted` mostra o "X").
  Recolorir para `Constants.COLOR_AMBER` (marca) e, no estado mudo, o "X" em
  `COLOR_BLOOD`/dim. Hard-edge, sem suavização.
- **Ação:** mute **completo** (não só música) via novo helper no `AudioDirector`:
  `toggle_master_mute()` / `set_master_muted(bool)` / `is_master_muted()`,
  usando `AudioServer.set_bus_mute(<Master idx>, on)` e **persistindo** em
  `user://settings.cfg` (mesmo `_save_settings()` dos volumes). O mute é global e
  sobrevive à troca de tela (Master mutado cala tudo: SFX, música, ambiência,
  hover).
- **Estado inicial:** o ícone reflete `is_master_muted()` ao montar; persiste
  entre sessões.
- **Posição:** onde estava o `_options_button` no cabeçalho do `HubShop`
  (canto, respeitando `_apply_safe_margins`/`_relayout`). Sem abrir painel —
  toque = toggle imediato.
- **Feedback:** háptico curto no toque (cozinha do `ControlsHud`); a troca de
  ícone (ondas ↔ X) é o retorno visual; um `play_ui_hover` antes de mutar.
- **Nota:** o `SpeakerButton` de música do HUD de combate (`hud.gd`,
  `toggle_music_ambience`) é **outro** controle e fica fora de escopo aqui
  (não confundir os dois; unificação é tema futuro).

**Aceite:** no acampamento, um ícone de som no lugar do botão Opções; toque muta/
desmuta TODO o áudio na hora; o estado persiste e reflete na volta; nada abre
painel; `OptionsPanel` não é mais instanciado pelo `HubShop`.

---

## 5. Fora de escopo

- Gameplay, arena, exploração, HUB, áudio de combate, sprites `player_*`.
- O loader HTML, boot splash, favicon/PWA e a transição em si (já entregues no
  `PLANO-marca-loader-menu-aaa` S1–S4). Aqui só **consumimos** o `SceneTransition`.
- Redesenho do wordmark/logo (fica como está; só reposiciona).
- Novos idiomas ou mudança no `Lang`/toggle de bandeiras (só reposiciona).
- Lógica do banner de update remoto (só herda o estilo de borda dura do tema).
- O `SpeakerButton` de música do **HUD de combate** (`hud.gd`) — controle
  distinto, permanece como está. Unificar os dois é tema de outra sessão.
- Mixagem relativa entre buses (SFX/Música/Ambiência) — fica baked; o Volume só
  move o Master.

---

## 6. Ordem de execução (uma tarefa por sessão)

| Sessão | Entrega | Gate |
|---|---|---|
| S1 | **R1** — remover "Sair" (cena + script + i18n) | `make gate` + grep limpo |
| S2 | **R2** — `start_button.gd`: forma, estados, brasa | `make gate` + `/validate-controls` (toca input/timing do menu) + captura retrato |
| S3 | **R7** — refator do `OptionsPanel` (Volume + reset com restart) | `make gate` + `test_audio_director`/`test_meta_progression` verdes |
| S4 | **R8** — ícone de SOM no acampamento + mute master no `AudioDirector` | `make gate` + `test_audio_director` verde + captura do hub |
| S5 | **R3 + R6** — composição em 3 faixas + scrim + entrada OPÇÕES | `make gate` + `/validate-platforms` (retrato E paisagem; safe-area) |
| S6 | **R4** — game feel do press (áudio/háptico/transição) | `make gate` + `/validate-controls` |
| S7 | **R5** — passe de performance + medição `?perf` no Android | `make export` + teste real no aparelho de referência |

Dependências: S2 depende de S1 (menu limpo); S5 (R6) depende de S2 (herói existe)
e S3 (painel refatorado); S4 é independente (acampamento). S6 e S7 dependem de S5.
Cada sessão = uma tarefa, um commit (protocolo do projeto).

---

## 7. Critérios de aceite globais

- A tela reduzida a thumbnail lê como a marca (mancha laranja + olhos brancos
  sobre breu) e o olho cai num único ponto de ação.
- Em retrato (~393px): logo no topo, herói na zona do polegar, rodapé na borda
  sem colidir com notch/barra do navegador (safe-area).
- Em paisagem/desktop: stack centralizado ≤30% de largura, intocado.
- O botão-herói tem personalidade autoral (serrilha + garras + brasa), respira
  no idle, acende no foco e é visceral no press — coerente com a Caipora.
- 60fps no menu no Android de referência; sem asset novo baixado.
- `make gate` verde; `/validate-controls` e `/validate-platforms` passam;
  `test_*` do menu (se houver) atualizados e verdes.
- Nenhum hex fora de `Constants`; nenhuma edição de `.tscn` via MCP; `git diff`
  do `.tscn` conferido.

---

## 8. Riscos e notas

- **Edição de `.tscn` (gotcha 7):** remover `QuitButton` e ajustar o container é
  edição de cena — fazer pela Godot editor ou manualmente com `git diff`
  conferido nó a nó; **nunca** MCP `add_node`/`save_scene` (a cena depende de
  autoloads e seria mangleada headless). Tudo que é runtime vai por código.
- **`/validate-controls` é obrigatório:** o botão-herói toca input/foco/timing do
  menu (gotcha 9). Rodar antes de cada commit de S2/S4.
- **`/validate-platforms` é obrigatório:** mudança de UI/safe-area/orientação
  (gotcha 10). Retrato E paisagem; phone, phone-landscape, tablet+.
- **Respiração da brasa pode virar custo escondido:** se o `_draw` redesenhar a
  cada frame, vira pico de CPU no Android fraco. Travar em `Tween` + redraw
  esparso; medir com `?perf`.
- **Cópia "DESPERTAR" precisa caber:** PressStart2P é largo; conferir que o
  rótulo (pt **e** en) não estoura a largura do botão em retrato a ~393px (com
  as garras-chevron ocupando as bordas). Fallback: reduzir `font_size` do
  rótulo, nunca cortar a palavra.
- **Stale `AGENTS.md` (gotcha 21):** se ao implementar algo em `AGENTS.md`/`PLAN`
  conflitar com este PRD, corrigir a instrução estável antes do código.

---

## 9. Arquivos afetados

| Arquivo | Mudança |
|---|---|
| `scenes/ui/main_menu.tscn` | Remove `QuitButton`; reorganiza container em 3 faixas; scrim vertical. Edição cuidadosa (editor/manual, `git diff`). |
| `scripts/ui/main_menu.gd` | Remove fluxo do Sair; instancia `StartButton` por código; novo layout/relayout das 3 faixas; scrim ancorado. |
| `scripts/ui/start_button.gd` | **Novo.** `class_name StartButton extends BaseButton`: forma serrilhada + garras + brasa + estados. |
| `scripts/ui/options_panel.gd` | **Refator (R7):** só Volume (Master) + Apagar progresso (com restart/refresh); remove sliders extras, idioma e touch. |
| `scripts/hub/hub_shop.gd` | **R8:** remove `_options_button`/`_options` (OptionsPanel); coloca o `SpeakerButton` de mute no lugar, no cabeçalho. |
| `scripts/ui/speaker_button.gd` | **R8:** reuso; recolorir para `COLOR_AMBER`, "X" mudo em sangue; ligar ao mute master. |
| `scripts/core/audio_director.gd` | **R8:** `toggle_master_mute()`/`set_master_muted()`/`is_master_muted()` via `AudioServer.set_bus_mute`, persistido em `settings.cfg`. |
| `scripts/core/meta_progression.gd` | **R7 (talvez):** se o restart precisar de hook além de `reset_save()`; senão intocado. |
| `assets/fonts/theme.tres` | Ajuste pontual se preciso (o herói não usa o stylebox do tema; o resto da UI fica). |
| `scripts/core/lang_pt.gd` / `lang_en.gd` | Remove `menu.quit`, `options.audio.*`, `options.language`, `options.touch*`; add `options.volume`; (D1) atualiza `menu.start`. |
| `tests/unit/test_audio_director.gd` | Cobrir mute master (toggle/persistência) e a ausência dos buses extras na UI. |
| `tests/unit/test_meta_progression.gd` | Garantir que `reset_save()` + caminho de restart não regridem. |
| `scripts/tools/gen_sfx.py` | **Só se** um stinger novo de press for aprovado (fim de `GENERATORS`, gotcha #19). |

---

## 10. Decisões abertas

- **D1 — Rótulo do botão.** Recomendação: **"DESPERTAR" / "AWAKEN"** (personalidade
  + fiel à lore do despertar). Alternativas: manter **"INICIAR"** (literal,
  seguro) ou **"ENTRAR NA MATA"** (mais longo, risco de largura em retrato).
  *Decisão necessária antes de S2.*
- **D2 — Stinger de press.** Reusar SFX existente (preferido, custo zero) vs.
  gerar um som novo de despertar em `gen_sfx.py`. *Decisão em S4.*
- **D3 — Conceito do botão.** "O Rastro" (limiar/garra serrilhada, proposto)
  confirmado como direção, ou explorar variante (ex.: a palavra esculpida na
  própria juba, sem placa). *Confirmar antes de S2.*
- **D4 — Controles Touch.** O pedido é manter só Volume + Apagar progresso no
  painel. Recomendação: **remover** o seletor de touch (o "auto" detecta toque e
  cobre o alvo). Risco: quem quer forçar o D-pad sempre/nunca perde o controle.
  Alternativa: mover esse seletor para uma futura tela de acessibilidade.
  *Decisão antes de S3.*
- **D5 — Restart no nativo.** Web usa `location.reload()` (sessão nova real). No
  nativo/editor, recarregar o `main_scene` cobre o caso (não há "refresh de
  página"). Confirmar que basta para o alvo (que é web). *Decisão em S3.*
- **D6 — Mute vs. Volume.** O mute master (acampamento) e o Volume (Opções) são
  independentes e ambos persistem. Recomendação: manter assim (mute = kill switch
  rápido; Volume = nível). Alternativa: mute zera o slider. *Decisão em S4.*
```
