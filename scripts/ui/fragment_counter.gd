class_name FragmentCounter
extends Control

# Contador de TERRA RARA compacto: o ícone de minério cristalino (sprite premium) + o número.
# Substitui o antigo `"+".repeat(n)` (que transbordava a tela) e o losango desenhado à mão.
# Largura praticamente constante: cresce só com a contagem de dígitos.

# ─── Constants ─────────────────────────────────────
const ICON_TEX: Texture2D = preload("res://assets/sprites/terra_rara_icon.png")
const ICON_BOX: float = 22.0  # lado do ícone (proporcional ao tamanho da fonte)
const GAP: float = 8.0        # respiro entre ícone e número

# ─── State ─────────────────────────────────────────
var _count: int = 0
var _glyph_size: float = 1.0
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

func configure_size(font_size: int) -> void:
	_glyph_size = clampf(float(font_size) / float(Constants.FONT_MD), 0.7, 1.6)
	if _label != null:
		_label.add_theme_font_size_override("font_size", font_size)
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
	_label.position = Vector2(box + GAP, 0.0)
	_label.size = Vector2(_label.get_minimum_size().x, h)
	custom_minimum_size = Vector2(box + GAP + _label.get_minimum_size().x, h)
	size = custom_minimum_size

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
