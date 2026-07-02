class_name BrandButton
extends BaseButton

# Botão de marca unificado (chrome da mata). Substitui os 3 caminhos de estilo de botão
# hoje espalhados (theme nativo, StyleBoxFlat inline, _draw() ad-hoc). Todo desenho vem de
# BrandFrame; cores de Constants; estados lit/pressed do vocabulário do chrome.
#
#  HERO    — placa completa + garras + brasa + rótulo (o botão-herói da tela inicial).
#  PRIMARY — placa + rótulo (ação padrão de menu/painel).
#  GHOST   — só a moldura serrilhada (fundo transparente) + rótulo.
#  FLAG    — como PRIMARY, pensado pequeno (bandeiras/toggles); o dono dimensiona.
#  LINK    — só rótulo (sem placa), para rodapé.

enum Variant { HERO, PRIMARY, GHOST, FLAG, LINK }

const HERO_MIN := Vector2(280.0, 96.0)
const LABEL_FONT_MAX := 26.0

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
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	if variant == Variant.HERO:
		_start_breath()

func _exit_tree() -> void:
	if _breath != null:
		_breath.kill()

## "Bote" do chrome: press escala (não afunda), release volta num tween curto.
func _on_button_down() -> void:
	_pressed_lit = true
	pivot_offset = size * 0.5
	scale = Vector2(Constants.CHROME_PRESS_SCALE, Constants.CHROME_PRESS_SCALE)
	queue_redraw()

func _on_button_up() -> void:
	_pressed_lit = false
	create_tween().tween_property(self, "scale", Vector2.ONE, Constants.CHROME_PRESS_SECS)
	queue_redraw()

func _set_lit(value: bool) -> void:
	_lit = value
	queue_redraw()

func _start_breath() -> void:
	if _breath != null:
		_breath.kill()
	_breath = create_tween().set_loops()
	_breath.tween_property(self, "_ember_alpha", 0.62, Constants.CHROME_BREATH_SECS)
	_breath.tween_property(self, "_ember_alpha", 0.32, Constants.CHROME_BREATH_SECS)

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
	var depth := BrandFrame.crest_clearance()
	var ow := float(Constants.UI_BORDER_WIDTH)
	var body := Rect2(ow, depth + ow, r.size.x - ow * 2.0, r.size.y - depth * 2.0 - ow * 2.0)
	BrandFrame.draw_plate(self, body, base, border, ow)
	var inner := body.grow(-float(Constants.SPACE_XS))
	if variant == Variant.HERO:
		BrandFrame.draw_claws(self, get_theme_default_font(), inner, claw)
		BrandFrame.draw_embers(self, body, Constants.COLOR_AMBER, _ember_alpha + (0.18 if lit else 0.0))
		# As pontas da crista acendem junto com a brasa — a placa respira viva.
		BrandFrame.draw_crest_embers(self, body, Constants.COLOR_AMBER, _ember_alpha + (0.24 if lit else 0.0))
	_draw_label(inner, text_col)

func _draw_label(inner: Rect2, color: Color) -> void:
	if label.is_empty():
		return
	var font := get_theme_default_font()
	var fs := label_font_for_inner(inner.size.y)
	# HERO divide o espaço com as garras >>/<< — orçamento de largura mais apertado.
	var budget := 0.58 if variant == Variant.HERO else 0.9
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	while width > inner.size.x * budget and fs > Constants.FONT_SM:
		fs -= 1
		width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var pos := Vector2(inner.position.x + (inner.size.x - width) * 0.5,
		inner.position.y + inner.size.y * 0.62)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x, fs, color)

## Fonte do rótulo para uma altura interna disponível (fórmula única do chrome).
static func label_font_for_inner(inner_h: float) -> int:
	return int(clampf(inner_h * 0.27, float(Constants.FONT_SM), LABEL_FONT_MAX))

## Fonte nominal do rótulo de um BrandButton de placa (HERO/PRIMARY/GHOST/FLAG) com
## `control_height` de altura total — espelha a geometria de _draw (crista 2×,
## borda 2×, respiro SPACE_XS 2×). Permite a outros controles (ex.: "Opções" no
## menu) casarem a fonte com o hero sem duplicar a fórmula.
static func hero_label_font_size(control_height: float) -> int:
	return label_font_for_inner(control_height - 2.0 * BrandFrame.crest_clearance()
		- 2.0 * float(Constants.UI_BORDER_WIDTH) - 2.0 * float(Constants.SPACE_XS))
