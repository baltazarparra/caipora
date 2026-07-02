class_name FragmentCounter
extends Control

# Contador de TERRA RARA compacto: o ícone de minério cristalino (sprite premium) + o número.
# Substitui o antigo `"+".repeat(n)` (que transbordava a tela) e o losango desenhado à mão.
# Largura PADRÃO: reserva espaço para RESERVE_DIGITS dígitos, então a placa do
# header não muda de tamanho conforme a contagem sobe (só além de 999).

# ─── Constants ─────────────────────────────────────
const ICON_TEX: Texture2D = preload("res://assets/sprites/terra_rara_icon.png")
const ICON_BOX: float = 22.0  # lado do ícone (proporcional ao tamanho da fonte)
const GAP: float = 8.0        # respiro entre ícone e número
const RESERVE_DIGITS: int = 3 # largura mínima do número (padrão de largura do header)

# ─── State ─────────────────────────────────────────
var _count: int = 0
var _glyph_size: float = 1.0
var _font_size: int = Constants.FONT_MD
var _label: Label
var _pop_tween: Tween

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel-art crocante (sem blur)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_label.add_theme_font_size_override("font_size", _font_size)
	add_child(_label)
	_relayout()

# ─── Public API ────────────────────────────────────
func set_count(value: int) -> void:
	var grew: bool = value > _count
	_count = maxi(value, 0)
	if _label != null:
		_label.text = str(_count)
	_relayout()
	queue_redraw()
	if grew:
		_pop()

## `scale` amplia ícone E número juntos (ex.: 2x no HUD tátil de exploração retrato).
## Default 1.0 preserva o comportamento atual (HUD normal, loja do acampamento).
func configure_size(font_size: int, scale: float = 1.0) -> void:
	_font_size = int(round(float(font_size) * scale))
	_glyph_size = clampf(float(font_size) / float(Constants.FONT_MD), 0.7, 1.6) * scale
	if _label != null:
		_label.add_theme_font_size_override("font_size", _font_size)
	_relayout()
	queue_redraw()

# ─── Internals ─────────────────────────────────────
func _icon_box() -> float:
	return ICON_BOX * _glyph_size

func _relayout() -> void:
	if _label == null:
		return
	var box: float = _icon_box()
	var h: float = maxf(box, _label.get_minimum_size().y)
	# Largura padrão: nunca menor que RESERVE_DIGITS dígitos na fonte atual.
	var label_w: float = maxf(_label.get_minimum_size().x, _digit_reserve_width())
	_label.position = Vector2(box + GAP, 0.0)
	_label.size = Vector2(label_w, h)
	custom_minimum_size = Vector2(box + GAP + label_w, h)
	size = custom_minimum_size

func _digit_reserve_width() -> float:
	var font: Font = _label.get_theme_font(&"font")
	if font == null:
		return 0.0
	return font.get_string_size("0".repeat(RESERVE_DIGITS),
		HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x

func _pop() -> void:
	if _pop_tween != null and _pop_tween.is_valid():
		_pop_tween.kill()
	pivot_offset = Vector2(_icon_box() * 0.5, size.y * 0.5)
	scale = Vector2(1.25, 1.25)
	_pop_tween = create_tween()
	_pop_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(self, "scale", Vector2.ONE, 0.25)

# ─── Drawing ───────────────────────────────────────
func _draw() -> void:
	var box: float = _icon_box()
	var rect := Rect2(0.0, (size.y - box) * 0.5, box, box)
	draw_texture_rect(ICON_TEX, rect, false)
