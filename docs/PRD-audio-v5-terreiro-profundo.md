# PRD Audio v5 — O Terreiro Profundo (arranjo, forma e épica de chefe)

> caipora — elevar a trilha de "loops curtos funcionais" para **música autoral de
> nível AAA dentro do grão lo-fi**: melodias mais ricas e agradáveis na exploração
> e **temas de chefe únicos, épicos e marcantes**, sempre fincados nas raízes —
> **maracatu, grave, frígio escuro, 100% procedural, zero samples externos**.
> Status: fonte canônica da próxima rodada de áudio.
> Base técnica: `AudioDirector`, `gen_sfx.py`, `check_audio.py`, bus Reverb.
> Antecede e NÃO substitui: [PRD-audio-v3](PRD-audio-v3.md) (Batuque da Mata, estética)
> e [PRD-audio-v4](PRD-audio-v4-som-funcional.md) (Som Funcional, UI de estado).
> O v4 cuidou do SFX como linguagem de estado; **o v5 cuida da MÚSICA como arranjo,
> forma e identidade.** As Etapas 2–5 do v4 (cry comum, telegraph metronômico,
> vocabulário do hub, bonk de parede) seguem pendentes e são puxadas pela Fase 4 daqui.

---

## Parte A — Como Pokémon faz música memorável (e o que isso nos ensina)

O v4 estudou o som **funcional** do Game Boy. O v5 estuda o que torna a música de
Pokémon **memorável e épica** — porque é exatamente o que nos falta. A escassez de
4 canais (2 pulse, 1 triangle/wave, 1 noise) é a MESMA do nosso motor; logo o que os
compositores fizeram com esses 4 canais é diretamente portável.

### A1. O segredo não é timbre — é ARRANJO
Dentro de 4 canais, o que diferencia um tema esquecível de um inesquecível:

| Canal GB | Função no arranjo | Nosso estado hoje |
|---|---|---|
| Pulse 1 | **Melodia / hook** | `_lead()` — temos, mas como ostinato, não hook |
| Pulse 2 | **Contra-melodia / harmonia** (call-and-response) | **AUSENTE** — eis a maior lacuna |
| Triangle/Wave | **Baixo que ANDA** (i→♭VI→♭VII→i) | `_bass()` — quase sempre tônica/quinta presa |
| Noise + perc. | **Groove** | rico (alfaia/caixa/ganzá/baque) — nosso ponto forte |

**Lei nº 1:** Pulse 2 quase nunca dobra a melodia — ele **responde** a ela. O
call-and-response é o que dá vida e densidade sem encher.

**Lei nº 2:** o baixo se move sob a melodia criando **harmonia que anda**. Nossos
baixos são ostinatos → soa estático mesmo com percussão rica.

**Lei nº 3:** existe um **hook** — um gancho melódico de 2–4 compassos que o jogador
assobia. Identidade vive no hook, não no preenchimento.

### A2. Forma longa = épica (o "tema de Campeão")
Temas de rota/cidade têm **intro + loop de 30–60s** com forma **AABA** (variação real
entre seções), não um loop de 8s repetido. Os temas de Campeão (Cynthia/Gen 4 — ápice
do VGM) são épicos por **estrutura multi-seção com mudança de tom e um clímax**, não por
mais instrumentos. Nossa fadiga de repetição vem direto daqui: explore = 2–3 compassos
(~7–9s); arena/boss = 4 compassos.

### A3. Escalada de ameaça por DEGRAUS
Selvagem < Treinador < Líder < Campeão < Lendário sobem **andamento + densidade
rítmica + complexidade melódica/harmônica**, não só volume. E gerações recentes mudam
a música em **fase 2** (Mega/Dynamax): quando a luta "vira", a trilha vira junto.

### A4. Leitmotif e callback
Motivos recorrem (tema principal, motivo de ginásio). Temas de Campeão **citam** temas
anteriores — o callback é parte do clímax narrativo.

**Tese do v5:** já temos os "4 canais" e um groove de maracatu de primeira. Falta
**arranjo (contra-melodia + harmonia que anda + hook)**, **forma (loops longos
seccionais)** e **escalada épica de chefe (fase 2 + leitmotif/callback)**. É problema de
composição e de teto de orçamento — não de tecnologia de runtime.

---

## Parte B — Diagnóstico: caipora sob esse modelo

### Já forte (manter intacto)
- **Runtime maduro e barato** (`audio_director.gd`): stems verticais base/mid/top com
  fade por intensidade, crossfade A/B, ducking, bus Reverb com perfis de espaço
  (mata/igreja/arena), heart-mode, "a mata respira", silêncio dramático. Custo de CPU
  irrisório. **Não reescrever.**
- **Vozes de maracatu modeladas** em `gen_sfx.py`: `alfaia` (surdo), `caixa`, `ganza`,
  `agogo`, `gongue`, `assovio` (leitmotif), + chip (`pulse`/`triangle`/`nes_noise`).
- **Humanização real**: jitter de velocity/tempo (`_humanize_events`), swing de samba
  (`_samba_shaker`), ghost fills (`_ghost_fill`), baque virado par/ímpar (`_baque_alfaia`).
- **Escalas propositalmente escuras**: menor natural + frígio (`MINOR_HARM`/`PHRYGIAN`).

### Os 3 tetos que travam "rico, agradável, épico"
1. **Loops curtíssimos.** Explore 2–3 compassos, arena/boss 4. Causa direta da fadiga.
2. **Sem contra-melodia e sem harmonia que anda.** Só 1 voz de lead; `_chord()` existe
   no código mas **nenhuma faixa usa**; baixos quase ostinato. Arranjo fino.
3. **Orçamento WAV apertado.** Música = 3.7 MB de **10 MB (FAIL)** / 9 MB (WARN). WAV
   8-bit @ 11 kHz não deixa alongar loops 4–8× nem somar camadas sem estourar. **Gargalo
   físico do "mais notas, mais elementos".**

---

## Parte C — Fundação técnica (Fase 0): destravar orçamento e o motor

> Decisão tomada (2026-06-19): **codec OGG Vorbis**. É o salto maior (~5–8× menor que
> WAV) e — descoberta que o viabiliza sem dor — **não precisa de ffmpeg/oggenc**: o
> ambiente já tem `soundfile` 0.13.1 + `libvorbisenc`/`libvorbis`/`libsndfile`/`libogg`.

### C1. Encoder OGG procedural (zero dependência nova)
- `gen_sfx._write(...)` ganha um caminho OGG via
  `soundfile.write(path, samples_float, MUSIC_RATE, format="OGG", subtype="VORBIS")`.
  Mantém a pureza procedural (nada de sample externo) e o pipeline `make export`.
- **Só MÚSICA e AMBIÊNCIA migram para OGG** (conteúdo longo e tonal). **SFX/stingers
  continuam WAV** (curtos, transientes, latência mínima, já couberam no budget).
- Loudness: o fiscal `check_audio.py` passa a ler OGG (via `soundfile.read`) para medir
  LUFS/pico dos alvos de `music`/`ambience`/`stem`. Mantém os mesmos alvos.

### C2. Loop seamless de OGG em runtime
- `AudioDirector._force_loop` passa a tratar `AudioStreamOggVorbis` além de
  `AudioStreamWAV`: setar `stream.loop = true` e `stream.loop_offset = 0.0`. Carregar via
  `load()` (importado) com fallback `AudioStreamOggVorbis.load_from_file()` (Godot 4.6).
- O grid periódico atual (caudas dão wrap) **continua válido**: o OGG é gravado já com o
  loop costurado pelo `_put(... % n)`. Vorbis tem priming/padding no decode → validar a
  emenda em playtest (risco conhecido; mitigável com cross-fade de 1 frame no buffer).

### C3. Orçamento novo (teto de "riqueza")
- OGG @ ~96 kbps mono: um loop de 32s ≈ ~380 KB (vs ~1.2 MB em WAV 8-bit). Isso paga
  **loops de 16–32 compassos com 5–7 vozes** para todas as faixas e **ainda sobra** sob
  os 10 MB. O fiscal continua sendo a lei (WARN 9 / FAIL 10).

### C4. Motor de composição estendido (`gen_sfx.py`)
Independente do codec, são os tijolos de arranjo que faltam:
- **`_counter()`** — voz de contra-melodia (Pulse 2): timbre distinto do lead (duty/oitava),
  para call-and-response.
- **Cama harmônica que anda** — ligar o `_chord()` já existente com progressões em menor
  natural/frígio (i–♭VI–♭VII–i, i–iv–♭II–i), repartindo ganho (anti-clip, já implementado).
- **`_section(...)`** — montador de forma AABA/intro+loop de 8–32 compassos com variação
  real por seção (não só o par/ímpar atual).
- **Mais maracatu** — voz `tarol` (caixa aguda/estalada), `agbê`/xequerê extra, padrões de
  **baque virado** mais autênticos e **polirritmia 3-contra-4** (o balanço do terreiro).
- **Regras invariantes mantidas**: detune por nota anti-sirene (regra do `mus_hub`), grave
  como fundação, frígio/menor escuro, humanização sempre ligada nas vozes longas.

---

## Parte D — Fases de conteúdo

### Fase 1 — Exploração rica *(pedido: melodias e loops mais complexos, mais maracatu)*
Para cada `mus_explore_p1..p5`:
- Loop sobe para **16–32 compassos** em forma A-B (o OGG paga o tamanho).
- **Lead com hook** memorável + **`_counter()` respondendo** + **baixo que anda** sobre a
  cama harmônica de `_chord()`.
- **Camadas de maracatu mais densas** com identidade por fase preservada (mata noturna ≠
  chamas ≠ névoa ≠ ruína ≠ igreja), sempre no grave e no frígio escuro.
- (Esticável) trazer **stems para a exploração** → a mata "acende" camadas conforme a
  proximidade de inimigos (reaproveita a maquinaria de intensidade do `AudioDirector`).

### Fase 2 — Chefes épicos *(pedido: temas únicos, épicos, agradáveis e marcantes)*
- **Leitmotif assinado por chefe**: um *gancho* de 2–4 compassos reconhecível (substitui a
  corrida de escala frenética atual), ancorado na voz `assovio` que já existe.
- **Forma de Campeão**: intro → A (tema) → B (ponte/clímax) → retorno, 16+ compassos, com
  contra-melodia e harmonia que anda.
- **Escalada fase-2**: quando o HP do chefe cruza um limiar baixo, a música **vira** (stem
  novo / seção mais intensa) — análogo do heart-mode, mas para o chefe. Requer um sinal
  novo no `SignalBus` (HP do boss já trafega; falta o gatilho de limiar).
- **Jesuíta (final)**: como o moveset cita todos os chefes, o tema **cita os leitmotifs**
  dos 4 anteriores (callback estilo Campeão). Marcante por design.

### Fase 3 — Timbre e mixagem premium (dentro do grão)
- Síntese mais rica sem perder grave nem lo-fi: **PWM** (varredura de duty), vibrato/
  portamento com envelope, **pad "supersaw-lite"** (2–3 pulsos detunados) e **sino FM**
  para gonguê/agogô/sino de igreja.
- Afinar LUFS por contexto e perfis do bus Reverb por cena. Fiscal verde.

### Fase 4 — SFX de combate premium (fecha o v4)
- Distinção **PERFEITO/GOOD/ERRO** mais "Pokémon" (super-eficaz grave/encorpado vs
  pouco-eficaz fino/abafado), por cima da escada de impacto da Etapa 1 do v4.
- Enriquecer os ~25 moves nomeados e os jingles de vitória/derrota.
- Fechar Etapas 2–5 pendentes do v4 (cry comum, telegraph metronômico, vocabulário do hub,
  bonk de parede).

---

## Parte E — Performance e invariantes (lei em todas as fases)
- **100% procedural, zero samples externos** (raiz do projeto).
- **Runtime praticamente inalterado**: só mais alguns `AudioStreamPlayer`; nenhuma síntese
  em tempo real no jogo. Loops maiores são pagos pelo **codec**, não por CPU.
- **Budget ≤ 10 MB** travado pelo `check_audio.py` (WARN 9 / FAIL 10) — agora medindo OGG.
- **Free orientation / web-first** intactos. `make gate` + escuta manual fecham cada fase.
- O agente **não ouve**: toda fase tem um item de **aceite auditivo manual** (emenda de
  loop OGG, hook do chefe, transição de fase-2, balanço de mixagem).

---

## Parte F — Ordem sugerida e por quê
1. **Fase 0** (fundação) — sem o destravamento de orçamento + motor de arranjo, nada do
   resto cabe. Entregável de prova: 1 faixa de exploração-piloto no novo padrão, medida em
   tamanho/qualidade/emenda.
2. **Fase 1** (exploração) — maior superfície percebida pelo jogador (tempo de tela).
3. **Fase 2** (chefes) — o pico emocional; depende dos tijolos da Fase 0/1.
4. **Fase 3** (timbre/mix) — polimento transversal.
5. **Fase 4** (SFX premium) — fecha o v4 e casa com a Fase 9 do jogo onde aplicável.

Uma fase por sessão. Commit ao fim de cada uma. Atualizar a memória `caipora-audio-v2`
(escopo de áudio) e o gotcha de áudio no `AGENTS.md` se surgir armadilha nova (ex.: priming
de loop OGG).
