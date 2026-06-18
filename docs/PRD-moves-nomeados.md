# PRD — "Cada Golpe Tem Nome" (moves nomeados, modelo Pokémon)

> Fase 0 do roadmap em `.claude/plans/vamos-planejar-um-novo-noble-haven.md`.
> Este documento é a **fonte única** de nomes, som e visual de cada golpe. As Fases
> 1 (dado), 3 (som) e 4 (sprite/VFX) leem desta tabela.

## Objetivo

Hoje o combate é genérico no áudio e no visual: todo ataque toca o mesmo
`timing_alert` e mostra a mesma pose. A referência é **Pokémon** — cada golpe tem
**nome próprio**, **som próprio** e **animação própria**, e o jogador aprende a *ler* o
golpe antes do impacto. Damos a cada uma das 24 sequências inimigas + aos golpes da
Caipora uma **identidade própria**: nome, som, sprite/VFX.

## Tom (não suavizar)

GORE / TERROR / SANGRENTO. Os nomes são folclóricos e **ameaçadores**, não fofos. A
mata é hostil; o golpe deve soar como ameaça. Sem mascote, sem piada limpa.

## Convenções (consumidas pelas Fases 1/3/4)

- **`display_name`** — nome exibido no banner de combate (Fase 2). Literal pt-BR
  (folclore). en-US cai no mesmo literal por ora (nomes são quase nomes próprios).
- **`audio_event`** — stem do WAV em `assets/audio/sfx/`, prefixo `mv_`. Tocado por
  `SfxSystem.play_named(audio_event)`. 1 variante por golpe (budget).
- **`vfx_id`** — id da folha/efeito de VFX (Fase 4), mesmo sufixo do `audio_event`
  sem o `mv_`. Baked (não entra no override remoto).
- **Paleta fechada** (constants.gd): laranja (juba/fogo) `#8b2a00→#ff4500`, fogo
  `#ff6808→#ffb032→#ffefb2`, preto `#000000`, branco `#ffffff`, verde-cristal
  `#00fa9a` (acento), sangue `#8b0000`, outline `#1a120a`. VFX novo respeita isto e o
  checklist de `.agents/skills/visual-identity/SKILL.md`.

A coluna **fase** indica onde o padrão aparece (compartilhados recorrem; bosses são
exclusivos). A fase muda só timing (já existente), não gera asset novo.

---

## Inimigos — 24 sequências

### Assombração (almas penadas) — fases 2–5
| pattern (.tres) | display_name | audio_event | vfx_id | som (caráter) | visual (caráter) |
|---|---|---|---|---|---|
| `assobio_pattern` (1 hit, 3.0×, janela assassina) | **Assovio da Cova** | `mv_assovio_cova` | `assovio_cova` | assobio descendente e respirado que termina em estalo úmido | corte frio único, branco-azulado, fino |
| `assombracao_pattern` (duplo) | **Mãos do Além** | `mv_maos_alem` | `maos_alem` | duas batidas abafadas de cova | duas garras espectrais cinzas |
| `rastro_pattern` (4 hits, →←→←) | **Procissão das Almas** | `mv_procissao_almas` | `procissao_almas` | corrente de gemidos frios alternando L/R | trilha de fachos azuis em ziguezague |

### Criatura / Boss-criatura (besta corrompida) — fases 1–5
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `criatura_pattern` (base, 1 hit) | **Dilacerar** | `mv_dilacerar` | `dilacerar` | rasgo seco de carne, baque único | talho vermelho de garra |
| `criatura_double_block_pattern` (duplo) | **Mordida Dobrada** | `mv_mordida_dobrada` | `mordida_dobrada` | duas mordidas que estalam | dois arcos de presas |
| `boss_pattern` (triplo) | **Fúria da Carniça** | `mv_furia_carnica` | `furia_carnica` | três golpes de rosnado em escalada | três arcos vermelhos de garra |
| `boss_double_pattern` (duplo, lunge) | **Investida** | `mv_investida` | `investida` | pisada + dupla chifrada | poeira + duas chifradas |
| `boss_double_block_pattern` (duplo pesado) | **Esmaga-Ossos** | `mv_esmaga_ossos` | `esmaga_ossos` | dois impactos com estalo de osso | impacto branco-osso |
| `boss_special_pattern` (4 hits, especial) | **Frenesi** | `mv_frenesi` | `frenesi` | combo raivoso de quatro tempos | redemoinho vermelho de garras |

### Mula sem Cabeça — fase 1 (boss)
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `mula_galope_pattern` (duplo) | **Galope sem Cabeça** | `mv_galope_sem_cabeca` | `galope_sem_cabeca` | cascos martelando que crescem até o baque | trilha de poeira laranja + duplo atropelo |
| `mula_cabecada_pattern` (↓↑, especial) | **Coice em Brasa** | `mv_coice_brasa` | `coice_brasa` | coice de casco com chiado de fogo | brasa explodindo do coto/cascos |

### Boitatá (serpente de fogo) — fase 2 (boss)
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `boitata_chama_pattern` (1 hit) | **Brasa Rasteira** | `mv_brasa_rasteira` | `brasa_rasteira` | crepitar grave com sopro | linha de brasa rente ao chão |
| `boitata_labareda_pattern` (↓↑, especial) | **Labareda Viva** | `mv_labareda_viva` | `labareda_viva` | rugido de chama em ascensão | coluna vertical de fogo |
| `boitata_chama_falsa_pattern` (↑↑↓, especial) | **Fogo-Fátuo** | `mv_fogo_fatuo` | `fogo_fatuo` | bruxuleio enganoso que estala de repente | chama-fantasma pálida (finta) e flash real |
| `boitata_white_special_pattern` (↑↑↓↓, 3.0×) | **Cobra-de-Fogo** | `mv_cobra_fogo` | `cobra_fogo` | sear branco-incandescente sustentado | espiral serpentina de fogo branco |

### Curupira (guardião de pés virados) — fase 3 (boss)
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `curupira_mata_pattern` (↑→, especial) | **Pé-Virado** | `mv_pe_virado` | `pe_virado` | correria de folhas + chicote na direção errada | rastro verde de desorientação |
| `curupira_trilha_pattern` (←↑→, especial) | **Trilha Falsa** | `mv_trilha_falsa` | `trilha_falsa` | passos que enganam e então golpeiam | pegadas verdes em zigue, depois garra |

### Saci (redemoinho de uma perna) — fase 4 (boss)
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `saci_assovio_pattern` (1 hit) | **Assovio do Mato** | `mv_assovio_mato` | `assovio_mato` | assobio curto e cortante | pequeno corte de vento |
| `saci_pula_pattern` (↑↓↑, especial) | **Redemoinho** | `mv_redemoinho` | `redemoinho` | rajadas giratórias ×3 | ciclone de poeira aos saltos |
| `saci_pirulito_pattern` (↑→↓←, 3.0×) | **Travessura** | `mv_travessura` | `travessura` | quatro batidas, brincalhão virando cruel | gorro vermelho girando em círculo completo |
| `saci_rastro_pattern` (→←→←, especial) | **Ventania** | `mv_ventania` | `ventania` | quatro chicotadas de vento | estrias horizontais de vento (ping-pong) |

### Jesuíta (catequese sangrenta) — fase 5 (boss final)
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `jesuita_cruz_pattern` (↑↓→, especial) | **Catequese** | `mv_catequese` | `catequese` | três badaladas de sino que dobram | talhos brancos em cruz (queimadura) |
| `jesuita_espada_pattern` (↑→↓→, 3.5×) | **Espada da Fé** | `mv_espada_fe` | `espada_fe` | quatro toques de aço em osso | arcos brancos de lâmina em cruz |

### Caçador (emboscada humana) — fases 1/2/4
| pattern (.tres) | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| `cacador_special_pattern` (↓↑, especial) | **Emboscada** | `mv_emboscada` | `emboscada` | engatilhar e disparo, estalo duplo | clarão de cano + talho |

---

## Caipora — golpes do herói (Fase 5)

Hoje sem catálogo (ver `arena_manager._start_caipora_turn` / `_start_cortejo_turn`).
A Caipora é predadora: o golpe é laranja e brutal; o Cortejo é ritual e sonoro.

| golpe | display_name | audio_event | vfx_id | som | visual |
|---|---|---|---|---|---|
| normal (1 hit) | **Garra Rubra** | `mv_garra_rubra` | `garra_rubra` | sibilo rápido de garra + impacto | arco de garra laranja |
| duplo | **Açoite do Cipó** | `mv_acoite_cipo` | `acoite_cipo` | dois açoites de cipó que cortam o ar | dois chicotes de cipó (verde-escuro) |
| Cortejo / Batuque | **Batuque do Cortejo** | (reusa `play_cortejo_beat` + `cortejo_full`) | `batuque_cortejo` | cadência de tambor (já existe) culminando em acento | luzes de espírito subindo |

### Invocações de espírito (Cortejo, por chefe libertado)
Já tocam `cortejo_<boss>.wav` via `AudioDirector.play_cortejo_link`. Alinhar nomes:

| direção | chefe | display_name | audio_event (existente) |
|---|---|---|---|
| ↑ | Mula | **Chamado da Mula** | `cortejo_mula` |
| → | Boitatá | **Chamado do Boitatá** | `cortejo_boitata` |
| ↓ | Curupira | **Chamado do Curupira** | `cortejo_curupira` |
| ← | Saci | **Chamado do Saci** | `cortejo_saci` |

---

## Resumo de contagem (budget)

- **24** sons de inimigo (`mv_*`) + **2** sons novos de Caipora (`mv_garra_rubra`,
  `mv_acoite_cipo`) = **26 WAVs novos**, 1 variante cada, curtos/mono. As invocações de
  Cortejo e o Batuque reusam áudio existente.
- **24 + 3** ids de VFX (`vfx_id`), gerados procedural em `gen_feedback_sprites.py`.
- Medir peso com `make export` nas Fases 3 e 4 (teto de áudio ~9MB).

## Pendências de design para fechar nas próximas fases
- Confirmar duração-alvo dos WAVs (sugestão: 0.18–0.45s) ao escrever os geradores.
- Decidir se o banner de nome (Fase 2) aparece também nos golpes da Caipora ou só nos
  inimigos (recomendado: ambos, mas inimigos primeiro).
- en-US: manter literal pt-BR ou criar gloss em `Lang` (decidir na Fase 2).
