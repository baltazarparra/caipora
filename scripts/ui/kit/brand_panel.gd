class_name BrandPanel
extends MarginContainer

# "Janela da mata" — painel/card de marca. O conteúdo entra como filho (as margens vêm
# dos tokens). framed=true desenha a placa serrilhada de marca atrás do conteúdo;
# framed=false desenha um scrim liso translúcido. Cantos sempre retos.

@export var framed: bool = true:
	set(value):
		framed = value
		_update_margins()
		queue_redraw()
@export_range(0.0, 1.0) var scrim_alpha: float = 0.82:
	set(value):
		scrim_alpha = value
		queue_redraw()
## Respiro adicional (H, V) somado aos paddings de token — para painéis que
## precisam de mais ar (ex.: modais de leitura como as Opções).
@export var pad_extra: Vector2i = Vector2i.ZERO:
	set(value):
		pad_extra = value
		_update_margins()

func _ready() -> void:
	_update_margins()

func _update_margins() -> void:
	# Com moldura, o topo/base precisam limpar a crista de juba (crest_clearance).
	var extra: int = int(BrandFrame.crest_clearance()) if framed else 0
	add_theme_constant_override("margin_left", Constants.UI_PADDING_H + pad_extra.x)
	add_theme_constant_override("margin_right", Constants.UI_PADDING_H + pad_extra.x)
	add_theme_constant_override("margin_top", Constants.UI_PADDING_V + extra + pad_extra.y)
	add_theme_constant_override("margin_bottom", Constants.UI_PADDING_V + extra + pad_extra.y)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 1.0 or r.size.y <= 1.0:
		return
	var bg := Constants.COLOR_NIGHT
	bg.a = scrim_alpha
	if framed:
		var depth := BrandFrame.crest_clearance()
		var ow := float(Constants.UI_BORDER_WIDTH)
		var body := Rect2(ow, depth + ow, r.size.x - ow * 2.0, r.size.y - depth * 2.0 - ow * 2.0)
		BrandFrame.draw_plate(self, body, bg, Constants.COLOR_JUBA_DARK, ow)
	else:
		draw_rect(r, bg)
