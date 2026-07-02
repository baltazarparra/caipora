class_name HdButton
extends Control

## Botão "HD" (qualidade gráfica), irmão visual do SpeakerButton: mesmo hitbox,
## mesmo contrato de sinal, mesmo lugar no topo. Ligado = wordmark âmbar pleno;
## desligado = apagado + talho de sangue (espelho do X de mudo do speaker).

# ─── Signals ───────────────────────────────────────
signal pressed

# ─── Exports ───────────────────────────────────────
@export var icon_color: Color = Constants.COLOR_AMBER
@export var off_slash_color: Color = Constants.COLOR_BLOOD
@export var hd_on: bool = false

# ─── Constants ─────────────────────────────────────
const SIZE := 28.0        # lado base do ícone desenhado
const HITBOX_PAD := 8.0   # respiro base ao redor (compõe o alvo de toque)
const OFF_ALPHA := 0.45

# ─── State ─────────────────────────────────────────
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
	var col := icon_color if hd_on else Color(icon_color, OFF_ALPHA)

	# Wordmark "HD" em RECTS cheios (sem draw_line nas letras: butt caps deixam
	# mossas — mesma regra do BrandFrame). Letras ocupam o ícone inteiro.
	var y0 := _pad + s * 0.14
	var h := s * 0.72
	var t := maxf(2.0, s * 0.14)   # espessura do traço
	var gap := s * 0.12
	var wl := (s - gap) * 0.5

	# H
	var hx := _pad
	draw_rect(Rect2(hx, y0, t, h), col)
	draw_rect(Rect2(hx + wl - t, y0, t, h), col)
	draw_rect(Rect2(hx, y0 + (h - t) * 0.5, wl, t), col)

	# D blocado (cantos cortados: leitura pixel-art, não "O")
	var dx := hx + wl + gap
	draw_rect(Rect2(dx, y0, t, h), col)
	draw_rect(Rect2(dx, y0, wl - t, t), col)
	draw_rect(Rect2(dx, y0 + h - t, wl - t, t), col)
	draw_rect(Rect2(dx + wl - t, y0 + t, t, h - t * 2.0), col)

	if not hd_on:
		# Talho diagonal de "desligado", par do X de mudo do SpeakerButton.
		draw_line(Vector2(_pad, _pad + s), Vector2(_pad + s, _pad),
			off_slash_color, 2.5, false)

# ─── Input ─────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pressed.emit()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit()

func set_hd(value: bool) -> void:
	hd_on = value
	queue_redraw()
