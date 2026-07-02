class_name AmbientLife
extends Node2D

## Vida ambiente da floresta amazônica: vaga-lumes flutuando (âmbar, pulsando) e
## insetos rastejando pelo chão — formigas (rápidas, em trilha) e aranhas pequenas
## (lentas, em stop-and-go). PURAMENTE DECORATIVO — não bloqueia, não colide nem
## interage com o jogador. Segue o padrão procedural de map_object.gd (zero assets).
##
## Vaga-lumes usam CPUParticles2D (NUNCA GPUParticles2D: export web é gl_compatibility
## com thread_support=false). Insetos são desenhados via _draw + _process.

# ─── Constants ─────────────────────────────────────
## Insetos simulam/redesenham a 20Hz: a formiga mais rápida anda 9px/s — a
## 20Hz isso é 0,45px por tick, invisível a olho. A 60Hz este nó re-gravava
## ~200 primitivas de _draw por frame (PLANO-performance-60fps §4, G5).
const TICK_INTERVAL: float = 1.0 / 20.0

const FIREFLY_COUNT: int = 60

const ANT_COUNT: int = 14
const ANT_SPEED: float = 9.0
const ANT_REPATH_MIN: float = 1.2   # formiga anda mais reto: repath mais longo
const ANT_REPATH_MAX: float = 3.0
const ANT_BODY := Color(0.14, 0.11, 0.08, 0.95)
const ANT_LEG := Color(0.20, 0.15, 0.11, 0.8)

const SPIDER_COUNT: int = 8
const SPIDER_SPEED: float = 5.0
const SPIDER_RUN_MIN: float = 0.3   # arranca por um tempo curto...
const SPIDER_RUN_MAX: float = 0.7
const SPIDER_PAUSE_MIN: float = 0.6 # ...depois congela (stop-and-go de aranha)
const SPIDER_PAUSE_MAX: float = 1.8
const SPIDER_BODY := Color(0.10, 0.09, 0.10, 0.95)
const SPIDER_LEG := Color(0.16, 0.14, 0.16, 0.85)

enum Kind { ANT, SPIDER }

# ─── State ─────────────────────────────────────────
var _bounds: Rect2 = Rect2(0, 0, 0, 0)
var _insects: Array[Dictionary] = []
var _tick_accum: float = 0.0

# ─── Public API ────────────────────────────────────
## `bounds` é a área (em pixels) onde a vida ambiente pode aparecer.
func setup(bounds: Rect2) -> void:
	_bounds = bounds
	z_index = -1  # insetos no chão, atrás de jogador/inimigos
	_spawn_fireflies()
	_spawn_insects()
	set_process(true)

# ─── Lifecycle ─────────────────────────────────────
func _process(delta: float) -> void:
	_tick_accum += delta
	if _tick_accum < TICK_INTERVAL:
		return
	var step: float = _tick_accum
	_tick_accum = 0.0
	var any_moved: bool = false
	for ins in _insects:
		if ins.kind == Kind.SPIDER:
			_step_spider(ins, step)
		else:
			_step_ant(ins, step)
		# rebate nas bordas (mantém dentro da área)
		if ins.pos.x < _bounds.position.x or ins.pos.x > _bounds.end.x:
			ins.vel.x = -ins.vel.x
		if ins.pos.y < _bounds.position.y or ins.pos.y > _bounds.end.y:
			ins.vel.y = -ins.vel.y
		ins.pos.x = clampf(ins.pos.x, _bounds.position.x, _bounds.end.x)
		ins.pos.y = clampf(ins.pos.y, _bounds.position.y, _bounds.end.y)
		if ins.vel != Vector2.ZERO:
			any_moved = true
	# Aranhas passam a maior parte do tempo congeladas (stop-and-go): com tudo
	# parado, a cena do tick anterior continua válida — sem re-record.
	if any_moved:
		queue_redraw()

# ─── Drawing (insetos) ─────────────────────────────
func _draw() -> void:
	for ins in _insects:
		if ins.kind == Kind.SPIDER:
			_draw_spider(ins)
		else:
			_draw_ant(ins)

# ─── Private helpers: movimento ────────────────────
## Formiga: caminhada contínua, mudando de rumo de tempos em tempos.
func _step_ant(ins: Dictionary, delta: float) -> void:
	ins.timer -= delta
	if ins.timer <= 0.0:
		var ang: float = randf() * TAU
		ins.vel = Vector2(cos(ang), sin(ang)) * ANT_SPEED
		ins.timer = randf_range(ANT_REPATH_MIN, ANT_REPATH_MAX)
	ins.pos += ins.vel * delta

## Aranha: stop-and-go — alterna entre arranque curto e pausa imóvel.
func _step_spider(ins: Dictionary, delta: float) -> void:
	ins.timer -= delta
	if ins.timer <= 0.0:
		if ins.moving:
			ins.moving = false
			ins.vel = Vector2.ZERO
			ins.timer = randf_range(SPIDER_PAUSE_MIN, SPIDER_PAUSE_MAX)
		else:
			ins.moving = true
			var ang: float = randf() * TAU
			ins.heading = Vector2(cos(ang), sin(ang))
			ins.vel = ins.heading * SPIDER_SPEED
			ins.timer = randf_range(SPIDER_RUN_MIN, SPIDER_RUN_MAX)
	ins.pos += ins.vel * delta

# ─── Private helpers: desenho ──────────────────────
func _draw_ant(ins: Dictionary) -> void:
	var p: Vector2 = ins.pos
	var heading: Vector2 = ins.vel.normalized() if ins.vel.length() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-heading.y, heading.x)
	# 3 pares de perninhas
	for k in range(-1, 2):
		var seg: Vector2 = p + heading * (k * 1.6)
		draw_line(seg, seg + perp * 2.2, ANT_LEG, 1.0)
		draw_line(seg, seg - perp * 2.2, ANT_LEG, 1.0)
	# corpo: 3 segmentos (cabeça, tórax, abdômen)
	draw_circle(p + heading * 2.2, 1.1, ANT_BODY)
	draw_circle(p + heading * 0.4, 1.0, ANT_BODY)
	draw_circle(p - heading * 1.6, 1.6, ANT_BODY)

func _draw_spider(ins: Dictionary) -> void:
	var p: Vector2 = ins.pos
	# Aranha mantém orientação na pausa (não gira parada).
	var heading: Vector2 = ins.heading if ins.heading.length() > 0.01 else Vector2.RIGHT
	var perp := Vector2(-heading.y, heading.x)
	# 4 pares de pernas longas e anguladas, espalhadas em torno do corpo.
	for k in range(-1, 3):
		var along: float = (k - 0.5) * 1.3
		var base: Vector2 = p + heading * along
		var tip_out: Vector2 = base + perp * 4.2 + heading * (1.0 if k >= 1 else -1.0)
		var tip_in: Vector2 = base - perp * 4.2 + heading * (1.0 if k >= 1 else -1.0)
		draw_line(base, tip_out, SPIDER_LEG, 1.0)
		draw_line(base, tip_in, SPIDER_LEG, 1.0)
	# corpo: cefalotórax pequeno + abdômen maior
	draw_circle(p + heading * 1.6, 1.2, SPIDER_BODY)
	draw_circle(p - heading * 1.0, 2.1, SPIDER_BODY)

# ─── Private helpers: spawn ────────────────────────
func _spawn_fireflies() -> void:
	var fireflies := CPUParticles2D.new()
	fireflies.z_index = 1  # flutuam acima do chão
	fireflies.position = _bounds.position + _bounds.size * 0.5
	var vp := get_viewport()
	var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
	fireflies.amount = maxi(1, int(float(FIREFLY_COUNT) * ps))  # phone corta pela metade (Frente E)
	fireflies.lifetime = 4.5
	fireflies.preprocess = 4.5  # já espalhados ao iniciar
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(_bounds.size.x * 0.5, _bounds.size.y * 0.5)
	fireflies.direction = Vector2(0, -1)
	fireflies.spread = 180.0
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 3.0
	fireflies.initial_velocity_max = 9.0
	fireflies.scale_amount_min = 1.5
	fireflies.scale_amount_max = 3.2
	fireflies.color_ramp = _firefly_glow_ramp()
	# Blend aditivo: o brilho fura o CanvasModulate da noite (vaga-lume realmente acende).
	fireflies.material = Constants.ADDITIVE_MATERIAL
	add_child(fireflies)

## Gradiente de alpha ao longo da vida: acende e apaga (pulso de vaga-lume).
func _firefly_glow_ramp() -> Gradient:
	var amber := Constants.COLOR_AMBER
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(amber.r, amber.g, amber.b, 0.0))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(amber.r, amber.g, amber.b, 0.0))
	grad.add_point(0.3, Color(amber.r, amber.g, amber.b, 1.0))
	grad.add_point(0.65, Color(1.0, 0.85, 0.4, 0.9))
	return grad

func _spawn_insects() -> void:
	for i in ANT_COUNT:
		_insects.append({
			"kind": Kind.ANT,
			"pos": _random_point(),
			"vel": Vector2.ZERO,
			"heading": Vector2.RIGHT,
			"moving": true,
			"timer": randf_range(0.0, ANT_REPATH_MAX),
		})
	for i in SPIDER_COUNT:
		var ang: float = randf() * TAU
		_insects.append({
			"kind": Kind.SPIDER,
			"pos": _random_point(),
			"vel": Vector2.ZERO,
			"heading": Vector2(cos(ang), sin(ang)),
			"moving": false,
			"timer": randf_range(0.0, SPIDER_PAUSE_MAX),
		})

func _random_point() -> Vector2:
	return Vector2(
		randf_range(_bounds.position.x, _bounds.end.x),
		randf_range(_bounds.position.y, _bounds.end.y)
	)
