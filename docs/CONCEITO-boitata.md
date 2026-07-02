# CONCEITO — O Boitatá (Boss da Fase 2) — v2

> **Este documento é lei visual** para o segundo chefe do jogo — a PRIMEIRA
> lei escrita dele (a v1 vivia só no docstring do gerador). Deriva da
> protagonista (`docs/CONCEITO-protagonista.md`) e da skill de identidade
> visual (`.agents/skills/visual-identity/SKILL.md`).
>
> Gerador canônico: `scripts/tools/gen_boitata.py`.  
> Prancha: `assets/sprites/boitata_contact_sheet.png`.  
> Contrato validado por `tests/unit/test_boitata_sprite_assets.gd` e
> `tests/unit/test_boss_scale_proportions.gd`.

---

## 1. O conceito — a muralha que arde

O Boitatá é a serpente de **fogo-cadáver** do folclore: nasceu do breu e vela
os campos contra quem queima a mata. Na leitura-espelho da protagonista
(Caipora = massa laranja serrilhada + vazio preto + olhos brancos), o Boitatá
é:

> **uma muralha enrolada de preto-carbonizado + uma crista de fogo serrilhada
> correndo a espinha da nuca ao rabo — e olhos em FENDA quente, nunca os
> pontos brancos dela.**

- **Horror físico:** cicatrizes de sangue na casca, placas de barriga como
  couro queimado, chifres de cinza.
- **Folclore brasileiro:** o fogo dele é o fogo-fátuo dos mortos — o coração
  espectral quase-branco (`FIRE_WHITE`) acende na boca e no dente da nuca.
- **Hostilidade:** encara a ESQUERDA (a Caipora), cabeça erguida em
  pescoço-S de vigia predadora.

## 2. Lei de escala — a serpente-muralha

```
Saci < Caipora ≈ Curupira < humanos adultos < BOITATÁ (massa horizontal)
< Mula sem Cabeça
```

- Canvas: **160×128**; escala de cena **1.2**.
- **A MASSA HORIZONTAL é assinatura** (trava exclusiva dele em
  `test_boss_scale_proportions`): largura visual > caçador × 1.2 — no canvas,
  bbox de largura ≥ 120 px (projeto: ~137).
- Altura visual > Caipora (bbox ≥ 80 px; projeto: ~90).
- Pés/base na linha de chão da Caipora (`offset.y = -38`): linha inferior
  opaca na banda **y ∈ [110, 116]** (travada por teste).

## 3. Assinaturas visuais (leitura a 48 px)

1. **Muralha enrolada preta-carbonizada chapada** — dois patamares de espiral
   em massa única (família CHAR, preto-QUENTE — distinto do void frio da
   Mula), sem modelagem interna mole; entalhes duros no dorso e no rabo.
2. **Crista de fogo serrilhada = a "juba" dele** — cumeeira contínua
   (`FIRE_DEEP`) com dentes deliberados em escada (o maior atrás da nuca,
   decrescendo rabo afora), selout chapado 4 tons
   (`FIRE_DEEP → FIRE → FIRE_HOT → FIRE_WHITE` no coração da nuca).
3. **Cabeça em cunha de víbora + olhos em FENDA** `EYE` — apontada à
   esquerda; chifres/raízes de cinza `ASH` rompendo o crânio; língua de fogo
   no idle, **boca de fogo-fátuo `FIRE_WHITE` no windup** (o mesmo
   quase-branco do telegraph overbright do especial "Cobra-de-Fogo").
4. **Placas de barriga segmentadas** `SCALE`/`SCALE_DK` — o couro queimado da
   serpente, 6 placas com vãos duros.
5. **Cicatrizes de sangue** `BLOOD` — talho no flanco, poça na base.
6. **Fogos-fátuos fixos** — 3 faíscas deliberadas orbitando + 2 línguas de
   fogo-cadáver rente ao chão flanqueando a espiral (nunca spray aleatório).

## 4. Paleta fechada (selout chapado, 3–4 tons por material)

| Material | Ramp |
|----------|------|
| Corpo carbonizado | `#0c0706` (oclusão/mandíbula) → `#180c09` (base) → `#2e1610` (acento de borda) |
| Placas de barriga | `#48160d → #842613` (couro queimado) |
| Crista/fogo | `#a82c0a → #e25718 → #ffb248 → #ffe8ae` (oclusão → coração espectral) |
| Chifres/cinza | `#7e7762` |
| Olhos (fenda) | `#facb53` |
| Sangue | `#8b0000` |
| Contorno | `#1a120a` (1 px, mesmo do mundo — padronizado na v2; a v1 usava `#110806`) |

**Travas de marca (nunca quebrar):**
- Nenhum olho branco redondo (`#ffffff`) — o quase-branco dele é `#ffe8ae`.
- Nenhum laranja da juba (`#ff4500` / `#8b2a00`).
- Nenhum verde `#00fa9a` — exclusivo do cristal/Fúria.
- Rampa de fogo PRÓPRIA — nunca os valores exatos da Mula
  (`#bc2a00/#ff6b08/#ffa838/#fff0c8`).
- **Sem gradiente, sem dither, sem elipses moles, sem spray aleatório** —
  formas deliberadas, 100% determinístico (sem RNG).

## 5. Poses e animações

| Animação | Descrição | Uso |
|----------|-----------|-----|
| `idle` | Vigia enrolada: crista acesa, fendas dos olhos, língua de fogo provando o ar. | Loop da arena/exploração/HUB. |
| `windup` | Canal `rise`: cabeça/pescoço ERGUEM, espirais apertam, crista incha (~2× a massa de fogo) e a boca acende `FIRE_WHITE`. | Telegraph do ataque. |

O gerador expõe canais paramétricos (`rise`, `breath`, `flame`) — a vida
multi-frame (respiração, pulso da crista, strike/hurt/death) entra por cima
destes canais nos estágios seguintes, no molde do CONCEITO-mula §5.

## 6. Pipeline técnico (premium reprodutível)

`scripts/tools/gen_boitata.py`, **100% determinístico**, stdlib + Pillow:

1. **Desenho vetorial supersampled 8×** (1280×1024): formas DELIBERADAS em
   coordenadas de canvas — polígonos de patamar, dentes de crista um a um
   (`_flame_tooth`, com clamp de ponta que nunca clipa o topo), cunha da
   cabeça, placas segmentadas.
2. **Downsample por área → 160×128** + threshold de alpha (sem halos).
3. **Snap de paleta fechada** (saída 100% dentro da paleta — verificado).
4. **Outline 1 px `#1a120a`** contínuo.

Regras de manutenção:
- **Nunca editar `boitata_*.png` à mão** — toda mudança passa por
  `gen_boitata.py` e por este documento.
- Fluxo: `python3 scripts/tools/gen_boitata.py` → `make import` → `make gate`.

## 7. O que NUNCA muda / o que pode evoluir

**Imutável:** as travas de marca (§4); corpo preto-carbonizado chapado
(elipses moles da v1 = regressão, travada por teste); crista de fogo
serrilhada contínua como assinatura; massa HORIZONTAL dominante; encarar a
esquerda; olhos em fenda; boca de fogo-fátuo no windup; acabamento flat +
outline 1 px; formas deliberadas sem RNG; tom GORE/TERROR.

**Evolui livremente:** número/fase dos dentes da crista, quantidade de sangue,
poses extras (`strike`, `recover`, `hurt`, `death`) e a vida multi-frame via
canais `rise`/`breath`/`flame` — desde que derivem das 6 assinaturas.
