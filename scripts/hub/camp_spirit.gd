class_name CampSpirit
extends Node2D

const ActorContrast := preload("res://scripts/entities/actor_contrast.gd")

# Presença de um encantado libertado em repouso no acampamento (Santuário dos
# Encantados — PRD-santuario-dos-encantados §4.3). NÃO é mascote: é uma entidade
# antiga descansando — idle mais lento que o combate, aura calma na cor canônica do
# boss e leitura abatida, para a Caipora seguir dona da tela (lei de marca). Anda
# ATERRADO (sombra de chão + quique de passo, igual às criaturas da exploração), não
# pairando. Montado por código (gotcha #7) e dirigido por DEFS (data-driven, uma
# entrada por encantado). O Jesuíta (P5) não é encantado: não tem entrada aqui.
#
# Contrato: add_child() ANTES de setup() — a aura e a sombra usam a árvore.

# ─── Constants ─────────────────────────────────────
# Repouso: leitura levemente abatida/fria (a dominância da Caipora vem dela estar no
# centro, iluminada — não de apagar os espíritos na mata escura) e idle lento.
const REST_MODULATE := Color(0.92, 0.92, 0.96)
const REST_SPEED: float = 0.6
# Sombra de chão: âncora visual (mesmo sistema da exploração) pra ler aterrado, não
# pairando. A baseline é a do chefe de mapa (sprite ~48px); aqui os frames premium
# renderizam ~2× isso, então a escala é por porte real, e o FUDGE afina o padding
# transparente da moldura.
const SHADOW_BASE := Vector2(0.95, 0.34)
const SHADOW_FUDGE: float = 0.7
const SHADOW_BASELINE_PX: float = 48.0
# Quique de passo: sem walk cycle nos frames, o pulinho vertical É a leitura de passo.
# Sincronizado à distância andada (cadência), assenta no chão na pausa.
const BOB_HEIGHT: float = 5.0
const BOB_RATE: float = 0.20
const BOB_SETTLE: float = 24.0
# Aura calma: a sombra de combate virou cinza de pira — densidade/velocidade mínimas.
const AURA_AMOUNT: int = 6
const AURA_LIFETIME: float = 2.2
const AURA_RADIUS: float = 22.0
const AURA_RISE: float = -14.0
# Luz própria: poça baixa na cor da aura — o espírito LÊ na mata escura sem perder o
# repouso abatido (a leitura vem da luz, não de clarear o sprite). Em HD a poça
# sobe de energia e pulsa (dessincronizada por fase); a coroa orbital abraça o corpo.
const GLOW_ENERGY: float = 0.95
const GLOW_ENERGY_HD: float = 1.35
const GLOW_SCALE: float = 1.1
const GLOW_WHITEN: float = 0.5
const CROWN_RADIUS: float = 26.0
# Perambulação livre pela clareira (sem colisão/interação — entidade etérea em repouso).
# Lento e à deriva, com pausas longas: lê como descanso vagando, não fuga.
const WANDER_SPEED: float = 14.0   # px/s — bem mais lento que o combate
const WANDER_PAUSE_MIN: float = 1.4
const WANDER_PAUSE_MAX: float = 3.6
const WANDER_ARRIVE_DIST: float = 4.0
const WANDER_INSET: float = 16.0   # margem pra borda da clareira (não encosta na mata)

# Identidade visual de cada espírito: os MESMOS frames premium da arena, em escala de
# set piece (2–4 tiles), com a cor de aura canônica da fase. `flip` vira o encantado
# para dentro da clareira (Mula ao norte olha pro fogo; Saci a sudeste olha pra oeste).
# A Mula v3 já encara a ESQUERDA no PNG (lei do CONCEITO), então fica sem flip.
const DEFS := {
	1: { "frames": "res://assets/sprites/mula_sprite_frames.tres",
		"scale": 0.55, "flip": false, "aura": Constants.COLOR_AURA_MULA },
	2: { "frames": "res://assets/sprites/boitata_sprite_frames.tres",
		"scale": 0.7, "flip": true, "aura": Constants.COLOR_AURA_BOITATA },
	3: { "frames": "res://assets/sprites/curupira_sprite_frames.tres",
		"scale": 0.8, "flip": false, "aura": Constants.COLOR_AURA_CURUPIRA },
	4: { "frames": "res://assets/sprites/saci_sprite_frames.tres",
		"scale": 0.8, "flip": true, "aura": Constants.COLOR_AURA_SACI },
}

# ─── State ─────────────────────────────────────────
var phase: int = 0
var _sprite: AnimatedSprite2D
# Perambulação (ligada por enable_wander; setup() sozinho deixa o espírito parado).
var _wandering: bool = false
var _roam_bounds: Rect2
var _roam_target: Vector2
var _pause_timer: float = 0.0
var _walk_phase: float = 0.0

# ─── Public API ────────────────────────────────────
## Monta a presença do encantado da fase. Retorna false para fase sem espírito
## (Jesuíta/inválida) — o caller descarta o nó.
func setup(spirit_phase: int) -> bool:
	if not DEFS.has(spirit_phase):
		return false
	phase = spirit_phase
	var def: Dictionary = DEFS[spirit_phase]
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load(def["frames"])
	_sprite.animation = &"idle"
	_sprite.speed_scale = REST_SPEED
	_sprite.flip_h = def["flip"]
	_sprite.scale = Vector2(def["scale"], def["scale"])
	_sprite.modulate = REST_MODULATE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.play()
	# Risco de giz: o mesmo contorno da Caipora/exploração — sem ele o espírito
	# some na mata escura (o glow lê a POSIÇÃO, o risco lê a SILHUETA).
	ActorContrast.apply_outline(_sprite)
	_spawn_calm_aura(def["aura"])
	_spawn_glow(def["aura"])
	_spawn_shadow(def["scale"])
	# Modo HD: o encantado vira set piece de verdade — contorno de brasas + halo
	# na cor canônica (SEM segunda luz: o glow próprio acima já ilumina) e coroa
	# orbital de raio largo. No-ops sem HD.
	ParticleRim.attach_to(_sprite, def["aura"], 1.0, Color.TRANSPARENT, false, true)
	ParticleRim.attach_crown(self, def["aura"], CROWN_RADIUS)
	return true

## Liga a perambulação livre dentro de `bounds` (a clareira). O espírito passa a derivar
## de ponto em ponto, sem colisão, virando o sprite pela direção. Chamar DEPOIS de setup().
func enable_wander(bounds: Rect2) -> void:
	_roam_bounds = bounds.grow(-WANDER_INSET)
	_wandering = true
	_roam_target = _pick_target()
	set_process(true)

# ─── Process: deriva lenta com pausas + quique de passo ─
func _process(delta: float) -> void:
	if not _wandering:
		return
	if _pause_timer > 0.0:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_roam_target = _pick_target()
		_settle(delta)
		return
	var to := _roam_target - position
	if to.length() <= WANDER_ARRIVE_DIST:
		_pause_timer = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
		_settle(delta)
		return
	var step := to.normalized() * WANDER_SPEED * delta
	position += step
	# Vira o sprite pela direção do passo (mantém o último rumo nos passos verticais).
	if absf(step.x) > 0.01:
		_sprite.flip_h = step.x < 0.0
	# Quique sincronizado à distância andada: cadência de passo (só pra cima). Mexe só
	# no sprite — a sombra (filha de self) fica ancorada no chão.
	_walk_phase += step.length() * BOB_RATE
	_sprite.position.y = -absf(sin(_walk_phase)) * BOB_HEIGHT

# Assenta o sprite no chão na pausa/chegada (desce o quique, não congela no ar).
func _settle(delta: float) -> void:
	_sprite.position.y = move_toward(_sprite.position.y, 0.0, BOB_SETTLE * delta)

# ─── Private ───────────────────────────────────────
func _pick_target() -> Vector2:
	return Vector2(
		randf_range(_roam_bounds.position.x, _roam_bounds.end.x),
		randf_range(_roam_bounds.position.y, _roam_bounds.end.y),
	)

func _spawn_calm_aura(color: Color) -> void:
	var aura := CPUParticles2D.new()
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	# ambient: dobra em HD (Quality.heavy); modo leve idêntico ao de sempre.
	aura.amount = maxi(2, int(AURA_AMOUNT * Constants.ambient_amount_scale(vp)))
	aura.lifetime = AURA_LIFETIME
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = AURA_RADIUS
	aura.gravity = Vector2(0, AURA_RISE)
	aura.initial_velocity_min = 2.0
	aura.initial_velocity_max = 6.0
	aura.scale_amount_min = 1.0
	aura.scale_amount_max = Quality.pick(2.0, 3.0)
	# Overbright moderado em HD: brilha mais sem perder o repouso abatido.
	aura.color = ParticleRim._overbright(color) if Quality.hd_enabled() else color
	add_child(aura)

func _spawn_glow(color: Color) -> void:
	var glow := ForestLight.make(color.lerp(Color.WHITE, GLOW_WHITEN),
		Quality.pick(GLOW_ENERGY, GLOW_ENERGY_HD), GLOW_SCALE)
	add_child(glow)
	if Quality.hd_enabled():
		# Pulso dessincronizado por espírito (período por fase, receita dos fátuos).
		var period := 1.6 + 0.2 * float(phase)
		var tween := glow.create_tween().set_loops()
		tween.tween_property(glow, "energy", GLOW_ENERGY_HD * 1.15, period) \
			.set_trans(Tween.TRANS_SINE)
		tween.tween_property(glow, "energy", GLOW_ENERGY_HD * 0.75, period) \
			.set_trans(Tween.TRANS_SINE)

# Sombra de chão sob os pés. O sprite é centralizado, então os pés ficam meia-altura
# abaixo da origem; a escala é por porte real (os frames premium são ~2× o chefe de
# mapa que a SHADOW_BASE pressupõe). Filha de self → herda o fade do rito de chegada.
func _spawn_shadow(scale: float) -> void:
	var frame := _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if frame == null:
		return
	var feet_y := frame.get_height() * 0.5 * scale
	var foot_factor := frame.get_height() * scale / SHADOW_BASELINE_PX
	var shadow_scale := SHADOW_BASE * foot_factor * SHADOW_FUDGE
	ActorContrast.add_ground_shadow(self, shadow_scale, Vector2(0.0, feet_y))
