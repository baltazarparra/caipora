# CONCEITO — Terra Rara (a economia do jogo)

> Lei visual do recurso que move a economia de **caipora**. Antes chamado
> "fragmentos", agora **Terra Rara**: o minério raro e precioso que a Caipora
> arranca da mata corrompida e gasta no cachimbo (ervas/aprimoramentos).
> Mudança de **nome e arte** — a mecânica (drop na morte, recuperação no local
> da queda, custo das ervas) é a mesma.

Fonte canônica:
- Gerador: `scripts/tools/gen_terra_rara.py` (PNG stdlib puro, determinístico).
- Sprites: `assets/sprites/terra_rara_icon.png` (HUD) e
  `assets/sprites/terra_rara_node.png` (drop na exploração).
- Contrato: `tests/unit/test_terra_rara_sprite_assets.gd`.

## 1. Princípio

A Terra Rara é **minério bruto cristalino**: uma matriz de rocha escura de onde
erupcionam **facetas de cristal âmbar/laranja-quente**. Lê, mesmo a ~24px, como
"recurso raro e valioso" — não como gema lapidada de fantasia genérica, nem como
moeda limpa.

Pertence ao mesmo mundo da Caipora: paleta fechada, formas chapadas, contorno
escuro 1px, sem gradiente suave nem brilho glossy.

## 2. Travas de marca

1. **Laranja/âmbar é o brilho do cristal** (`#ff6b00` no miolo, `#ffaa46` na
   faceta clara, `#be4600` na faceta escura, ponta `#ffd696`). É o mesmo laranja
   da identidade — a Terra Rara é "da mesma família" da Caipora.
2. **A matriz é rocha escura** (browns/soot da paleta de madeira/casca). O
   cristal precisa de um leito escuro para o âmbar saltar.
3. **NUNCA verde.** O verde é reservado ao cristal/Fúria da Caipora. A economia
   não usa verde — travado em `test_terra_rara_sprite_assets.gd`.
4. **Contorno escuro 1px contínuo**, facetas com no máximo 2–3 tons, leitura por
   silhueta antes de detalhe.
5. O drop (`terra_rara_node`) é horror material: o minério jaz numa **poça de
   sangue** no tile da morte — marca o "lugar da queda" da corpse run.

## 3. Onde aparece

- **HUD** (`scripts/ui/fragment_counter.gd`): ícone + número no canto superior
  direito; pulsa ao ganhar.
- **Exploração** (`scripts/exploration/map_object.gd`, `Type.BAG`): o minério
  caído na morte, sob um brilho âmbar pulsante (`ForestLight`) que guia a volta.
- **Acampamento/loja** e **popups** de ganho: texto "Terra Rara" (i18n
  `hub.fragments`, `card.cost`, `hud.fragment.*`).

## 4. Checklist antes de entregar

- O âmbar domina o cristal e a rocha fica escura por baixo?
- Não vazou nenhum pixel verde (Fúria)?
- O contorno 1px e as facetas chapadas leem em 24–32px?
- O drop parece "perda sangrenta no chão", não um baú fofo de loot?
- Continua parecendo do mesmo mundo da Caipora (laranja/preto/branco)?

Se mexer nos sprites:
- Edite `scripts/tools/gen_terra_rara.py`, regenere os PNGs e rode
  `godot --headless --import` antes de `make gate`.
