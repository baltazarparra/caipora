class_name ArenaBackdrop
extends Node2D

## Palco da arena: céu, treelines em planos, banda de chão tileada e props por
## fase — tudo em world space atrás dos atores, dimensionado ao redor do STAGE
## do ArenaManager (centro 320,225). Construído 100% por código (padrão
## Atmosphere.new()): o ArenaManager só instancia; a fase vem de
## GameState.active_phase.
##
## O terço central do stage fica de baixo contraste de propósito: é onde as
## bolhas de timing e os atores vivem — o palco emoldura, não compete.

# Geometria do palco (coordenadas de mundo, derivadas do STAGE 560×340 @ 320,225).
# As faixas extrapolam o stage porque em retrato a câmera revela muito além dele.
const HORIZON_Y: float = 150.0
const SKY_TOP: float = -600.0
const FLOOR_BOTTOM: float = 598.0
const STRIP_X: float = -120.0
const STRIP_W: float = 840.0
const TILE: int = 32
const BackdropLayerScript := preload("res://scripts/arena/backdrop_layer.gd")

# Planos de treeline: FAR baixa e densa atrás, MID alta e esparsa na frente.
const FAR_TREES: int = 13
const MID_TREES: int = 8
const TREE_BAND_H: float = 36.0

# Parallax do screenshake: o FeedbackSystem sacode via camera.offset; planos
# distantes SEGUEM o offset (jitter menor na tela) — céu quase parado, chão
# quase colado nos atores. Profundidade de graça em cada impacto.
const SHAKE_FOLLOW_SKY: float = 0.9
const SHAKE_FOLLOW_FAR: float = 0.85
const SHAKE_FOLLOW_MID: float = 0.65
const SHAKE_FOLLOW_FLOOR: float = 0.3

const FLOOR_VARIANTS: int = 4
const WALL_VARIANTS: int = 2
# Chão some na escuridão: brilho cai com a distância do horizonte (longe = escuro)
# e as últimas linhas desvanecem em alpha para fundir com o vazio abaixo.
const FLOOR_NEAR_BRIGHT: float = 1.0
const FLOOR_FAR_BRIGHT: float = 0.22

# Estilo por fase. sky usa alpha parcial para o DoomFire (CanvasLayer atrás)
# respirar através — P2/P4 (mata queimada) deixam o fogo vazar mais.
const PHASE_STYLE: Dictionary = {
	1: {
		"sky": Color(0.030, 0.040, 0.065, 0.85),
		"far": Color(0.050, 0.034, 0.016),
		"mid": Color(0.095, 0.060, 0.022),
		"floor": "res://assets/sprites/tile_floor.png",
		"floor_gain": 1.0,
		"church": false,
		# arena.tscn (P1) não tem CanvasModulate próprio — sem ele a PointLight2D
		# não tem escuridão para "devolver" cor. P2–P5 já têm o seu na cena.
		"modulate": Color(0.82, 0.84, 0.90),
	},
	2: {
		"sky": Color(0.085, 0.018, 0.0, 0.38),
		"far": Color(0.075, 0.020, 0.004),
		"mid": Color(0.120, 0.040, 0.010),
		"floor": "res://assets/sprites/tile_floor.png",
		"floor_gain": 1.15,
		"church": false,
	},
	3: {
		"sky": Color(0.018, 0.045, 0.028, 0.90),
		"far": Color(0.028, 0.062, 0.036),
		"mid": Color(0.055, 0.105, 0.055),
		"floor": "res://assets/sprites/tile_floor.png",
		"floor_gain": 1.7,
		"church": false,
	},
	4: {
		"sky": Color(0.055, 0.012, 0.010, 0.52),
		"far": Color(0.065, 0.014, 0.010),
		"mid": Color(0.105, 0.028, 0.018),
		"floor": "res://assets/sprites/tile_floor.png",
		"floor_gain": 1.55,
		"church": false,
	},
	5: {
		"sky": Color(0.040, 0.042, 0.058, 0.92),
		"far": Color(0.0, 0.0, 0.0),
		"mid": Color(0.0, 0.0, 0.0),
		"floor": "res://assets/sprites/tile_floor_church.png",
		"floor_gain": 1.2,
		"church": true,
	},
}

var _floor_tex: Texture2D
var _wall_tex: Texture2D
var _style: Dictionary
var _far_line: TitleTreeline
var _mid_line: TitleTreeline
var _far_base: Vector2
var _mid_base: Vector2
var _cam_offset: Vector2 = Vector2.ZERO
var _has_moon: bool = false
var _bonfire_pos: Vector2 = Vector2.INF
var _layers: Array = []
var _mist: CPUParticles2D
var _fire_nodes: Array[Node] = []
var _embers: CPUParticles2D

func _ready() -> void:
	z_index = -20
	_style = PHASE_STYLE.get(GameState.active_phase, PHASE_STYLE[1])
	_floor_tex = load(_style["floor"])
	if _style.has("modulate"):
		var cm := CanvasModulate.new()
		cm.color = _style["modulate"]
		add_child(cm)
	# Camadas estáticas em ordem de profundidade; desenham uma vez e o shake
	# só move position (ver BackdropLayer). Treelines/névoa/dressing entram
	# DEPOIS — ordem de filhos = ordem de desenho: copas sobre o céu, mist e
	# brasas sobre o palco. Os flags _has_moon/_bonfire_pos são setados pelo
	# dressing ainda no _ready, antes do primeiro frame renderizado — o _draw
	# único de cada camada já os vê.
	_add_layer(SHAKE_FOLLOW_SKY, _draw_sky_layer)
	_add_layer(SHAKE_FOLLOW_FLOOR, _draw_floor_layer)
	if _style["church"]:
		_wall_tex = load("res://assets/sprites/tile_wall_church.png")
		_add_layer(SHAKE_FOLLOW_MID, _draw_church_layer)
	else:
		# Vento mais forte no plano próximo (MID) — profundidade também no balanço.
		_far_line = _add_treeline(_style["far"], FAR_TREES, 1.5, 0.66, HORIZON_Y - 4.0, 41, 1.4)
		_mid_line = _add_treeline(_style["mid"], MID_TREES, 2.3, 1.0, HORIZON_Y + 8.0, 97, 2.6)
		_far_base = _far_line.position
		_mid_base = _mid_line.position
	_spawn_horizon_mist()
	_setup_phase_dressing()

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or cam.offset.is_equal_approx(_cam_offset):
		return
	_cam_offset = cam.offset
	for layer in _layers:
		layer.position = _cam_offset * layer.shake_follow
	if _far_line != null:
		_far_line.position = _far_base + _cam_offset * SHAKE_FOLLOW_FAR
	if _mid_line != null:
		_mid_line.position = _mid_base + _cam_offset * SHAKE_FOLLOW_MID

func _add_layer(follow: float, draw_func: Callable) -> Node2D:
	var layer = BackdropLayerScript.new()
	layer.shake_follow = follow
	layer.draw_callback = draw_func
	add_child(layer)
	_layers.append(layer)
	return layer

func _add_treeline(color: Color, count: int, scale_f: float, height_f: float,
		base_world_y: float, seed_v: int, sway: float) -> TitleTreeline:
	var line := TitleTreeline.new()
	line.static_bounds = Rect2(0.0, 0.0, STRIP_W, height_f * 110.0 + TREE_BAND_H)
	line.base_y = height_f * 110.0
	line.scroll_speed = 0.0
	line.sway_amount = sway
	line.silhouette_color = color
	line.tree_count = count
	line.tree_scale = scale_f
	line.rng_seed = seed_v
	# z relativo 0: filhos desenham depois do _draw do pai (céu/chão) — as copas
	# ficam sobre o céu e a massa da base ancora as árvores sobre o chão.
	line.layer_z = 0
	line.position = Vector2(STRIP_X, base_world_y - height_f * 110.0)
	add_child(line)
	return line

func _draw_sky_layer(canvas: Node2D) -> void:
	canvas.draw_rect(
		Rect2(STRIP_X, SKY_TOP, STRIP_W, HORIZON_Y - SKY_TOP),
		_style["sky"])
	if _has_moon:
		_draw_moon(canvas)

func _draw_floor_layer(canvas: Node2D) -> void:
	_draw_floor(canvas)
	if _bonfire_pos.is_finite():
		_draw_bonfire_logs(canvas)
	if _style["church"]:
		_draw_pews(canvas)

func _draw_church_layer(canvas: Node2D) -> void:
	_draw_church(canvas)

func _draw_moon(canvas: Node2D) -> void:
	# Lua doentia espiando entre as copas — pálida, com mordida de sombra.
	var center := Vector2(452.0, -26.0)
	canvas.draw_circle(center, 17.0, Color(0.72, 0.74, 0.68, 0.85))
	canvas.draw_circle(center + Vector2(6.0, -4.0), 14.0, Color(_style["sky"].r,
		_style["sky"].g, _style["sky"].b, 0.55))

func _draw_bonfire_logs(canvas: Node2D) -> void:
	# Toras carbonizadas sob a chama do FireEffect (P2 — a mata queimando).
	var p := _bonfire_pos
	canvas.draw_rect(Rect2(p.x - 14.0, p.y - 2.0, 28.0, 5.0), Constants.COLOR_BARK_DARK)
	canvas.draw_rect(Rect2(p.x - 9.0, p.y - 6.0, 18.0, 5.0), Constants.COLOR_BARK)
	canvas.draw_rect(Rect2(p.x - 4.0, p.y - 8.0, 8.0, 4.0), Constants.COLOR_BARK_DARK)

func _draw_floor(canvas: Node2D) -> void:
	var rows: int = int((FLOOR_BOTTOM - HORIZON_Y) / float(TILE))
	var cols: int = int(STRIP_W / float(TILE))
	for row: int in rows:
		var y: float = HORIZON_Y + row * TILE
		# Longe (horizonte) escuro, perto claro.
		var depth: float = 1.0 - float(row) / float(maxi(rows - 1, 1))
		var gain: float = _style["floor_gain"]
		var bright: float = lerpf(FLOOR_NEAR_BRIGHT, FLOOR_FAR_BRIGHT, pow(depth, 1.3)) * gain
		# As últimas 4 linhas desvanecem em alpha — o chão funde com o vazio
		# abaixo em vez de terminar numa aresta dura.
		var fade: float = 1.0
		var from_end: int = rows - 1 - row
		if from_end < 4:
			fade = [0.10, 0.28, 0.52, 0.78][from_end]
		var tint := Color(bright, bright, bright, fade)
		for col: int in cols:
			var variant: int = (col * 31 + row * 17) % FLOOR_VARIANTS
			canvas.draw_texture_rect_region(
				_floor_tex,
				Rect2(STRIP_X + col * TILE, y, TILE, TILE),
				Rect2(variant * TILE, 0, TILE, TILE),
				tint)

func _draw_church(canvas: Node2D) -> void:
	# Parede de fundo da nave: duas fiadas de taipa acima do horizonte, escurecendo
	# para cima (a abóbada some na treva).
	for row: int in 2:
		var y: float = HORIZON_Y - (row + 1) * TILE
		var bright: float = 0.62 - row * 0.30
		for col: int in int(STRIP_W / float(TILE)):
			var variant: int = (col * 13 + row * 7) % WALL_VARIANTS
			canvas.draw_texture_rect_region(
				_wall_tex,
				Rect2(STRIP_X + col * TILE, y, TILE, TILE),
				Rect2(variant * TILE, 0, TILE, TILE),
				Color(bright, bright, bright))
	# Cruz torta sobre o altar, no eixo central acima da ação (vocabulário do
	# MapObject._draw_cross, ampliado 2x — silhueta litúrgica, baixo contraste).
	var cx: float = 320.0
	var cy: float = HORIZON_Y - 34.0
	var wood := Constants.COLOR_WOOD_DARK
	var gold := Constants.COLOR_GOLD_DARK
	canvas.draw_rect(Rect2(cx - 4.0, cy - 24.0, 8.0, 48.0), wood)
	canvas.draw_rect(Rect2(cx - 14.0, cy - 12.0, 28.0, 8.0), wood)
	canvas.draw_rect(Rect2(cx - 2.0, cy - 24.0, 4.0, 48.0), gold)
	canvas.draw_rect(Rect2(cx - 14.0, cy - 10.0, 28.0, 2.0), gold)
	# Altar: bloco de pedra sob a cruz, na linha do horizonte.
	canvas.draw_rect(Rect2(cx - 30.0, HORIZON_Y - 12.0, 60.0, 12.0), Constants.COLOR_STONE_DARK)
	canvas.draw_rect(Rect2(cx - 30.0, HORIZON_Y - 12.0, 60.0, 3.0), Constants.COLOR_STONE)

func _draw_pews(canvas: Node2D) -> void:
	# Bancos quebrados flanqueando a nave (fora do terço central da ação),
	# vocabulário do MapObject._draw_pew ampliado.
	for pew_y: float in [210.0, 268.0, 326.0]:
		_draw_pew_silhouette(canvas, 28.0, pew_y)
		_draw_pew_silhouette(canvas, 612.0, pew_y)

func _draw_pew_silhouette(canvas: Node2D, cx: float, cy: float) -> void:
	var wood := Constants.COLOR_WOOD
	var wood_dark := Constants.COLOR_WOOD_DARK
	canvas.draw_rect(Rect2(cx - 36.0, cy + 4.0, 72.0, 8.0), wood_dark)   # assento
	canvas.draw_rect(Rect2(cx - 36.0, cy + 4.0, 72.0, 3.0), wood)
	canvas.draw_rect(Rect2(cx - 36.0, cy - 12.0, 72.0, 6.0), wood_dark)  # encosto
	canvas.draw_rect(Rect2(cx - 36.0, cy - 12.0, 72.0, 2.0), wood)
	canvas.draw_rect(Rect2(cx - 33.0, cy + 10.0, 6.0, 12.0), wood_dark)  # pernas
	canvas.draw_rect(Rect2(cx + 25.0, cy + 10.0, 6.0, 12.0), wood_dark)
	canvas.draw_rect(Rect2(cx - 33.0, cy - 12.0, 4.0, 16.0), wood_dark)  # suportes
	canvas.draw_rect(Rect2(cx + 27.0, cy - 12.0, 4.0, 16.0), wood_dark)

# ─── Vida do palco (névoa, luzes, brasas) ──────────

func _spawn_horizon_mist() -> void:
	# Mesma receita da ForestAmbience._spawn_mist, contida na faixa do horizonte.
	var mist := CPUParticles2D.new()
	mist.texture = ForestLight.LIGHT_TEXTURE
	mist.position = Vector2(320.0, HORIZON_Y + 6.0)
	mist.amount = 6
	mist.lifetime = 9.0
	mist.preprocess = 9.0
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(STRIP_W * 0.5, 24.0)
	mist.direction = Vector2(1, 0)
	mist.spread = 20.0
	mist.gravity = Vector2.ZERO
	mist.initial_velocity_min = 3.0
	mist.initial_velocity_max = 8.0
	mist.scale_amount_min = 0.6
	mist.scale_amount_max = 1.2
	mist.color_ramp = _mist_ramp()
	mist.material = Constants.ADDITIVE_MATERIAL
	_mist = mist
	add_child(mist)

func _mist_ramp() -> Gradient:
	var c := Color(0.30, 0.36, 0.44)
	var grad := Gradient.new()
	grad.set_offset(0, 0.0); grad.set_color(0, Color(c.r, c.g, c.b, 0.0))
	grad.set_offset(1, 1.0); grad.set_color(1, Color(c.r, c.g, c.b, 0.0))
	grad.add_point(0.5, Color(c.r, c.g, c.b, 0.14))
	return grad

## Uma fonte de luz motivada por fase (máx. 2 PointLight2D por arena — piso de
## performance é o Safari/iPhone).
func _setup_phase_dressing() -> void:
	match GameState.active_phase:
		1:
			_has_moon = true
			_add_moon(Color(0.55, 0.65, 0.85), 0.7)
		2:
			_bonfire_pos = Vector2(46.0, 172.0)
			var pre_count: int = get_child_count()
			FireEffect.attach(self, Vector2(46.0, 166.0), 1.4)
			for fi in range(pre_count, get_child_count()):
				_fire_nodes.append(get_child(fi))
		3:
			_has_moon = true
			_add_moon(Color(0.45, 0.70, 0.55), 0.6)
		4:
			_spawn_rising_embers()
		5:
			_add_vitral_light()

func _add_moon(color: Color, energy: float) -> void:
	var light := ForestLight.make(color, energy, 2.6)
	light.position = Vector2(452.0, -26.0)
	add_child(light)

func _add_vitral_light() -> void:
	# Feixe dourado entrando por uma janela alta, inclinado sobre o altar.
	var light := PointLight2D.new()
	light.texture = load("res://assets/sprites/light_vitral.png")
	light.color = Color(0.95, 0.80, 0.45)
	light.energy = 0.9
	light.texture_scale = 1.6
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	light.position = Vector2(396.0, 96.0)
	light.rotation = 0.42
	add_child(light)

func _spawn_rising_embers() -> void:
	# P4: brasas da mata morta subindo do chão da arena (aditivas, sem luz).
	var embers := CPUParticles2D.new()
	embers.position = Vector2(320.0, 330.0)
	embers.amount = 12
	embers.lifetime = 4.0
	embers.preprocess = 4.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(300.0, 100.0)
	embers.direction = Vector2(0, -1)
	embers.spread = 12.0
	embers.gravity = Vector2(0, -16)
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 36.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.2
	embers.color_ramp = _ember_ramp()
	embers.material = Constants.ADDITIVE_MATERIAL
	_embers = embers
	add_child(embers)

## Pausa ou restaura todos os efeitos visuais de background durante o combate.
## Chamado pelo ArenaManager antes da primeira janela de timing para liberar
## orçamento de CPU/GPU para a mecânica de reflexo.
func set_combat_mode(active: bool) -> void:
	if _far_line != null:
		_far_line.visible = not active
	if _mid_line != null:
		_mid_line.visible = not active
	if is_instance_valid(_mist):
		_mist.visible = not active
		_mist.emitting = not active
	for node: Node in _fire_nodes:
		if is_instance_valid(node):
			node.visible = not active
			if node is CPUParticles2D:
				(node as CPUParticles2D).emitting = not active
	if is_instance_valid(_embers):
		_embers.visible = not active
		_embers.emitting = not active
	set_process(not active)

func _ember_ramp() -> Gradient:
	var grad := Gradient.new()
	grad.set_offset(0, 0.0); grad.set_color(0, Color(Constants.COLOR_FIRE_MID, 0.0))
	grad.set_offset(1, 1.0); grad.set_color(1, Color(Constants.COLOR_FIRE_LOW, 0.0))
	grad.add_point(0.3, Color(Constants.COLOR_FIRE_HOT, 0.8))
	return grad
