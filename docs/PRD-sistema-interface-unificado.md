# PRD — Sistema de Interface Unificado ("O Chrome da Mata")

> Status: **proposto** · Escopo: TODA a camada de UI/HUD do jogo (boot → menu → transições → acampamento → exploração → combate → telas de história)
> Alvo de qualidade: coerência e polish de franquia (Final Fantasy) **sem** trair a marca de horror folk — um único sistema de interface, uma linguagem visual, um conjunto de tokens.
> Decisões travadas com o dono do projeto (2026-07-01): **(1) Híbrido autoral** — a linguagem de garra/serrilhado vira o chrome padrão; **(2) Reescrita unificada (big-bang)** — um `UiRoot` único; **(3) DANO/VIDA** — esconder a trilha só quando não há upgrade a oferecer (predicado A).
> Não toca em lógica de dano/vida, timing, input, câmera ou balanceamento. É camada de apresentação.

---

## 1. Contexto e motivação

O jogo hoje **não tem um sistema de UI — tem N componentes isolados** que resolvem o mesmo problema de formas diferentes. Cada tela foi construída na sua sessão, reusando pouco, e o resultado é incoerente ao atravessar o fluxo `menu → acampamento → exploração → combate`. Exemplos concretos, todos verificados no código:

- **Três implementações do MESMO "header" (moeda + mudo):**
  - Exploração: `hud.gd::_layout_exploration` (`scripts/ui/hud.gd:102-124`), posicionamento **absoluto** (`Vector2` math), CanvasLayer **0**.
  - Combate: `hud.gd::_layout_combat_header` (`hud.gd:128-139`), header espelhado, CanvasLayer **52**.
  - Acampamento: `hub_shop.gd::_build_header` (`scripts/hub/hub_shop.gd:74-104`), **containers** Godot (`MarginContainer`+`HBox`), CanvasLayer **10** — reimplementa "Terra Rara + mudo" do zero.
  - Consequência: o mesmo `FragmentCounter` aparece a `~46px`/fonte 38 na exploração-retrato e a `~34px`/fonte `FONT_LG=28` fixa no acampamento; o `SpeakerButton` dobra em retrato na exploração (`HUD_TOUCH_SCALE`, `hud.gd:111-113`) e **nunca** escala no hub (`hub_shop.gd:99-104`). É exatamente o "tamanho e disposição diferentes" percebido entre telas.

- **Safe-area calculada por 3 fórmulas divergentes** para a mesma intenção "margem de topo/lateral":
  - `hud.gd:92-93`: `side=clamp(min(vp)*0.055, 32, 72)`, `top=clamp(min(vp)*0.05, 24, 56)`.
  - `hub_shop.gd:253-254`: `side=clamp(min(vp)*0.055, 40, 80)`, `top=clamp(min(vp)*0.05, 28, 64)` (o comentário diz "espelha o HUD antigo" — mas os números não batem).
  - `main_menu.gd::_relayout_menu`: `side=clamp(min*0.055, 24, 80)`, `top=clamp(min*0.05, 28, 64)`, `bottom=clamp(min*0.04, 18, 56)`.

- **Dois "loaders com texto" sem código comum:** o cross-screen `SceneTransition` (fade preto + flavor âmbar `FONT_MD` + assinatura "dois olhos brancos", CanvasLayer 100, `scripts/core/scene_transition.gd`) e o `arena_manager::_run_combat_loader` (revelação silábica "Pe→Pele→Pelejar", `FONT_TITLE=48`, CanvasLayer 30, fade `COLOR_ARENA_BG`). Gramática de tween parecida, zero reuso.

- **Duas camadas de fade concorrentes na layer 100:** `SceneTransition.LAYER=100` e o fade paralelo próprio do menu (`main_menu.gd::_setup_fade`, `FADE_LAYER=100`, 1.2s) — que `PLANO-marca-loader-menu-aaa` (Etapa 3) já **declarou aposentado**, mas continua no código (instrução stale, gotcha #21).

- **Dois sistemas de popup flutuante** quase idênticos (subir + fade): `hud.gd::_show_popup` (`:195-209`) e `hub_shop.gd::_spawn_floating_cost` (`:226-239`).

- **Três sistemas de texto no combate, nenhum comum:** HUD/HealthBar/loader usam a fonte do tema em `FONT_*`; o nome do golpe usa `PressStart2P.ttf` size 10 (`feedback_system.gd:288-315`); os rótulos de resultado (crítico/perfeito/errou/aparou) e o contador de combo usam **sprite-sheets PNG** (`result_*.png`, `combo_digit_sheet.png`).

- **Combate: elementos de HUD em espaço de mundo errado.** O contador de combo é um `Node2D` em world-space na posição fixa `(60,60)` z_index 25 (`feedback_system.gd:442-496`) — filho da cena Arena, portanto **afetado pela `Camera2D` (zoom/pan do killing-blow)** e escurecido pelo `Atmosphere`; os rótulos de resultado (z20) e a tag de nome de golpe (z5) também vivem no mundo. As barras de HP, porém, são screen-space (CanvasLayer 52). O HUD de combate está fragmentado em **três donos e três espaços de coordenadas**.

- **Três abordagens de estilo de botão:** o tema `assets/fonts/theme.tres` (Buttons nativos), `StyleBoxFlat` inline em código (`main_menu.gd::_apply_options_style`/`_apply_flag_style`, `hub_card.gd::_build_styles`) e `_draw()` puro (`StartButton`, `CombatArrowButton`, `SpeakerButton`). Não existe um "botão de marca".

- **Tokens existem, mas não são obedecidos.** `Constants` já tem a paleta única (`COLOR_*`, linhas 245-320) e a escala (`FONT_SM/MD/LG/TITLE`, `SPACE_XS…XL`, `UI_BORDER_WIDTH=2`, `UI_CORNER_RADIUS=0`, `UI_PADDING_H/V`, linhas 368-383). Mas os arquivos de UI enterram **magic numbers de layout** (`0.055`, `0.05`, `0.026`, `0.24`, `0.34`, `0.40`, `48`, `10`, `12`…), cores bespoke fora de token (`main_menu.gd:176` cinza `Color(0.494,0.514,0.541,0.72)`) e o `theme.tres` **duplica a paleta como floats crus** (não pode referenciar `Constants`, então mudanças não propagam). A lacuna não é criar tokens — é **forçar consumo**.

- **Dois laranjas para "a cor de destaque" (accent bifurcado — o mais insidioso).** O `theme.tres` pinta o accent de botões com **`COLOR_JUBA #ff4500`** (`font_hover_color`/`font_pressed_color` `:91-92`; styleboxes hover/pressed/focus border `:27,39,51`), enquanto **todo o código inline** usa **`COLOR_AMBER #ff6b00`** para o mesmo papel (títulos, headings, popups). São dois laranjas diferentes para o mesmo significado, em todas as telas.

- **`theme.tres` está off-token.** `default_font_size = 16` (`theme.tres:89`) não existe na escada `12/18/28/48` — todo `Label` sem override renderiza em **16**. E o tema define **só `font_color` para `Label`** (sem `font_size`), então **31 chamadas** de `add_theme_font_size_override` espalhadas suprem o buraco à mão. `LinkButton = 14` (off-token) também.

- **i18n do combate vaza pt-BR.** A chamada de luta "Pe/Pele/Pelejar" (`arena_manager.gd:172-184`) e o outro de vitória "assim seguimos…" (`:220`) são **literais**, não passam por `Lang` — aparecem em pt-BR mesmo em EN (a exploração é 100% traduzida, 19× `Lang.t`). Pior: os rótulos de resultado (crítico/aparou/erro) são **PNG pré-assados** (`result_*.png`), logo **não-i18n** e presos aos glifos — o "bloqueio" mostra **"APAROU"** porque a fonte 5×7 do gerador não tem B/L (gotcha #19).

- **Painéis: cada tela tem o seu.** Cinco fundos diferentes de painel/card (marrons/verdes/pretos ad-hoc) e quase nenhum usa o `panel_bg` do tema; `options_panel.gd:43-48` **reconstrói à mão** um StyleBox quase idêntico ao do tema.

- **Layers como magic numbers dispersos** (doom_fire −10, menu 1, world 0, beacon 9, hub_shop 10, rito 12, combat_loader 30, Atmosphere 50, combat_hud 52, D-pad 55, options 60, transition 100). O `Atmosphere` (50) escurece tudo abaixo (~65% nos cantos, gotcha #13), então exploração (0) e acampamento (10) ficam sob a vinheta e só o combate (52) tem header cristalino — a **mesma informação tem legibilidade diferente por tela**.

- **O nome real do inimigo/boss nunca aparece** (a barra usa o i18n genérico `hud.enemy`, `hud.gd:149`); a **fase atual não é exibida em lugar nenhum**.

- **Aprimoramento do acampamento:** os títulos de trilha **DANO/VIDA** (`hub_shop.gd:148-154`) são criados **incondicionalmente**, antes do `if not avail.is_empty()`. Uma trilha travada/maxada mostra o título sobre uma coluna vazia — o alvo explícito da correção pedida.

**Tese da PRD:** o problema não é falta de peças boas (há várias já maduras — `HealthBar`, `FragmentCounter`, `SpeakerButton`, `SceneTransition`, `StartButton`, `CombatArrowButton`). É **falta de um sistema**: uma linguagem visual única, tokens obrigatórios, componentes compartilhados e um dono de composição (`UiRoot`). Vamos construí-lo.

---

## 2. Decisões travadas (norte do projeto)

| # | Decisão | Implicação |
|---|---|---|
| **D1** | **Híbrido autoral.** FF = coerência + polish, mantendo a marca: cantos retos, `PressStart2P`, paleta laranja/sangue. A linguagem de **garra + placa serrilhada + brasa** (hoje só no `StartButton` e no D-pad de combate) vira o **chrome padrão de toda a UI**. | Nada de janela azul de JRPG. O "chrome" é uma moldura serrilhada/garra autoral, aplicada a painéis, cards, headers e botões. |
| **D2** | **Reescrita unificada (big-bang).** Um `UiRoot` único + biblioteca de componentes substitui os headers/telas de uma vez, numa refatoração coordenada (um branch → um PR). | Ver §12 para o sequenciamento interno com gate verde em cada checkpoint — big-bang não significa quebrar tudo de uma vez. |
| **D3** | **DANO/VIDA:** a trilha some **só quando não há upgrade a oferecer** (travada por fase / maxada / pré-requisito não cumprido — o card nem existe). Se o upgrade existe mas falta Terra Rara, mostra normal (estado "caro") como meta. | Predicado A (ver §10). Estável, sem piscar conforme a Terra Rara sobe/desce. |

---

## 3. Visão — "O Chrome da Mata"

Um único **Sistema de Interface** com quatro camadas:

```
┌─ TOKENS ──────────────────────────────────────────────────────────┐
│  Constants (paleta, escala, espaço, chrome, layers, safe-area)     │
│  + UiTheme construído em código a partir dos tokens (fim do drift) │
└───────────────────────────────────────────────────────────────────┘
                              ▼
┌─ CHROME (linguagem visual híbrida autoral) ───────────────────────┐
│  BrandFrame  — placa serrilhada + borda dura (garra/brasa)        │
│  desenhada por um util compartilhado (o vocabulário do StartButton)│
└───────────────────────────────────────────────────────────────────┘
                              ▼
┌─ COMPONENTES (kit reutilizável, scripts/ui/kit/) ─────────────────┐
│  BrandButton · BrandPanel · HudHeader · HealthBar · CurrencyCounter│
│  MuteButton · FloatingPopup · UpgradeCard · CombatFeedback        │
└───────────────────────────────────────────────────────────────────┘
                              ▼
┌─ UiRoot (autoload dono de composição + z-order + transições) ─────┐
│  HeaderSlot · OverlaySlot · TransitionSlot · FeedbackSlot         │
│  Compõe cada tela a partir do kit; z-order canônico; 1 transição  │
└───────────────────────────────────────────────────────────────────┘
```

Princípio-guia: **cada tela é uma composição do mesmo kit, não uma UI nova.** Trocar de tela troca o conteúdo dos slots, não a linguagem.

---

## 4. Tokens de design (Constants) — o que existe e o que falta

A fundação existe. Vamos **completá-la** e torná-la **obrigatória**.

### 4.1 Já existe (manter, referenciar sempre)
- **Paleta** (`constants.gd:245-320`): `COLOR_NIGHT #0d1117`, `COLOR_ARENA_BG #1a0f0f`, `COLOR_EARTH`, `COLOR_MOSS`, `COLOR_BLOOD #8b0000`, `COLOR_AMBER #ff6b00`, `COLOR_TEXT #c9d1d9`, `COLOR_JUBA #ff4500`, `COLOR_JUBA_DARK #8b2a00`, `COLOR_CHAMA_HOT #ffb032`, `COLOR_CHAMA_CORE #ffefb2`, `COLOR_CRYSTAL_GLOW`, `COLOR_GOLD`, `COLOR_BONE`.
- **Tipografia**: `FONT_SM=12`, `FONT_MD=18`, `FONT_LG=28`, `FONT_TITLE=48`.
- **Espaço**: `SPACE_XS=8`, `SPACE_SM=16`, `SPACE_MD=24`, `SPACE_LG=40`, `SPACE_XL=64`.
- **UI**: `UI_CORNER_RADIUS=0` (cantos retos — lei), `UI_BORDER_WIDTH=2`, `UI_PADDING_H=20`, `UI_PADDING_V=12`.
- **Helper**: `Constants.is_portrait(vp)` (`:15`).

### 4.2 Falta criar (novos tokens — matam os magic numbers)
```gdscript
# ─── Camadas canônicas (z-order único; hoje espalhado como magic numbers) ───
const LAYER_WORLD        := 0    # mundo + grade de cor por fase (atmosphere grade_layer)
const LAYER_WORLD_BEACON := 9    # ponteiros de borda (exit_beacon)
const LAYER_ATMOSPHERE   := 50   # vinheta+grão (já é 50) — NADA de leitura crítica abaixo
const LAYER_HUD          := 52   # HUD legível SEMPRE acima do Atmosphere
const LAYER_DPAD         := 55   # ControlsHud (já é 55)
const LAYER_STORY        := 58   # letterbox/telas narrativas (absorve FinalChoice 56/57, ending 20, boss-intro 15)
const LAYER_OVERLAY      := 60   # painéis modais (options, rito, pausa)
const LAYER_TRANSITION   := 100  # a ÚNICA transição/loader
const LAYER_DEBUG        := 127  # PerfHud
# Regra nova: NENHUM elemento de leitura crítica abaixo de LAYER_HUD.

# ─── Safe-area única (substitui as 3 fórmulas divergentes) ───
static func safe_insets(vp: Vector2) -> Vector2:
    var s := minf(vp.x, vp.y)
    return Vector2(clampf(s * 0.055, 40.0, 80.0), clampf(s * 0.05, 28.0, 64.0)) # (side, top)

# ─── Política tátil única (2x em telefone-retrato, aplicada IGUAL em toda tela) ───
const PHONE_SHORT_SIDE_MAX := 820.0
const HUD_TOUCH_SCALE      := 2.0
static func hud_touch_scale(vp: Vector2) -> float:
    return HUD_TOUCH_SCALE if is_portrait(vp) else 1.0

# ─── Chrome autoral (geometria da placa serrilhada + garra) ───
const CHROME_SAW_STEP   := 18.0  # do StartButton
const CHROME_SAW_DEPTH  := 8.0
const CHROME_CLAW_INSET := 6.0
```

> **Realidade atual do z-order (o que os tokens `LAYER_*` consertam):** hoje há **7 overlays de tela cheia caindo no layer 1 default** (menu, HUD de exploração, doom_fire, end_screen, cortejo_unlock, final_choice-root, timing_cue) — coordenados só por "não colidem porque são telas diferentes", frágil. Além disso `FinalChoice` usa 56/57/99, `BossIntro` 15, `Ending` 20, combat loader 30, `PerfHud` 127 — **nenhum enum central**, só comentários. E **dois componentes empatam no 100** (fade do menu + `SceneTransition`), resolvido por sorte de ordem de árvore. Com o `UiRoot`, **um só lugar seta `layer`**.

### 4.3 Regra de ouro dos tokens
- **Nenhum `Color(...)` literal novo em código de UI.** Deriva de `COLOR_*` (`lightened`/`darkened`/`.a`) ou vira token.
- **Nenhuma fração/clamp de layout inline.** Vira token ou helper em `Constants`.
- A cor bespoke da versão (`main_menu.gd:176`) vira `COLOR_TEXT_DIM` em `Constants`.
- **`COLOR_GOOD` colide com `COLOR_AMBER`** (`:255`) e com o fill da barra do inimigo — introduzir `COLOR_TEXT_DIM` e revisar se o âmbar do bloqueio parcial precisa de tom próprio (decisão de arte na §6).

---

## 5. UiTheme — fim do drift do `theme.tres`

**Problema:** `theme.tres` codifica a paleta como floats crus (`Color(0.545,0.165,0,1)` = `COLOR_JUBA_DARK`, etc.). Mudar `Constants` **não propaga** ao tema.

**Solução:** um autoload/serviço `UiTheme` que **constrói o `Theme` em código a partir de `Constants`** no boot e o registra como tema default do projeto (`ThemeDB.get_project_theme()` ou aplicado ao `UiRoot`). Um único ponto de verdade: a paleta e a escala vivem em `Constants`, o tema é derivado.

- `theme.tres` é **descontinuado** como fonte (pode virar um snapshot só para preview no editor).
- O `UiTheme` gera os `StyleBoxFlat` de `BrandButton`/`BrandPanel`/`ProgressBar` a partir dos tokens (bordas duras `UI_BORDER_WIDTH`, cantos retos `UI_CORNER_RADIUS=0`, paddings `UI_PADDING_*`, cores `COLOR_*`).
- Fonte default: `PressStart2P`, `default_font_size = FONT_MD` (hoje é **16 off-token**, `theme.tres:89`).
- **Fim do accent bifurcado:** o tema passa a usar **`COLOR_AMBER`** no accent de texto (hover/pressed/focus de botões e links) — hoje o `theme.tres` usa `COLOR_JUBA` aí, criando dois laranjas. Regra de marca: **`COLOR_JUBA` = borda/moldura do chrome (a "juba" que emoldura); `COLOR_AMBER` = acento/destaque/texto-cue e brasa** (consistente com o `StartButton`: borda JUBA, garra/brasa AMBER).
- **`Label` ganha `font_size = FONT_MD` no tema** (hoje só tem `font_color`, caindo no 16 off-token). Isso elimina a maioria das 31 chamadas inline de `add_theme_font_size_override`; `LinkButton = FONT_SM`.
- **Teste:** `test_ui_theme.gd` — o tema construído tem `default_font == PressStart2P`, cores de botão == `COLOR_*`, e nenhum stylebox com canto arredondado.

---

## 6. A linguagem visual híbrida autoral (o "Chrome")

O chrome é a assinatura de UI: **placa com bordas serrilhadas (dente de serra), moldura de borda dura, garras-chevron como ornamento e brasa âmbar como acento.** Já existe, isolado, em dois lugares — vamos extraí-lo para um util compartilhado.

### 6.1 Fonte do vocabulário (extrair, não inventar)
- **Placa serrilhada + garras `>>`/`<<` + brasas:** `StartButton::_saw_plate` (`start_button.gd:96-110`), `_draw_claws` (`:116-121`), `_draw_embers` (`:134-148`). Constantes `SAW_STEP=18`, `SAW_DEPTH=8`, `OUTLINE_WIDTH=2`.
- **Glifo de garra tribal 16×16 + plate de borda dura + overlays de resultado** (cristal/âmbar/sangue) + anel de impacto + carga de fogo: `CombatArrowButton` (`combat_arrow_button.gd:25-42, 249-342`).

### 6.2 `BrandFrame` (util de desenho compartilhado)
Um script utilitário (`scripts/ui/kit/brand_frame.gd`, `class_name BrandFrame`) com funções estáticas de desenho, consumidas por qualquer `Control` no seu `_draw()`:
```gdscript
static func draw_saw_plate(ci: CanvasItem, rect: Rect2, bg: Color, border: Color) -> void
static func draw_claws(ci: CanvasItem, inner: Rect2, color: Color) -> void   # >> ... <<
static func draw_embers(ci: CanvasItem, rect: Rect2, color: Color, alpha: float) -> void
static func draw_hard_border(ci: CanvasItem, rect: Rect2, color: Color, w: int) -> void
```
- Reusa a geometria do `StartButton` (mesmos `CHROME_SAW_*`).
- É a **única** implementação de "placa serrilhada de marca" — `StartButton`, `BrandPanel`, `HudHeader` e a bandeja do acampamento passam a chamá-la.

### 6.3 Estados e movimento (unificados)
- **Idle → respiro** (brasa pulsa, `StartButton::_start_breath` 1.3s/lado) — para elementos-herói.
- **Hover/focus → "lit"** (borda `COLOR_JUBA_DARK`→`COLOR_JUBA`, garra `COLOR_AMBER`).
- **Press → bote** (escala 1.04 / lunge do glifo, não afundamento).
- **Resultado (combate):** cristal (`COLOR_CRYSTAL_GLOW`) = perfeito, âmbar (`COLOR_GOOD`) = GOOD, sangue (`COLOR_BLOOD`) = erro — vocabulário do `CombatArrowButton`, reusado nos feedbacks.
- Durações viram tokens (`CHROME_PRESS_SECS`, `CHROME_BREATH_SECS`) em vez de literais por arquivo.

### 6.4 Travas de identidade visual (skill `visual-identity`)
O chrome **reforça** a marca (silhueta laranja serrilhada, vazio preto, olhos brancos, verde mínimo, pixel-art chapada, outline 1-2px duro). Proibições: nada de canto arredondado, gradiente suave, blur, dither decorativo, glossy. Consultar `.agents/skills/visual-identity/SKILL.md` antes de qualquer ajuste de forma/cor.

---

## 7. Biblioteca de componentes (`scripts/ui/kit/`)

Cada componente tem API estável, consome só tokens, e substitui código espalhado. Todos `Control`-based, testáveis por estado, i18n via `Lang.t`.

### 7.1 `BrandButton` (unifica todos os botões)
Substitui: `StartButton` (herói), botão Opções + bandeiras (`main_menu.gd` styleboxes inline), banner update, e serve como base de qualquer botão do jogo.
```gdscript
class_name BrandButton extends BaseButton
enum Variant { HERO, PRIMARY, GHOST, FLAG, LINK }
@export var variant: Variant = Variant.PRIMARY
@export var label: String = ""
func configure(size_px: Vector2) -> void
```
- `_draw()` via `BrandFrame`. Estados lit/pressed/disabled do vocabulário do chrome.
- `HERO` = a placa completa (serrilhado + garras + brasa) do `StartButton` atual.
- `PRIMARY/GHOST` = placa mais sóbria para menus/painéis.
- Fim dos 3 caminhos de estilo de botão.

### 7.2 `BrandPanel` (a "janela" da mata)
Substitui: a bandeja do acampamento (`hub_shop.gd::_tray_style`), o painel de opções, o fundo de diálogo/ending, o scrim do menu.
```gdscript
class_name BrandPanel extends PanelContainer
@export var framed: bool = true        # borda serrilhada de marca vs. scrim liso
@export var scrim_alpha: float = 0.82
```
- Uma única "janela" para todo modal/painel → coerência FF de "caixa de menu".

### 7.3 `HudHeader` (mata o problema central)
Substitui os **três** headers (`hud.gd::_layout_exploration`, `hud.gd::_layout_combat_header`, `hub_shop.gd::_build_header`).
```gdscript
class_name HudHeader extends Control
enum Mode { MENU, CAMP, EXPLORATION, COMBAT }
func set_mode(mode: Mode) -> void
# Slots resolvidos por modo:
#   left  : HealthBar do jogador (CAMP: oculto — o acampamento cura ao entrar)
#   center: (COMBAT) nada / respiro; (outros) livre
#   right : CurrencyCounter + MuteButton (COMBAT: ocultos)
#   mirror: (COMBAT) HealthBar do inimigo à direita, espelhada, com NOME REAL da criatura
```
- **Um só sistema de layout** (containers + `Constants.safe_insets` + `Constants.hud_touch_scale`) — fim do "absoluto vs. containers" e das 3 safe-areas.
- `CurrencyCounter`/`MuteButton` **têm o mesmo tamanho em toda tela e orientação** (política tátil única).
- **COMBAT** mostra o **nome real do inimigo/boss** (novo requisito) e, opcional, um **badge de fase** (`GameState.active_phase`) — hoje invisível em todo lugar.
- Vive em `LAYER_HUD=52` em TODAS as telas → legibilidade uniforme acima do `Atmosphere`.

### 7.4 `HealthBar` (evoluir o que já é bom)
Já é o componente mais maduro (`health_bar.gd`): fill com tween, rastro-fantasma de dano, ticks de 1 HP, pulso de vida baixa, `set_mirrored`, `configure_size`. Mudanças:
- Geometria (`HEADER_H=22`, `BAR_H=20`, `GAP=4`, tweens 0.18/0.45) e a derivação de borda (hoje divergente: jogador `lightened(0.2)` vs. inimigo `darkened(0.15)`, `hud.gd:47,149`) viram **tokens/uma regra única**.
- Variante `boss` vira **preset nomeado** (não flag + magic `+4/+6`).
- Aceitar **nome real** (parâmetro de label já existe; o `HudHeader` passa o nome da criatura em vez de `hud.enemy`).
- Mantém a lei de "barra sem número" já estabelecida por `PRD-hud-premium` (R1).

### 7.5 `CurrencyCounter` (era `FragmentCounter`) e `MuteButton` (era `SpeakerButton`)
Já componentizados. Unificar **dimensionamento** (a política tátil vira do componente, não do chamador) e **semântica do mudo** (hoje o hub faz `toggle_master_mute` e o HUD faz `toggle_music_ambience` — escolher UMA; recomendação: `toggle_music_ambience` em todo lugar, com `master_mute` só nas Opções).

### 7.6 `FloatingPopup` (serviço único)
Substitui `hud.gd::_show_popup`/`_show_fragment_popup` e `hub_shop.gd::_spawn_floating_cost`.
```gdscript
UiRoot.popup(text: String, color: Color, anchor: Vector2) -> void   # subir + fade, uma curva só
```

### 7.7 `UpgradeCard` (era `HubCard`) + trilha
Mantém a ficha de uma linha (`[+N dano/HP   ◈ custo]`, `hub_card.gd`), estados afford/locked, `consume`/`deny`. Passa a usar `BrandFrame` para a borda (fim do `BORDER=3` inline vs. `UI_BORDER_WIDTH=2`) e tokens de margem (fim do `12` hardcoded). É o §10 (DANO/VIDA).

### 7.8 `CombatFeedback` (tira o HUD de combate do world-space)
Move contador de combo, rótulos de resultado e tag de nome de golpe do **world-space** (`feedback_system.gd`, hoje afetados por câmera e vinheta) para uma camada **screen-space** em `LAYER_HUD`.
- Combo deixa de derivar com o zoom-punch e de escurecer sob o `Atmosphere`.
- Mantém os assets PNG existentes (`result_*.png`, `combo_digit_sheet.png`) — só muda o dono/espaço.
- O tell reativo por-hit (`timing_alert`) e a bolha de timing permanecem no mundo (são diegéticos, ancorados no ator) — **não** migram.

---

## 8. Arquitetura — `UiRoot`

Um autoload (`scripts/core/ui_root.gd`, `class_name UiRoot`) que é o **dono da composição de UI**. Não substitui `GameState` (roteamento de cena continua nele) — o `UiRoot` reage a `SignalBus.screen_changed` e monta a UI da tela a partir do kit.

```gdscript
UiRoot
 ├─ HeaderSlot   (HudHeader, LAYER_HUD)      — recomposto por modo a cada tela
 ├─ FeedbackSlot (CombatFeedback, LAYER_HUD) — só ativo em combate
 ├─ OverlaySlot  (BrandPanel modais, LAYER_OVERLAY) — options, rito, pausa
 └─ TransitionSlot (LAYER_TRANSITION)        — a ÚNICA transição/loader
```

Responsabilidades:
- **Z-order canônico** (tokens `LAYER_*`) — um lugar decide a pilha; fim dos layers mágicos por arquivo.
- **Composição por modo** — `screen_changed(EXPLORATION)` → `HeaderSlot.set_mode(EXPLORATION)`, esconde `FeedbackSlot`, etc.
- **Persistência entre telas** — o header e a transição deixam de ser recriados por cena (hoje `hud.tscn` é instanciado em cada `.tscn` de arena/exploração e o hub tem o seu). As cenas de gameplay ficam só com o **mundo**; a UI vive no `UiRoot`.
- **Legibilidade uniforme** — todo HUD acima do `Atmosphere`.

> **Nota de arquitetura:** hoje `scenes/ui/hud.tscn` está embutido em cada `.tscn` de exploração/arena e o acampamento monta o seu em código. O `UiRoot` centraliza isso. Como mexer em `.tscn` é arriscado (gotcha #7), a remoção do `hud.tscn` das cenas é feita com `git diff` revisado a cada passo (ver §12) — de preferência removendo a instância via editor Godot, não por MCP.

---

## 9. Transições e loaders unificados

Um único **serviço de transição** no `TransitionSlot` (evolui `SceneTransition`), com variantes:

| Variante | Uso | Vem de |
|---|---|---|
| `FADE` | troca simples (entrada de arena) | `SceneTransition` atual |
| `THEMED_TEXT` | fase nova / acampamento (flavor âmbar + olhos que piscam) | `SceneTransition::_flavor_for` |
| `SYLLABLE` | chamada de luta ("Pe→Pele→Pelejar") | absorve `arena_manager::_run_combat_loader` |
| `PROGRESS` | boot web (barra real) | espelha `html/shell.html` (fora do engine; alinhar marca) |

- **Mata o fade paralelo do menu** (`main_menu.gd::_setup_fade`, já declarado morto pelo `PLANO-marca-loader-menu-aaa`).
- **Assinatura "olhos que piscam"** vira **um** motivo de marca reutilizável (hoje reimplementado 3×: `scene_transition.gd:52-65`, logo `main_menu.gd::_schedule_blink`, HTML `@keyframes caipora-blink`).
- O combat loader deixa de ter fonte/layer/tween próprios — é a variante `SYLLABLE` do serviço único (o SFX de sílaba e o `transition_window` remoto permanecem). **Ao absorver, rotear "Pelejar" e o outro de vitória por `Lang`** — hoje são literais pt-BR (`arena_manager.gd:172-184,220`) que vazam em EN.

---

## 10. O fix DANO/VIDA (predicado A) — detalhado

**Estado atual:** o heading da trilha é criado incondicionalmente (`hub_shop.gd:148-154`) antes do `if not avail.is_empty()` (`:158`). `available_keys(keys)` (→ `MetaProgression.is_available`, `meta_progression.gd:180-192`) filtra por **fase alcançada + gate de vitórias + pré-requisito + não-maxado**, mas **não** por Terra Rara (affordability é estado de UI, `:178-179`). Logo `column["cards"]` já inclui os upgrades "a caminho" (elegíveis mas ainda caros).

**Predicado A:** a trilha (título **e** coluna) aparece **sse e somente se** `not column["cards"].is_empty()`.
- Tem card comprável **ou** a caminho (caro) → mostra `DANO`/`VIDA`.
- Travada por fase / maxada / pré-requisito não cumprido → 0 cards → **esconde**.
- Comprou o último card disponível nesta visita (`_remove_card`, `:199-204`) → coluna esvazia → **esconde** no `refresh()`.

**Implementação (mínima, sem tocar em lógica):**
1. Em `_build_column` (`:141-167`), após montar `column`, esconder a **coluna inteira** quando vazia:
   ```gdscript
   column["vbox"].visible = not column["cards"].is_empty()
   ```
   Esconder o `vbox` (não só o heading `Label`) faz o `BoxContainer` pai **não reservar largura** para a coluna morta, e `_tracks.alignment = ALIGNMENT_CENTER` **recentraliza** a trilha sobrevivente — sem gap vazio. (Esconder só o heading deixaria uma coluna fantasma ocupando espaço.)
2. Em `refresh()` (`:208-214`), reavaliar por linha (roda no build, pós-compra e troca de idioma):
   ```gdscript
   for line: String in _columns:
       var col: Dictionary = _columns[line]
       col["vbox"].visible = not col["cards"].is_empty()
       for card: HubCard in col["cards"]:
           card.set_affordable(MetaProgression.fragments >= card.cost)
   ```
3. `_refresh_text` (`:215-223`) já chama `refresh()` no fim → troca de idioma mantém a regra.
4. **Edge case:** ambas as trilhas vazias (tudo maxado/travado) → nenhuma coluna visível. O acampamento deve mostrar um estado "nada a aprender agora" (um `Label` discreto no lugar da bandeja) em vez de bandeja vazia — decisão de arte, mas prevista.

**Teste (`test_hub_shop.gd`):** trilha sem `available_keys` → `column["vbox"].visible == false`; trilha com pelo menos 1 elegível (mesmo caro) → `visible == true`; comprar o último card → `visible` vira `false` após `refresh()`.

---

## 11. Composição por tela (tudo do mesmo kit)

| Tela | Header | Overlay | Transição de entrada | Notas |
|---|---|---|---|---|
| **Boot (web)** | — | — | `PROGRESS` (shell.html) | Fora do engine; só alinhar marca/cores aos tokens. |
| **Menu** | `HudHeader.MENU` (só footer/versão) | `BrandPanel` (Opções) | `THEMED_TEXT`/`FADE` | Botões = `BrandButton`; diorama de fundo mantido; fade paralelo removido. |
| **Acampamento** | `HudHeader.CAMP` (Terra Rara + mudo, **sem HP**) | `BrandPanel` (rito) | `THEMED_TEXT` ("o acampamento respira…") | Bandeja e cards = `BrandPanel`/`UpgradeCard`; §10. |
| **Exploração** | `HudHeader.EXPLORATION` (HP esq. + Terra Rara/mudo dir.) | — | `THEMED_TEXT` ("a mata se reorganiza…") | Ícones 2x em telefone-retrato via política única. |
| **Combate** | `HudHeader.COMBAT` (HP jogador × inimigo espelhado + nome real + badge de fase) | — | `SYLLABLE` ("Pelejar") | `CombatFeedback` (combo/resultado/nome de golpe) em screen-space. |
| **História/Ending** | — | `BrandPanel` (diálogo/escolha) | `FADE`/`THEMED_TEXT` | `dialogue_screen`, `ending_*`, `final_choice` passam a usar `BrandPanel`/`BrandButton`. |

---

## 12. Migração big-bang — sequenciamento com gate verde

Big-bang = **um branch, um PR**, mas entregue como uma pilha de commits em que **cada checkpoint mantém `make gate` verde** (o protocolo do projeto exige commit por passo e não pode quebrar o smoke). Ordem que minimiza risco:

1. **Tokens** — adicionar `LAYER_*`, `safe_insets`, `hud_touch_scale`, `CHROME_*`, `COLOR_TEXT_DIM` em `Constants`. Nenhum consumidor muda ainda. `make import` (novos consts) + `make gate`.
2. **`UiTheme`** — construir o tema em código a partir dos tokens; testar (`test_ui_theme`). `theme.tres` ainda existe como fallback. Gate.
3. **`BrandFrame` + `BrandButton` + `BrandPanel`** — kit de chrome, com testes de estado. Ainda não plugado nas telas. Gate (contagem de testes **sobe** — gotcha #12).
4. **`HudHeader`** — o componente que mata os 3 headers, com testes de modo. Ainda não plugado. Gate.
5. **`UiRoot`** (autoload) — slots + z-order + composição por `screen_changed`, começando por **uma** tela (exploração, a mais simples) atrás do novo caminho, com o antigo ainda vivo nas outras. Gate + `/validate-platforms`.
6. **Migrar tela a tela** (menu → acampamento → combate → história), cada uma um commit, removendo o header/estilo antigo daquela tela. Remoção do `hud.tscn` embutido feita via editor Godot com `git diff` revisado (gotcha #7). `/validate-controls` ao tocar combate; `/validate-platforms` sempre.
7. **§10 DANO/VIDA** — dentro da migração do acampamento (ou antes, como quick win isolado).
8. **`CombatFeedback`** — mover combo/resultado/nome de golpe para screen-space. `/validate-controls` + gate.
9. **Transições unificadas** — absorver combat loader + matar fade paralelo do menu. Gate.
10. **Limpeza** — remover código morto (`_show_popup` duplicado, `_apply_*_style` inline, `theme.tres` como fonte, magic numbers), atualizar `AGENTS.md` (novo gotcha de "UI vive no UiRoot, não nas cenas") e os PRDs superados. Remover o órfão `assets/fonts/m5x7.ttf.import` (sem `.ttf`, sem referências).

> Cada passo é `commitável` e verde. O PR final é grande, mas revisável commit-a-commit. Se o dono preferir fatiar em PRs empilhados, a mesma ordem serve.

---

## 13. i18n, plataformas e acessibilidade

- **i18n:** todo texto de UI via `Lang.t`/`Lang.tf`. O kit **nunca** hardcoda pt-BR. Auditar strings soltas na migração (a `Hud.format_fragment_popup` static é a exceção documentada — não mexer, gotcha do i18n). Trocar idioma re-lê todos os componentes (o `UiRoot` reemite para os slots). **Gaps concretos a fechar:** o combat loader "Pe/Pele/Pelejar" e o outro "assim seguimos…" (`arena_manager.gd:172-184,220`) vazam pt-BR (ver §9); os rótulos de resultado são PNG não-traduzíveis ("APAROU" pela fonte 5×7) — decidir texto vivo vs. PNG por-idioma no `CombatFeedback`.
- **Plataformas (gotcha #10):** orientação livre; tudo reflui em `size_changed` via `UiRoot`. Retrato de telefone (~393px), paisagem com safe-areas `env()` (o `ControlsHud` já trata), tablet+ (zoom cap 2.0x). `/validate-platforms` antes de cada commit de UI.
- **Legibilidade sob `Atmosphere` (gotcha #13):** regra nova — leitura crítica **sempre** ≥ `LAYER_HUD=52`. Fim do header escurecido na exploração/acampamento.
- **Alvo de toque:** mudo ≥ 72px físicos em retrato (política tátil única, herda o critério de `PRD-hud-premium` R3).
- **Reduce-motion (futuro próximo):** o respiro/brasa do chrome deve respeitar uma flag de movimento reduzido (amarrar ao trabalho de `PLANO-refino-protagonista`).

---

## 14. Plano de testes

- **Unit (GUT), novos:** `test_ui_theme` (tema derivado dos tokens), `test_brand_button`/`test_brand_panel` (estados por variante, sem canto arredondado), `test_hud_header` (modo → visibilidade de slots; nome real do inimigo em COMBAT; ícones ocultos em COMBAT; escala tátil só em retrato), `test_ui_root` (z-order canônico; composição por `screen_changed`).
- **Unit, ajustes:** `test_hub_shop` (predicado A do §10), `test_health_bar` (mantém "sem número", `set_mirrored`, nome real), `test_menu_v3` (botões via `BrandButton`).
- **Regra gotcha #12:** após adicionar arquivos de teste, confirmar que a **contagem total subiu** no resumo do GUT (GUT pula em silêncio arquivos que não parseiam após novo `class_name` sem `make import`).
- **Smoke:** `make smoke` verde em cada checkpoint.
- **Manual:** `/validate-platforms` (retrato/paisagem/tablet) e `/validate-controls` (ao tocar combate/D-pad/feedback) — atravessar `menu → camp → exploração → combate` e conferir que o header, os ícones e as transições são visualmente **os mesmos** em toda parte.
- **Preview tools:** estender `scripts/tools/preview_hud.gd`/`preview_combat_dpad.gd`/`preview_camp_spirits.gd` para capturar cada modo do `HudHeader` sob Xvfb.

---

## 15. Critérios de aceite

1. **Um** componente `HudHeader` serve menu, acampamento, exploração e combate — não há mais 3 headers.
2. `CurrencyCounter` e `MuteButton` têm o **mesmo tamanho e posição relativa** em toda tela, escalando por uma **única** política tátil (2x em telefone-retrato).
3. Safe-area vem de **uma** função (`Constants.safe_insets`); zero fórmulas divergentes.
4. Todo botão do jogo é `BrandButton`; todo painel/modal é `BrandPanel`; ambos desenham o chrome via `BrandFrame` (placa serrilhada + borda dura). Nenhum `StyleBoxFlat` inline sobrando.
5. `UiTheme` deriva de `Constants`; mudar um `COLOR_*` propaga para toda a UI. `theme.tres` não é mais fonte de verdade.
6. Uma **única** transição/loader (`FADE`/`THEMED_TEXT`/`SYLLABLE`/`PROGRESS`); o fade paralelo do menu e o combat loader isolado deixaram de existir como código separado.
7. HUD de combate (combo, resultado, nome de golpe) em **screen-space** acima do `Atmosphere` — não deriva com o zoom nem escurece.
8. Combate mostra o **nome real** do inimigo/boss (fim do `hud.enemy` genérico).
9. Acampamento: trilha **DANO/VIDA some** quando não há upgrade a oferecer (predicado A), recentralizando a trilha sobrevivente; reaparece quando um upgrade fica elegível.
10. Todo texto de UI via `Lang`; nada hardcoded. Reflui em `size_changed`; `make gate`, `/validate-platforms` e `/validate-controls` verdes.
11. **Tom preservado:** cantos retos, paleta fechada, chrome de garra/serrilhado/brasa — o horror folk fica **mais** coeso, nunca suavizado.

---

## 16. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| Big-bang quebra o gate no meio | Sequenciamento §12 com commit verde por checkpoint; a tela nova convive com a antiga até ser trocada. |
| Corrupção de `.tscn` ao remover `hud.tscn` embutido (gotcha #7) | Remover via editor Godot, `git diff` revisado a cada passo; nunca via MCP `save_scene`. |
| `UiRoot` autoload e cenas de preview (gotcha #14) | Configurar estado no frame 1 do `_process`, não em `_initialize`; sandbox de save nos previews. |
| Regressão de input ao mover feedback de combate | `/validate-controls` obrigatório; o contrato de input (D-pad dual-path) **não** muda — só o dono do visual. |
| Tema em código diverge do preview no editor | `theme.tres` vira snapshot só-editor gerado a partir dos mesmos tokens; teste trava a paridade. |
| Escopo enorme numa sessão | Se o dono preferir, os checkpoints §12 viram PRs empilhados (uma tela por sessão) — mesma arquitetura, entrega fatiada. |

---

## 17. Fora de escopo / futuro

- Retratos de personagem (P1/P2) ao lado das barras (custo de asset; já anotado em `PRD-hud-premium` §10).
- Barra de combo/super no header.
- Menu de comando FF-like no combate (Atacar/Defender/Item) — o combate é timing puro; um menu quebraria o ritmo. Não fazer.
- Tipografia secundária (fonte de corpo além da `PressStart2P`) para textos longos de diálogo — avaliar legibilidade em telefone.
- Som de UI unificado (hover/press/erro) amarrado ao chrome — hoje disperso em `AudioDirector.play_ui_*`.

---

## 18. Referências

- **Prior art (superado/absorvido):** `docs/PRD-hud-premium.md` (barras sem número, header espelhado, ícones 2x, link github — já implementado; vira caso particular do `HudHeader`), `docs/PRD-acampamento-premium-i18n.md` (já implementado), `docs/PRD-tela-inicial-v3.md`, `docs/PLANO-marca-loader-menu-aaa.md` (fade paralelo do menu já declarado morto — esta PRD executa a remoção).
- **Código-fonte inventariado:** `scripts/ui/hud.gd`, `scripts/ui/health_bar.gd`, `scripts/ui/fragment_counter.gd`, `scripts/ui/speaker_button.gd`, `scripts/ui/main_menu.gd`, `scripts/ui/start_button.gd`, `scripts/ui/combat_arrow_button.gd`, `scripts/ui/options_panel.gd`, `scripts/core/scene_transition.gd`, `scripts/hub/hub_shop.gd`, `scripts/hub/hub_card.gd`, `scripts/systems/feedback_system.gd`, `scripts/arena/arena_manager.gd` (loader/HUD), `scripts/utils/constants.gd`, `assets/fonts/theme.tres`, `html/shell.html`.
- **Skills obrigatórias:** `.agents/skills/visual-identity/SKILL.md` (marca), gotchas #7 (`.tscn`), #10 (plataformas), #12 (`make import`/GUT), #13 (`Atmosphere`), #14 (previews/autoloads), #21 (instruções stale).
- **Comandos:** `/validate-platforms`, `/validate-controls`, `make gate`, `make import`.
