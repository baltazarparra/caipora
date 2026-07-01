# PLANO — A Caipora Viva: Animação, Juice, VFX e Atmosfera (norte Hollow Knight × Cult of the Lamb)

> Plano final derivado do dossiê de referências de 2026-06-30 (HK, CotL, Vlambeer)
> e de uma auditoria linha a linha do código-âncora, incorporando as 3 críticas
> (marca, técnica, craft). **Meta:** tirar a Caipora de "1 desenho por pose"
> (morta na exploração, rígida na arena) e entregar uma criatura que **respira,
> apaga os olhos no breu, chicoteia a juba, antecipa, estampa o golpe e faz o
> inimigo recuar** — sem tocar na marca, sem dessaturar o sprite, sustentando
> 60fps no piso (Android de entrada + iPhone Safari).
>
> **Divisão canônica (leia antes de tudo).** Todo trabalho vive em **DUAS
> camadas que nunca se misturam.** (1) **BAKED** — determinística, testada, em
> `scripts/tools/gen_caipora.py`: só a *pose-silhueta* (keyframes, selout, smear,
> forma da capa, olhos-que-apagam). Zero RNG. (2) **RUNTIME** — viva, em
> `ActorAnimator`/`FeedbackSystem`/cena: respiração (transform), hit-stop, shake,
> recoil, partículas, glow, parallax, névoa. Confundir as duas = tween brigando
> por `scale` + shimmer.
>
> **Regra de ouro (HK).** O sprite é chapado e **não dessatura**; a vida vem de
> cima dele (movimento + luz + efeito). **Corolário de craft (CotL):** juice não
> é lista de efeitos soltos — é **um pico sincronizado** governado por um
> **CONDUTOR de impacto** (§F3.1). **Corolário de marca:** o juice do CotL é um
> motor de fofura; aqui ele serve à **predadora**, não ao mascote — respiração
> pesada, squash reservado à agressão, olhos que **apagam** (nunca piscam com
> pálpebra).

---

## A. Resumo / Visão

O Cavaleiro de Hollow Knight é um primo folclórico da Caipora: void preto, dois
olhos claros sem feições, capa arredondada como silhueta dominante, chifres. O
que faz o HK parecer AAA **não** é fidelidade de render — é **hierarquia de
leitura + animação por princípios clássicos + efeitos/atmosfera separados do
sprite**. Cult of the Lamb ensina o resto: **outline confiante + cel-shading de
poucos tons bem colocados + squash/stretch + wobble + juice em camadas**.

O motor de juice já é forte (`FeedbackSystem` + `ActorAnimator` têm hit-stop via
`speed_scale`, shake, squash de dano, afterimage, flash de dano automático), mas
hoje: o **sprite não estica, não apaga os olhos, não antecipa**; o **inimigo não
recua ao apanhar**; a respiração é um **bob simétrico** (lê fofo); e — pior —
cada handler de combate lista shake/partícula/hit-stop/strike **na mão, com
valores divergentes** (crít 26/6, duplo 22/4, esquiva 22/5, normal 13/3, GOOD
10/2, dano 14/2, whiff 6/0). Sem um maestro, juice vira ruído.

Este plano fecha os gaps em 6 fases faseadas (18 sessões, 1 commit cada), com um
**condutor de impacto** como espinha do combate.

**Norte por prioridade do diretor:**
- **(a) Animação** → HK: respiração **pesada/predadora** (transform), olhos que
  **apagam** raramente, secondary motion da capa por defasagem de keyframe.
- **(b) Juice** → CotL/Vlambeer: anticipation → **contato congelado** (freeze
  generoso, até ~200ms — input nunca congela) → follow-through com overshoot;
  **recoil do alvo + lunge de convergência**; tudo **no mesmo pico**.
- **(c) VFX** → HK: o efeito carrega o alcance (arco de garra), **anel de choque**
  vende peso, glow dos olhos = estado, brasa = identidade.
- **(d) Cena/atmosfera** → HK: 3 camadas + névoa + a Caipora **É** a luz que guia
  — **sempre na CENA, nunca no sprite** (a esquiva NÃO a dessatura).

---

## B. Princípios & Decisões travadas

### B.1 As 3 decisões do diretor (não-negociáveis)

1. **ESCOPO = refinar a silhueta DENTRO da marca.** Preservar a LEITURA e as **5
   assinaturas** (juba laranja serrilhada dominante; corpo/rosto/chifres/cajado
   pretos; 2 olhos brancos IGUAIS; cristal verde mínimo; postura predadora
   chibi). **PODE** reesculpir serrilhado, proporção e poses. **JAMAIS** virar
   mascote/fantasia genérica. (Já sancionado por `CONCEITO §6`.)
2. **ACABAMENTO = 3–4 tons/material + selout mais rico.** Relaxar a lei de
   `≤2 tons/material` para **3–4 tons/material via selout chapado
   (oclusão→sombra→base→realce)**, mantendo **pixel-art com outline 1px e paleta
   fechada**. Norte: **Cult of the Lamb**. Exige atualizar a lei (CONCEITO,
   `assets/AGENTS.md` 2c, SKILL) e as travas de teste — sem afrouxar a MARCA (§D).
3. **PRIORIDADES = todas as quatro:** (a) animação; (b) juice; (c) VFX; (d) cena.
   Referências-norte: **Hollow Knight** e **Cult of the Lamb**.

### B.2 Princípios de engenharia e de craft (travados)

- **BAKED × RUNTIME nunca se misturam.** Um dono por efeito.
- **Determinismo absoluto no gerador.** Tudo derivado de `t` (fase normalizada)
  ou `random.Random(seed_fixa)`. Regeneração byte-idêntica.
- **Um condutor de impacto** (`FeedbackSystem.impact`) é a **única fonte de
  verdade por tier** de combate — dispara todas as camadas no mesmo frame,
  ancoradas ao pico do freeze, e é dono do release do flash-hold. (C3-conductor)
- **60fps é orçamento, não aspiração.** A escada escala **só** o barato (tween,
  frames de hit-stop, pitch, zoom) — **nunca** contagem de partículas.
  `particle_amount_scale` corta em aparelho fraco; `ADDITIVE_MATERIAL` compartilhado
  preserva batching.
- **Input NUNCA congela.** Hit-stop via `speed_scale` (sprites+bolhas), **nunca**
  `Engine.time_scale` (só no finisher/Cortejo). Como o input não congela e o jogo
  é por-turno, **freezes generosos (money crit ~166–200ms) são seguros** — o teto
  de 133ms do HK é restrição de platformer, não deste jogo. (C3-hitstop)
- **O sprite chapado não dessatura.** Atmosfera na CENA. Feedbacks sob fases
  escuras usam `feedback_gain_for_phase`. **Nenhuma cue de combate desatura a
  Caipora** (nem a esquiva). (C1.4)
- **Juice serve à predadora, não ao mascote.** Respiração **pesada/assimétrica**
  (fole coiled, nunca bob flutuante simétrico); **squash reservado à agressão**
  (windup/strike/impacto), nunca no idle; glow dos olhos **baixa energia, brilha
  na agressão e APAGA no dano** — nunca floresce em "olhinho fofo". (C1.3)
- **Horror é marca.** Olhos que apagam no breu e na morte, sangue no chão, capa
  que chicoteia, pose de dano (guardiã sangrando), luz-isca laranja no escuro —
  é **mais** HK-hostil, não menos.

### B.3 Ledger de sessões (cada linha = 1 commit)

| Fase | Sessão | Entrega | Gate |
|---|---|---|---|
| **F0** | S0.1 | Lei atualizada (CONCEITO §2.2/§3/§5/§6, AGENTS 2c, SKILL) + testes pré-relaxados (família **laranja E preta**) + sanção de "olhos que apagam" | `make gate` |
| **F1** | S1.1 | Refactor `Pose`/`sample()`/`bake()` + set de easing ampliado; reproduz poses atuais (n=1, byte-idêntico) | gen → `make import` → `make gate` |
| | S1.2 | Paleta 3–4 tons + selout chapado (oclusão/realce), inset | gen → `make import` → `make gate` |
| | S1.3 | Reescultura serrilhado + proporção + poses + `ry` de olho por pose + **restaurar olhos IGUAIS** | gen → `make import` → `make gate` |
| | S1.4 | Idle 5f (só forma de capa) + `idle_dim` 2f (olhos apagam) + walk 6f + secondary motion baked por-contexto + `_write_sprite_frames()` | gen → `make import` → `make gate` |
| | S1.5 | Windup/strike/recover multi-frame com **durações por-frame** (smear ≤0.03s de corpo inteiro, overshoot) + **pose de HURT** 2f | gen → `make import` → `make gate` |
| **F2** | S2.1 | Breath **split-responsibility** (mantém engine, torna predatória; capa baked compõe) + wire das novas anims | `/validate-controls` + `make gate` |
| | S2.2 | Olhos-que-apagam por timer raro (arena + exploração; ausente no combate) | `/validate-controls` + `make gate` |
| **F3** | S3.1 | **CONDUTOR de impacto** + trauma-model de shake (base) + consolidação dos valores dispersos; dono do flash-release | `/validate-controls` + `make gate` |
| | S3.2 | flash-hold + release rápido + escada de hit-stop re-espaçada (+fratura de outline opcional) | `/validate-controls` + `make gate` |
| | S3.3 | Recoil do inimigo + recoil/HURT da Caipora + lunge de convergência no crít simples + `anticipation_squash` (2 atores, pause de breath) + settle elástico runtime | `/validate-controls` + `make gate` |
| | S3.4 | Zoom-punch tierizado com **HOLD no pico sincronizado ao freeze** (fit-relative, guard de reentrância) + kick direcional + rotação 0.5–1° | `/validate-controls` + `/validate-platforms` + `make gate` |
| | S3.5 | Reduce-motion (cap de shake no OptionsPanel) | `/validate-controls` + `/validate-platforms` + `make gate` |
| **F4** | S4.1 | Trilha da juba (afterimage) + arco de garra + **anel de choque radial** | `/validate-controls` + `make gate` |
| | S4.2 | Glow dos olhos (aditivo, baixa energia, apaga por HP) | `make import` + `/validate-controls` + `make gate` |
| | S4.3 | Poeira nos pés + sangue direcional + brasas CHAMA | `/validate-controls` + `make gate` |
| **F5** | S5.1 | Rim/back light que **substitui** a front light (ou sprite aditivo), gated, persiste no combate | `/validate-platforms` + `make gate` |
| | S5.2 | Parallax 3 camadas (exploração) + névoa entre camadas | `/validate-platforms` + `make gate` |
| | S5.3 | `Atmosphere.pulse` (vinheta+ crít; vinheta de **sangue** no dano; vinheta **fria SEM dessaturar** na esquiva) — **sem aberração** | `/validate-controls` + `/validate-platforms` + `make gate` |

### B.4 Ledger de resolução das críticas

> Legenda: **A** = aceito · **R** = rejeitado (com motivo) · **S** = superado por
> outra crítica. Ref. = onde no plano.

**Crítica 1 (marca).**
| # | Ponto | Dec. | Resolução / Ref. |
|---|---|---|---|
| 1 | Blink = pálpebra amolece o rosto-vazio | **A** | "Blink" vira **olhos que se apagam no vazio** (truque Hollow), nunca pálpebra; sancionado em CONCEITO §2.2/§6. F0/§D.2b, S1.4, S2.2 |
| 2 | `orange>black` fica cego com `VOID_COOL` | **A** | Preto também vira **família** (`#000000 + #140f14`) no mesmo helper F0. §D.5 |
| 3 | Juice do CotL é motor de fofura | **A** | Teto na lei: respiração pesada/predadora, squash só na agressão, glow baixo/apaga. B.2, §E, S2.1, S4.2 |
| 4 | Esquiva dessatura a Caipora | **A** | Sem dessaturação global; vinheta fria + speed-lines na cena/inimigo, protege o laranja. S5.3 |
| 5 | CONCEITO §3 **título** (linha 52) também diz "2 tons" | **A** | De/Para nomeia **linha 52 E linha 66**. §D.1 |
| 6 | SKILL item 3 é técnica GERAL | **A** | Escopar "3–4 tons" **à protagonista** (inimigos/chefes seguem seu CONCEITO). §D.4 |
| 7 | Olhos já desiguais no gerador (269–270) | **A** | Restaurar igualdade real (mesmo rx/ry/y; fator por-pose igual aos dois). S1.3 |

**Crítica 2 (técnica).**
| # | Ponto | Dec. | Resolução / Ref. |
|---|---|---|---|
| 1 | Aberração viola o no-SCREEN_TEXTURE do `atmosphere.gdshader` | **A** | **Remover a aberração**; `pulse()` só overlay (vinheta). Opção `gradient_map` rejeitada (desaturaria a Caipora + custo web). S5.3 |
| 2 | Testes `test_actor_animator/feedback_system/atmosphere` **não existem** | **A** | Marcados como **arquivos NOVOS** → gotcha #12 (rodar `make import`, confirmar total do GUT subiu). F2/F3/F5 |
| 3 | Rim light é a **3ª/4ª** PointLight2D (estoura o teto 2) | **A** | Rim **substitui** a front light (reposicionada atrás) ou usa **sprite aditivo**, gated por device. S5.1 |
| 4 | Guard de breath precisa `has_animation` | **S** | Superado por C3-a: **mantemos engine breath universal** (sem guard) → o crash nunca ocorre. S2.1 |
| 5 | `flash_hold` sobrescrito pelo flash de dano | **A** | Condutor é dono do hold; `_on_health_changed` respeita hold ativo; `flash_hold` após `take_damage`. S3.1/S3.2 |
| 6 | `anticipation_squash` disputa `scale` com o breath do inimigo | **A** | Replicar o pause de `_breath_tweens` do `impact_squash`. S3.3 |
| 7 | `zoom_punch` deriva sob sobreposição | **A** | Snapshot do **zoom de fit** (reusa `_update_camera_fit`) + guard de reentrância. S3.4 |
| 8 | Imprecisões factuais | **A** | (a) Removida a nota "mantém uid://" (não há uid; `CaiporaSkin` carrega por path). (b) Idle-morto é curado por **F1.4** (loop 6f), não pelo guard F2.1. F1/F2 |

**Crítica 3 (craft).**
| # | Ponto | Dec. | Resolução / Ref. |
|---|---|---|---|
| a | Condutor de impacto ausente | **A** | `FeedbackSystem.impact(tier,pos,dir,step)` como espinha. S3.1 |
| b | Hit-stop achatado; money pode ir a ~200ms | **A** | Escada re-espaçada por tier; money 9→12 frames. S3.2 |
| c | Breath vai PIORAR (bob ±0.5px colapsa) | **A** | **Split-responsibility**: engine mantém breath (transform); baked = só forma da capa (corpo/olhos travados). Reverte draft F2.1. S2.1 |
| d | Mola de capa única; falta lag(strike)/lead(recover) | **A** | `k`/`damp` por contexto; capa **arrasta** no strike, **chicoteia** no recover. S1.4/S1.5 |
| e | Strike a `speed` uniforme; smear lê como pose | **A** | **Durações por-frame** (smear ≤0.03s), smear estica o **corpo inteiro**. S1.5 |
| f | Crít simples sem lunge de convergência | **A** | `_caipora_step_forward` no crít simples (536–559). S3.3 |
| g | flash-hold com decay mole; "break_amount = RGB-split" | **A/R** | **A**: release rápido (0.06–0.08s), não `FLASH_DECAY_S`. **R**: `break_amount` é **quebra de OUTLINE** (`n>break_amount`), não split de canal; sem `SCREEN_TEXTURE` no ator não há RGB-split. A "crocância" vem do flash-hold; fratura de outline opcional no crít. S3.2 |
| h | Zoom sem HOLD; 6% tímido | **A** | HOLD 2 frames no pico sincronizado ao freeze; tierizado (+6%/+10–12%). S3.4 |
| i | Shake: tweens brigam, jitter zumbe, rotação invisível | **A** | Trauma-model **base** (acumulador único, decai no `_process`) + noise suavizado + rotação 0.5–1° + kick direcional. S3.1/S3.4 |
| j | Anel de choque radial ausente | **A** | `spawn_impact_ring`. S4.1 |
| k | Pose de HURT + recoil da Caipora ausentes | **A** | Pose baked (S1.5) + recoil runtime (S3.3). |
| l | Recoil do inimigo subvalorizado; reação do inimigo é 50% do impacto | **A** | Valores fortes (crít ~24–28px) + priorizar a reação do inimigo. S3.3 |
| m | Set de easing tímido | **A** | `expo/circ/cubic/quart` baked (`_ease`) + `TRANS_ELASTIC` runtime no settle. S1.1/S3.3 |
| n | Falta ordem de camadas VFX | **A** | Tabela z-index em F4. |

---

## C. Fases

> **Convenção de gate.** `make gate` = smoke + GUT. `make import` = obrigatório
> após gerar PNG/`.tres` novos **e** após criar `class_name` novo (gotcha #12 — GUT
> mente verde se um script não parseia; **confirmar que o total de testes SUBIU**).
> `/validate-controls` quando tocar input/arena/timing. `/validate-platforms`
> quando tocar câmera/UI/safe-area/atmosfera (retrato E paisagem, `size_changed`).

---

### F0 — Lei & Fundação (fazer PRIMEIRO)

**Objetivo.** Sancionar na LEI e nas TRAVAS, **antes de tocar um pixel:** (1) 3–4
tons + selout; (2) silhueta refinável; (3) **olhos que se apagam** (não pálpebra);
(4) teto anti-fofura do juice. Nesta fase os PNGs **não** mudam; `make gate`
continua verde nos assets atuais.

**Arquivos exatos.**
- `docs/CONCEITO-protagonista.md` (§2.2 forma dos olhos; §3 **linha 52 título** +
  tabela paleta 54–63 + bloco "Acabamento chapado" linha ~66; §5 pipeline ~80–97;
  §6 "o que pode evoluir").
- `assets/AGENTS.md` (regra **2c**).
- `.agents/skills/visual-identity/SKILL.md` (§3 item 3 linha 84; item 8 linha 73;
  paleta-guia; checklist). `CLAUDE.md` é symlink — editar `AGENTS.md`.
- `tests/unit/test_caipora_sprite_assets.gd` (`COLOR_MANE` linha 28; dominância
  linhas 65–66/88–89).

**Mudanças concretas (executa a §D).**
- CONCEITO §3: reescrever **linha 52** (título "2 tons por material") **e** o
  bloco "Acabamento chapado" (linha ~66, "máximo 2 tons… sem selout graduado") →
  "3–4 tons/material via selout chapado (oclusão→sombra→base→realce); realce
  NUNCA `#ffffff` (reservado aos olhos); outline 1px; sem gradiente/dither/blur;
  norte CotL". Atualizar a tabela de paleta. (C1.5)
- CONCEITO §5: inserir o passo **"selout chapado (polígonos highlight+occlusion,
  inset da borda)"** entre snap (passo 3) e outline (passo 4).
- CONCEITO §2.2 + §6: **sancionar explicitamente** "os olhos podem se **apagar/
  sumir** brevemente no vazio (nunca uma pálpebra); a forma do olho pode mudar
  por pose (windup arregala, strike/hurt vira fenda), sempre igual nos dois". (C1.1)
- CONCEITO §6 (motion law): "respiração e secondary-motion são **pesadas e
  predadoras** (fole coiled, nunca bob simétrico flutuante); squash é reservado à
  agressão; nenhum efeito dessatura o sprite". (C1.3)
- `assets/AGENTS.md` 2c: reconciliar o **stale** "selout → rim light duplo" (o
  gerador não faz nem selout nem rim light) com a receita real + nova lei (§D.3).
- SKILL §3 item 3: "≤2 tons" → "3–4 tons chapados/material", **escopado à
  protagonista** ("inimigos/chefes seguem seu próprio CONCEITO/gerador"). Manter
  item 8. Expandir paleta-guia. (C1.6)
- **Pré-relaxar o teste (inócuo hoje):** um helper `_count_orange_family(image)`
  = `#ff4500 + #8b2a00 + #5a1a00 + #ff7a33` **e** `_count_dark_family(image)` =
  `#000000 + #140f14`, trocando as linhas 65–66/88–89. Tons ainda inexistentes =
  `+0` → `assert_gt(orange, black)` e `green ≤ 12` continuam verdes hoje e ficam
  **simétricos e honestos** amanhã (mede laranja × massa escura, não `#000000`
  isolado). (C1.2, C2.8)

**Gate.** `make gate` (teste alterado continua verde nos PNGs atuais).

**Aceite.**
- CONCEITO (§2.2/§3/§5/§6), `assets/AGENTS.md` 2c e SKILL descrevem a MESMA
  receita, sem contradição.
- "Olhos que apagam" e "juice predador" estão sancionados na lei.
- `test_caipora_sprite_assets.gd` passa **sem** regenerar assets; nenhuma trava de
  marca afrouxada (5 assinaturas, `green ≤ 12`, no-branco em back/dead).

**Riscos.** *Relaxar teste antes da arte* → soma de tons/pretos ausentes = 0
(inócuo). *Doc divergente* → editar os 3 documentos na MESMA sessão (gotcha #21).

---

### F1 — Pipeline `gen_caipora.py` (3–4 tons + selout + silhueta + N frames)

**Objetivo.** Evoluir o gerador de "1 desenho por pose" para **rig paramétrico →
keyframes → sampler com easing → N frames baked**, com selout de 3–4 tons,
serrilhado reesculpido, olhos IGUAIS, olhos-que-apagam e pose de HURT — tudo
determinístico.

**Arquivo exato.** `scripts/tools/gen_caipora.py` (âncoras: `PALETTE` 34–44; `Rig`
48; `render`/threshold `a<112` 101–111; `_outline` 129; `_rig` 146; `_draw_serrated_cloak`
179; `_draw_face_and_horns` 254, **olhos 269–270**; `_draw_black_body` 278; `_draw_staff`
305, cristal `CRYSTAL` no `staff_tip`; `caipora()` 363; `POSES` 388; `_make_contact_sheet`
400; `generate_all` 420). Saída: `assets/sprites/player_*.png` + `caipora_sprite_frames.tres`
+ `..._chama.tres`.

**S1.1 — Refactor estrutural + easing ampliado, ZERO mudança visual.**
- `Rig` → dataclass `Pose` com canais animáveis: `breath`, `squash`,
  `squash_pivot`, `eye_open=1.0`, `eye_ry_scale=1.0`, `juba_lag`, `juba_flare`,
  `smear`, `stretch`, `pose_kind`. Manter `pose_kind` porque `strike`/`back`/`dead`
  **trocam a topologia** dos polígonos (não interpolar entre topologias diferentes).
- `caipora()` recebe `t: float=0.0` e threadá-lo até `_rig(pose, phase, chama, t)`.
- `_ease(kind, p)` **ampliado** (C3-m): `linear`; `sine`; `cubic_in`=`p³`;
  `quart_in`=`p⁴`; `expo_out`=`1-2^(-10p)`; `circ_out`=`√(1-(p-1)²)`;
  `back`=`1+c3·(p-1)³+c1·(p-1)²`. (`ease_in` quadrático é mole — windup usa
  `cubic_in`/`quart_in`; contato usa `expo_out`/`circ_out` para snap.)
- `_lerp_pose(a,b,u)`, `sample(anim, phase)`, `bake(anim, n, loop)`.
- **Aceite:** com `n=1` por pose, os 16 PNGs saem **byte-idênticos** (`git diff`
  vazio). Base segura. (`.tres` sem `uid=` a preservar — `CaiporaSkin` carrega por
  path; regenerar por código é seguro. C2.8)

**S1.2 — Paleta 3–4 tons + selout chapado.**
- Expandir `PALETTE`: `ORANGE_OCC=(90,26,0)` (#5a1a00), `ORANGE_HI=(255,122,51)`
  (#ff7a33); manter `ORANGE_DK`/`ORANGE` como sombra/base **dominante**. CHAMA
  ganha 4º tom (`FIRE_OCC`). Corpo: `VOID_COOL=(20,15,20)` (#140f14) **só** como
  linha de separação interna (precedente: finishers usam near-black).
- **Desenhar o selout explicitamente** (não confiar no snap do AA — emergente =
  shimmer): por material, 1 polígono de **realce** (topo da juba, ponta dos
  chifres, aresta de ataque da capa no strike) + 1 de **oclusão** (junção
  capa↔vazio do rosto, sob o queixo, axila), na MESMA ordem em todos os frames
  (fill → sombra → oclusão → realce). São **polígonos-filhos** da forma-mãe, inset
  ≥1px, velocidade relativa 0.
- **Anti-halo:** nenhum tom claro (`ORANGE_HI`/`FIRE_CORE`) encosta na
  transparência (o pixel de AA snapa escuro; o `_outline` preto puro **estabiliza**
  a borda). Realce NUNCA `#ffffff` (travas 87/98).
- **Não** desenhar `CRYSTAL_HL` no sprite (`green ≤ 12`); riqueza do cristal vem
  da aura runtime.
- **Aceite:** lê Cult-of-the-Lamb a 32px (volume por células duras); dominância e
  `green ≤ 12` intactos (helpers de família do F0).

**S1.3 — Reescultura + olhos por pose + olhos IGUAIS.**
- `_draw_serrated_cloak` dentes: 5 triângulos iguais → **rítmicos e assimétricos**
  (3 grandes + 2 pequenos), nos dois lados, profundidade variando por pose.
- Proporção chibi (`_rig`): cabeça+juba ≈ 55–60%; chifres "V" assimétrico, pontas
  SEMPRE ultrapassando a juba.
- **Olhos IGUAIS restaurados** (C1.7): hoje 269–270 são desiguais
  (`2.4×2.7 @ y−0.8` vs `2.3×2.5 @ y−0.1`). Igualar `rx/ry/|x|/y` e aplicar o
  fator por-pose **igual aos dois**: `eye_ry_scale` = windup `1.3` (arregala),
  strike/hurt `0.35` (fenda) — o único traço facial que muda (CONCEITO §2.2).
- **INVARIANTE CRÍTICA:** o `staff_tip` do **idle** (66.5, 23.5) **não move** —
  `FuriaVisual.CRYSTAL_ANCHOR=(18.5,−24.5)`, `BODY_CENTER_LOCAL=(-18.5,24.5)`,
  `FIRE_FOOT_DROP=26.0` são derivados dele; `test_furia_visual` sonda verde nesse
  ponto.
- **Aceite:** silhueta premium; olhos idênticos; `test_furia_visual` verde.

**S1.4 — Idle (só capa) + `idle_dim` (olhos apagam) + walk + secondary motion.**
- `POSES` → `POSE_FRAMES = {"idle":5, "idle_dim":2, "walk":6, "windup":3,
  "strike":4, "recover":4, "hurt":2, "back":1, "dead":1}`. `generate_all` itera
  `t=i/max(1,n-1)`; frame 0 = nome canônico; extras `player_<pose>_<i:02d>.png`
  (+ `_chama`).
- **Idle = APENAS forma da capa** (C3-c): corpo/cabeça/olhos/cajado travados no
  MESMO pixel/y em todos os 5 frames — **zero bob** (o bob é do engine breath, F2).
  Só a bainha/pontas da juba oscilam (`juba_flare` mínimo + `juba_lag`).
- **`idle_dim` (ex-blink)** (C1.1): 2 frames onde os **olhos se apagam no vazio**
  — as elipses dos olhos são desenhadas em `VOID`/near-black (some o branco),
  resto idêntico ao idle frame 0. **NÃO é pálpebra.** Frame 0 do idle permanece de
  olhos brancos abertos (trava 55).
- **Walk:** 2 → 6 frames (contato/passagem × 2 + overlap da juba defasado),
  `speed 11`.
- **Secondary motion baked por-contexto** (C3-d): `_apply_secondary_motion(frames,
  loop, k, damp)` — mola amortecida, **3 ciclos** (transiente morre nos 2 primeiros
  → loop contínuo), gravando `juba_lag`, pesada por altura do vértice (topo 0.2 →
  bainha 1.0). **Constantes por contexto:** idle mole (`k≈0.25, damp≈0.6`,
  fluttera); strike/recover rígido (`k≈0.5, damp≈0.8`, para seco). Puramente
  aritmético = byte-estável.
- **`_write_sprite_frames()`** (novo): emite os DOIS `.tres` deterministicamente
  (nomes: `default/idle/idle_dim/walk/windup/strike/recover/hurt`; `duration` por
  frame; `speed`/`loop` por anim). Emitir os dois pelo MESMO código garante a
  simetria base⇄chama por construção (`test_caipora_chama_frames`). Não editar
  `.tres` à mão (gotcha #7); conferir `git diff` do `.tres`.

**S1.5 — Poses de combate multi-frame + durações por-frame + HURT.**
- **Durações por-frame, não `speed` uniforme** (C3-e): o SpriteFrames guarda
  `duration` por frame.

  | anim | frames | loop | durações (s) | notas |
  |---|---|---|---|---|
  | `idle` | 5 | true | ~0.30 cada | só forma de capa |
  | `idle_dim` | 2 | false | 0.06, 0.10 | olhos apagam; timer raro (F2.2) |
  | `walk` | 6 | true | ~0.09 cada | overlap defasado |
  | `windup` | 3 | false | 0.06, 0.06, **hold** | `cubic_in`+`squash<0`, segura o último (anticipation) |
  | `strike` | 4 | false | 0.05, **0.03**, 0.08, 0.05 | pré-contato / **SMEAR** / contato / early follow-through |
  | `recover` | 4 | false | 0.06 cada | `expo_out→back`, overshoot da juba |
  | `hurt` | 2 | false | 0.07, 0.12 | cabeça pra trás, olhos em fenda |
  | `back`/`dead` | 1 | — | — | carregados direto (não mexer) |

- **Windup:** `squash<0` (comprime, pivô nos pés via `_squash_xf`, `sx=1/sy`,
  volume preservado) + hold no último frame (mola carregada segura).
- **Strike:** frame de **SMEAR é o mais curto** (0.03s) e **estica o CORPO
  INTEIRO** ~1.3× no eixo do golpe (`stretch`), não só arrasta o cajado; a trilha
  do cajado é **polígono-trilha** (NÃO multi-draw translúcido — o threshold
  `a<112` come cópias) ligando `staff_tip[i-1]→[i]`, afinando na cauda, cor quente.
  A capa **arrasta atrás** do swing (lag). Empurra o ramo `strike` que já estica a
  capa.
- **Recover:** `expo_out → back` — a capa **chicoteia pra frente**, passa do
  repouso e assenta (o "último balanço" do HK; oscilação amortecida fica no
  RUNTIME, F3.3).
- **HURT** (C3-k, novo): 2 frames — cabeça/torso pra trás, olhos em fenda (mesma
  geometria sancionada do strike), juba eriçada pra trás. É pose de combate
  (tocada via `play_pose` na arena, entra no `.tres`) — **não** é loader direto.
- `back`/`dead` ficam em **1 frame** — `final_choice_screen.gd` e
  `ending_sacrifice_screen.gd` carregam os PNGs **direto** (fora do `SpriteFrames`).

**Atualização de testes/lei.**
- `SPRITE_PATHS` (test): adicionar cada frame novo em base **e** `_chama`
  (`player_idle_01..04`, `player_idle_dim_01/02`, `player_walk_01..05`,
  `player_windup_01/02`, `player_strike_01..03`, `player_recover_01..03`,
  `player_hurt` + `player_hurt_01`). Cada um: 96×96, massa >180. **Confirmar que o
  total de testes SUBIU** (gotcha #12). `idle_dim` e `hurt` **não** entram nos
  asserts de olho branco (idle_dim tem olhos apagados; hurt tem fenda).
- Adicionar `POSE_FRAMES` ao `_make_contact_sheet`.

**Gate.** `python scripts/tools/gen_caipora.py` → `make import` → `make gate`.

**Aceite.**
- Regeneração **byte-estável** (2×, `git diff` vazio na 2ª).
- 32px: "mancha laranja serrilhada + 2 olhos brancos iguais", juba domina.
- `test_caipora_sprite_assets`, `test_caipora_chama_frames`, `test_furia_visual`
  verdes; total de testes maior.
- Orçamento web respeitado (§F).

**Riscos.** *Boil de borda* → features legíveis (olhos/chifres/cajado) em
pixel/meio-pixel inteiro; boil só na juba; quantizar keyframes `q=round(v*2)/2`.
*Boil piora com 3–4 tons* → selout como polígonos-filhos inset, ordem estável.
*Inverter trava de marca* → famílias laranja/preta + `green ≤ 12`. *Corromper
`.tres`* → gerar por código, `git diff`, `make import`. *Desancorar FuriaVisual* →
`staff_tip` idle imóvel.

---

### F2 — Integração de animação (respiração / olhos-que-apagam)

**Objetivo.** Ligar os frames novos ao runtime **sem dupla-animação**, dar vida ao
idle nos TRÊS contextos (arena/exploração/menu) e fazer os olhos apagarem raro.

**Arquivos exatos.**
- `scripts/systems/actor_animator.gd` (`STRIKE_HOLD_S`/`RECOVER_HOLD_S`/
  `FLASH_DECAY_S`/`BREATH_PERIOD_S`; `_start_breathing` ~154; `play_pose` ~50;
  `strike` ~59; `settle` ~64; `track` ~28).
- `scripts/entities/caipora.gd` (exploração: `play("idle")` ~109, `play("walk")` ~77).
- `scripts/ui/title_walker.gd` (menu: `play("walk")` — decorativo, sem apagar olhos).

**S2.1 — Breath split-responsibility (C3-c, supera C2.4).**
- **NÃO desligar o engine breath.** Ele é `scale:y ±1.5%` no sprite (transform),
  buttery e de graça — fica para **todos** os atores. Os frames baked de idle
  carregam **só a forma da capa** (S1.4), com corpo/olhos travados; os dois canais
  **compõem sem brigar** (engine = escala; baked = pixels). O rosto não tem
  animação **independente** — só acompanha a escala sutil da silhueta inteira.
  Como o breath continua universal, **não há guard `get_frame_count`** → o crash de
  `has_animation` da Crítica 2#4 nunca ocorre.
- **Tornar o breath predador** (C1.3): em `_start_breathing`, ease **assimétrico**
  (sobe devagar `cubic`, assenta mais rápido) e viés para os pés (respira como
  fole coiled, não bob flutuante). Amplitude mantida (~1.5%).
- Folga nos holds para os frames caberem: `STRIKE_HOLD_S 0.22 → 0.28`,
  `RECOVER_HOLD_S 0.25 → 0.30`. **São holds de follow-through PÓS-resolução
  (cosméticos), não a janela de input** — o timing de acerto vem do `TimingSystem`;
  `/validate-controls` confirma.
- `strike`/`settle`/`_settle`/`_back_to_idle` seguem por **timer** (não
  `animation_finished`). `_spawn_afterimages` já é multi-frame-safe
  (`get_frame_texture(anim, frame)`).
- **Idle-morto na exploração é curado aqui como efeito do F1.4** (C2.8): `caipora.gd`
  e `title_walker.gd` **nunca** usaram o engine breath (só a arena rastreia atores);
  eles revivem porque `idle` virou loop de 5 frames que `play("idle")` anima. O
  split-responsibility só evita respiração dupla **dentro** da arena.

**S2.2 — Olhos-que-apagam por timer raro (C1.1).**
- Em `ActorAnimator`: `Timer` por ator, `randf_range(3.5, 7.0)` (cadência
  **irregular**, não metrônomo); no timeout, se a anim é `idle`, `play(&"idle_dim")`
  e reagenda; timer curto (~0.16s) volta a `idle`.
- Em `caipora.gd` (exploração): mesmo timer leve, só quando parada.
- `title_walker` **sem** apagar olhos. **Combate sem** apagar olhos (a forma do
  olho muda pela POSE — windup arregala, strike/hurt fenda).

**Atualização de testes/lei.** **NOVO** `tests/unit/test_actor_animator.gd` (C2.2):
assert de que idle multi-frame + engine breath **compõem** (breath ativo E anim
idle >1 frame); `idle_dim` não deixa branco. `class_name` novo → `make import`
antes; confirmar total do GUT subiu.

**Gate.** `/validate-controls` + `make gate`.

**Aceite.** Caipora respira (transform predador) + capa oscila (baked) em
exploração/menu/arena — **uma** respiração. Olhos apagam raro e irregular no idle;
ausentes no combate. Poses de combate cabem nos holds; sem flicker de estado.

**Riscos.** *Dupla-animação* → canais distintos (engine=escala, baked=capa).
*Apagar virar metrônomo* → intervalo aleatório. *Holds atrasarem o turno* → são
pós-resolução (`ATTACK_COOLDOWN_SECONDS` encadeia o turno); `/validate-controls`.

---

### F3 — Juice de combate (condutor + anticipation → contato congelado → follow-through)

**Objetivo.** Fazer o crítico e a esquiva perfeita **doerem** — freeze generoso
com silhueta branca, recoil do alvo + lunge de convergência, zoom-punch com hold e
shake físico — **tudo no mesmo pico**, por um **condutor único**, respeitando o
orçamento. **A reação do inimigo é metade do impacto sentido e é barata (zero
arte nova) — prioridade.** (C3-l)

**Arquivos exatos.**
- `scripts/systems/feedback_system.gd` (`trigger_screenshake` ~66; `_shake_camera`
  ~79; `trigger_hit_stop`/`force_clear_hit_stop` ~89; sinais `hit_stop_started/ended`;
  `combo_step`; `spawn_critical_particles`).
- `scripts/systems/actor_animator.gd` (`flash` ~87; `impact_squash` ~97;
  `perfect_dodge` ~117; `_on_health_changed` ~80).
- `scripts/arena/arena_manager.gd` (`_play_killing_blow_zoom` 235; `_update_camera_fit`
  253; `add_front_light` 294; normal-hit + `_caipora_step_forward` 455–472; duplo
  484–505; **crít simples 536–559**; esquiva 812–823; GOOD 824–835; dano 836–850;
  `_on_hit_stop_started/ended` 915–929).
- `scripts/utils/constants.gd` (`combo_scale`; `combo_hitstop_bonus`; `COMBO_MAX_STEP`;
  `COMBO_ZOOM_BONUS_PER_STEP`; novos caps de shake/rotação/hitstop).
- `OptionsPanel` (S3.5).

**S3.1 — O CONDUTOR de impacto + trauma-model de shake (base). (C3-a, C3-i)**
- Criar `FeedbackSystem.impact(tier, pos, dir, combo_step, target, attacker)` —
  **única fonte de verdade por tier**. Substitui as listas manuais dispersas nos
  handlers (crít 26/6, duplo 22/4, esquiva 22/5, normal 13/3, GOOD 10/2, dano 14/2,
  whiff 6/0 → consolidadas numa tabela). Sequência, tudo ancorado ao freeze:

  ```
  no frame do contato:
    1. hit-stop começa (speed_scale=0 nos sprites+bolhas)   ← congela tudo
    2. flash_hold(target=1.0)   [+ fratura de outline no crít]        (S3.2)
    3. recoil(target, dir, px)  +  lunge(attacker, +dir)             (S3.3)
    4. zoom_punch(tier): in → HOLD no pico (coincide com o freeze)   (S3.4)
    5. camadas de partícula (ordem da tabela §F4) — todas de uma vez (F4)
    6. add_trauma(tier) direcional + Atmosphere.pulse(kind)          (S3.4/S5.3)
  fim do freeze (hit_stop_ended / force_clear):
    7. flash_release rápido (0.06–0.08s) + zoom-out + speed_scale=1
  ```

- **Dono do flash-release** (resolve o órfão C3-g/C2.5): o condutor mantém
  `_held_flash: Array` e libera **todos** em `hit_stop_ended` **e**
  `force_clear_hit_stop`. Assim, um 2º impacto cujo hit-stop é descartado pelo
  anti-acúmulo (`if _hit_stop_active: return`) não deixa a silhueta branca presa.
- **Trauma-model como BASE** (não opcional): acumulador único `_trauma` (0–1),
  `add_trauma(x)` soma e satura; `_process` decai (`_trauma -= decay*delta`) e
  aplica `offset = noise(t)*trauma²*MAX_OFFSET` + `rotation = noise2(t)*trauma*MAX_ROT`.
  **Conserta o bug real** de dois `trigger_screenshake` sobrepostos brigando pelo
  `camera.offset` (o 2º callback resetava o offset). `_shake_camera` troca
  `randf_range` (jitter que **zumbe**) por **noise suavizado** (tranco físico).
  `trigger_screenshake` legado vira fino wrapper de `add_trauma` (compat).
- **Escalonamento por combo** só no barato (trauma, frames de hit-stop, zoom).
- **Killing-blow intacto:** o condutor trata **não-fatais**; o golpe final mantém
  `_play_killing_blow_zoom` (finisher com `time_scale`).

**S3.2 — flash-hold + release rápido + escada de hit-stop re-espaçada. (C3-b/g)**
- `ActorAnimator.flash_hold(actor)` = `flash_amount=1.0` **sem** decay;
  `flash_release(actor)` = decai em **0.06–0.08s** (NÃO `FLASH_DECAY_S=0.18`, que
  vira fade mole dentro de um freeze de 150ms). Chamado **depois** do `take_damage`
  em cada ramo; `_on_health_changed` **respeita um hold ativo** (não sobrescreve).
- **Escada de hit-stop re-espaçada** (separação por tier, não só o topo):

  | evento | atual | proposto (frames@60 → ms) |
  |---|---|---|
  | whiff | 0 | **0** (o vazio é a punição) |
  | input/chip | 0 | 0 |
  | tomar dano | 2 (33) | **3 (50)** |
  | GOOD / bloqueio | 2 (33) | **4 (66)** |
  | golpe normal / 1º do duplo | 2–3 | **4–5 (66–83)** |
  | esquiva perfeita | 5–7 | **7–9 (117–150)** |
  | **crít simples (money)** | 6–8 | **9→12 (150→200)** |
  | crít do duplo | 4–6 | **7→10 (117–166)** |
  | killing blow | `time_scale` | manter |

  E `COMBO_HITSTOP_BONUS_AT_MAX` **2 → 3–4** (rampa sentida). Seguro: input via
  `speed_scale` nunca congela (B.2).
- *(Opcional, on-brand)* no crít money, spike de `break_amount` (uniform de
  `hit_flash.gdshader`) por 1–2 frames = **fratura/serrilha do outline** (não
  RGB-split — não existe sem `SCREEN_TEXTURE`; C3-g rejeitado). Violento e de graça.

**S3.3 — Recoil (inimigo + Caipora/HURT) + lunge de convergência + anticipation. (C3-f/k/l/m)**
- `ActorAnimator.recoil(actor, dir, px)` — saída `0.05s` (`TRANS_CIRC/EXPO`, seco)
  → volta `0.12–0.16s` (`TRANS_BACK`). **Inimigo:** crít ~24–28px, GOOD ~10–12px,
  normal ~16px. **É a física que mais falta.**
- **Lunge de convergência no crít simples** (C3-f): chamar `_caipora_step_forward`
  no ramo 536–559 (hoje só o normal 455–472 e o duplo o fazem). Impacto = dois
  corpos convergindo (Caipora avança + inimigo recua).
- **Caipora apanha** (C3-k): no ramo de dano (836–850), `play_pose(_caipora,
  &"hurt")` + `recoil(_caipora, Vector2(-1,0), ~14px)`. A guardiã sangra — horror
  on-brand (já há blood particles + HURT sfx ali).
- `anticipation_squash(actor)` (inverso do impacto, `scale (0.9,1.1)`, pivô pés) em
  `play_pose(&"windup")` dos DOIS atores (768 inimigo / 374 Caipora). **Replicar o
  pause de `_breath_tweens`** do `impact_squash` (C2.6) — senão dois tweens de
  `scale` colidem no inimigo (que mantém o engine breath).
- **Settle elástico runtime** (C3-m): variante `TRANS_ELASTIC` no volta do
  `impact_squash`/recover da capa (o wobble/jiggle "gosminha" do CotL que 3 frames
  baked não mostram).

**S3.4 — Zoom-punch (hold no pico) + shake direcional + rotação. (C3-h/i, C2.7)**
- `FeedbackSystem.zoom_punch(tier, combo_step)` generalizando `_play_killing_blow_zoom`
  na `get_viewport().get_camera_2d()`: **tierizado** — crít +6%, crít em combo alto
  +10–12%. Timing: **in 0.04s `EASE_OUT` → HOLD 2 frames (33ms) no pico → out 0.12s
  `EASE_IN`**. O HOLD é **obrigatório** e **sincroniza com o freeze** (congela NO
  pico do zoom — o "soco" do CotL). Só tier PERFEITO (crít + esquiva); GOOD/ERRO
  **sem** zoom (a ausência É a informação de tier).
- **Anti-drift** (C2.7): snapshot/retorno ao **zoom de fit** (reusa o `z` de
  `_update_camera_fit`, **não** o zoom "atual"), guard `_zoom_punch_active` contra
  reentrância (duplo perfeito ~0.5s) e contra `size_changed`. Opera **sobre** o fit
  (retrato × paisagem, gotcha #10).
- Kick direcional no trauma: viés `+X` ao acertar, `-X`/baixo ao apanhar;
  **rotação 0.5–1°** no pico (não 0.4°, invisível no mobile), via o `MAX_ROT` do
  trauma-model.

**S3.5 — Reduce-motion (lição de enjoo do CotL).**
- Slider `shake_intensity` no `OptionsPanel` → cap em `constants.gd` respeitado no
  trauma-model e na escada de combo. Obrigatório em web/mobile.

**Atualização de testes/lei.** **NOVOS** `test_actor_animator.gd` (recoil/
flash_hold/anticipation_squash — existência + pause de breath) e
`test_feedback_system.gd` (impact/zoom_punch/add_trauma — guards, tier→frames,
release em `hit_stop_ended` **e** `force_clear`) (C2.2). `class_name` novo →
`make import`; confirmar total subiu.

**Gate.** `/validate-controls` + `make gate` (S3.4/S3.5 também `/validate-platforms`).

**Aceite.**
- Crít: silhueta branca congelada (segura o freeze inteiro) + recoil do inimigo +
  lunge da Caipora + micro zoom-punch com hold; a escada `ERRO < GOOD < PERFEITO <
  PERFEITO+combo < killing blow` é **sentida** sem ler texto.
- Caipora apanha com pose de HURT + recoil.
- Input flui durante o freeze; sem shake que zumbe; dois impactos rápidos não
  brigam pelo offset nem deixam flash órfão.
- Reduce-motion zera o shake sem quebrar o resto. 60fps no frame de crít (§F).

**Riscos.** *Zoom empilhar/derivar* → fit-relative + guard. *flash órfão* →
condutor libera todos em `ended`+`force_clear`. *anticipation vs breath* → pause de
tween. *Tocar timing* → holds/recoil são pós-resolução; `/validate-controls`.

---

### F4 — VFX & Partículas (trilha, arco, ANEL de choque, olhos, poeira, sangue, CHAMA)

**Objetivo.** Adicionar o vocabulário HK/CotL — o efeito carrega o alcance, o
**anel de choque** vende peso, o glow dos olhos = estado, a brasa = identidade —
**barato e por cima do sprite chapado**, disparado **pelo condutor** (F3.1).

**Arquivos exatos.**
- `scripts/systems/feedback_system.gd` (`_VFX_ARCH`; `_VFX_BY_ID`; `spawn_attack_vfx`;
  `spawn_critical_particles`; pool de VFX; sinal `blood_spilled`).
- `scripts/systems/actor_animator.gd` (`_spawn_afterimages` ~127; `perfect_dodge`;
  `strike`).
- `scripts/entities/furia_visual.gd` (`CRYSTAL_ANCHOR` 19; `BODY_CENTER_LOCAL` 25;
  `FIRE_FOOT_DROP` 27; gate CHAMA; olhos derivados de `_draw_face_and_horns` 269–270).
- `scripts/utils/constants.gd` (`ADDITIVE_MATERIAL`; `particle_amount_scale`;
  `COLOR_JUBA`/`COLOR_CRYSTAL`).

**Ordem de camadas VFX** (o diretor pediu explicitamente; z-index trás→frente).
Regra: **identidade/ambiente ATRÁS do sprite; impacto NA FRENTE; UI no topo.**

| z | camada | dono |
|---|---|---|
| −3 | sombra de chão | `ActorContrast` |
| −2 | rim/back light + fogo traseiro (T6) | S5.1 / `FuriaVisual` |
| −1 | **poeira nos pés**, afterimages da capa | S4.3 / S4.1 |
| 0 | sprite do ator | — |
| +2 | **glow dos olhos** (aditivo, no rosto) | S4.2 |
| +3 | respingo de sangue (direcional) | `blood_spilled` |
| +4 | **arco de garra + anel de choque** | S4.1 |
| +5 | nome do golpe (Label, existente) | `spawn_move_name` (gotcha #17) |
| +6 | VFX-id do golpe (existente) | `spawn_attack_vfx` |
| 10 | timing bubble | — |
| 20 | rótulo de resultado | — |
| 25 | combo | — |

**S4.1 — Trilha da juba + arco de garra + ANEL DE CHOQUE.**
- Reusar `_spawn_afterimages` tingido `COLOR_JUBA` (count reduzido) no strike/crít
  e no lunge do finisher — o "motion trail" do HK, de graça.
- **Arco de garra** no crítico (o "branco" do HK — o efeito carrega o alcance,
  não o cajado): `Line2D`/`Polygon2D` aditivo curvo (`#ff4500` → transparente,
  `0.12s`), no apex do strike. Novo `spawn_slash_arc(pos, dir)`.
- **Anel de choque radial** (C3-j, o cue de FORÇA mais barato e eficaz):
  `spawn_impact_ring(pos, tier)` — 1 sprite/`Line2D` aditivo que **expande e
  desvanece** (`0.15s`), z=+4. Disparado pelo condutor no contato do crít/esquiva.

**S4.2 — Glow dos olhos (o canal emocional do HK, sem virar fofo). (C1.3)**
- Dois `Sprite2D` **aditivos** (não `PointLight2D` — teto de luzes, ver S5.1)
  ancorados no rosto (offsets de `_draw_face_and_horns` 269–270). **Baixa energia**:
  pulso mínimo no idle; **brilha no crítico**; **APAGA no dano/HP baixo/morte**
  (escutar `health_changed` em `_on_health_changed`). Nunca floresce em "olhinho
  fofo" — o brilho é agressão; a ausência é o Hollow.
- `class_name EyeGlow` → `make import` + confirmar total subiu.

**S4.3 — Poeira nos pés + sangue direcional + brasas CHAMA.**
- Arquétipo `dust` neutro em `_VFX_ARCH`/`_VFX_BY_ID`; burst no `foot_y` no
  walk/land/`perfect_dodge` (vende peso). Respeita `particle_amount_scale`.
- Viés direcional (`direction`) de `slash`/`impact`/`blood_spilled` para `+X` — o
  sangue "voa" na direção do golpe.
- Brasas CHAMA no crítico quando `has_chama`, sob o gate único do `furia_visual`;
  1 `CPUParticles2D` one-shot aditivo em `BODY_CENTER_LOCAL`.

**Atualização de testes/lei.** `test_attack_vfx` (todo `vfx_id` no registro,
**existe**), `test_sfx_variants` (se novo som, **existe**), `test_furia_visual` (se
novo emissor). Confirmar total subiu.

**Gate.** `/validate-controls` + `make gate`; `make import` se novo `class_name`.

**Aceite.** Arco laranja lê "corte"; **anel** lê "peso"; poeira vende passo; olhos
pulsam/apagam com o HP. Verde do cristal mínimo (`green ≤ 12`; aura localizada).
z-index da tabela respeitado; nenhum VFX cobre os olhos. 60fps: pool, sem
`instantiate/queue_free` no hot path, escala por velocidade/spread (não `amount`).

**Riscos.** *Estourar orçamento* → pool + `particle_amount_scale` + `ADDITIVE_MATERIAL`.
*Glow vazar verde* → olhos são brancos aditivos. *3ª+ luz* → sprite aditivo p/ olhos.

---

### F5 — Cena & Atmosfera (iluminação / parallax / névoa estilo Hollow Knight)

**Objetivo.** Fazer a Caipora "pop" contra o breu **pela CENA** — luz de recorte,
3 camadas com parallax, névoa e pulso reativo — **sem dessaturar o sprite** e sem
cobrir a UI crítica.

**Arquivos exatos.**
- `scripts/entities/actor_contrast.gd` (`add_front_light` 294-uso; `add_ground_shadow`;
  `apply_outline`) + `scripts/exploration/forest_light.gd` (classe `ForestLight`).
- `scripts/arena/arena_backdrop.gd` (`_setup_phase_dressing` 305; `_add_moon` 326;
  `_add_vitral_light` 331; **`set_combat_mode` 368–384 — NÃO culla os PointLight2D
  de fase**; "máx 2 PointLight2D" 304–305).
- `scripts/ui/atmosphere.gd` + `assets/shaders/atmosphere.gdshader` (vinheta+grão;
  **não lê SCREEN_TEXTURE**, **não tem `pulse`**).
- `scripts/exploration/exploration_manager.gd` (câmera segue a Caipora).
- `scripts/core/signal_bus.gd` (`attack_result_perfect`; `defense_result_perfect`;
  `defense_result_miss`).

**S5.1 — Rim/back light que SUBSTITUI a front light. (C2.3)**
- **Substituir** (não somar) a `add_front_light` da Caipora (294) por
  `ActorContrast.add_rim_light()` — `PointLight2D` **aditiva** ATRÁS do ator
  (`z < sprite`), quente da juba OU frio do cristal (eco da Fúria), gated por
  device (`particle_amount_scale`, como a front light). **Motivo:** em P1/P3/P5 o
  `set_combat_mode` **não** culla o dressing (`_add_moon`/`_add_vitral_light`), e a
  Fúria T6 acende +1 — somar rim daria **4 luzes** (teto = 2). Substituindo,
  fica ≤ 2 no pior caso; onde ainda apertar, usar **sprite aditivo** no lugar de
  luz. Vive no ATOR → sobrevive ao `set_combat_mode` e persiste nas janelas de
  timing (o "a luz mais forte da tela é o jogador" do HK).

**S5.2 — Parallax 3 camadas + névoa entre camadas.**
- **Exploração** (câmera segue a Caipora): `Parallax2D`/`ParallaxBackground` com 3
  camadas (mata hostil ao fundo / chão no midground / vultos pretos no foreground)
  reagindo a `size_changed` (gotcha #10, retrato E paisagem). Na **arena** (câmera
  quase estática) o parallax é só via shake.
- **Névoa entre camadas:** shader de noise, alpha baixo, **entre** bg e midground,
  **ABAIXO da layer 50** (recebe vinheta/grão, integra no mundo) — o breu úmido
  amazônico. Vultos de foreground sutis (z 1–10, aditivo) sem competir com a
  `TimingBubble` (z 10).

**S5.3 — `Atmosphere.pulse` reativo (SEM aberração, SEM dessaturar a Caipora). (C2.1, C1.4)**
- **NÃO** adicionar aberração cromática ao `atmosphere.gdshader` — ele **não lê
  SCREEN_TEXTURE** por contrato (custo/instabilidade em gl_compatibility web). A
  alternativa `gradient_map.gdshader` (que lê tela) é **rejeitada** aqui: ela
  desaturaria/graduaria a Caipora junto. Ficamos em **overlay puro**.
- Expor 2 uniforms no `atmosphere.gdshader` — `vignette_boost` e `vignette_tint` —
  e `Atmosphere.pulse(kind, strength)` que os tweena sobre `vignette_opacity`/
  `vignette_color` já existentes:
  - **Crítico:** `vignette_boost +20%`, decai `0.20s EASE_OUT`.
  - **Tomar dano:** **vinheta VERMELHA** (sangue) de fora pra dentro, `0.25s` —
    horror direto (mantido; C1.4 endossa).
  - **Esquiva perfeita:** vinheta **fria** + *speed-lines* na cena/inimigo,
    `0.15s` — **sem** dessaturação global (a Caipora **não** perde o laranja; C1.4).
- Pendurar em `SignalBus.attack_result_perfect`/`defense_result_perfect`/
  `defense_result_miss` (extensão limpa via bus, sem tocar o `ArenaManager`).
  Sincronizar o pico com o freeze do condutor (F3.1) e o duck de áudio. Layer 50
  (acima da gameplay, abaixo do D-pad 55) — cobre o palco, não os controles.

**Atualização de testes/lei.** **NOVO** (opcional) `test_atmosphere.gd`: uniforms
`vignette_boost`/`vignette_tint` e `pulse()` (C2.2). `class_name` novo → `make import`.

**Gate.** `/validate-platforms` (câmera/parallax/safe-area, retrato E paisagem,
DPR cap) + `make gate`; `/validate-controls` em S5.3 (o `pulse` engancha sinais).

**Aceite.** A Caipora é a mancha laranja acesa no breu (rim + glow); o sprite
**não** dessatura (só luz/overlay aditivo). Rim persiste no combate (não é culled)
e o teto de ≤2 `PointLight2D`/arena é respeitado. Parallax reage a `size_changed`.
Pulso só nos tiers certos; **sem aberração**; nada acima da layer 50.

**Riscos.** *Culling apaga o efeito* → o que persiste vive no ATOR. *Dessaturar a
Caipora* → overlay aditivo; sem `gradient_map` na cue de esquiva. *Estourar luzes*
→ rim substitui front; sprite aditivo onde apertar. *Quebrar orientação* → parallax
lê `size_changed`; `pulse` opera sobre o fit; `/validate-platforms`.

---

## D. Atualização da LEI (sancionando 3–4 tons + selout + silhueta + olhos-que-apagam)

> Executada em **F0**, antes de qualquer pixel (gotcha #21).

| # | Arquivo / âncora | De | Para |
|---|---|---|---|
| D.1 | `CONCEITO §3` **título (linha 52)** **e** bloco "Acabamento chapado" (linha ~66) | "…, 2 tons por material" / "máximo 2 tons… sem selout graduado" | "**3–4 tons/material via selout chapado** (oclusão→sombra→base→realce); **realce NUNCA `#ffffff`** (reservado aos olhos); **outline 1px**; sem gradiente/dither/blur; norte **CotL**". **Ambas as linhas.** Tabela de paleta += `ORANGE_OCC #5a1a00`, `ORANGE_HI #ff7a33`, 4º tom CHAMA. (C1.5) |
| D.2 | `CONCEITO §5` (pipeline ~80–97) | 4 passos (vetor→downsample/threshold→snap→outline) | inserir passo **"selout chapado (highlight+occlusion polys, inset da borda)"** entre snap e outline. |
| D.2b | `CONCEITO §2.2` + `§6` | (sem menção a apagar; olhos "iguais que brilham") | **sancionar** "os olhos podem **apagar/sumir** brevemente no vazio (**nunca** pálpebra); a forma muda por pose (windup arregala, strike/hurt fenda), sempre **igual nos dois**; respiração/secondary-motion **pesadas/predadoras**, squash só na agressão, nenhum efeito dessatura o sprite". (C1.1, C1.3, C1.7) |
| D.3 | `assets/AGENTS.md` **2c** | "selout → rim light duplo…" (**STALE** — o gerador não faz nem selout nem rim light) | receita REAL + nova lei: "supersample 8× → BOX downsample → threshold α<112 → snap de paleta fechada (**3–4 tons/material**) → **selout chapado (highlight+occlusion polys, inset)** → outline 1px preto. Sem rim light suave / sem gradiente." |
| D.4 | `SKILL §3 item 3` (linha 84) | "Usar no máximo 2 tons por material" | "Usar **3–4 tons chapados/material** (selout: oclusão/sombra/base/realce), sem gradiente/dither/blur — **padrão da PROTAGONISTA; inimigos/chefes seguem seu próprio CONCEITO/gerador**". Manter item 8. Expandir paleta-guia (`ORANGE_OCC`/`ORANGE_HI`). Sancionar "olhos que apagam". (C1.6) |
| D.5 | `test_caipora_sprite_assets.gd` (65–66 / 88–89) | `orange = MANE + Color8(139,42,0)`; `black = _count_color(COLOR_VOID)` | `orange = _count_orange_family` (`#ff4500+#8b2a00+#5a1a00+#ff7a33`) **e** `black = _count_dark_family` (`#000000+#140f14`). Mantém `assert_gt(orange, black)` e `assert_lte(green, 12)`. **Simétrico** (mede laranja × massa escura). (C1.2) |

**Restrição dura de paleta (do teste, não afrouxa):** realce/selout **nunca**
`#ffffff` — branco puro é dos DOIS olhos (asserts 87/98 proíbem branco em
back/dead). Corpo pode ganhar `VOID_COOL #140f14` como linha de separação — o
outline puro-preto mantém a leitura, e o preto agora é **família** (não some da
contagem). Verde mínimo (não desenhar `CRYSTAL_HL` no sprite).

---

## E. Brand-Safety (as 5 assinaturas + teto anti-fofura — checklist por commit)

Antes de commitar QUALQUER sessão que toque arte/VFX/cena:

- [ ] **Juba laranja serrilhada dominante** — a 32px é "a mancha laranja de olhos
      brancos"? `orange_family > dark_family` (65–68 / 88–90)?
- [ ] **Corpo/rosto/chifres/cajado pretos** — `_has_color(VOID)` presente (56);
      `VOID_COOL` convive com o outline puro (contado na família preta).
- [ ] **Dois olhos brancos IGUAIS** — `#ffffff` presente no idle frame 0 (57);
      ausente em back/dead (87/98); **iguais** em rx/ry/y (C1.7); `idle_dim`/`hurt`
      não vazam branco parcial pros asserts.
- [ ] **Olhos apagam, NUNCA pálpebra** — `idle_dim` é o vazio engolindo os olhos,
      não uma piscada mamífera. (C1.1)
- [ ] **Cristal verde mínimo** — `green ≤ 12` (69); aura runtime localizada.
- [ ] **Postura predadora chibi** — cabeça+juba ≈ 55–60%; pés normais pra frente;
      nunca mascote.
- [ ] **Juice predador, não fofo** — respiração pesada/assimétrica (não bob
      simétrico); squash só na agressão; glow dos olhos baixo e que **apaga**;
      nenhum wobble no idle. (C1.3)
- [ ] **A Caipora não dessatura** — nenhuma cue (nem a esquiva) drena o laranja
      dela; atmosfera vive na CENA. (C1.4)
- [ ] **Acabamento** — flat + outline 1px mesmo com 3–4 tons; sem gradiente/blur/dither.
- [ ] **Determinismo** — nenhum `player_*.png` editado à mão; regeneração byte-estável.
- [ ] **Não-boil** — olhos/rosto/chifres/cajado estáveis entre frames; boil só na juba.
- [ ] **Back/dead sem olhos brancos** (87/98) — 1 frame, não multi-framear.
- [ ] **Horror preservado** — predadora, hostil, sangue no chão, pose de HURT,
      olhos que apagam no breu e na morte. **Nunca suavizar.**

---

## F. Orçamento Web (PNG/frames, 60fps, partículas)

**Frames/PNG (BAKED).**
- Contagem: idle 5 + idle_dim 2 + walk 6 + windup 3 + strike 4 + recover 4 + hurt 2
  + back 1 + dead 1 = **28 frames/variante × 2 = 56 PNGs** (era 16).
- Tamanho **medido**: os 16 PNGs atuais somam **21.804 bytes** (~1,36KB/frame,
  96×96 paleta fechada). 56 frames ≈ **~78KB** — folga absoluta nos 10MB do
  projeto e abaixo dos "<150KB". Manter PNG-por-frame (os loaders de `back`/`dead`
  exigem nome canônico; atlas conflita). `.tres` regenerados por código (sem `uid=`
  a preservar; C2.8); `.import`/`.uid` por `make import`.

**60fps (RUNTIME).**
- Frames baked = **custo zero** (troca de textura é grátis).
- Pior caso: crít money (freeze até 200ms + trauma + bursts + backdrop + DoomFire).
  O juice novo escala **só** tween/frames/pitch/zoom por combo — **nunca** `amount`.
- Hit-stop via `speed_scale`; `Engine.time_scale` só no finisher/Cortejo. Freeze
  generoso NÃO custa responsividade (input nunca congela).
- Cap de DPR e `particle_amount_scale` cortam em aparelho fraco.

**Partículas / luz.**
- Pool de VFX (1 draw call) + `ADDITIVE_MATERIAL` compartilhado (não quebra batching).
- Novos bursts (dust, trilha, brasa, arco, **anel**) ≤ orçamento por-hit; escalar
  velocidade/spread, não contagem.
- Teto **≤2 `PointLight2D`/arena** (piso Safari/iPhone): olhos = sprite aditivo,
  não luz; rim **substitui** a front light (não soma). (C2.3)
- Reduce-motion (S3.5) obrigatório — evita enjoo no Safari mobile (CotL).

---

## G. Tabela Referência → Técnica → Mudança concreta no caipora

| Referência | Técnica | Mudança (arquivo · símbolo · sessão) |
|---|---|---|
| HK — silhueta/leitura | Efeito carrega o alcance, não a arma | Arco de garra aditivo · `FeedbackSystem.spawn_slash_arc` · **S4.1** |
| HK/Vlambeer — força | Onda de choque radial | `spawn_impact_ring` (1 draw call, expande+some) · **S4.1** (C3-j) |
| HK — rosto-vazio | Olhos = estado (acende/APAGA) | Glow aditivo baixo, apaga no HP · `EyeGlow`/`_on_health_changed` · **S4.2** |
| HK — rosto-vazio | **Olhos apagam, não piscam** | `idle_dim` baked (olhos no vazio) + timer raro · **S1.4/S2.2** (C1.1) |
| HK — rosto-vazio | Forma do olho por pose, igual nos dois | `eye_ry_scale` (windup arregala, strike/hurt fenda) · `_draw_face_and_horns` 269–270 · **S1.3** (C1.7) |
| HK — capa | Secondary motion por defasagem, mola por-contexto | mola amortecida baked, `k/damp` idle mole × strike/recover rígido; **capa arrasta no strike, chicoteia no recover** · `_apply_secondary_motion` · **S1.4/S1.5** (C3-d) |
| HK — idle | Respiração imperceptível, **predadora** | engine breath mantido + assimétrico/pés; capa baked compõe · `_start_breathing` · **S2.1** (C3-c, C1.3) |
| HK/CotL — anticipation | Comprimir antes de soltar | windup `cubic_in`+`squash<0` baked · `_squash_xf`; `anticipation_squash` runtime (pause de breath) · **S1.5/S3.3** (C2.6) |
| HK/CotL — smear | 1 frame **curto** de contato, corpo inteiro | strike `duration 0.03s` + `stretch` do corpo + polígono-trilha · **S1.5** (C3-e) |
| HK — impact frame | Silhueta branca congelada, release rápido | `flash_hold`→`flash_release 0.06–0.08s`; condutor dono do release · **S3.1/S3.2** (C3-g, C2.5) |
| CotL — wobble/jiggle | Follow-through elástico | recover `expo_out→back` baked; `TRANS_ELASTIC` runtime no settle · **S1.5/S3.3** (C3-m) |
| CotL — game feel | Recoil + convergência vendem massa | `recoil(inimigo, dir, 24–28px)` + lunge da Caipora no crít simples · **S3.3** (C3-f/l) |
| CotL — guardiã sangra | Reação ao apanhar | pose de **HURT** baked + `recoil` da Caipora · **S1.5/S3.3** (C3-k) |
| CotL — juice snappy | Zoom-punch com HOLD no pico | `zoom_punch` tierizado, hold sincronizado ao freeze, fit-relative · **S3.4** (C3-h, C2.7) |
| Vlambeer — trauma | Shake que soma, não briga; físico | trauma-model base + noise suavizado + rotação 0.5–1° + kick direcional · `FeedbackSystem` · **S3.1/S3.4** (C3-i) |
| CotL — orquestração | Todas as camadas no mesmo pico | **CONDUTOR** `FeedbackSystem.impact(tier,…)` · **S3.1** (C3-a) |
| CotL — acessibilidade | Reduce-motion | cap de shake no `OptionsPanel` · **S3.5** |
| CotL — cel-shading | 3–4 tons, borda dura, inset | `ORANGE_OCC/HI` + selout chapado · `PALETTE` + §D · **S1.2** (C1.5/6) |
| HK — poeira/peso | Burst neutro nos pés | arquétipo `dust` no `foot_y` · **S4.3** |
| HK — motion trail | Afterimage da capa | `_spawn_afterimages` tingido `COLOR_JUBA` · **S4.1** |
| CotL — acento ritual | Brasa como identidade | brasas CHAMA no crít sob gate · **S4.3** |
| HK — 3 camadas + névoa | Parallax + fog | `Parallax2D` 3 camadas + névoa < layer 50 · **S5.2** |
| HK — luz guia | A Caipora é a luz mais forte | `add_rim_light` **substitui** a front light, gated, persiste · **S5.1** (C2.3) |
| CotL — vinheta-punch | Pós-processo reativo parcimonioso, **sem dessaturar** | `Atmosphere.pulse` (vinheta+ crít, sangue no dano, fria na esquiva); **sem aberração** · **S5.3** (C2.1, C1.4) |

---

### Arquivos-âncora (absolutos)

- Gerador: `/home/baltz/caipora/scripts/tools/gen_caipora.py`
- SpriteFrames: `/home/baltz/caipora/assets/sprites/caipora_sprite_frames.tres` (+ `..._chama.tres`)
- Runtime animação: `/home/baltz/caipora/scripts/systems/actor_animator.gd`
- Juice: `/home/baltz/caipora/scripts/systems/feedback_system.gd` · `/home/baltz/caipora/scripts/arena/arena_manager.gd` · `/home/baltz/caipora/scripts/utils/constants.gd`
- Consumidores: `/home/baltz/caipora/scripts/entities/caipora_skin.gd` · `/home/baltz/caipora/scripts/entities/caipora.gd` · `/home/baltz/caipora/scripts/ui/title_walker.gd`
- VFX/Fúria: `/home/baltz/caipora/scripts/entities/furia_visual.gd`
- Cena: `/home/baltz/caipora/scripts/entities/actor_contrast.gd` · `/home/baltz/caipora/scripts/arena/arena_backdrop.gd` · `/home/baltz/caipora/scripts/ui/atmosphere.gd` · `/home/baltz/caipora/assets/shaders/atmosphere.gdshader`
- Shaders de ator: `/home/baltz/caipora/shaders/hit_flash.gdshader` (`flash_amount`, `break_amount`=quebra de outline) · `/home/baltz/caipora/shaders/gradient_map.gdshader` (lê tela; NÃO usar na cue de esquiva)
- Lei & travas: `/home/baltz/caipora/docs/CONCEITO-protagonista.md` · `/home/baltz/caipora/assets/AGENTS.md` · `/home/baltz/caipora/.agents/skills/visual-identity/SKILL.md` · `/home/baltz/caipora/tests/unit/test_caipora_sprite_assets.gd` · `/home/baltz/caipora/tests/unit/test_caipora_chama_frames.gd` · `/home/baltz/caipora/tests/unit/test_furia_visual.gd`
- Testes NOVOS (F2/F3/F5, gotcha #12): `tests/unit/test_actor_animator.gd` · `tests/unit/test_feedback_system.gd` · `tests/unit/test_atmosphere.gd`