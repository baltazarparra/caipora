# CONCEITO — A Mula sem Cabeça (Boss da Fase 1) — v3

> **Este documento é lei visual** para o primeiro chefe do jogo. Deriva da
> protagonista (`docs/CONCEITO-protagonista.md`) e da skill de identidade visual
> (`.agents/skills/visual-identity/SKILL.md`).
>
> Gerador canônico: `scripts/tools/gen_mula.py`.  
> Prancha: `assets/sprites/mula_contact_sheet.png`.  
> Contrato validado por `tests/unit/test_mula_sprite_assets.gd` e
> `tests/unit/test_boss_scale_proportions.gd`.

---

## 1. O conceito — a leitura-espelho da Caipora

A Mula sem Cabeça é a **primeira impressão** do jogador sobre os chefes de
*caipora* — e a primeira prova de que todos vivem no mesmo universo da
protagonista. A Caipora lê como **massa laranja serrilhada + vazio preto +
olhos brancos**. A Mula é o espelho invertido:

> **um monumento preto-vazio de montaria + uma "juba" de fogo serrilhada no
> lugar da cabeça — e nenhum olho, porque não há cabeça para tê-los.**

Ela é o pesadelo da estrada de terra: uma égua negra amaldiçoada cujo pescoço
termina num toco cru de onde erupciona uma coroa de fogo. As ferraduras de
ferro reluzem a cada passada, e o arreio vermelho-sangue ainda pinga da última
cavalgada.

- **Horror físico:** carne viva no toco, sangue no arreio, breu no pelo.
- **Folclore brasileiro:** a Mula do folclore é castigo e fogo — nunca uma
  fera genérica de fantasia ocidental.
- **Hostilidade:** ela ENCARA a Caipora — o desenho aponta para a ESQUERDA,
  como todos os inimigos (lei corrigida na v3: a v2 dava as costas).

## 2. Lei de escala — a montaria sobre todos

A Caipora é uma criança da mata. A Mula é uma **montaria amaldiçoada** e deve
agigantar-se sobre todos os outros atores:

```
Saci (menino de uma perna) < Caipora ≈ Curupira (criança da mata)
< humanos adultos (Jesuíta, caçador-de-machados ≈ caçador/bruxo comuns)
< Boitatá (serpente gigante — massa horizontal enrolada)
< Mula sem Cabeça (montaria + coluna de fogo, agiganta sobre todos)
```

- Canvas: **192×192**; escala de cena **0.9** (altura visual ~166 px).
- Os pés assentam na mesma linha de chão da Caipora (`offset.y = -77`);
  a linha inferior opaca do desenho fica na banda **y ∈ [184, 191]** do canvas
  (travada por teste).
- A crista do fogo fica em y ≈ 2–8 px — imponência máxima SEM clipar o canvas.

## 3. Assinaturas visuais (leitura a 32 px)

1. **Corpo preto-vazio chapado** — a massa dominante é a família VOID (preto
   quase puro), como o corpo/chifres/cajado da Caipora. SEM modelagem interna,
   SEM marrom-lamacento, SEM músculos desenhados: a informação vive na
   silhueta. Dentes deliberados de pelo no peito (encarando a jogadora), na
   anca e na barriga — grandes, duros, desenhados um a um (nunca ruído).
2. **Coroa de fogo serrilhada = a "juba" dela** — o toco decepado erupciona
   uma coluna de fogo desenhada com a MESMA linguagem da juba da protagonista:
   dentes triangulares deliberados (1 grande + escada decrescente arrastando
   para trás), selout chapado de 4 tons e coração branco-quente junto ao toco.
   Sem cabeça; o fogo é a cabeça.
3. **Ferraduras de ferro reluzentes** — banda de ferro + flash prateado nos
   cascos próximos; o par distante fica sem brilho (profundidade chapada).
4. **Arreio amaldiçoado** — sela escura com debrum vermelho-sangue, barrigueira
   e peiteira; fivela e gota de sangue como acentos.
5. **Toco cru sangrento** — elipse de carne viva onde o fogo nasce, com um
   crescente branco-quente no contato fogo↔ferida.
6. **Pose de montaria prestes a galopar** — peso recolhido, peito aberto para
   a esquerda, patas firmes. Três brasas fixas trilham atrás da coroa
   (deliberadas, nunca spray aleatório).

## 4. Paleta fechada (selout chapado, 3–4 tons por material)

| Material | Ramp |
|----------|------|
| Corpo-vazio | `#0a0708` (oclusão/patas distantes) → `#150f10` (base) → `#261a1a` (acento de borda, chapado) |
| Casco | `#100a09` |
| Ferradura de ferro | `#7a7c8a → #bcc0ce` (flash prateado) |
| Carne do toco | `#4a0808` |
| Fogo (oclusão → coração) | `#bc2a00 → #ff6b08 → #ffa838 → #fff0c8` |
| Arreio/sela | `#28160e → #961810` (couro escuro + debrum sangue) |
| Contorno | `#1a120a` (1 px, mesmo do mundo) |

**Travas de marca (nunca quebrar):**
- Nenhum olho branco redondo (`#ffffff`) — assinatura exclusiva da Caipora.
  O branco-quente do fogo é `#fff0c8`, nunca branco puro.
- Nenhum laranja da juba (`#ff4500` / `#8b2a00`) — o fogo da Mula vive na
  rampa própria dela (`#ff6b08`), nunca na massa laranja-marca da protagonista.
- Nenhum verde `#00fa9a` — exclusivo do cristal/Fúria.
- **Sem rim light, sem gradiente, sem dither, sem brasas aleatórias** — o
  acabamento é pixel art chapada com formas deliberadas (v3 removeu o rim
  light e o spray de brasas da v2).

## 5. Poses e animações

| Animação | Descrição | Uso |
|----------|-----------|-----|
| `idle` | Monumento firme, coroa de fogo com dentes desenhados, ferraduras assentadas. | Loop da arena/exploração/HUB. |
| `windup` | Corpo AFUNDA (coil ~2.2 unidades de grid), joelhos abrem, patas traseiras se recolhem, e a coroa **erupciona** (~2× a massa de fogo: dente extra, mais largura, mais coração branco-quente). | Telegraph visual do ataque. |

O gerador expõe canais paramétricos (`coil`, `breath`, `flame`) — a vida
multi-frame (respiração, pulso do fogo, strike/hurt/death) entra por cima
destes canais nos estágios seguintes do redesign.

## 6. Pipeline técnico (premium reprodutível)

`scripts/tools/gen_mula.py`, **100% determinístico (sem RNG)**, stdlib + Pillow:

1. **Desenho vetorial supersampled 8×** (1536×1536): formas DELIBERADAS em
   grade lógica de 64 — polígonos de dentes desenhados um a um (corpo, crina,
   coroa de fogo), cápsulas de membro, elipses de acento.
2. **Downsample por área → 192×192** + threshold de alpha (sem halos).
3. **Snap de paleta fechada**: cada pixel cai na cor mais próxima da paleta da
   Mula (saída 100% dentro da paleta — verificado).
4. **Outline 1 px `#1a120a`**: todo pixel opaco que toca transparência vira
   contorno escuro contínuo.

Regras de manutenção:
- **Nunca editar `mula_*.png` à mão** — toda mudança visual passa por
  `gen_mula.py` e por este documento.
- Contrato de saída atual: 2 poses (`idle`, `windup`) em 192×192, validado
  pelos testes de assets e de escala.
- Fluxo: `python3 scripts/tools/gen_mula.py` → `make import` → `make gate`.

## 7. O que NUNCA muda / o que pode evoluir

**Imutável:** as travas de marca (§4); corpo preto-vazio chapado (a v2
marrom-lamacenta é regressão, travada por teste); toco decepado + coroa de
fogo serrilhada como assinatura; encarar a esquerda; escala de montaria maior
que todos os outros atores; ferraduras de ferro reluzentes; arreio
vermelho-sangue; acabamento flat + outline 1 px; formas deliberadas (nunca
jag-noise/spray aleatório); tom GORE/TERROR.

**Evolui livremente:** número e fase dos dentes da coroa, quantidade de sangue
no arreio, poses extras (`strike`, `recover`, `hurt`, `death`) e a vida
multi-frame via canais `coil`/`breath`/`flame` — desde que derivem das 6
assinaturas de silhueta.
