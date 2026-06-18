class_name ChargeBubble
extends Node2D

## Anel de CARGA do Cortejo dos Encantados — irmão visual da TimingBubble (que lê
## taps). Aqui o jogador SEGURA ↑ e o anel enche de 0% a 100% no ritmo do
## HoldTimingSystem; no cheio "estala" (armado), soltar no cheio = landado (estoura
## em luz), soltar cedo/overcharge/timeout = perdido (some em fumaça morta).
## A lógica de carga vive no HoldTimingSystem; este nó só REFLETE o progresso que
## o ArenaManager injeta via set_progress/set_armed/burst_landed/burst_missed.

# ─── Constants ─────────────────────────────────────
const RADIUS: float = TimingBubble.RADIUS_TARGET     # mesmo raio-alvo do tap
const RING_WIDTH: float = 3.0
const BURST_SECS: float = 0.16

const PHASE_IDLE: int = 0
const PHASE_CHARGING: int = 1
const PHASE_BURST: int = 2

# ─── State ─────────────────────────────────────────
var _phase: int = PHASE_IDLE
var _progress: float = 0.0
var _armed: bool = false
var _pulse_t: float = 0.0
var _burst_timer: float = -1.0
var _burst_landed: bool = false
var _burst_radius: float = RADIUS
var _burst_alpha: float = 0.0
var _frozen: bool = false
## Ganho de cor da fase (compensa o CanvasModulate escuro) — ver TimingBubble.
var _color_gain: Color = Color(1, 1, 1)

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if _frozen:
		return
	if _phase == PHASE_BURST:
		_process_burst(delta)
		return
	if _phase != PHASE_CHARGING:
		return
	# Pulso vivo no anel: lento enchendo, rápido (e mais forte) quando armado.
	_pulse_t += delta * (8.0 if _armed else 3.0)
	queue_redraw()

func _process_burst(delta: float) -> void:
	_burst_timer -= delta
	var t: float = 1.0 - clampf(_burst_timer / BURST_SECS, 0.0, 1.0)
	if _burst_landed:
		_burst_radius = lerpf(RADIUS * 0.8, RADIUS * 1.7, t)
		_burst_alpha = lerpf(0.95, 0.0, t)
	else:
		_burst_radius = lerpf(RADIUS * 0.8, RADIUS * 0.3, t)
		_burst_alpha = lerpf(0.8, 0.0, t)
	queue_redraw()
	if _burst_timer <= 0.0:
		_phase = PHASE_IDLE
		visible = false

# ─── Public API ────────────────────────────────────
func show_ring(world_pos: Vector2) -> void:
	position = world_pos
	_phase = PHASE_CHARGING
	_progress = 0.0
	_armed = false
	_pulse_t = 0.0
	_burst_timer = -1.0
	visible = true
	queue_redraw()

func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _phase == PHASE_CHARGING:
		queue_redraw()

func set_armed() -> void:
	_armed = true
	_progress = 1.0
	_pulse_t = 0.0
	if _phase == PHASE_CHARGING:
		queue_redraw()

func burst_landed() -> void:
	_start_burst(true)

func burst_missed() -> void:
	_start_burst(false)

func hide_ring() -> void:
	_phase = PHASE_IDLE
	_burst_timer = -1.0
	visible = false

func set_frozen(value: bool) -> void:
	_frozen = value

func set_color_gain(gain: Color) -> void:
	_color_gain = gain

# ─── Private ───────────────────────────────────────
func _start_burst(landed: bool) -> void:
	_phase = PHASE_BURST
	_burst_landed = landed
	_burst_timer = BURST_SECS
	_burst_radius = RADIUS * 0.8
	_burst_alpha = 0.95 if landed else 0.8
	visible = true
	queue_redraw()

func _draw() -> void:
	if _phase == PHASE_BURST:
		var bc: Color
		if _burst_landed:
			bc = Color(Constants.COLOR_CHAMA_HOT.r, Constants.COLOR_CHAMA_HOT.g, Constants.COLOR_CHAMA_HOT.b, _burst_alpha)
		else:
			bc = Color(Constants.COLOR_PARTICLE_FAIL.r, Constants.COLOR_PARTICLE_FAIL.g, Constants.COLOR_PARTICLE_FAIL.b, _burst_alpha)
		draw_circle(Vector2.ZERO, _burst_radius, _g(bc))
		draw_arc(Vector2.ZERO, _burst_radius, 0.0, TAU, 32, _g(Color(1, 1, 1, _burst_alpha * 0.4)), 1.5)
		return

	if _phase != PHASE_CHARGING:
		return

	# 1. Trilho de fundo (anel escuro) — mostra o quanto falta encher.
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 40, _g(Color(0.08, 0.05, 0.05, 0.55)), RING_WIDTH)

	# 2. Anel de carga: enche do topo, sentido horário. Juba enchendo → âmbar no
	#    cheio, com pulso vivo (a "mão erguida" da Caipora chamando o espírito).
	var fill_color: Color = Constants.COLOR_JUBA
	if _armed:
		var pulse: float = 0.5 + 0.5 * sin(_pulse_t)
		fill_color = Constants.COLOR_AMBER.lerp(Constants.COLOR_CHAMA_HOT, pulse)
	var start: float = -PI * 0.5
	var sweep: float = TAU * _progress
	if sweep > 0.001:
		draw_arc(Vector2.ZERO, RADIUS, start, start + sweep, 48, _g(Color(fill_color.r, fill_color.g, fill_color.b, 0.95)), RING_WIDTH + 1.0)

	# 3. Glifo ↑ pixel-art no centro, opacidade crescendo com a carga.
	var glyph_alpha: float = lerpf(0.4, 1.0, _progress)
	if _armed:
		glyph_alpha = 0.7 + 0.3 * (0.5 + 0.5 * sin(_pulse_t))
	_draw_up_glyph(glyph_alpha, fill_color)

func _draw_up_glyph(alpha: float, color: Color) -> void:
	var grid: int = TimingBubble.ARROW_GRID
	var cell: float = TimingBubble.ARROW_CELL
	var half: float = grid * cell * 0.5
	var origin: Vector2 = Vector2(-half, -half)
	var cs: Vector2 = Vector2.ONE * (cell + 0.5)
	var bright: Color = _g(Color(color.r, color.g, color.b, alpha))
	var dark: Color = _g(Color(Constants.COLOR_JUBA_DARK.r, Constants.COLOR_JUBA_DARK.g, Constants.COLOR_JUBA_DARK.b, alpha * 0.7))
	var outline: Color = Color(0.0, 0.0, 0.0, alpha)
	for r: int in grid:
		var row: String = TimingBubble.ARROW_GLYPH[r]
		for c: int in grid:
			var ch: String = row[c]
			if ch == ".":
				continue
			var col: Color
			match ch:
				"O": col = bright
				"D": col = dark
				_:   col = outline
			draw_rect(Rect2(origin + Vector2(float(c), float(r)) * cell, cs), col, true)

func _g(c: Color) -> Color:
	return Color(c.r * _color_gain.r, c.g * _color_gain.g, c.b * _color_gain.b, c.a)
