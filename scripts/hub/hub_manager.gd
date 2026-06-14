extends Node2D

# Acampamento jogável (HUB entre fases). Mini-clareira cercada de mata onde a floresta não
# alcança: fogueira baixa, cachimbo, e a interface de aprimoramentos (HubShop) por cima — cards
# clicáveis das ervas que a Caipora pode fumar, numa faixa no topo. A Caipora anda, recupera HP cheio ao
# entrar e pisa no RASTRO (saída pulsante) para voltar à mata — à próxima exploração pendente
# (advance_phase_via_hub) ou, vindo de uma derrota, ao começo de uma caçada nova (santuário).
#
# Reusa ao máximo a exploração: a MESMA entidade Caipora (movimento/câmera/colisão por
# TileMap), o marcador de saída pulsante (ForestLight + COLOR_EXIT), a fogueira (MapObject
# FIRE), a vida ambiente (AmbientLife/ForestAmbience) e o color-grade (Atmosphere). A compra
# vive no HubShop (purchase_upgrade é a fonte única); aqui só tocamos o SFX da compra.

const ForestLight := preload("res://scripts/exploration/forest_light.gd")
const MapObject := preload("res://scripts/exploration/map_object.gd")
const HubExitBeaconScript := preload("res://scripts/hub/exit_beacon.gd")

# Identidade do acampamento.
const CACHIMBO_TEXTURE := preload("res://assets/sprites/cachimbo.png")

# Variantes de tile no atlas (espelha exploration_manager: source 0 = chão, source 1 = parede).
const FLOOR_VARIANTS := 4
const WALL_VARIANTS := 2

# Clareira do acampamento: retângulo de chão centrado no grid, cercado de parede. O grid
# mantém GRID_WIDTH×GRID_HEIGHT (a câmera da Caipora usa essas dimensões), então a mata em
# volta da clareira emoldura o respiro sem barras pretas.
const CLEARING_WIDTH := 16
const CLEARING_HEIGHT := 12

# ─── Onready ───────────────────────────────────────
@onready var _tilemap: TileMap = $TileMap
@onready var _caipora: Caipora = $Caipora
@onready var _objects: Node2D = $Objects
@onready var _shop: HubShop = $HubShop
@onready var _sfx: SfxSystem = $SfxSystem

# ─── State ─────────────────────────────────────────
var _clearing: Rect2i
var _spawn_pos: Vector2i
var _exit_pos: Vector2i
var _fire_pos: Vector2i
var _locked: bool = false
# Fogueira do acampamento (a pira da Mula a transforma — Santuário).
var _fire: MapObject

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	# O acampamento é o único lugar onde a floresta não alcança: recupera HP cheio.
	GameState.heal_to_full()
	_compute_layout()
	_setup_tilemap()
	_setup_caipora()
	_setup_camp_camera()
	_spawn_exit_marker()
	_spawn_exit_beacon()
	_spawn_camp_identity()
	_spawn_spirits()
	_apply_sanctuary_layers()
	_start_arrival_rites()
	# O HubShop (filho) já está montado no seu _ready; aqui só ligamos o SFX da compra.
	_shop.purchased.connect(_on_purchased)
	_shop.denied.connect(_on_denied)

# Clareira centrada; spawn de um lado, rastro de saída do outro (mesma linha do meio). A
# fogueira fica no centro (vira parede: bloqueia o atalho reto, então o jogador contorna ao
# voltar para o rastro). Os cards de aprimoramento ficam por cima, no HubShop (screen-space).
func _compute_layout() -> void:
	var ox: int = (Constants.GRID_WIDTH - CLEARING_WIDTH) / 2
	var oy: int = (Constants.GRID_HEIGHT - CLEARING_HEIGHT) / 2
	_clearing = Rect2i(ox, oy, CLEARING_WIDTH, CLEARING_HEIGHT)
	var mid_y: int = oy + CLEARING_HEIGHT / 2
	_spawn_pos = Vector2i(ox + 1, mid_y)
	_exit_pos = Vector2i(ox + CLEARING_WIDTH - 2, mid_y)
	_fire_pos = Vector2i(ox + CLEARING_WIDTH / 2, mid_y)

func _is_floor(pos: Vector2i) -> bool:
	return _clearing.has_point(pos)

func _setup_caipora() -> void:
	_caipora.tilemap = _tilemap
	_caipora.position = Vector2(_spawn_pos) * Constants.TILE_SIZE
	_caipora.move_finished.connect(_on_caipora_moved)

# ─── Câmera-diorama do acampamento ─────────────────
# O acampamento é a vitrine do meta-progresso (Santuário dos Encantados): em vez do
# cover da exploração (close na Caipora), a câmera faz CONTAIN da clareira + moldura —
# o santuário lê INTEIRO em retrato e paisagem, com os limit_* pinando o quadro no
# coração do acampamento (diorama estável; a câmera não rola). A mata pintada além do
# grid (FOREST_APRON) cobre o respiro do contain — sem void nas bordas.
const CAMP_VIEW_TILES := Vector2(18.0, 14.0)   # clareira 16×12 + 1 tile de moldura
const CAMP_ZOOM_MAX: float = 2.0               # mesmo teto da arena (tablet)
const CAMP_ZOOM_MIN: float = 0.55              # piso de sanidade p/ viewport degenerada
const FOREST_APRON: int = 12                   # tiles de mata pintados além do grid

func _setup_camp_camera() -> void:
	var cam := _caipora.get_node("Camera2D") as Camera2D
	_fit_camp_camera(cam)
	# Filhos ficam prontos antes do pai: o handler de cover da própria Caipora já está
	# conectado ao size_changed — este conecta DEPOIS, então no resize o contain do
	# acampamento decide por último (gotcha #10: reagir a size_changed sempre).
	get_viewport().size_changed.connect(_fit_camp_camera.bind(cam))

func _fit_camp_camera(cam: Camera2D) -> void:
	var view := CAMP_VIEW_TILES * float(Constants.TILE_SIZE)
	var vp := get_viewport().get_visible_rect().size
	var raw := clampf(minf(vp.x / view.x, vp.y / view.y), CAMP_ZOOM_MIN, CAMP_ZOOM_MAX)
	# Snap por FLOOR (não snap_contain, que arredonda pra cima: em retrato 0.68→1.0
	# estoura o contain e corta a clareira). z <= raw preserva o diorama; com texel < 1
	# o zoom fica fracionário — pixel menos chunky, aceitável na vitrine do acampamento.
	var s := PixelScale.device_scale(get_viewport())
	var texel := floorf(raw * s)
	var z := raw if texel < 1.0 else texel / s
	cam.zoom = Vector2(z, z)
	# Pina o quadro: a janela dos limites tem exatamente o tamanho visível, centrada
	# no coração do acampamento — a câmera fica imóvel enquanto a Caipora anda.
	var visible := vp / z
	var center := _clearing_bounds().get_center()
	cam.limit_left = int(center.x - visible.x * 0.5)
	cam.limit_top = int(center.y - visible.y * 0.5)
	cam.limit_right = int(center.x + visible.x * 0.5)
	cam.limit_bottom = int(center.y + visible.y * 0.5)

# ─── SFX da compra (dono do SfxSystem) ─────────────
## "Fumar a erva": chocalho da colheita e, um tempo de tragada depois, o sopro no
## cachimbo. Timer da cena (morre com ela); fallback preserva o feedback antigo.
const PIPE_SMOKE_DELAY: float = 0.25

func _on_purchased(_key: String) -> void:
	if not _sfx.play_named("herb_pickup"):
		_sfx.play(_sfx.timing_perfect_sound, -3.0)
		return
	get_tree().create_timer(PIPE_SMOKE_DELAY).timeout.connect(
		func() -> void: _sfx.play_named("pipe_smoke"))

func _on_denied(_key: String) -> void:
	_sfx.play(_sfx.ui_click_sound, -8.0)          # insuficiente: clique seco e baixo

# ─── Saída (rastro) ────────────────────────────────
func _on_caipora_moved(grid_pos: Vector2i) -> void:
	if _locked:
		return
	# move_finished = movimento confirmado; o acampamento é chão de mata.
	_sfx.play_named("step_grass", Constants.STEP_VOLUME_DB)
	if grid_pos == _exit_pos:
		_trigger_exit()

func _trigger_exit() -> void:
	_locked = true
	var dest := _exit_destination()
	if not GameState.run_active:
		# Santuário pós-derrota: a run acabou — começa uma caçada nova.
		GameState.start_run()
	GameState.change_screen(dest)

## Destino do rastro: a exploração pendente (run em andamento, definida no avanço de fase)
## ou a Fase 1 (santuário pós-derrota, onde a run recomeça). Pura — o efeito colateral de
## iniciar a run fica em _trigger_exit.
func _exit_destination() -> SignalBus.Screen:
	return GameState.pending_exploration if GameState.run_active else SignalBus.Screen.EXPLORATION

# ─── Marcador de saída (boca de toca coberta de folhas) ───
func _spawn_exit_marker() -> void:
	var half := Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	var center := Vector2(_exit_pos) * Constants.TILE_SIZE + half
	# Boca de toca com folhas (MapObject.BURROW): simboliza a saída pra mata melhor que o
	# tile âmbar — e centra no tile (o Sprite2D antigo ficava meio tile fora do lugar).
	var burrow := MapObject.new()
	_objects.add_child(burrow)
	burrow.setup(MapObject.Type.BURROW, _exit_pos)
	# Luz âmbar pulsante: marca a saída na penumbra sem texto (mesma leitura da exploração).
	var light := ForestLight.make(Constants.COLOR_AMBER, 1.0, 1.8)
	light.position = center
	_objects.add_child(light)
	var tween := create_tween().set_loops()
	tween.tween_property(light, "energy", 2.0, 1.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "energy", 0.9, 1.3).set_trans(Tween.TRANS_SINE)

# Seta de borda que aponta pro rastro enquanto ele está fora do quadro (em retrato a saída
# nasce fora da tela, à direita). Numa CanvasLayer acima do mundo e abaixo do HubShop (layer 10),
# pra ficar visível na metade de baixo livre sem cobrir os cards nem o cabeçalho.
func _spawn_exit_beacon() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var half := Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	var beacon: Control = HubExitBeaconScript.new()
	beacon.setup(Vector2(_exit_pos) * Constants.TILE_SIZE + half)
	layer.add_child(beacon)

# ─── Identidade do acampamento ─────────────────────
# Fogueira no centro, cachimbo ao pé do fogo, vida ambiente sobre a clareira e o color-grade
# da Atmosphere — o único respiro entre as caçadas. Tudo reusado da exploração.
func _spawn_camp_identity() -> void:
	# Fogueira viva (chama desenhada + luz + brasas/fumaça), igual às fases de poucas fogueiras.
	_fire = MapObject.new()
	_objects.add_child(_fire)
	_fire.setup(MapObject.Type.FIRE, _fire_pos, true)

	# Cachimbo descansando no chão, ao lado do fogo (decoração — a Caipora passa por cima).
	var cachimbo := Sprite2D.new()
	cachimbo.texture = CACHIMBO_TEXTURE
	cachimbo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cachimbo.position = Vector2(_fire_pos + Vector2i(1, 0)) * Constants.TILE_SIZE \
		+ Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	cachimbo.scale = Vector2(0.5, 0.5)
	cachimbo.z_index = -1
	_objects.add_child(cachimbo)

	# Vaga-lumes/insetos + neblina/esporos sobre a clareira (área interna).
	var t := Constants.TILE_SIZE
	var bounds := Rect2(Vector2(_clearing.position) * t, Vector2(_clearing.size) * t)
	var life := AmbientLife.new()
	add_child(life)
	life.setup(bounds)
	var ambience := ForestAmbience.new()
	add_child(ambience)
	ambience.setup(bounds)

	# Vinheta/grão/color-grade: costura o acampamento ao mesmo mundo das fases.
	add_child(Atmosphere.new())

# ─── Santuário dos Encantados ──────────────────────
# Os encantados libertados (MetaProgression.freed_bosses) vivem aqui: presenças em
# repouso (CampSpirit) na moldura de mata ao redor da clareira — celas não-caminháveis,
# walkability intocada. O visual de cada espírito é data-driven em CampSpirit.DEFS;
# aqui mora só o layout (a cela de cada um no acampamento).
func _spawn_spirits() -> void:
	var half := Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	for spirit_phase: int in MetaProgression.freed_bosses:
		var spirit := CampSpirit.new()
		_objects.add_child(spirit)
		if not spirit.setup(spirit_phase):
			spirit.queue_free()
			continue
		spirit.position = Vector2(_spirit_anchor(spirit_phase)) * Constants.TILE_SIZE + half
		# Espírito recém-chegado nasce invisível: o rito de chegada o revela (uma vez).
		if not MetaProgression.has_seen_spirit(spirit_phase):
			spirit.modulate.a = 0.0

# Cela de cada espírito na moldura de mata, nos FLANCOS leste/oeste: Mula e Curupira
# a oeste (atrás do spawn), Boitatá e Saci a leste (atrás do rastro). A banda y
# [mid+1, mid+4] é a única legível nas duas orientações: em retrato os cards do
# HubShop cobrem a metade norte, em paisagem a borda sul corta, e a vinheta da
# Atmosphere come os cantos (gotcha #13). Derivado de _clearing.
func _spirit_anchor(spirit_phase: int) -> Vector2i:
	var mid_y: int = _clearing.position.y + _clearing.size.y / 2
	var west: int = _clearing.position.x - 1
	var east: int = _clearing.end.x
	match spirit_phase:
		1: return Vector2i(west, mid_y + 1)
		2: return Vector2i(east, mid_y + 1)
		3: return Vector2i(west, mid_y + 4)
		4: return Vector2i(east, mid_y + 4)
	return _clearing.position

# ─── Transformações do santuário (o grande upgrade visual por encantado) ───
# Cada libertação muda a CENA do acampamento, de forma cumulativa: pira da Mula,
# fogos-fátuos do Boitatá, mata viva do Curupira, vento do Saci. Tudo com as
# ferramentas existentes (CPUParticles2D, ForestLight, MapObject), pixel art chapada,
# densidades mínimas respeitando particle_amount_scale (mobile).
const PYRE_FIRE_SCALE: float = 1.35
const PYRE_LIGHT_ENERGY: float = 1.4
const PYRE_LIGHT_SCALE: float = 3.2
const PYRE_EMBER_AMOUNT: int = 18
const WISP_SPACING: int = 4            # tiles entre fogos-fátuos no perímetro
const WISP_ENERGY: float = 1.0
const WISP_TEXTURE_SCALE: float = 0.8
const FLORA_COUNT: int = 12
const FLORA_SEED: int = 0xCA1B0        # determinístico: o santuário não re-sorteia por visita
const WIND_LEAF_AMOUNT: int = 14
const WIND_DRIFT: float = 46.0

func _apply_sanctuary_layers() -> void:
	for spirit_phase: int in MetaProgression.freed_bosses:
		match spirit_phase:
			1: _layer_mula_pyre()
			2: _layer_boitata_wisps()
			3: _layer_curupira_flora()
			4: _layer_saci_wind()

func _clearing_bounds() -> Rect2:
	var t := float(Constants.TILE_SIZE)
	return Rect2(Vector2(_clearing.position) * t, Vector2(_clearing.size) * t)

## Mula — O Fogo Dela: a fogueira vira pira ritual (chama maior, luz mais quente e de
## raio maior) e as brasas dela flutuam sobre a clareira inteira. O acampamento sai da
## penumbra fria — agora tem o fogo dela.
func _layer_mula_pyre() -> void:
	_fire.scale = Vector2(PYRE_FIRE_SCALE, PYRE_FIRE_SCALE)
	var layer := Node2D.new()
	layer.name = "LayerMulaPyre"
	_objects.add_child(layer)
	var half := Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	var light := ForestLight.make(Constants.COLOR_AMBER, PYRE_LIGHT_ENERGY, PYRE_LIGHT_SCALE)
	light.position = Vector2(_fire_pos) * Constants.TILE_SIZE + half
	layer.add_child(light)
	var embers := CPUParticles2D.new()
	var bounds := _clearing_bounds()
	embers.amount = _scaled_amount(PYRE_EMBER_AMOUNT)
	embers.lifetime = 4.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = bounds.size * 0.5
	embers.position = bounds.get_center()
	embers.gravity = Vector2(0, -10)
	embers.initial_velocity_min = 2.0
	embers.initial_velocity_max = 8.0
	embers.color = Constants.COLOR_AURA_MULA
	layer.add_child(embers)

## Boitatá — A Luz que Ronda: fogos-fátuos pálidos circundam a clareira em pulso lento
## e dessincronizado — o aro de luz que a corrupção não cruza. O acampamento é protegido.
func _layer_boitata_wisps() -> void:
	var layer := Node2D.new()
	layer.name = "LayerBoitataWisps"
	_objects.add_child(layer)
	var wisp_color := Constants.COLOR_AURA_BOITATA.lerp(Color.WHITE, 0.45)
	var half := Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	var i := 0
	for tile: Vector2i in _perimeter_tiles(WISP_SPACING):
		var wisp := ForestLight.make(wisp_color, WISP_ENERGY, WISP_TEXTURE_SCALE)
		wisp.position = Vector2(tile) * Constants.TILE_SIZE + half
		layer.add_child(wisp)
		# Pulso dessincronizado: período levemente diferente por fátuo (nunca em fase).
		var period := 1.4 + 0.17 * float(i % 5)
		var tween := wisp.create_tween().set_loops()
		tween.tween_property(wisp, "energy", WISP_ENERGY * 1.7, period).set_trans(Tween.TRANS_SINE)
		tween.tween_property(wisp, "energy", WISP_ENERGY * 0.6, period).set_trans(Tween.TRANS_SINE)
		i += 1

## Curupira — A Mata Volta a Crescer: vida verde brota na clareira (flora da paleta
## existente, sorteio determinístico). O verde entra como acento de cena — nunca
## competindo com o cristal da Fúria nem com a leitura da Caipora.
func _layer_curupira_flora() -> void:
	var layer := Node2D.new()
	layer.name = "LayerCurupiraFlora"
	_objects.add_child(layer)
	var flora: Array = [MapObject.Type.FERN, MapObject.Type.MOSS, MapObject.Type.VINE,
		MapObject.Type.MUSHROOM, MapObject.Type.ROOTS]
	var rng := RandomNumberGenerator.new()
	rng.seed = FLORA_SEED
	var cands: Array[Vector2i] = []
	for y: int in range(_clearing.position.y, _clearing.end.y):
		for x: int in range(_clearing.position.x, _clearing.end.x):
			var pos := Vector2i(x, y)
			if pos == _fire_pos or pos == _spawn_pos or pos == _exit_pos:
				continue
			cands.append(pos)
	var placed := 0
	while placed < FLORA_COUNT and not cands.is_empty():
		var pick := rng.randi_range(0, cands.size() - 1)
		var pos: Vector2i = cands[pick]
		cands.remove_at(pick)
		var deco := MapObject.new()
		layer.add_child(deco)
		deco.setup(flora[rng.randi_range(0, flora.size() - 1)], pos)
		placed += 1

## Saci — O Vento no Acampamento: folhas em deriva cruzam a clareira com um leve
## redemoinho. O acampamento, antes parado, agora se move — está vivo.
func _layer_saci_wind() -> void:
	var layer := Node2D.new()
	layer.name = "LayerSaciWind"
	_objects.add_child(layer)
	var leaves := CPUParticles2D.new()
	var bounds := _clearing_bounds()
	leaves.amount = _scaled_amount(WIND_LEAF_AMOUNT)
	leaves.lifetime = 5.0
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = bounds.size * 0.5
	leaves.position = bounds.get_center()
	leaves.direction = Vector2(1, 0)
	leaves.spread = 18.0
	leaves.gravity = Vector2(0, 6)
	leaves.initial_velocity_min = WIND_DRIFT * 0.6
	leaves.initial_velocity_max = WIND_DRIFT
	leaves.tangential_accel_min = 14.0
	leaves.tangential_accel_max = 26.0
	leaves.color = Color(0.30, 0.38, 0.16, 0.85)
	layer.add_child(leaves)

# Tiles do anel interno da clareira (a cada `spacing`), para o perímetro de fátuos.
func _perimeter_tiles(spacing: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var left := _clearing.position.x
	var top := _clearing.position.y
	var right := _clearing.end.x - 1
	var bottom := _clearing.end.y - 1
	for x: int in range(left, right + 1, spacing):
		tiles.append(Vector2i(x, top))
		tiles.append(Vector2i(x, bottom))
	for y: int in range(top + spacing, bottom, spacing):
		tiles.append(Vector2i(left, y))
		tiles.append(Vector2i(right, y))
	return tiles

func _scaled_amount(base: int) -> int:
	var vp := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	return maxi(4, int(base * Constants.particle_amount_scale(vp)))

# ─── O rito de chegada (reveal único por encantado) ─────────
# Primeira visita ao acampamento após cada libertação: a clareira escurece um
# instante, o espírito surge (fade-in + brasas na cor da aura) com uma fala seca, e a
# cicatriz sonora do chefe volta EM PAZ (a mesma assinatura da morte, mais baixa).
# Uma vez por encantado (spirits_seen, persistido); 2+ pendentes enfileiram. Skip por
# toque/tecla com carência anti-acidente. Movimento e saída travam durante o rito.
const RITE_DIM_ALPHA: float = 0.5
const RITE_DIM_TIME: float = 0.4
const RITE_FADE_TIME: float = 0.7
const RITE_HOLD_TIME: float = 1.6
const RITE_SKIP_GRACE_MS: int = 400
const RITE_BURST_AMOUNT: int = 14
const RITE_LINES := {
	1: "a mula descansa. o fogo dela é teu agora.",
	2: "a luz do boitatá ronda a clareira. nada atravessa.",
	3: "o parente mais antigo vigia. a mata volta a crescer.",
	4: "o vento entrou no acampamento. o saci fuma em silêncio.",
}

var _rite_queue: Array[int] = []
var _rite_phase: int = 0
var _rite_overlay: CanvasLayer
var _rite_dim: ColorRect
var _rite_label: Label
var _rite_tween: Tween
var _rite_skip_unlock_ms: int = 0

func _start_arrival_rites() -> void:
	for spirit_phase: int in MetaProgression.freed_bosses:
		if not MetaProgression.has_seen_spirit(spirit_phase):
			_rite_queue.append(spirit_phase)
	if _rite_queue.is_empty():
		return
	_locked = true
	_caipora.set_process(false)
	_build_rite_overlay()
	_next_rite()

# Overlay acima do HubShop (10) e abaixo de OptionsPanel (60)/SceneTransition (100):
# o rito é um beat cinematográfico — cobre os cards, engole toques (skip).
func _build_rite_overlay() -> void:
	_rite_overlay = CanvasLayer.new()
	_rite_overlay.layer = 12
	add_child(_rite_overlay)
	_rite_dim = ColorRect.new()
	_rite_dim.color = Color(0, 0, 0, 0)
	_rite_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rite_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rite_dim.gui_input.connect(_on_rite_gui_input)
	_rite_overlay.add_child(_rite_dim)
	_rite_label = Label.new()
	_rite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rite_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rite_label.modulate.a = 0.0
	_rite_label.anchor_left = 0.08
	_rite_label.anchor_right = 0.92
	_rite_label.anchor_top = 0.62
	_rite_label.anchor_bottom = 0.74
	_rite_overlay.add_child(_rite_label)

func _next_rite() -> void:
	if _rite_queue.is_empty():
		_end_rites()
		return
	_rite_phase = _rite_queue.pop_front()
	_rite_skip_unlock_ms = Time.get_ticks_msec() + RITE_SKIP_GRACE_MS
	AudioDirector.play_spirit_rite(_rite_phase)
	_rite_label.text = Lang.t(StringName("rite.%d" % _rite_phase))
	_rite_label.modulate.a = 0.0
	var spirit := _find_spirit(_rite_phase)
	_rite_tween = create_tween()
	_rite_tween.tween_property(_rite_dim, "color:a", RITE_DIM_ALPHA, RITE_DIM_TIME)
	if spirit != null:
		_rite_tween.tween_callback(_burst_embers.bind(
			spirit.global_position, CampSpirit.DEFS[_rite_phase]["aura"]))
		_rite_tween.tween_property(spirit, "modulate:a", 1.0, RITE_FADE_TIME)
	_rite_tween.parallel().tween_property(_rite_label, "modulate:a", 1.0, RITE_FADE_TIME)
	_rite_tween.tween_interval(RITE_HOLD_TIME)
	_rite_tween.tween_property(_rite_dim, "color:a", 0.0, RITE_DIM_TIME)
	_rite_tween.parallel().tween_property(_rite_label, "modulate:a", 0.0, RITE_DIM_TIME)
	_rite_tween.tween_callback(_complete_current_rite)

## Fecha o rito atual (fim natural OU skip): estado final aplicado, rito gravado como
## visto (persiste) e fila segue. Idempotente via _rite_phase == 0.
func _complete_current_rite() -> void:
	if _rite_phase == 0:
		return
	if _rite_tween != null:
		_rite_tween.kill()
	var spirit := _find_spirit(_rite_phase)
	if spirit != null:
		spirit.modulate.a = 1.0
	_rite_dim.color.a = 0.0
	_rite_label.modulate.a = 0.0
	MetaProgression.mark_spirit_seen(_rite_phase)
	_rite_phase = 0
	_next_rite()

func _end_rites() -> void:
	_locked = false
	_caipora.set_process(true)
	if _rite_overlay != null:
		_rite_overlay.queue_free()
		_rite_overlay = null

func _on_rite_gui_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
		_try_skip_rite()

func _unhandled_input(event: InputEvent) -> void:
	if _rite_phase != 0 and event is InputEventKey and event.pressed and not event.echo:
		_try_skip_rite()

func _try_skip_rite() -> void:
	if _rite_phase == 0 or Time.get_ticks_msec() < _rite_skip_unlock_ms:
		return
	_complete_current_rite()

func _burst_embers(at: Vector2, color: Color) -> void:
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = RITE_BURST_AMOUNT
	burst.lifetime = 0.9
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 14.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 70.0
	burst.gravity = Vector2(0, -30)
	burst.color = color.lerp(Color.WHITE, 0.3)
	burst.position = at
	burst.finished.connect(burst.queue_free)
	_objects.add_child(burst)
	burst.emitting = true

func _find_spirit(spirit_phase: int) -> CampSpirit:
	for child: Node in _objects.get_children():
		if child is CampSpirit and child.phase == spirit_phase:
			return child
	return null

# ─── TileMap (mesmo tileset/atlas da exploração) ───
func _setup_tilemap() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1 << (Constants.LAYER_WALL - 1))
	tileset.set_physics_layer_collision_mask(0, 1 << (Constants.LAYER_PLAYER - 1))

	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = preload("res://assets/sprites/tile_floor.png")
	floor_source.texture_region_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	for i: int in FLOOR_VARIANTS:
		floor_source.create_tile(Vector2i(i, 0))
	tileset.add_source(floor_source, 0)

	var wall_source := TileSetAtlasSource.new()
	wall_source.texture = preload("res://assets/sprites/tile_wall.png")
	wall_source.texture_region_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	for i: int in WALL_VARIANTS:
		wall_source.create_tile(Vector2i(i, 0))
	tileset.add_source(wall_source, 1)

	_tilemap.tile_set = tileset
	_paint_map()

# Source 0 = chão (andável) na clareira; source 1 = parede (bloqueia) na mata em volta.
# A Caipora colide nativamente: _would_collide() trata source_id == 1 como parede.
# A mata se estende FOREST_APRON tiles além do grid: o contain da câmera-diorama
# respira além dos 26×18 e não pode mostrar void (posmod: coordenadas negativas).
func _paint_map() -> void:
	for y: int in range(-FOREST_APRON, Constants.GRID_HEIGHT + FOREST_APRON):
		for x: int in range(-FOREST_APRON, Constants.GRID_WIDTH + FOREST_APRON):
			var pos := Vector2i(x, y)
			# A fogueira no centro bloqueia (parede sob o fogo); o resto da clareira é chão.
			if _is_floor(pos) and pos != _fire_pos:
				var fv: int = posmod(x * 7 + y * 13, FLOOR_VARIANTS)
				_tilemap.set_cell(0, pos, 0, Vector2i(fv, 0))
			else:
				var wv: int = posmod(x * 5 + y * 11, WALL_VARIANTS)
				_tilemap.set_cell(0, pos, 1, Vector2i(wv, 0))
