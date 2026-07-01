---
name: visual-identity
description: Mantem a identidade visual de caipora baseada na protagonista aprovada: silhueta laranja serrilhada, vazio preto, olhos brancos, horror folclorico brasileiro e pixel art chapada.
disable-model-invocation: true
---

# Visual Identity — caipora

Use esta skill sempre que mexer em arte, sprites, VFX, UI visual, key art,
paleta, inimigos, cenarios, thumbnails, marketing, docs de arte ou qualquer
coisa que possa enfraquecer a marca visual do jogo.

Fonte canonica:
- `docs/CONCEITO-protagonista.md`
- `assets/sprites/caipora_pop_dark_contact_sheet.png`
- `scripts/tools/gen_caipora.py`
- `tests/unit/test_caipora_sprite_assets.gd`

Inimigos comuns (cacador & bruxo) derivam desta identidade:
- `docs/CONCEITO-inimigos.md` (lei visual dos invasores)
- `assets/sprites/inimigos_contact_sheet.png`
- `scripts/tools/gen_inimigos.py`
- `tests/unit/test_inimigos_sprite_assets.gd`

Bosses derivam desta identidade (um por sessao de redesign):
- `docs/CONCEITO-mula.md` (primeiro boss — Mula sem Cabeça)
- `assets/sprites/mula_contact_sheet.png`
- `scripts/tools/gen_mula.py`
- `tests/unit/test_mula_sprite_assets.gd`

Curupira (boss P3, o parente mais antigo) deriva desta identidade:
- `docs/CONCEITO-curupira.md` (lei visual do chefe)
- `assets/sprites/curupira_contact_sheet.png`
- `scripts/tools/gen_bosses.py`
- `tests/unit/test_curupira_sprite_assets.gd`

Jesuita (boss final P5, o padre-guerreiro) deriva desta identidade:
- `docs/CONCEITO-jesuita.md` (lei visual do chefe final; design autoral —
  nunca trade dress de personagem alheio)
- `assets/sprites/jesuita_contact_sheet.png`
- `scripts/tools/gen_bosses.py`
- `tests/unit/test_jesuita_sprite_assets.gd`

Terra Rara (a economia do jogo, antes "fragmentos") deriva desta identidade:
- `docs/CONCEITO-terra-rara.md` (lei visual do minério bruto cristalino)
- `assets/sprites/terra_rara_icon.png` / `assets/sprites/terra_rara_node.png`
- `scripts/tools/gen_terra_rara.py`
- `tests/unit/test_terra_rara_sprite_assets.gd`

## 1. Principio-marca

A Caipora aprovada define a marca do jogo. Ela deve ser reconhecivel como:

> uma massa laranja serrilhada, predatoria, com corpo/rosto/chifres/cajado
> pretos, dois olhos brancos puros, e um minimo verde ritual no cristal.

Tudo no jogo deve parecer que pertence ao mesmo mundo: floresta hostil,
folclore brasileiro, sangue real, entidade antiga, formas chapadas, leitura
forte em baixa resolucao.

## 2. Travas da protagonista

Nunca quebrar estas regras:

1. A juba-capa laranja e a silhueta dominante.
2. Rosto, corpo, chifres e cajado leem como preto.
3. O rosto nao tem boca, nariz, sobrancelha, sorriso ou expressao humana.
4. Os olhos sao dois pontos/circulos brancos, simples e assustadores.
5. O verde do cristal e minimo, so para ancorar `FuriaVisual`.
6. A proporcao e chibi, mas a leitura e perigosa, nao mascote.
7. Poses devem sugerir predadora: pronta, eriçada, em bote, ou assentando peso.
8. O acabamento e pixel art chapada: paleta fechada, 1px outline, sem gradiente
   suave, sem blur, sem dither decorativo.

## 3. Tecnica de estilo

Use formas grandes primeiro. Se uma ideia nao funciona em silhueta, ela ainda
nao esta pronta.

Pipeline recomendado:

1. Validar a silhueta em preto/laranja antes de detalhes.
2. Reduzir o sprite para leitura em 32px mentalmente ou por preview.
3. Usar 3-4 tons chapados por material (selout: oclusao/sombra/base/realce), sem
   gradiente/dither/blur - padrao da PROTAGONISTA; inimigos/chefes seguem seu
   proprio CONCEITO/gerador. O realce nunca e branco puro (branco e so dos olhos).
4. Preservar outline escuro continuo em sprites pequenos.
5. Fazer o clima sombrio na cena, luz, vinheta, sangue, particulas e contraste,
   nao dessaturando a Caipora.
6. Usar acentos frios com muita parcimonia. Verde pertence ao cristal/Furia.

Paleta-guia da protagonista:

| Papel | Cores |
|-------|-------|
| Juba/capa | `#5a1a00`, `#8b2a00`, `#ff4500`, `#ff7a33` |
| CHAMA | `#c24a08`, `#ff6808`, `#ffb032`, `#ffefb2` |
| Corpo/rosto/chifres/cajado | `#000000` |
| Olhos | `#ffffff` |
| Cristal/Furia | `#00fa9a`, poucos pixels |
| Sangue/acento hostil | `#8b0000` |

## 4. Aplicando a outros assets

Personagens e inimigos:
- Devem ter uma silhueta clara e agressiva antes de detalhe interno.
- Podem contrastar com a Caipora, mas nao podem parecer de outro jogo.
- Evite excesso de roupa, acessorios ou render brilhante.
- Prefira olhos, dentes, chifres, ossos, manchas, fogo, lama e sangue como
  sinais graficos fortes.
- Travas de marca (assert no GUT): nenhum inimigo usa olhos brancos redondos,
  o laranja da juba (`#ff4500`/`#8b2a00`) ou o verde do cristal. Cacador e
  bruxo saem SOMENTE de `gen_inimigos.py` (ver `docs/CONCEITO-inimigos.md`).

Cenarios:
- A floresta e personagem hostil. Use dentes de folha, troncos como garras,
  cipó como armadilha, sombras que apertam o caminho.
- O ambiente pode ser escuro, mas a jogabilidade precisa continuar legivel.
- O horror deve ser material: sangue, fuligem, carne, osso, lama, vela, breu,
  marca ritual, madeira podre.

UI e feedback:
- A UI deve respeitar a leitura de jogo: funcional, brutal, sem enfeite fofo.
- Use a laranja/preto/branco da Caipora como identidade, e verde so quando o
  sistema realmente se conecta a Furia/cristal.
- Critico, esquiva perfeita e golpes devem ter impacto visceral: hit-stop,
  shake, sangue e contraste alto.

Marketing/key art:
- A Caipora deve aparecer como sinal de primeira leitura: mancha laranja,
  vazio preto, olhos brancos.
- Nao transformar em menina fofa, mascote, heroina limpa ou fantasia generica.
- Se a imagem for detalhada, ainda deve ser possivel reconhecer a silhueta
  principal em miniatura.

## 5. Checklist antes de entregar

- A Caipora continua sendo a marca mais memoravel da tela?
- A silhueta le em 32px?
- O laranja domina a protagonista e o verde ficou minimo?
- O rosto ficou vazio, sem expressao humana?
- O asset parece de horror folclorico brasileiro, nao fantasia generica?
- O acabamento segue pixel art chapada com paleta controlada?
- O sangue, a mata e a entidade continuam perigosos?

Se mexer nos sprites da protagonista:
- Nunca edite PNG `player_*` manualmente.
- Edite `scripts/tools/gen_caipora.py`.
- Regenere os PNGs.
- Rode `make gate` antes de commit.

Se mexer so em docs desta identidade:
- Rode pelo menos `make smoke`.
