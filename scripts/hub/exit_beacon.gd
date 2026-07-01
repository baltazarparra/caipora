class_name HubExitBeacon
extends Control

# Seta âmbar que aponta pro RASTRO de saída do acampamento enquanto ele está fora do quadro.
# Em retrato a clareira é mais larga que o recorte da câmera (que fica fechada na Caipora), então
# a saída nasce fora da tela, à direita — sem uma pista, o jogador não sabe pra onde andar pra
# voltar à mata. A seta repousa na borda da tela na direção do rastro e some quando ele entra no
# quadro (a luz âmbar pulsante do mundo já o marca de perto). Não rouba o toque (mouse ignorado).

const EDGE_MARGIN := 72.0      # afastamento da seta em relação à borda da tela
const ARROW_LEN := 24.0        # meio-comprimento do triângulo (ponta ↔ base)
const ARROW_HALF_W := 18.0     # meia-largura da base do triângulo
const ON_SCREEN_INSET := 28.0  # folga: trata como "na tela" um pouco antes da borda real
const LABEL_FONT_SIZE := 16

var _target_world: Vector2
var _pulse: float = 0.0

func _ready() -> void:
	Lang.language_changed.connect(func(_lang: StringName) -> void: queue_redraw())

func setup(target_world: Vector2) -> void:
	_target_world = target_world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	# Projeta a posição-mundo do rastro pra tela usando a transform do canvas (respeita câmera/zoom).
	var screen := get_viewport().get_canvas_transform() * _target_world
	var inset := Vector2(ON_SCREEN_INSET, ON_SCREEN_INSET)
	if Rect2(inset, vp - inset * 2.0).has_point(screen):
		return  # rastro no quadro: a luz pulsante do mundo basta
	var center := vp * 0.5
	var dir := screen - center
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	var pos := _edge_point(vp, center, dir)
	var alpha := 0.70 + 0.30 * (0.5 + 0.5 * sin(_pulse * 3.0))  # respiro âmbar
	_draw_arrow(pos, dir, alpha)

# Ponto na borda interna (com EDGE_MARGIN) na direção dir a partir do centro da tela.
func _edge_point(vp: Vector2, center: Vector2, dir: Vector2) -> Vector2:
	var half := vp * 0.5 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var reach := INF
	if absf(dir.x) > 0.0001:
		reach = minf(reach, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		reach = minf(reach, half.y / absf(dir.y))
	return center + dir * reach

func _draw_arrow(pos: Vector2, dir: Vector2, alpha: float) -> void:
	var color := Constants.COLOR_EXIT
	color.a = alpha
	var perp := Vector2(-dir.y, dir.x)
	var tip := pos + dir * ARROW_LEN
	var base_a := pos - dir * ARROW_LEN + perp * ARROW_HALF_W
	var base_b := pos - dir * ARROW_LEN - perp * ARROW_HALF_W
	draw_colored_polygon(PackedVector2Array([tip, base_a, base_b]), color)
	# Rótulo "rastro" atrás da seta (lado de dentro da tela), pra dizer o que ela aponta.
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var label := Lang.t(&"hub.exit.trail")
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var anchor := pos - dir * (ARROW_LEN + 8.0)
	draw_string(
		font, anchor - Vector2(size.x * 0.5, -size.y * 0.5), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, color
	)
