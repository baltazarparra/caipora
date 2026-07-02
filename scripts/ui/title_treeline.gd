class_name TitleTreeline
extends Node2D

## Camada de silhueta de árvores mortas para a abertura ("Horizonte Infernal").
## Faz scroll horizontal com wrap sem costura (desenha duas cópias lado a lado),
## criando parallax quando instanciada em velocidades diferentes (FAR lenta, MID
## rápida). Reusa o vocabulário procedural de MapObject._draw_dead_tree. Puramente
## decorativo — sem colisão, sem input.

# ─── Exports ───────────────────────────────────────
@export var scroll_speed: float = 8.0
@export var silhouette_color: Color = Constants.COLOR_BARK_DARK
@export var base_y: float = 560.0
@export var tree_count: int = 10
@export var tree_scale: float = 2.0
@export var layer_z: int = -80
@export var rng_seed: int = 1
## Modo estático (arena): tamanho fixo em coordenadas locais, sem scroll e sem
## escala por viewport — base_y vira coordenada local absoluta. Zero = modo
## abertura (viewport + scroll), comportamento original do menu.
@export var static_bounds: Rect2 = Rect2()
## Vento (wind_sway.gdshader): deslocamento máximo das copas em px. 0 desliga.
@export var sway_amount: float = 2.5
@export var sway_speed: float = 1.1

# ─── State ─────────────────────────────────────────
var _vp_w: float = 1280.0
var _vp_h: float = 720.0
var _eff_base_y: float = 0.0
var _offset: float = 0.0
var _trees: Array[Dictionary] = []

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	if static_bounds.size.x > 0.0:
		_vp_w = static_bounds.size.x
		_vp_h = static_bounds.size.y
		_eff_base_y = base_y
		set_process(false)
	else:
		var vp := get_viewport().get_visible_rect().size
		_vp_w = vp.x
		_vp_h = vp.y
		_eff_base_y = base_y / 720.0 * _vp_h
	z_index = layer_z
	_apply_wind()
	_generate_trees()
	queue_redraw()

## Vento por vertex shader: raiz cravada em _eff_base_y, copa balançando.
## A massa do chão (abaixo de base_y) tem peso 0 — só as árvores respiram.
func _apply_wind() -> void:
	if sway_amount <= 0.0:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/wind_sway.gdshader")
	mat.set_shader_parameter("base_y", _eff_base_y)
	mat.set_shader_parameter("span", 60.0 * tree_scale)
	mat.set_shader_parameter("amount", sway_amount)
	mat.set_shader_parameter("speed", sway_speed)
	material = mat

func _process(delta: float) -> void:
	# Scroll é transform puro (position.x) e o vento é vertex shader: a geometria
	# desenhada (2 strips fixas do wrap) NUNCA muda — sem queue_redraw por frame
	# (re-gravava ~284 primitivas/frame à toa; PRD-performance-refactor-web RF-D1).
	_offset += scroll_speed * delta
	if _offset >= _vp_w:
		_offset -= _vp_w
	position.x = -_offset

# ─── Drawing ───────────────────────────────────────
func _draw() -> void:
	_draw_strip(0.0)
	# A segunda cópia só existe para o wrap do scroll — modo estático não rola.
	if static_bounds.size.x <= 0.0:
		_draw_strip(_vp_w)

func _draw_strip(ox: float) -> void:
	# Massa sólida do chão/cordilheira (recorta contra o fogo).
	draw_rect(Rect2(ox, _eff_base_y, _vp_w, _vp_h - _eff_base_y), silhouette_color)
	for t: Dictionary in _trees:
		_draw_tree(ox + t.x, _eff_base_y, t.height, t.scale)

func _draw_tree(tx: float, gy: float, hfac: float, sc: float) -> void:
	# Altura cresce com o "depth scale" para a treeline MID dominar sobre a FAR.
	var trunk_h: float = 60.0 * hfac * (0.7 + sc * 0.22)
	var trunk_w: float = 3.0 * sc
	var top: float = gy - trunk_h
	draw_rect(Rect2(tx - trunk_w * 0.5, top, trunk_w, trunk_h), silhouette_color)
	# Galhos secos retorcidos (silhueta — cor única).
	var branches: Array = [
		[Vector2(tx, top + 6), Vector2(tx - 16 * sc, top - 10 * sc)],
		[Vector2(tx, top + 2), Vector2(tx + 14 * sc, top - 14 * sc)],
		[Vector2(tx, top + 14), Vector2(tx + 10 * sc, top + 2)],
		[Vector2(tx, top + 10), Vector2(tx - 12 * sc, top - 4 * sc)],
	]
	for b: Array in branches:
		draw_line(b[0], b[1], silhouette_color, 2.0 * sc)

# ─── Private helpers ───────────────────────────────
func _generate_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_trees.clear()
	for i: int in tree_count:
		_trees.append({
			"x": rng.randf() * _vp_w,
			"height": rng.randf_range(0.6, 1.3),
			"scale": tree_scale * rng.randf_range(0.8, 1.3),
		})
