# PRD — HUD Premium: barras sem número, header de luta e HUD tátil de exploração

> Status: proposto · Autor: sessão de design · Escopo: camada de UI (HUD + footer do menu)
> Alvo de qualidade: **visual premium**, sem tocar em lógica de dano/vida, input, timing ou câmera.

---

## 1. Contexto e motivação

O HUD hoje é **um único componente compartilhado** (`scenes/ui/hud.tscn` → `scripts/ui/hud.gd`)
instanciado tanto na exploração quanto na arena. Ele mostra sempre: barra do jogador
(topo-esq), contador de Terra Rara + botão de mudo (topo-dir) e, quando `show_enemy_hp`,
a barra do inimigo centralizada abaixo.

Três problemas de leitura e polimento:

1. **Números de HP poluem a leitura.** As barras já comunicam a proporção com fill animado,
   rastro de dano e ticks de 1 HP; o texto `"cur/max"` é ruído e destoa de um acabamento
   premium — a barra deve falar sozinha.
2. **HUD de exploração é pequeno demais no telefone retrato.** No modo tátil, o botão de
   mudo (28 px desenhados) e o ícone de Terra Rara (~17 px no retrato de telefone) são
   alvos e leituras minúsculos onde o polegar e o olho mais precisam deles.
3. **Combate não tem hierarquia de jogo de luta.** Terra Rara e o botão de áudio não têm
   função durante a briga e disputam atenção com o combate. Falta o header espelhado
   "P1 × P2" de _fighting games_ (Street Fighter), que é a linguagem que o timing-combat pede.

O menu inicial precisa ainda de um link **github** apontando para o repositório do jogo.

---

## 2. Objetivos e não-objetivos

### Objetivos
- **O1.** Remover os números de HP de **ambas** as barras (jogador e inimigo), preservando
  a barra, o nome e o feedback visual (fill, rastro, ticks, pulso de vida baixa).
- **O2.** Footer da tela inicial com link **github** que abre o **repositório do jogo**.
- **O3.** Exploração, telefone, **retrato**: dobrar (≥2x) o ícone de mudo e o
  ícone+contagem de Terra Rara, mantendo alvo de toque generoso.
- **O4.** Combate (arena): **ocultar** Terra Rara e botão de mudo; apresentar apenas um
  **header espelhado com os dois HPs** (jogador à esquerda, adversário à direita), no
  espírito Street Fighter, com acabamento premium.

### Não-objetivos
- Não alterar lógica de dano, cura, `HealthComponent`, timing, input tátil ou câmera.
- Não mudar o roteamento de áudio nem o significado do botão de mudo (só tamanho/visibilidade).
- Não introduzir novos assets pesados (o header usa desenho procedural, como as barras atuais).
- Não travar orientação: tudo continua reagindo a `size_changed` (gotcha #10).

---

## 3. Estado atual (auditoria)

| Elemento | Onde | Comportamento hoje |
|---|---|---|
| Número de HP | `scripts/ui/health_bar.gd:172` (`_update_value_label`), label criado em `:53-57`, desenhado como `"%d/%d"` | Sempre visível, alinhado à direita do cabeçalho da barra |
| Nome da barra | `health_bar.gd:48-51`, `_name_label` | Mantém (CAIPORA / nome do inimigo) |
| Fill / rastro / ticks / pulso | `health_bar.gd:_draw()` `:177-219` | Fill **sempre ancorado à esquerda** (drena p/ a direita) |
| Barra do jogador | `scripts/ui/hud.gd:33-42`, `_layout` `:80-83` | Topo-esquerda |
| Terra Rara | `scripts/ui/fragment_counter.gd` (`ICON_BOX=22 * glyph_size`), no HUD `hud.gd:44-46`, `_layout` `:86-97` | Topo-direita, escala pela fonte (fica ~17 px no retrato de telefone) |
| Botão de mudo | `scripts/ui/speaker_button.gd` (`SIZE=28`, `HITBOX_PAD=8` → alvo 44×44), no HUD `hud.gd:48-52` | Topo-direita, tamanho **fixo** |
| Barra do inimigo | `hud.gd:54-59`, `_setup_enemy_bar` `:108-118`, `_layout` `:101-106` | **Centralizada abaixo** dos cantos do topo |
| Discriminador de modo | `show_enemy_hp` (`hud.gd:15`) | `false` em `scenes/exploration/*.tscn:24`; `true` (default) nas `scenes/arena/*.tscn` → **é o seam confiável combate↔exploração** |
| Link github | `scripts/ui/main_menu.gd:164-170` + `_on_github_pressed` `:329-331` | **Já existe** o `LinkButton "github"`, mas abre o **perfil** `https://github.com/baltazarparra` |
| Repositório real | `git remote` | `git@github.com:baltazarparra/caipora.git` → `https://github.com/baltazarparra/caipora` |
| Teste que trava o número | `tests/unit/test_health_bar.gd:45-48` | `assert_eq(_bar._value_label.text, "6/10")` — **vai quebrar** e precisa ser reescrito |

**Achado importante:** o link github **não precisa ser criado** — precisa **apontar para o
repo**. E o modo de combate **já é distinguível** por `show_enemy_hp`, então não é preciso
inventar sinal novo para ramificar o layout.

---

## 4. Requisitos detalhados

### R1 — Barras de HP sem número (jogador e inimigo)

**Comportamento:** a barra continua idêntica (fill, rastro, ticks, pulso, moldura, nome);
apenas o texto `"cur/max"` deixa de existir.

**Abordagem (elegante, mínima):**
- Em `HealthBar`, remover o `_value_label` do cabeçalho e liberar o `_name_label` para
  ocupar a largura útil do header (o nome deixa de dividir espaço com o número em
  `_relayout()` `:155-162`).
- `_update_value_label()` deixa de existir (ou vira _no-op_); as chamadas em `setup`/`set_max`/`set_value` saem.
- **Ticks de 1 HP permanecem** — eram a leitura discreta que os ícones davam e ganham
  importância agora que não há número. Mantidos como estão (`_draw()` `:209-216`).
- **Teste:** substituir `test_value_label_text` (`test_health_bar.gd:45-48`) por uma
  asserção de que a barra **não** expõe rótulo numérico (ex.: garantir que não há `_value_label`
  ou que o header só contém o nome). Não afrouxar os testes de lógica de valor/máx/clamp.

**Premium:** sem o número, dar ao nome um tratamento tipográfico levemente mais forte
(peso/《tracking》) e garantir contraste sobre a moldura. O rastro de dano (ghost) passa a
ser a principal pista de "quanto saiu" — mantê-lo bem visível.

---

### R2 — Footer do menu: link **github** → repositório do jogo

**Comportamento:** clicar em "github" abre `https://github.com/baltazarparra/caipora`.

**Abordagem:** corrigir a URL em `main_menu.gd:330`
(`OS.shell_open("https://github.com/baltazarparra")` → `.../caipora`). O `LinkButton` já
existe, já está no footer, já tem hover-SFX e i18n-safe (nome de marca, sem tradução).

- Definir a URL como constante nomeada no topo (`const GITHUB_URL := "https://github.com/baltazarparra/caipora"`)
  para evitar _magic string_ (padrão do projeto: sem strings/números mágicos).
- No web, `OS.shell_open` abre nova aba — comportamento desejado; validar que não é bloqueado
  por pop-up (é disparado por gesto do usuário, então ok).

---

### R3 — Exploração, telefone, retrato: ícones 2x (mudo + Terra Rara)

**Comportamento:** quando `show_enemy_hp == false` **e** `Constants.is_portrait(vp)` **e**
telefone (`minf(vp) < Constants.PHONE_SHORT_SIDE_MAX`), o botão de mudo e o bloco de Terra
Rara ficam com **≥2x** o tamanho atual, com o alvo de toque do mudo crescendo junto.

**Abordagem:**
- `SpeakerButton`: tornar o tamanho configurável. Adicionar
  `func configure_size(icon_px: float) -> void` que ajusta o desenho e o
  `custom_minimum_size` (`icon_px + HITBOX_PAD*2`, com o pad também escalando um pouco para
  manter respiro). `SIZE=28` vira o _default_/base. Sem `configure_size`, comportamento atual.
- `FragmentCounter`: já escala por `glyph_size` (`:41-46`). Aceitar um multiplicador de
  ícone/fonte para o modo tátil (ex.: `configure_size(font_size, icon_scale := 1.0)`), ou
  simplesmente passar uma fonte maior no HUD para este modo — o `ICON_BOX` acompanha o
  `glyph_size`. Preferir o multiplicador explícito para não distorcer a fonte do resto do HUD.
- `Hud._layout()` (`:74-106`): calcular um fator `hud_scale` — `2.0` quando exploração +
  retrato + telefone, `1.0` caso contrário — e aplicá-lo a `_music_btn` e `_frag_counter`.
  Como `_layout` já roda em `size_changed`, girar o device recomputa o fator (retrato↔paisagem
  reflui sozinho).
- Definir os fatores como constantes no `Hud` (`HUD_TOUCH_SCALE := 2.0`) — sem números mágicos.

**Premium & acessibilidade:**
- Alvo de toque do mudo ≥ 72 px físicos no retrato (Apple HIG mínimo 44 pt; 2x nos leva a
  ~72–88 px — folgado para o polegar).
- O ícone de Terra Rara maior ganha peso de "moeda" na tela; manter o `_pop()` (pulso ao
  ganhar) proporcional ao novo tamanho.
- **Cuidado com o `Atmosphere` (gotcha #13):** a vinheta (CanvasLayer 50) escurece os
  cantos onde esses ícones vivem. Com o dobro do tamanho eles ganham massa e legibilidade,
  mas validar contraste no export web; se necessário, clarear **só** os ícones
  (não o fundo) — nunca suavizar a atmosfera.

---

### R4 — Combate: header espelhado estilo Street Fighter

**Comportamento:** na arena (`show_enemy_hp == true`):
- **Ocultar** `_frag_counter` e `_music_btn` (não há Terra Rara nem mudo durante a briga).
- Apresentar **apenas** um header com os dois HPs no topo:
  - **Jogador** à esquerda, nome para fora (esquerda), fill drenando **da borda esquerda
    em direção ao centro**.
  - **Adversário** à direita, nome para fora (direita), fill **espelhado**: ancorado na
    borda direita, drenando em direção ao centro.
  - Os dois se encontram no centro, deixando um respiro (ou divisória sutil) no meio —
    a leitura "eu × ele" imediata dos jogos de luta.

**Abordagem:**
- `HealthBar`: adicionar `func set_mirrored(value: bool)` (default `false`). Quando `true`,
  o `_draw()` ancora o fill/rastro/sheen na **direita** e o `_name_label` alinha à direita.
  Ticks, pulso e moldura são simétricos — inalterados. O jogador usa `false`, o inimigo `true`.
- `Hud._layout()`: quando `show_enemy_hp`, posicionar as duas barras **na mesma fileira do
  topo** — jogador ancorado à esquerda (`side`), inimigo ancorado à direita
  (`vp.x - side - ew`) — em vez de centralizar a barra do inimigo abaixo. Largura simétrica
  entre as duas (o boss pode ser mais largo/alto pelo caminho `is_boss` já existente
  `health_bar.gd:144-153`, mas mantendo o espelhamento).
- `Hud._ready()`/`_layout()`: `_frag_counter.visible` e `_music_btn.visible` passam a
  `not show_enemy_hp`. Manter a criação e a fiação de sinais como está (só visibilidade),
  para não mexer no fluxo de exploração.

**Premium (direção de arte — flat, bordas retas, paleta fechada):**
- Faixa de header: um _scrim_ escuro sutil (gradiente/retângulo translúcido) atrás das duas
  barras dá legibilidade sobre a arena e evoca a barra preta superior dos _fighting games_,
  sem quebrar o tom (mantém a floresta hostil visível abaixo).
- Divisória central discreta (opcional): um glifo folk-horror (garra/caveira 1-px) ou apenas
  um vão — evitar "VS" literal se destoar do tom; decisão de arte na implementação.
- Cores mantidas: jogador `COLOR_BLOOD`, inimigo `COLOR_AMBER` (já em `hud.gd:37,116`).
- Boss: manter o realce de altura/largura de `is_boss`; o nome do boss pode receber
  tratamento tipográfico maior (leitura de "chefão").
- **Legibilidade sob `Atmosphere`:** cantos do topo são os mais escurecidos pela vinheta.
  Se o header ficar "lama", considerar clarear as barras via o padrão já existente de
  ganho de feedback por fase (sem clarear o fundo) — QA no export web decide.

---

## 5. Arquitetura — mudanças por arquivo

| Arquivo | Mudança |
|---|---|
| `scripts/ui/health_bar.gd` | Remover `_value_label`/`_update_value_label`; `_name_label` ocupa o header; adicionar `set_mirrored(bool)` e espelhar `_draw()`/`_relayout()` quando ligado. |
| `scripts/ui/hud.gd` | Ramificar `_layout()` por `show_enemy_hp`: **combate** → header espelhado (duas barras na fileira do topo) + ocultar Terra Rara/mudo; **exploração retrato/telefone** → `HUD_TOUCH_SCALE` no mudo e na Terra Rara. Constantes de escala no topo. |
| `scripts/ui/speaker_button.gd` | `configure_size(icon_px)` (base `SIZE=28`); `custom_minimum_size` e desenho escalam; alvo de toque cresce junto. |
| `scripts/ui/fragment_counter.gd` | Aceitar multiplicador de ícone/fonte no `configure_size` para o modo tátil; `_pop()` proporcional. |
| `scripts/ui/main_menu.gd` | URL do github → `.../caipora` (constante nomeada). |
| `tests/unit/test_health_bar.gd` | Reescrever `test_value_label_text` para afirmar ausência de número. |
| `tests/unit/test_menu_v3.gd` (se cobrir o footer/link) | Ajustar/adicionar asserção da URL do repo, se aplicável. |

Nenhuma mudança em `.tscn` de cena (evita corrupção — gotcha #7): o layout é todo por código,
e `show_enemy_hp` já está setado nas cenas. `hud.tscn` permanece intacto.

---

## 6. Responsividade e plataformas (gotcha #10)

- Tudo recomputa em `size_changed` (`hud.gd:61`, `main_menu.gd:47`). Girar o device
  (retrato↔paisagem) reflui o HUD, liga/desliga a escala 2x e mantém o header simétrico.
- **Retrato de telefone (~393 px):** foco do R3 (ícones 2x) e do header de combate compacto.
- **Paisagem de telefone:** header de combate ocupa a fileira do topo com _safe areas_
  respeitadas (o `ControlsHud` já trata `env()`); ícones de exploração **não** recebem o 2x
  (o gatilho é retrato) — manter tamanho atual ou um bump menor (decisão de arte).
- **Tablet/desktop:** header e ícones em escala base; sem 2x.
- Rodar **`/validate-platforms`** antes de commit (mudança de UI/safe-area). O combate vive
  na arena; se qualquer ajuste tocar input/timing, rodar também **`/validate-controls`**
  (não previsto aqui — é só camada visual do HUD).

---

## 7. Edge cases

- **Boss vs. barra normal do inimigo:** o header espelhado precisa acomodar o boss (mais
  largo/alto) sem colidir com a barra do jogador nem sair da tela em retrato estreito —
  clampar larguras e, se faltar espaço, reduzir simetricamente.
- **HP muito alto (jogador cresce, boss 36 HP):** ticks já se auto-omitem acima de
  `MAX_TICKS=48` (`health_bar.gd:19,211`); sem número, isso continua legível.
- **Troca de idioma em combate:** nomes das barras vêm de `Lang.t` (`hud.gd:40,117`);
  o header re-lê no `size_changed`/re-setup — garantir refresh de nome ao trocar idioma.
- **Mudo persistido:** ocultar o botão em combate **não** altera o estado de áudio; ao
  voltar à exploração o botão reaparece refletindo `AudioDirector.is_music_enabled()`.
- **Popups de ganho** (Terra Rara/erva/chama, `hud.gd:150-176`) ocorrem na exploração;
  não aparecem em combate — nenhum ajuste necessário, mas confirmar que não vazam com a
  Terra Rara oculta.

---

## 8. Plano de testes

- **Unit (GUT):**
  - `test_health_bar`: sem rótulo numérico; lógica de valor/máx/clamp intacta; `set_mirrored`
    não altera `_value`/`_max`.
  - Novo/ajuste: `HealthBar.set_mirrored(true)` mantém dimensões e apenas inverte a âncora
    (validável por estado, sem render).
  - HUD: com `show_enemy_hp=false`, `_music_btn`/`_frag_counter` visíveis; com `true`, ocultos.
    Escala tátil aplicada só em retrato+telefone+exploração.
- **Menu:** URL do github = repositório (`.../caipora`).
- **Manual / `/validate-platforms`:** retrato telefone, paisagem telefone, tablet — verificar
  2x na exploração, header espelhado no combate, contraste sob a vinheta.
- **Gate:** `make gate` (smoke + test) verde; confirmar que a contagem de testes **subiu**
  se arquivos novos entrarem (gotcha #12).

---

## 9. Critérios de aceite

1. Nenhuma das barras de HP (jogador/inimigo/boss) mostra número em nenhum modo.
2. "github" no footer abre `https://github.com/baltazarparra/caipora`.
3. Exploração em telefone retrato: ícone de mudo e ícone+contagem de Terra Rara com ≥2x do
   tamanho atual; alvo de toque do mudo ≥72 px físicos.
4. Combate (arena): sem Terra Rara e sem botão de mudo; header com os dois HPs no topo,
   jogador à esquerda e adversário à direita, fills espelhados encontrando-se no centro.
5. Tudo reflui corretamente ao girar o device; `make gate` e `/validate-platforms` passam.
6. Tom preservado: nada de suavizar o horror; acabamento flat, bordas retas, paleta fechada.

---

## 10. Fora de escopo / futuro

- Retratos/《portraits》 de personagem ao lado das barras (P1/P2) no estilo SF — bom candidato
  a uma v2 do header, mas fora deste escopo (custo de asset).
- Barra de combo/《super》 no header.
- Animação de "primeiro sangue"/"K.O." tipográfica no fim do combate.
- Reaproveitar o header espelhado no ending/boss-intro se fizer sentido narrativo.
