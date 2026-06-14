class_name FloatingDpad
extends Control

# Pad direcional flutuante no padrão dos MOBAs mobile AAA (Wild Rift, Mobile Legends,
# Brawl Stars): em repouso, uma base "fantasma" fica visível no canto inferior direito
# como affordance; ao tocar em qualquer ponto da área de jogo, a base se recentra sob
# o dedo e o arrasto além da zona morta pressiona a direção cardinal. Quando o dedo
# passa do raio, a base desliza atrás dele ("follow joystick"), preservando o controle
# relativo em arrastos longos. Ao soltar, some no ponto do toque e reaparece como
# fantasma na pose de repouso.
#
# Este nó é APENAS gesto + visual. A injeção dual de input (Input.action_press +
# Input.parse_input_event) permanece no ControlsHud, dono do contrato com o jogo —
# este widget só emite direction_pressed/direction_released.

signal direction_pressed(action: String)
signal direction_released(action: String)

# ─── Constants ─────────────────────────────────────
# Zona morta pequena: um flick rápido ainda registra o toque de timing no combate
# (a direção é pressionada no instante em que o arrasto cruza a zona morta).
const DEAD_ZONE_FRACTION: float = 0.22
const DEAD_ZONE_MIN: float = 10.0
# Para trocar de EIXO, o novo eixo precisa dominar com folga — evita tremular entre
# horizontal/vertical num arrasto a ~45°. Dentro do mesmo eixo o sinal inverte na
# hora (sequências ←→←→ do Curupira viram um "wiggle" sem levantar o dedo).
const AXIS_SWITCH_BIAS: float = 1.25

const KNOB_RADIUS_FRACTION: float = 0.24
const ARROW_DISTANCE_FRACTION: float = 0.72
const ARROW_SIZE_FRACTION: float = 0.52
const ARROW_ALPHA_IDLE: float = 0.38
const ARROW_ACTIVE_SCALE: float = 1.22
const HIGHLIGHT_DURATION: float = 0.06

const ALPHA_REST: float = 0.4
const ALPHA_ACTIVE: float = 0.9
const POP_DURATION: float = 0.09
const RELEASE_FADE_DURATION: float = 0.14
const REST_FADE_DURATION: float = 0.3

# Garra Tribal — mesmo glifo canônico de CombatArrowButton.
# K = outline preto  O = juba clara  D = juba escura  . = transparente
const ARROW_GLYPH: PackedStringArray = [
	"................",   # 0
	".......KK.......",   # 1 — ponta 2 px
	"......KOOK......",   # 2
	"....KKOOOOKK....",   # 3
	"...KKOOOOOOKK...",   # 4
	"..KKOOODDOOOKK..",   # 5
	".KKOOODDDDOOOKK.",   # 6
	"KKOOODDKKDDOOOKK",   # 7 — ombros totais
	"KKKK.KOOODK.KKKK",   # 8 — entalhe tribal (arrowhead → shaft)
	".....KOOODK.....",   # 9 — shaft
	".....KOOODK.....",   # 10
	".....KOOODK.....",   # 11
	".....KOOODK.....",   # 12
	".....KDDDDK.....",   # 13 — base com sombra
	".....KKKKKK.....",   # 14 — base fechada
	"................",   # 15
]
const ARROW_GLYPH_SIZE: int = 16

const _ARROW_DIRECTIONS: Dictionary = {
	"ui_up": Vector2.UP,
	"ui_left": Vector2.LEFT,
	"ui_down": Vector2.DOWN,
	"ui_right": Vector2.RIGHT,
}

# ─── State ─────────────────────────────────────────
# position deste Control É o centro do pad (o desenho é centrado em Vector2.ZERO).
var _radius: float = 0.0
var _dead_zone: float = 0.0
var _rest_center: Vector2 = Vector2.ZERO
var _clamp_rect: Rect2 = Rect2()
var _knob_offset: Vector2 = Vector2.ZERO
var _active_action: String = ""
var _touch_active: bool = false
var _fade_tween: Tween = null

# Highlight de seta: uma única direção ativa por vez (toque único).
var _highlight_amount: float = 0.0
var _highlight_action: String = ""
var _highlight_tween: Tween = null


# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	_fade_to(ALPHA_REST, REST_FADE_DURATION)


# ─── Public API ────────────────────────────────────
## Geometria do pad: raio, pose de repouso e o retângulo onde o CENTRO pode ficar
## (margens e safe area já descontadas pelo chamador). Chamado no boot e a cada resize.
func configure(radius: float, rest_center: Vector2, clamp_rect: Rect2) -> void:
	_radius = radius
	_dead_zone = maxf(radius * DEAD_ZONE_FRACTION, DEAD_ZONE_MIN)
	_rest_center = rest_center
	_clamp_rect = clamp_rect
	if not _touch_active:
		position = rest_center
	queue_redraw()


## O dedo pousou: o pad se recentra sob o ponto de toque com um "pop" de surgimento.
func begin_touch(point: Vector2) -> void:
	_touch_active = true
	_knob_offset = Vector2.ZERO
	position = _clamp_center(point)
	scale = Vector2(0.85, 0.85)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2.ONE, POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fade_to(ALPHA_ACTIVE, POP_DURATION)
	queue_redraw()


## O dedo arrastou: knob segue o dedo (limitado ao raio), base segue além do raio,
## e a direção cardinal resolvida vira press/release de action.
func drag_to(finger: Vector2) -> void:
	if not _touch_active:
		return
	var offset := finger - position
	if offset.length() > _radius:
		position = _clamp_center(position + offset.normalized() * (offset.length() - _radius))
		offset = finger - position
	_knob_offset = offset.limit_length(_radius)
	_set_active_action(resolve_action(offset, _dead_zone, _active_action))
	queue_redraw()


## O dedo levantou: solta a action ativa, some no lugar e renasce no repouso.
func end_touch() -> void:
	if not _touch_active:
		return
	_touch_active = false
	_set_active_action("")
	_knob_offset = Vector2.ZERO
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, RELEASE_FADE_DURATION)
	_fade_tween.tween_callback(_return_to_rest)
	_fade_tween.tween_property(self, "modulate:a", ALPHA_REST, REST_FADE_DURATION)
	queue_redraw()


func is_touch_active() -> bool:
	return _touch_active


## Retângulo ocupado na tela agora (consultado pela arena para bolhas/enquadramento).
func get_screen_rect() -> Rect2:
	if _radius <= 0.0:
		return Rect2()
	var extent := Vector2(_radius, _radius)
	return Rect2(position - extent, extent * 2.0)


## Resolve o offset do arrasto numa action cardinal ("" = zona morta). Função pura e
## determinística (testável sem input real). A histerese favorece o eixo da action
## atual: só troca de eixo quando o outro domina por AXIS_SWITCH_BIAS.
static func resolve_action(offset: Vector2, dead_zone: float, current: String) -> String:
	if offset.length() < dead_zone:
		return ""
	var ax := absf(offset.x)
	var ay := absf(offset.y)
	var horizontal: bool
	match current:
		"ui_left", "ui_right":
			horizontal = ay <= ax * AXIS_SWITCH_BIAS
		"ui_up", "ui_down":
			horizontal = ax > ay * AXIS_SWITCH_BIAS
		_:
			horizontal = ax >= ay
	if horizontal:
		return "ui_right" if offset.x > 0.0 else "ui_left"
	return "ui_down" if offset.y > 0.0 else "ui_up"


# ─── Private helpers ───────────────────────────────
func _set_active_action(new_action: String) -> void:
	if new_action == _active_action:
		return
	if _active_action != "":
		_highlight(_active_action, false)
		direction_released.emit(_active_action)
	if new_action != "":
		_highlight(new_action, true)
		direction_pressed.emit(new_action)
	_active_action = new_action


func _highlight(action: String, active: bool) -> void:
	_highlight_action = action if active else ""
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	_highlight_tween.tween_method(
		func(v: float) -> void:
			_highlight_amount = v
			queue_redraw(),
		_highlight_amount,
		1.0 if active else 0.0,
		HIGHLIGHT_DURATION
	)


func _clamp_center(point: Vector2) -> Vector2:
	if _clamp_rect.size == Vector2.ZERO:
		return point
	return point.clamp(_clamp_rect.position, _clamp_rect.end)


func _return_to_rest() -> void:
	position = _rest_center
	scale = Vector2.ONE


func _fade_to(alpha: float, duration: float) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, duration)


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()


func _draw() -> void:
	if _radius <= 0.0:
		return
	# Base: disco de sangue seco com aro vivo — legível sobre qualquer arena, sem
	# esconder o gore atrás (alpha do nó faz o resto do trabalho).
	draw_circle(Vector2.ZERO, _radius, Color(0.05, 0.01, 0.01, 0.55))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, Color(Constants.COLOR_BLOOD, 0.9), 2.0, true)
	# Aro da zona morta: o "olho" do pad, referência de onde o flick começa a contar.
	draw_arc(Vector2.ZERO, _dead_zone, 0.0, TAU, 24, Color(Constants.COLOR_BLOOD, 0.35), 1.0, true)
	var knob_color := Constants.COLOR_AMBER if _active_action != "" else Constants.COLOR_BONE
	var knob_r := _radius * KNOB_RADIUS_FRACTION
	draw_circle(_knob_offset, knob_r, Color(knob_color, 0.85))
	draw_arc(_knob_offset, knob_r, 0.0, TAU, 24, Color(0.0, 0.0, 0.0, 0.5), 1.5, true)
	# Setas Garra Tribal — mesmo glifo 16×16 do D-pad de combate.
	var dist := _radius * ARROW_DISTANCE_FRACTION
	var base_cell := _radius * ARROW_SIZE_FRACTION / float(ARROW_GLYPH_SIZE)
	for action: String in _ARROW_DIRECTIONS:
		var is_active := action == _highlight_action
		var cell: float = base_cell * lerp(1.0, ARROW_ACTIVE_SCALE, _highlight_amount if is_active else 0.0)
		var alpha: float = lerp(ARROW_ALPHA_IDLE, 1.0, _highlight_amount if is_active else 0.0)
		var center: Vector2 = _ARROW_DIRECTIONS[action] * dist
		_draw_arrow_glyph(action, center, cell, alpha)


func _draw_arrow_glyph(action: String, center: Vector2, cell_size: float, alpha: float) -> void:
	var half := ARROW_GLYPH_SIZE * cell_size * 0.5
	var origin := center - Vector2(half, half)
	var cs := Vector2.ONE * (cell_size + 0.5)
	var bright := Color(Constants.COLOR_JUBA.r, Constants.COLOR_JUBA.g, Constants.COLOR_JUBA.b, alpha)
	var dark   := Color(Constants.COLOR_JUBA_DARK.r, Constants.COLOR_JUBA_DARK.g, Constants.COLOR_JUBA_DARK.b, alpha * 0.7)
	var outline := Color(0.0, 0.0, 0.0, alpha)
	var g := ARROW_GLYPH_SIZE - 1
	for r: int in ARROW_GLYPH_SIZE:
		var row: String = ARROW_GLYPH[r]
		for c: int in ARROW_GLYPH_SIZE:
			var ch: String = row[c]
			if ch == ".":
				continue
			var col: Color
			match ch:
				"O": col = bright
				"D": col = dark
				_:   col = outline
			var cell_pos: Vector2
			match action:
				"ui_right": cell_pos = Vector2(float(g - r), float(c))
				"ui_down":  cell_pos = Vector2(float(g - c), float(g - r))
				"ui_left":  cell_pos = Vector2(float(r),     float(g - c))
				_:          cell_pos = Vector2(float(c),     float(r))
			draw_rect(Rect2(origin + cell_pos * cell_size, cs), col, true)
