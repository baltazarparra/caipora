class_name BrandButton
extends BaseButton

# Botão de marca unificado (chrome da mata). Substitui os 3 caminhos de estilo de botão
# hoje espalhados (theme nativo, StyleBoxFlat inline, _draw() ad-hoc). Todo desenho vem de
# BrandFrame; cores de Constants; estados lit/pressed do vocabulário do chrome.
#
#  HERO    — placa completa + garras + brasa + rótulo (o antigo StartButton).
#  PRIMARY — placa + rótulo (ação padrão de menu/painel).
#  GHOST   — só a moldura serrilhada (fundo transparente) + rótulo.
#  FLAG    — como PRIMARY, pensado pequeno (bandeiras/toggles); o dono dimensiona.
#  LINK    — só rótulo (sem placa), para rodapé.

enum Variant { HERO, PRIMARY, GHOST, FLAG, LINK }

const HERO_MIN := Vector2(280.0, 96.0)

@export var variant: Variant = Variant.PRIMARY:
	set(value):
		variant = value
		queue_redraw()
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()

var _lit: bool = false
var _pressed_lit: bool = false
var _ember_alpha: float = 0.4:
	set(value):
		_ember_alpha = value
		queue_redraw()
var _breath: Tween

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if variant == Variant.HERO and custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = HERO_MIN
	mouse_entered.connect(func() -> void: _set_lit(true))
	mouse_exited.connect(func() -> void: _set_lit(has_focus()))
	focus_entered.connect(func() -> void: _set_lit(true))
	focus_exited.connect(func() -> void: _set_lit(is_hovered()))
	button_down.connect(func() -> void: _pressed_lit = true; queue_redraw())
	button_up.connect(func() -> void: _pressed_lit = false; queue_redraw())
	if variant == Variant.HERO:
		_start_breath()

func _exit_tree() -> void:
	if _breath != null:
		_breath.kill()

func _set_lit(value: bool) -> void:
	_lit = value
	queue_redraw()

func _start_breath() -> void:
	if _breath != null:
		_breath.kill()
	_breath = create_tween().set_loops()
	_breath.tween_property(self, "_ember_alpha", 0.62, 1.3)
	_breath.tween_property(self, "_ember_alpha", 0.32, 1.3)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return
	var lit := _lit or has_focus() or is_hovered()
	var text_col := Color.WHITE if lit else Constants.COLOR_TEXT
	if variant == Variant.LINK:
		if not lit:
			text_col = Constants.COLOR_TEXT_DIM
		_draw_label(r, text_col)
		return

	var base := Constants.COLOR_NIGHT
	base.a = 0.94
	if variant == Variant.GHOST:
		base.a = 0.0
	if _pressed_lit:
		base = Constants.COLOR_BLOOD
		base.a = 0.92
	var border := Constants.COLOR_JUBA if lit else Constants.COLOR_JUBA_DARK
	var claw := Constants.COLOR_AMBER if lit else Color(Constants.COLOR_JUBA_DARK, 0.72)
	var depth := Constants.CHROME_SAW_DEPTH
	var ow := float(Constants.UI_BORDER_WIDTH)
	var body := Rect2(ow, depth + ow, r.size.x - ow * 2.0, r.size.y - depth * 2.0 - ow * 2.0)
	BrandFrame.draw_plate(self, body, base, border, ow)
	var inner := body.grow(-float(Constants.SPACE_XS))
	if variant == Variant.HERO:
		BrandFrame.draw_claws(self, get_theme_default_font(), inner, claw)
		BrandFrame.draw_embers(self, body, Constants.COLOR_AMBER, _ember_alpha + (0.18 if lit else 0.0))
	_draw_label(inner, text_col)

func _draw_label(inner: Rect2, color: Color) -> void:
	if label.is_empty():
		return
	var font := get_theme_default_font()
	var fs := int(clampf(inner.size.y * 0.27, float(Constants.FONT_SM), 26.0))
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	while width > inner.size.x * 0.9 and fs > Constants.FONT_SM:
		fs -= 1
		width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var pos := Vector2(inner.position.x + (inner.size.x - width) * 0.5,
		inner.position.y + inner.size.y * 0.62)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, fs, color)
