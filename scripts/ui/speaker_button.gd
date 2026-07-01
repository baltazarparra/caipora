class_name SpeakerButton
extends Control

# ─── Signals ───────────────────────────────────────
signal pressed

# ─── Exports ───────────────────────────────────────
@export var icon_color: Color = Color(1.0, 0.6, 0.0)
@export var muted_color: Color = Constants.COLOR_BLOOD
@export var muted: bool = false

# ─── Constants ─────────────────────────────────────
const SIZE := 28.0        # lado base do ícone desenhado
const HITBOX_PAD := 8.0   # respiro base ao redor (compõe o alvo de toque)

# ─── State ─────────────────────────────────────────
# Tamanho efetivo do ícone e do respiro. `configure_size` os escala juntos (ex.: 2x no
# HUD tátil de exploração retrato). Sem chamar, mantém o tamanho base (loja do acampamento).
var _icon_px: float = SIZE
var _pad: float = HITBOX_PAD

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	custom_minimum_size = Vector2(_icon_px + _pad * 2.0, _icon_px + _pad * 2.0)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Escala o ícone (e o alvo de toque proporcional) para `icon_px` pixels de lado.
func configure_size(icon_px: float) -> void:
	_icon_px = maxf(icon_px, 1.0)
	_pad = HITBOX_PAD * (_icon_px / SIZE)
	custom_minimum_size = Vector2(_icon_px + _pad * 2.0, _icon_px + _pad * 2.0)
	size = custom_minimum_size
	queue_redraw()

func _draw() -> void:
	var s := _icon_px
	var ox := _pad
	var oy := _pad
	var col := Color(icon_color, 0.72) if muted else icon_color

	# corpo do alto-falante (retângulo esquerdo)
	var body := Rect2(ox, oy + s * 0.3, s * 0.35, s * 0.4)
	draw_rect(body, col)

	# trompa (triângulo à direita do corpo)
	var horn: PackedVector2Array = [
		Vector2(ox + s * 0.35, oy + s * 0.2),
		Vector2(ox + s * 0.35, oy + s * 0.8),
		Vector2(ox + s * 0.62, oy + s),
		Vector2(ox + s * 0.62, oy),
	]
	draw_colored_polygon(horn, col)

	if not muted:
		# onda pequena
		_draw_arc_lines(ox + s * 0.68, oy + s * 0.5, s * 0.14, col, 2.0)
		# onda grande
		_draw_arc_lines(ox + s * 0.68, oy + s * 0.5, s * 0.26, col, 2.0)
	else:
		# X de mudo
		var x0 := ox + s * 0.70
		var y0 := oy + s * 0.25
		var x1 := ox + s * 0.98
		var y1 := oy + s * 0.75
		draw_line(Vector2(x0, y0), Vector2(x1, y1), muted_color, 2.5, false)
		draw_line(Vector2(x1, y0), Vector2(x0, y1), muted_color, 2.5, false)

func _draw_arc_lines(cx: float, cy: float, r: float, col: Color, width: float) -> void:
	var steps := 8
	var a_from := deg_to_rad(-50.0)
	var a_to   := deg_to_rad(50.0)
	for i in range(steps):
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a0 := lerpf(a_from, a_to, t0)
		var a1 := lerpf(a_from, a_to, t1)
		draw_line(
			Vector2(cx + cos(a0) * r, cy + sin(a0) * r),
			Vector2(cx + cos(a1) * r, cy + sin(a1) * r),
			col, width, true
		)

# ─── Input ─────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit()

func set_muted(value: bool) -> void:
	muted = value
	queue_redraw()
