class_name StartButton
extends BaseButton

## Botao-heroi da tela inicial: "O Rastro". Desenhado em codigo para manter
## pixel art chapada, custo baixo no web e a silhueta de garra/juba da Caipora.

# ─── Constants ─────────────────────────────────────
const MIN_SIZE := Vector2(280.0, 96.0)
const SAW_STEP := 18.0
const SAW_DEPTH := 8.0
const OUTLINE_WIDTH := 2.0
const EMBER_ROWS := 3

# ─── State ─────────────────────────────────────────
@export var text: String = "DESPERTAR":
	set(value):
		text = value
		queue_redraw()

var _ember_alpha: float = 0.36:
	set(value):
		_ember_alpha = value
		queue_redraw()

var _focus_lit: bool = false
var _pressed_lit: bool = false
var _pulse_tween: Tween

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = MIN_SIZE
	mouse_entered.connect(_set_lit.bind(true))
	mouse_exited.connect(_set_lit.bind(has_focus()))
	focus_entered.connect(_set_lit.bind(true))
	focus_exited.connect(_set_lit.bind(get_global_rect().has_point(get_global_mouse_position())))
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_start_breath()

func _exit_tree() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return
	var lit := _focus_lit or has_focus() or is_hovered()
	var base := Constants.COLOR_NIGHT
	base.a = 0.94
	if _pressed_lit:
		base = Constants.COLOR_BLOOD
		base.a = 0.92
	var border := Constants.COLOR_JUBA if lit else Constants.COLOR_JUBA_DARK
	var claw := Constants.COLOR_AMBER if lit else Color(Constants.COLOR_JUBA_DARK, 0.72)
	var text_col := Color.WHITE if lit else Constants.COLOR_TEXT

	var body := Rect2(OUTLINE_WIDTH, SAW_DEPTH + OUTLINE_WIDTH,
		r.size.x - OUTLINE_WIDTH * 2.0, r.size.y - SAW_DEPTH * 2.0 - OUTLINE_WIDTH * 2.0)
	var plate := _saw_plate(body)
	draw_colored_polygon(plate, base)
	_draw_polyline_closed(plate, border, OUTLINE_WIDTH)

	var inner := body.grow(-8.0)
	_draw_claws(inner, claw)
	_draw_label(inner, text_col)
	_draw_embers(body, lit)

# ─── Private ───────────────────────────────────────
func _start_breath() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "_ember_alpha", 0.62, 1.3)
	_pulse_tween.tween_property(self, "_ember_alpha", 0.32, 1.3)

func _set_lit(value: bool) -> void:
	_focus_lit = value
	queue_redraw()

func _on_button_down() -> void:
	_pressed_lit = true
	scale = Vector2(1.04, 1.04)
	pivot_offset = size * 0.5
	queue_redraw()

func _on_button_up() -> void:
	_pressed_lit = false
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	queue_redraw()

func _saw_plate(body: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(body.position.x, body.position.y + SAW_DEPTH))
	var x := body.position.x
	while x < body.end.x:
		pts.append(Vector2(minf(x + SAW_STEP * 0.5, body.end.x), body.position.y))
		pts.append(Vector2(minf(x + SAW_STEP, body.end.x), body.position.y + SAW_DEPTH))
		x += SAW_STEP
	pts.append(Vector2(body.end.x, body.end.y - SAW_DEPTH))
	x = body.end.x
	while x > body.position.x:
		pts.append(Vector2(maxf(x - SAW_STEP * 0.5, body.position.x), body.end.y))
		pts.append(Vector2(maxf(x - SAW_STEP, body.position.x), body.end.y - SAW_DEPTH))
		x -= SAW_STEP
	return pts

func _draw_polyline_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], color, width, false)

func _draw_claws(inner: Rect2, color: Color) -> void:
	var font := get_theme_default_font()
	var fs := int(clampf(inner.size.y * 0.24, 18.0, 28.0))
	var y := inner.position.y + inner.size.y * 0.57
	draw_string(font, Vector2(inner.position.x + 6.0, y), ">>", HORIZONTAL_ALIGNMENT_LEFT, 70.0, fs, color)
	draw_string(font, Vector2(inner.end.x - 76.0, y), "<<", HORIZONTAL_ALIGNMENT_RIGHT, 70.0, fs, color)

func _draw_label(inner: Rect2, color: Color) -> void:
	var font := get_theme_default_font()
	var fs := int(clampf(inner.size.y * 0.27, 18.0, 26.0))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	while width > inner.size.x * 0.58 and fs > 14:
		fs -= 1
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var pos := Vector2(inner.position.x + (inner.size.x - width) * 0.5,
		inner.position.y + inner.size.y * 0.60)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, fs, color)

func _draw_embers(body: Rect2, lit: bool) -> void:
	var alpha := _ember_alpha + (0.18 if lit else 0.0)
	var col := Constants.COLOR_AMBER
	col.a = clampf(alpha, 0.0, 0.86)
	var y := body.end.y - SAW_DEPTH - 3.0
	var center := body.position.x + body.size.x * 0.5
	var max_half := body.size.x * 0.34
	for row in range(EMBER_ROWS):
		var half := max_half * (1.0 - float(row) * 0.23)
		var yy := y + float(row) * 3.0
		var x := center - half
		while x < center + half:
			var w := 3.0 + fmod(floorf(x + row * 11.0), 4.0)
			draw_rect(Rect2(Vector2(x, yy), Vector2(w, 2.0)), col)
			x += 10.0
