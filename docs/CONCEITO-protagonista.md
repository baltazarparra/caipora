# CONCEITO — A Caipora, Protagonista ("A Guardia da Mata")

> **Este documento é lei visual.** Todo asset, animação, partícula, key art,
> ícone ou material promocional que envolva a protagonista deriva daqui.
> Gerador canônico: `scripts/tools/gen_caipora.py`. Fonte do conceito: prancha
> aprovada em 2026-06, **"Mata Hostil — Prancha de conceito de personagem:
> Caipora, guardia perigosa da mata"**, recorte de **silhuetas A/B/C**: massa
> laranja serrilhada, rosto/corpo/cajado pretos, dois olhos brancos, chifres
> pretos e variante CHAMA.

---

## 1. O conceito

A Caipora não tem rosto. Dentro da mancha laranja existe apenas **vazio negro e
dois olhos brancos, redondos, que brilham** — a última coisa que o caçador vê.
A juba-capa laranja vibrante envolve tudo como uma pele serrilhada, quase maior
que o corpo. Chifres pretos rompem a massa laranja. Na mão, um cajado preto com
miolo verde mínimo no cristal — o verde existe para a Fúria, mas não deve roubar
a leitura da silhueta.

**Proporção chibi (lei):** cabeça + juba ≈ 55–60% da altura do sprite. O corpo
é curto, menor que a juba-capa, com pés descalços simples. A fofura é isca: o
rosto-vazio é o horror.

Ela não é mascote. É a dona da mata, e a mata cobra em sangue. O clima sombrio
do jogo vem da atmosfera da cena (vinheta, grão, color-grade) — não de
dessaturar o sprite.

## 2. Assinaturas visuais (as 5 travas do design)

1. **Juba-capa laranja serrilhada** — massa laranja vibrante que envolve o capuz
   por cima, dos dois lados e pelas costas, quase até o chão. É A
   silhueta: a 32px, a protagonista é "a mancha laranja de olhos brancos". No
   strike estica horizontal (velocidade); no windup eriça pra cima (ameaça);
   no recover assenta.
2. **Rosto-vazio de olhos brancos** — elipse de vazio (`VOID`) emoldurada pelo
   capuz; **dois olhos circulares brancos IGUAIS, sem halo** (`EYE_WHITE`
   puro). Sem boca, sem traços: o horror é a ausência. No windup arregalam;
   no strike viram fendas.
3. **Chifres rompendo a juba** — dois chifres curvos pretos emergindo do
   cabelo em "V", assimétricos (o do lado da juba é mais longo). As pontas
   SEMPRE ultrapassam a silhueta da juba (ganham outline e leitura).
4. **Cajado preto com miolo verde mínimo** — haste reta e fina coroada por uma
   lâmina/cristal preto, como na silhueta A. O verde (`CR`) fica reduzido a
   poucos pixels no centro para ancorar `FuriaVisual`; a leitura do cajado deve
   permanecer preta.
5. **Corpo preto + pés descalços** — corpo curto em mancha preta irregular, sem
   detalhe de roupa competindo com a capa. **PÉS NORMAIS PRA FRENTE** — o
   pé-pra-trás é do Curupira (parente), não dela.

## 3. Paleta (fechada — fonte: `gen_caipora.py`, 3–4 tons por material via selout chapado)

| Material | Ramp |
|----------|------|
| Juba (base) | `#5a1a00` (oclusão) → `#8b2a00` (sombra) → `#ff4500` (base) → `#ff7a33` (realce) |
| Juba (CHAMA) | `#c24a08` (oclusão) → `#ff6808` (base) → `#ffb032` (realce) + coração `#ffefb2` |
| Corpo / chifres / cajado | `#000000` |
| Vazio do rosto | `#000000` |
| Olhos | `#ffffff` puro (sem halo) |
| Cristal | `#00fa9a` em poucos pixels, nunca dominante |
| Sangue/acento hostil | `#8b0000` |
| Contorno | `#1a120a` (1px, toda a silhueta) |

**Acabamento chapado (lei):** flat fill + contorno escuro de 1px na silhueta;
**3–4 tons por material via selout chapado** (oclusão→sombra→base→realce),
colocados como polígonos-filhos inset da forma-mãe — sem gradiente, sem dither,
sem rim light suave, sem blur, sem selout graduado. O realce **nunca** é
`#ffffff` (branco puro pertence só aos olhos). Norte de acabamento: Cult of the
Lamb (poucos tons duros, bem colocados). O clima sombrio vem da atmosfera/grading
da cena, não do sprite. O verde do cristal segue sendo o único acento frio.

## 4. Linguagem corporal por frame

| Frame | Corpo | Juba | Cajado |
|-------|-------|------|--------|
| `idle` | Peso pronto, corpo preto simples | Silhueta B frontal | Fincado vertical, quase todo preto |
| `walk_1/2` | Passada mínima | Bounce sutil da massa laranja | Fincado/carregado, quase todo preto |
| `windup` | Agachada, mola comprimida | Silhueta A: capa eriçada e serrilhada | Erguido vertical/diagonal, topo preto |
| `strike` | Afundo, lean forte | Silhueta C: capa puxada pelo golpe | Varrido à frente como forma preta |
| `recover` | Assentando o peso | Volta para B | Finca de novo |

## 5. Pipeline técnico (o "premium" reprodutível)

`gen_caipora.py`, determinístico, stdlib + Pillow:

1. **Desenho vetorial supersampled 8×** (768×768): formas chapadas de silhueta,
   capa serrilhada, corpo preto e cajado preto — **incluindo os polígonos de
   selout (oclusão + realce) inset ≥1px da borda**, desenhados na mesma ordem em
   todo frame (fill → sombra → oclusão → realce).
2. **Downsample por área → 96×96** + threshold de alpha (sem halos).
3. **Snap de paleta**: cada pixel cai na cor mais próxima (paleta fechada).
4. **Outline 1px**: todo pixel opaco que toca transparência vira `OUTLINE` —
   contorno escuro contínuo na silhueta inteira, como na referência.

Regras de manutenção:
- **Nunca editar os PNGs `player_*` à mão** — toda mudança visual da
  protagonista passa por `gen_caipora.py` e por este documento.
- **`gen_chars.py` NUNCA toca os `player_*`** — protagonista só sai do gerador
  canônico.
- Contrato de saída: 6 poses × 2 variantes, 96×96, validado por
  `tests/unit/test_caipora_sprite_assets.gd`.

## 6. O que NUNCA muda / o que pode evoluir

**Imutável:** rosto-vazio com dois olhos brancos circulares iguais; juba
laranja como silhueta dominante envolvendo o capuz e fluindo PRA TRÁS;
proporção chibi (cabeça + juba ≈ 55–60% da altura); chifres rompendo a juba;
corpo/cajado/chifres pretos; cristal verde reduzido a miolo mínimo para a
Fúria; acabamento flat + outline 1px; pés normais pra frente; postura de
predadora; tom GORE/TERROR — a mata é hostil, a Caipora é perigosa, nunca
suavizar.

**Evolui livremente:** serrilhado da capa, agressividade dos chifres, poses de
ataque, partículas e key art em resolução maior — desde que derive das 5
assinaturas de silhueta.

**Fúria (T1–T6) manifesta no cristal:** sem sprite de arma separado — o cajado
é parte do corpo. `furia_visual.gd` ancora partículas no miolo verde mínimo do
cristal: glow verde que escala com o tier + identidade de lore por tier
(fumaça, aura dourada, breu, osso, carne viva). A CHAMA soma a chama viva ao
conjunto.

**CHAMA (meta-progressão) = "juba em brasa":** a variante `player_*_chama.png`
(`caipora(..., chama=True)`) acende a juba — ramp quente (`#ff6808 → #ffb032`)
no lugar do laranja base, coração claro `F_CORE` na coroa e brasas orbitando.
Mesma geometria, outro estado: a fúria antiga da mata acordou. Selecionada em
runtime por `CaiporaSkin` (exploração, arena e TitleWalker).

> Direções anteriores ("Predadora-Rainha da Mata", "Caipora Brasa" /
> `docs/PLANO-redesign-caipora-pop-dark.md`) ficam como histórico; em qualquer
> conflito, vale este documento.
