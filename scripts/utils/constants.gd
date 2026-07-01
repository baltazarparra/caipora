class_name Constants
extends RefCounted

# ─── Grid ──────────────────────────────────────────
const TILE_SIZE := 32
const GRID_WIDTH := 26
const GRID_HEIGHT := 18

# ─── Viewport / Orientação ─────────────────────────
# Fonte ÚNICA da lógica de orientação: D-pad, hub e câmera consultam isto em vez de
# comparar vp.x/vp.y soltos. Telefone = lado curto abaixo deste limite (tablet/desktop isento).
const PHONE_SHORT_SIDE_MAX := 640.0

## True quando o viewport está em retrato (mais alto que largo).
static func is_portrait(vp: Vector2) -> bool:
	return vp.y > vp.x

# Densidade de partículas por classe de device (Fase 10): telefone corta pela
# metade — orçamento de 60fps em Android modesto. O gore não recua: os decals
# de sangue (baratos e permanentes) seguem em densidade cheia.
const PHONE_PARTICLE_SCALE := 0.5

## Fator aplicado ao `amount` dos CPUParticles2D do FeedbackSystem.
static func particle_amount_scale(vp: Vector2) -> float:
	return PHONE_PARTICLE_SCALE if minf(vp.x, vp.y) < PHONE_SHORT_SIDE_MAX else 1.0

# ─── Color grading (gradient map) ──────────────────
# Lê SCREEN_TEXTURE (custo real em gl_compatibility) — por isso a chave dupla:
# GRADING_ENABLED liga o sistema; GRADING_ON_WEB libera o grade no export web.
# Sem ele o web ficava chapado/sem contraste vs. o desktop (era a única
# diferença visual entre as plataformas). Validar FPS no iPhone com `?perf`;
# se cair abaixo de 60, desligar aqui de novo.
const GRADING_ENABLED := true
const GRADING_ON_WEB := true
const GRADING_MIX := 0.55

# ─── Combat ────────────────────────────────────────
const TIMING_WINDOW_FRAMES := 12
const TIMING_PERFECT_FRAMES := 3
const ATTACK_COOLDOWN_SECONDS := 0.0
const DODGE_COOLDOWN_SECONDS := 0.5
const TIMING_WINDOW_ATTACK := 0.8
const TIMING_PERFECT_START := 0.65
const TIMING_PERFECT_END := 0.85
const TIMING_DOUBLE_CHANCE := 0.30
const TIMING_DOUBLE_INTERVAL := 0.5
const TIMING_DOUBLE_BUBBLE_SPREAD_MIN := 60.0
const TIMING_DOUBLE_BUBBLE_SPREAD_MAX := 80.0
const TIMING_DOUBLE_BLOCK_DURATION := 0.55  # TIMING_WINDOW_ATTACK (0.8) - 0.25
const TIMING_WINDOW_MIN := 0.2
const TOUCH_TIMING_WINDOW_BONUS := 0.2
## Janelas base por tier de dificuldade (número de botões na sequência).
## Usadas como attack_duration nos .tres antes da redução de fase.
const TIMING_TIER1_WINDOW := 1.0   # 1 botão — tutorial / surpresa
const TIMING_TIER2_WINDOW := 0.85  # 2 botões — normal
const TIMING_TIER3_WINDOW := 0.75  # 3 botões — médio
const TIMING_TIER4_WINDOW := 0.65  # 4 botões — difícil

# ─── Faixas de acerto (tier PERFEITO / GOOD / ERRO) ─
# Modelo "faixas absolutas sobre a janela existente" (docs/PRD-combate-refino.md §5): a
# duração total D (timing_window_for_phase / action_windows) NÃO muda — só ONDE ficam as
# faixas dentro dela. Os meios-spans são ABSOLUTOS (segundos), então a PRECISÃO do acerto é
# constante entre fases; só o lead-in (D − banda) encurta quando D encolhe por fase.
#   PERFEITO = crítico/contra-ataque (+combo); GOOD = bloqueio ~50% (combo preservado);
#   ERRO = dano cheio. band_fractions() devolve as frações 0..1 para a bolha e o TimingSystem.
const PERFECT_HALF_SPAN := 0.09     # faixa perfeita = ±0.09s (~0.18s de largura)
const GOOD_HALF_SPAN := 0.20        # faixa GOOD = ±0.20s (flanco GOOD ~0.11s de cada lado)
const LATE_GRACE := 0.04            # tolerância SÓ no lado tardio (lag de toque/web)
const ACTION_TAIL := 0.06           # rabo de colapso após a banda
const MIN_ACTION_DURATION := 0.55   # piso de D p/ a banda absoluta sempre caber
const GOOD_BLOCK_MULT := 0.5        # GOOD na defesa bloqueia ~50% do dano

## Frações 0..1 das faixas de acerto dentro de uma janela de `duration` segundos. A precisão
## (largura perfect/good em segundos) é constante; o que varia entre fases é o lead-in, pois D
## muda. Default seguro: chamadas que ignoram a faixa GOOD (Cortejo/hold) continuam binárias.
static func band_fractions(duration: float) -> Dictionary:
	var d: float = maxf(duration, MIN_ACTION_DURATION)
	# Centro = o mais tarde possível deixando o flanco GOOD + rabo caberem no fim da janela.
	var center: float = clampf(d - ACTION_TAIL - GOOD_HALF_SPAN, GOOD_HALF_SPAN, d)
	return {
		"perfect_start": clampf((center - PERFECT_HALF_SPAN) / d, 0.0, 1.0),
		"perfect_end":   clampf((center + PERFECT_HALF_SPAN + LATE_GRACE) / d, 0.0, 1.0),
		"good_start":    clampf((center - GOOD_HALF_SPAN) / d, 0.0, 1.0),
		"good_end":      clampf((center + GOOD_HALF_SPAN + LATE_GRACE) / d, 0.0, 1.0),
	}

# ─── Escada de combo (gatilho de recompensa) ───────
# Quanto maior o streak de perfeitos, mais o combate "estoura": shake, hit-stop,
# zoom e pitch da recompensa sobem juntos. Escala SÓ parâmetros já baratos (tween,
# frames, pitch, duck) — NUNCA contagem de partículas/nós (orçamento 60fps Android).
# O streak começa no passo 0 (1º perfeito) e satura em COMBO_MAX_STEP.
const COMBO_MAX_STEP := 5
const COMBO_SHAKE_BONUS_PER_STEP := 0.12   # +12% de amplitude de shake por passo
const COMBO_HITSTOP_BONUS_AT_MAX := 2      # +N frames de hit-stop no topo do streak
const COMBO_PITCH_STEP := 0.04             # +4% de pitch na camada de recompensa por passo
const COMBO_ZOOM_BONUS_PER_STEP := 0.04    # aproximação extra no killing-blow por passo

## Multiplicador de intensidade (>= 1.0) para o passo de combo. Satura no teto.
static func combo_scale(step: int) -> float:
	return 1.0 + clampi(step, 0, COMBO_MAX_STEP) * COMBO_SHAKE_BONUS_PER_STEP

## Bônus inteiro de frames de hit-stop, proporcional ao passo (0 no início, máx no teto).
static func combo_hitstop_bonus(step: int) -> int:
	return int(round(float(clampi(step, 0, COMBO_MAX_STEP)) / float(COMBO_MAX_STEP) * COMBO_HITSTOP_BONUS_AT_MAX))

## Janela de acao real depois do tuning por fase. O bonus de touch e aplicado
## sempre — e a janela padrao unica para todas as plataformas.
static func timing_window_for_phase(base: float, phase: int) -> float:
	var window: float = base
	match phase:
		5:
			window = maxf(base - PHASE5_TIMING_REDUCTION, TIMING_WINDOW_MIN)
		4:
			window = maxf(base - PHASE4_TIMING_REDUCTION, TIMING_WINDOW_MIN)
		3:
			window = maxf(base - PHASE3_TIMING_REDUCTION, TIMING_WINDOW_MIN)
		2:
			window = maxf(base - PHASE2_TIMING_REDUCTION, TIMING_WINDOW_MIN)
	window += TOUCH_TIMING_WINDOW_BONUS
	return window

# ─── Cortejo dos Encantados (O Chamado — SEGURAR → SOLTAR) ───────
# Terceiro tipo de ataque da Caipora. FONTE DA MECÂNICA: docs/PRD-cortejo-o-chamado.md
# (4ª forma). O jogador SEGURA ui_up: um medidor enche e os espíritos LIBERTADOS
# (MetaProgression.freed_bosses, teto CORTEJO_MAX_LINKS) coalescem um a um; SOLTAR na
# banda dourada → BARRAGEM completa + FEVER (crítico no último). Reusa o modelo 3-tier
# do combate: banda = PERFEITO, ombro = GOOD (barragem sem crit), cedo = FRACO (barragem
# parcial), segurar demais = QUEIMA (contra-ataque). Disparado por roll no turno, MESMA
# chance do ataque duplo. Motor: arena_manager._start_cortejo_turn reusa o modo hold do
# TimingSystem (open_window(..., hold=true, good_start, good_end) + window_progress()).
const CORTEJO_CHANCE: float = TIMING_DOUBLE_CHANCE  # = 0.30, espelha o duplo (pedido)
const CORTEJO_MAX_LINKS: int = 4            # teto = encantados libertáveis (P1–P4)
const CORTEJO_LINK_HITS: int = 2            # hits de dano por espírito na barragem
# Cada hit da barragem é FIXO em 1 (não escala com o dano da Caipora nem com crit): a
# força do Chamado vem do NÚMERO de hits (espíritos × LINK_HITS), não da magnitude por
# golpe. Mantém a fonte numérica única do PRD-economia-v2.
const CORTEJO_HIT_DAMAGE: float = 1.0
# Custo do erro: multiplicador do contra-ataque (1.0 = um golpe inteiro do inimigo).
# Usado na QUEIMA (overcharge) — ver _cortejo_whiff.
const CORTEJO_MISS_COUNTER_MULT: float = 1.0

# ─── O Chamado: carga (SEGURAR → SOLTAR) — frações de CHAMADO_CHARGE_SEC ───────
# O medidor enche de 0→1 em CHAMADO_CHARGE_SEC enquanto ui_up está pressionado. A FASE
# NÃO encurta a carga (é promessa tátil estável; a dificuldade vem de acertar o release).
# Release: [GOOD_START, RELEASE_START) = GOOD (barragem, sem crit); [RELEASE_START,
# RELEASE_END] = PERFEITO/FEVER; < GOOD_START = FRACO (parcial); > RELEASE_END ou timeout
# em 100% = QUEIMA (contra-ataque). Banda larga de propósito (perdão) — ver PRD §3.
const CHAMADO_CHARGE_SEC: float = 1.10      # 0→100% segurando ui_up
const CHAMADO_GOOD_START: float = 0.66      # início do ombro GOOD (fração)
const CHAMADO_RELEASE_START: float = 0.80   # início da banda dourada PERFEITO (fração)
const CHAMADO_RELEASE_END: float = 0.94     # fim da banda (largura ~0.14 = perdão)

## Um MISS de hold do Chamado é FRACO (soltou CEDO, antes do ombro → barragem parcial,
## sem punição) quando o progresso < GOOD_START; senão é QUEIMA (segurou além da banda
## ou timeout → contra-ataque). Seam puro/testável lido pelo arena após o MISS.
static func chamado_miss_is_weak(progress: float) -> bool:
	return progress < CHAMADO_GOOD_START

## Nº de espíritos numa barragem PARCIAL (FRACO): proporcional à fração carregada no
## release, mínimo 1, teto n. Soltar quase no ombro já traz quase todos (recompensa o
## "quase certo cedo"); soltar no início traz 1.
static func chamado_partial_count(n: int, progress: float) -> int:
	if n <= 0:
		return 0
	return clampi(int(ceil(float(n) * progress / CHAMADO_RELEASE_START)), 1, n)

# Ritmo da barragem: espaçado DE PROPÓSITO para a leitura (cada espírito e cada hit
# lê individualmente, não vira borrão). Só timing/hit-stop — nada de partículas extras.
const CORTEJO_SPIRIT_TELEGRAPH: float = 0.12   # antecipação antes do espírito investir
const CORTEJO_HIT_GAP: float = 0.14            # intervalo entre hits do mesmo espírito
const CORTEJO_SPIRIT_GAP: float = 0.22         # intervalo entre espíritos da corrente

# ─── Golpes nomeados da Caipora (PRD docs/PRD-moves-nomeados.md) ────────────
# Poucos e fixos (a Caipora não tem catálogo de .tres): nome + som (sfx/<audio>.wav,
# via SfxSystem.play_named) + vfx (FeedbackSystem._VFX_BY_ID). audio "" = sem som
# próprio (Cortejo já soa pelo Batuque/play_cortejo_*). Espelha os mv_* do gen_sfx.
const CAIPORA_MOVE_NORMAL := {"name_key": &"move.caipora.normal", "audio": "mv_garra_rubra", "vfx": "garra_rubra"}
const CAIPORA_MOVE_DOUBLE := {"name_key": &"move.caipora.double", "audio": "mv_acoite_cipo", "vfx": "acoite_cipo"}
const CAIPORA_MOVE_CORTEJO := {"name_key": &"move.caipora.cortejo", "audio": "", "vfx": "batuque_cortejo"}

## Espíritos da barragem a partir das fases libertadas: ordenadas e cortadas no teto.
## Seam puro/testável: a arena lê isto para a barragem e para o cálculo de dano.
static func cortejo_spirits_for(freed: Array[int]) -> Array[int]:
	var ordered: Array[int] = freed.duplicate()
	ordered.sort()
	if ordered.size() > CORTEJO_MAX_LINKS:
		ordered.resize(CORTEJO_MAX_LINKS)
	return ordered

# ─── Audio ─────────────────────────────────────────
# Passo bem abaixo dos SFX de combate: presença tátil, nunca spam. O asset é
# normalizado pelo fiscal (check_audio); o "baixo" vive no play, não no arquivo.
const STEP_VOLUME_DB := -10.0

# ─── Damage ────────────────────────────────────────
const DAMAGE_BASE := 1
const DAMAGE_CRIT_MULTIPLIER := 1.0
const DAMAGE_COUNTER_MULTIPLIER := 1.0

# ─── Health ────────────────────────────────────────
const FIRE_TILE_DAMAGE := 2

# HP/dano de INIMIGO (comuns e bosses) e o bônus de dano por fase vivem na fonte
# única EnemyStats (scripts/utils/enemy_stats.gd). NÃO duplique aqui.
# O dano da Caipora não escala por fase: ele vem da trilha Fúria/CHAMA. A fase
# endurece inimigos, janelas e padrões; upgrades são a fonte legível de poder.
# Ver docs/PRD-economia-v2.md §7.
const CAIPORA_MAX_HEALTH := 2

## Dano-base de CADA golpe da Caipora. Fase não soma dano; Fúria/CHAMA somam por cima.
static func caipora_base_damage_for_phase(_phase: int) -> int:
	return DAMAGE_BASE

# ─── Economia: recompensas de combate (PRD-economia-v2) ──
# Snowball in-run pela metade: kill comum dá meio HP máx. (materializa +1 coração a cada
# 2 kills, via acúmulo em GameState.caipora_max_hp); boss dá +1 HP máx. como marco.
const COMMON_KILL_HP_GROWTH := 0.5
const BOSS_KILL_HP_GROWTH := 1.0
# Fragmentos inteiros, escalando com a profundidade (chave 1..4 = fase).
const COMMON_FRAGMENT_REWARD := { 1: 1, 2: 2, 3: 3, 4: 4, 5: 5 }
const BOSS_FRAGMENT_BOUNTY := { 1: 3, 2: 5, 3: 8, 4: 12, 5: 20 }

# ─── Materiais compartilhados ──────────────────────
# Fonte ÚNICA do blend aditivo (glow). CanvasItemMaterial.new() idênticos por
# emissor quebram o batching do Compatibility e alocam à toa — todo glow do
# jogo referencia ESTE recurso (PLANO-performance-60fps G9).
const ADDITIVE_MATERIAL: CanvasItemMaterial = preload("res://resources/materials/additive_glow.tres")

# ─── Actor contrast (shadow + front-light + outline) ───
const SHADOW_OVAL_PATH := "res://assets/sprites/shadow_oval.png"
const COLOR_ACTOR_FRONT_LIGHT := Color(0.92, 0.84, 0.68) # osso quente contra breu
const COLOR_ACTOR_SHADOW := Color(0.0, 0.0, 0.0, 0.86)
const COLOR_ACTOR_OUTLINE := Color(0.92, 0.78, 0.52, 0.5)
const ACTOR_FRONT_LIGHT_ENERGY := 1.0
const ACTOR_FRONT_LIGHT_SCALE := 2.0
const ACTOR_OUTLINE_THICKNESS := 1.0
# Compatibilidade temporária para scripts antigos enquanto o contraste migra
# para ActorContrast.
const COLOR_ENEMY_FRONT_LIGHT := COLOR_ACTOR_FRONT_LIGHT
const COLOR_ENEMY_SHADOW := COLOR_ACTOR_SHADOW
const ENEMY_FRONT_LIGHT_ENERGY := ACTOR_FRONT_LIGHT_ENERGY
const ENEMY_FRONT_LIGHT_SCALE := ACTOR_FRONT_LIGHT_SCALE

# ─── Colors (Horror Folk Palette) ──────────────────
# Fonte ÚNICA de cor do jogo. Qualquer Color() novo deve referenciar/derivar daqui —
# não inventar tons soltos nos scripts. (doom_fire.gd é a única exceção: gradiente próprio.)
#
# Tons-base (paleta amazônica de horror folk):
const COLOR_NIGHT := Color("#0d1117")    # fundo / noite
const COLOR_ARENA_BG := Color("#1a0f0f") # fundo da arena
const COLOR_EARTH := Color("#3d1f1f")    # terra / trilha
const COLOR_MOSS := Color("#1a2f1a")     # folhagem / musgo
const COLOR_BLOOD := Color("#8b0000")    # sangue / dano
const COLOR_AMBER := Color("#ff6b00")    # destaque / fogo / cue
const COLOR_GOOD := COLOR_AMBER          # faixa GOOD (bloqueio parcial) — alias semântico
const COLOR_TEXT := Color("#c9d1d9")     # texto / branco sujo
const COLOR_TEXT_DIM := Color(0.494, 0.514, 0.541) # texto secundário: versão, rodapé, legendas

# Vida (ícones): ativo usa COLOR_BLOOD/COLOR_AMBER; "vazio" = tom apagado translúcido.
const COLOR_BLOOD_EMPTY := Color(0.25, 0.04, 0.04, 0.35)
const COLOR_AMBER_EMPTY := Color(0.3, 0.18, 0.02, 0.35)

# Entidades no mapa (encantado/maligno → roxo).
const COLOR_ENEMY_TINT := Color(0.7, 0.5, 0.9, 1.0)   # criatura comum (modulate)
const COLOR_BOSS_TINT := Color(0.08, 0.0, 0.14, 1.0)  # boss caçador amaldiçoado (modulate)
const COLOR_AURA_BOSS := Color(0.18, 0.0, 0.28, 0.75) # aura de partículas do boss
const COLOR_EXIT := Color(1.0, 0.42, 0.0, 0.85)       # marcador de saída (âmbar)

# Fogo procedural (fogueira do mapa) — gradiente quente.
const COLOR_FIRE_GLOW := Color(0.55, 0.08, 0.0, 0.35)
const COLOR_FIRE_HOT := Color(1.00, 0.55, 0.05)
const COLOR_FIRE_MID := Color(0.85, 0.30, 0.0)
const COLOR_FIRE_LOW := Color(0.75, 0.20, 0.0)

# Juba/CHAMA da protagonista (= gen_caipora.py / docs/CONCEITO-protagonista.md).
# Identidade do D-pad de combate: garra laranja serrilhada sobre vazio preto;
# o press flasheia nos tons de CHAMA.
const COLOR_JUBA := Color("#ff4500")
const COLOR_JUBA_DARK := Color("#8b2a00")
const COLOR_CHAMA_HOT := Color("#ffb032")
const COLOR_CHAMA_CORE := Color("#ffefb2")

# Cristal do cajado da Caipora (acento frio da protagonista).
const COLOR_CRYSTAL := Color("#1da75c")                  # esmeralda (= CR do gen_caipora.py)
const COLOR_CRYSTAL_GLOW := Color(0.55, 1.7, 0.9, 1.0)   # overbright p/ glow aditivo
# Erva da Vida: verde neon FORTE (overbright p/ glow aditivo) — pickup de HP máx. por fase.
# Exceção deliberada à regra de marca (verde = acento mínimo do cristal); escolha do dono.
const COLOR_HERB_GLOW := Color(0.35, 1.9, 0.55, 1.0)

# Materiais de props/decoração (derivados intencionais da paleta).
const COLOR_GOLD := Color(0.92, 0.78, 0.12)
const COLOR_GOLD_DARK := Color(0.55, 0.42, 0.04)
const COLOR_AURA_BUSTER_DARK := Color(0.45, 0.30, 0.04, 0.0)  # fim do ramp da aura (fade)
const COLOR_SMOKE_DARK := Color(0.09, 0.07, 0.05, 0.42)        # fumaça murky do tronco
const COLOR_WOOD := Color(0.32, 0.17, 0.04)
const COLOR_WOOD_DARK := Color(0.16, 0.07, 0.01)
const COLOR_METAL := Color(0.48, 0.38, 0.10)
const COLOR_BARK := Color(0.18, 0.11, 0.05)
const COLOR_BARK_DARK := Color(0.10, 0.06, 0.02)
const COLOR_BONE := Color(0.78, 0.74, 0.62)
const COLOR_BONE_HOLLOW := Color(0.12, 0.10, 0.08)
const COLOR_STONE := Color(0.34, 0.34, 0.38)
const COLOR_STONE_DARK := Color(0.20, 0.20, 0.24)
const COLOR_MOSS_DECO := Color(0.13, 0.24, 0.10, 0.7)
const COLOR_MOSS_DECO_DARK := Color(0.08, 0.16, 0.06, 0.7)
const COLOR_BLOOD_POOL := Color(0.42, 0.02, 0.02, 0.75)
const COLOR_BLOOD_POOL_DARK := Color(0.24, 0.0, 0.0, 0.8)
const COLOR_PENTAGRAM := Color(0.50, 0.0, 0.0)
# Novas decorações da floresta (Fase 1).
const COLOR_MUSHROOM := Color(0.78, 0.70, 0.64, 0.95)      # chapéu pálido/doentio
const COLOR_MUSHROOM_GLOW := Color(0.55, 0.85, 0.70, 0.9)  # bioluminescência encantada
const COLOR_WATER := Color(0.10, 0.16, 0.20, 0.8)          # poça refletindo a noite
const COLOR_WATER_LIGHT := Color(0.20, 0.30, 0.36, 0.7)    # brilho da superfície

# Cues de combate (telegraph/bolhas). Valores >1 são overbright p/ glow intencional.
const COLOR_TELEGRAPH_ENEMY := Color(1.4, 0.4, 0.4)     # wind-up da criatura (vermelho)
const COLOR_TELEGRAPH_ENEMY_ALT := Color(1.4, 0.9, 0.2) # flash de ataque duplo (âmbar)
const COLOR_TELEGRAPH_BOSS := Color(0.5, 0.05, 1.0)     # wind-up do boss (roxo)
const COLOR_BUBBLE_BOSS := Color(0.55, 0.05, 0.95, 1.0) # bolha de timing do boss
const COLOR_TELEGRAPH_BOITATA_WHITE := Color(2.0, 2.0, 2.0) # especial branco do Boitatá (overbright)
const COLOR_AURA_BOITATA := Color(1.0, 0.45, 0.05, 0.75)    # aura de fogo do Boitatá
const COLOR_TELEGRAPH_CURUPIRA := Color(0.1, 1.5, 0.35)     # telegraph do Curupira (verde-mata overbright)
const COLOR_AURA_CURUPIRA := Color(0.0, 0.28, 0.06, 0.72)   # aura do Curupira (verde profundo da floresta)
const COLOR_TELEGRAPH_SACI := Color(2.0, 0.7, 0.15)         # telegraph do Saci (fogo overbright)
const COLOR_AURA_SACI := Color(0.35, 0.10, 0.02, 0.75)      # aura do Saci (brasa escura, casa consumida pelo fogo)
const COLOR_TELEGRAPH_MULA := Color(2.0, 0.55, 0.1)         # telegraph da Mula sem Cabeça (jato de fogo overbright)
const COLOR_AURA_MULA := Color(0.55, 0.12, 0.02, 0.72)      # aura de brasas da Mula (fogo escuro subindo do toco)
const COLOR_TELEGRAPH_JESUITA := Color(1.7, 1.4, 0.6)       # telegraph do Jesuíta (ouro de incenso corrompido, overbright)
const COLOR_AURA_JESUITA := Color(0.42, 0.34, 0.10, 0.75)   # aura do Jesuíta (fumaça de incenso podre, dourado-acinzentado)
const COLOR_BAPTISM_TINT := Color(0.80, 0.90, 1.06)         # mini-boss convertido: pele fria de batismo forçado (azulado overbright)
const COLOR_BAPTISM_DROP := Color(0.75, 0.88, 1.0, 0.85)    # pingos de água benta escorrendo do convertido

# Cores de diálogo (speaker labels nos pre-boss dialogues).
const COLOR_DIALOGUE_CAIPORA  := Color(0.55, 0.90, 0.60, 1.0)  # voz da Caipora (verde floresta)
const COLOR_DIALOGUE_BOITATA  := Color(1.0,  0.42, 0.0,  1.0)  # voz do Boitatá (fogo)
const COLOR_DIALOGUE_CURUPIRA := Color(0.1,  0.85, 0.30, 1.0)  # voz do Curupira (verde mata)
const COLOR_DIALOGUE_SACI     := Color(1.0,  0.55, 0.12, 1.0)  # voz do Saci (fogo)
const COLOR_DIALOGUE_MULA     := Color(1.0,  0.50, 0.10, 1.0)  # voz da Mula sem Cabeça (fogo)
const COLOR_DIALOGUE_JESUITA  := Color(0.92, 0.82, 0.45, 1.0)  # voz do Jesuíta (ouro litúrgico corrompido)

# Partículas de feedback de combate (>1 = overbright p/ glow aditivo intencional).
const COLOR_PARTICLE_SPARK := Color(0.6, 1.6, 0.9, 1.0)   # faísca de crítico (cristal do cajado)
const COLOR_PARTICLE_DODGE := Color(0.9, 0.95, 1.0, 0.95) # flash de esquiva (azul-claro)
const COLOR_PARTICLE_FAIL := Color(0.20, 0.18, 0.22, 0.9) # estilhaço de erro (cinza-fumaça morto, deriva de COLOR_STONE_DARK)

# ─── Ganho de cor dos feedbacks por fase ───────────
# Algumas fases têm um CanvasModulate de arena muito escuro (clima), que multiplica
# TODOS os canvas items da layer 0 — inclusive timing bubble, rótulos, VFX e bursts —
# tornando os feedbacks de timing ilegíveis. Para clarear SÓ os feedbacks (sem mexer
# no modulate/fundo), pré-multiplicamos a cor deles por este ganho overbright: o
# modulate da fase reduz de volta e o feedback renderiza na sua cor autoral.
# Fase 3 (Curupira): recíproco do CanvasModulate de scenes/arena/arena_phase3.tscn
# Color(0.18, 0.45, 0.22) → se aquele modulate mudar, atualize este valor.
# Fase 4 (Saci): recíproco do CanvasModulate de scenes/arena/arena_phase4.tscn
# Color(0.4, 0.16, 0.07) — a casa em chamas escurece tudo na layer 0 e afogava
# as setas de feedback em laranja/sangue. O ganho restaura a cor autoral (legível).
const FEEDBACK_GAIN_BY_PHASE: Dictionary = {
	3: Color(1.0 / 0.18, 1.0 / 0.45, 1.0 / 0.22),
	4: Color(1.0 / 0.4, 1.0 / 0.16, 1.0 / 0.07),
}

## Ganho de cor dos feedbacks para a fase. Identidade (1,1,1) quando a fase não
## tem entrada — fases sem escurecimento agressivo ficam inalteradas.
static func feedback_gain_for_phase(phase: int) -> Color:
	return FEEDBACK_GAIN_BY_PHASE.get(phase, Color(1, 1, 1))

# ─── UI Design Tokens (escala de espaçamento / tipografia) ──
# Padronização AAA: telas e HUD consomem estes tokens, nunca números soltos.
const SPACE_XS := 8
const SPACE_SM := 16
const SPACE_MD := 24
const SPACE_LG := 40
const SPACE_XL := 64

const FONT_SM := 12
const FONT_MD := 18
const FONT_LG := 28
const FONT_TITLE := 48

# Direção de arte da UI (scenes/AGENTS.md): cantos retos, bordas duras — sem arredondar.
const UI_CORNER_RADIUS := 0
const UI_BORDER_WIDTH := 2
const UI_PADDING_H := 20  # padding horizontal interno de botões/painéis
const UI_PADDING_V := 12  # padding vertical interno

# ─── Camadas canônicas de UI (z-order único; substitui os layers soltos por tela) ───
# Regra: nada de leitura crítica abaixo de LAYER_HUD (o Atmosphere vive em LAYER_ATMOSPHERE).
const LAYER_WORLD := 0
const LAYER_WORLD_BEACON := 9
const LAYER_ATMOSPHERE := 50
const LAYER_HUD := 52
const LAYER_DPAD := 55
const LAYER_STORY := 58
const LAYER_OVERLAY := 60
const LAYER_TRANSITION := 100
const LAYER_DEBUG := 127

# ─── Escala tátil do HUD: 2x em telefone-retrato (política única entre telas) ───
const HUD_TOUCH_SCALE := 2.0
static func hud_touch_scale(vp: Vector2) -> float:
	return HUD_TOUCH_SCALE if is_portrait(vp) else 1.0

# ─── Safe-area única (recuos lateral/topo em px de canvas; substitui as 3 fórmulas) ───
## Deriva do lado curto do viewport. Retorna Vector2(lateral, topo).
static func safe_insets(vp: Vector2) -> Vector2:
	var s := minf(vp.x, vp.y)
	return Vector2(clampf(s * 0.055, 40.0, 80.0), clampf(s * 0.05, 28.0, 64.0))

# ─── Chrome autoral (placa serrilhada + garra + movimento — vocabulário do BrandFrame) ───
const CHROME_SAW_STEP := 18.0
const CHROME_SAW_DEPTH := 8.0
const CHROME_CLAW_INSET := 6.0
const CHROME_PRESS_SCALE := 1.04  # "bote" no press (escala, não afundamento)
const CHROME_PRESS_SECS := 0.08   # volta do bote
const CHROME_BREATH_SECS := 1.3   # meio-ciclo do respiro da brasa (elementos-herói)

# ─── Fase 2 ────────────────────────────────────────
# Toda janela de ação (ataque e defesa) encurta 0.1s — a floresta fica mais
# impiedosa. O bônus de dano de inimigo por fase vive em EnemyStats.PHASE_DAMAGE_BONUS.
const PHASE2_TIMING_REDUCTION := 0.1

# ─── Fase 3 ────────────────────────────────────────
const PHASE3_TIMING_REDUCTION := 0.15

# ─── Fase 4 ────────────────────────────────────────
# A casa arde. A janela de ação encurta ainda mais que a Fase 3 (0.15 + 0.15 =
# 0.30 "mais rápido"). O bônus de dano de inimigo por fase vive em EnemyStats.
const PHASE4_TIMING_REDUCTION := 0.30

# ─── Fase 5 (A Igreja na Mata) ─────────────────────
# A fase FINAL. Rebalanceada em 2026-06: a janela de ação encurta o MESMO que a
# Fase 4 (0.30, travado no piso de 0.2s em _phase_window). O bônus de dano de
# inimigo da Fase 5 (-1, com piso em arena_manager) vive em EnemyStats.
const PHASE5_TIMING_REDUCTION := 0.30

# ─── Physics Layers ────────────────────────────────
const LAYER_PLAYER := 1
const LAYER_ENEMY := 2
const LAYER_WALL := 3
const LAYER_TRIGGER := 4
