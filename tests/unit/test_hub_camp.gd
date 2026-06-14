extends GutTest

## Acampamento jogável (Etapa 1 da Fase 9): a cena monta a clareira (chão cercado de mata),
## posiciona a Caipora no spawn e o rastro de saída, e o destino do rastro segue a run
## pendente (entre fases) ou recomeça a caçada (santuário). O D-pad de toque reconhece o HUB
## como gameplay (a Caipora caminha pelo acampamento). Tudo headless.

const HubManagerScript := preload("res://scripts/hub/hub_manager.gd")

var _hub: Node2D
var _saved_run_active: bool
var _saved_pending: int
var _saved_save_path: String

func before_each() -> void:
	_saved_run_active = GameState.run_active
	_saved_pending = GameState.pending_exploration
	# O rito de chegada persiste spirits_seen: redireciona o save (não toca o do dev).
	_saved_save_path = MetaProgression.SAVE_PATH
	MetaProgression.SAVE_PATH = "user://test_hub_savegame.json"

func after_each() -> void:
	if is_instance_valid(_hub):
		_hub.queue_free()
	GameState.run_active = _saved_run_active
	GameState.pending_exploration = _saved_pending
	MetaProgression.freed_bosses = []
	MetaProgression.spirits_seen = []
	if FileAccess.file_exists(MetaProgression.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgression.SAVE_PATH))
	MetaProgression.SAVE_PATH = _saved_save_path

func _instantiate() -> void:
	_hub = load("res://scenes/hub/hub.tscn").instantiate()
	add_child_autofree(_hub)
	await wait_frames(1)

# ── A clareira é montada: chão no spawn e na saída, mata (parede) na borda ──
func test_clearing_is_painted() -> void:
	await _instantiate()
	var tm: TileMap = _hub._tilemap
	assert_eq(tm.get_cell_source_id(0, _hub._spawn_pos), 0, "spawn é chão (source 0)")
	assert_eq(tm.get_cell_source_id(0, _hub._exit_pos), 0, "saída é chão (source 0)")
	assert_eq(tm.get_cell_source_id(0, Vector2i(0, 0)), 1, "borda do grid é parede (source 1)")
	assert_true(_hub._is_floor(_hub._spawn_pos), "spawn dentro da clareira")
	assert_false(_hub._is_floor(Vector2i(0, 0)), "canto do grid fora da clareira")

# ── Caipora nasce no spawn, longe do rastro de saída ──
func test_caipora_spawns_at_spawn_tile() -> void:
	await _instantiate()
	assert_eq(_hub._caipora.position, Vector2(_hub._spawn_pos) * Constants.TILE_SIZE,
		"Caipora posicionada no tile de spawn")
	assert_ne(_hub._spawn_pos, _hub._exit_pos, "spawn e saída em tiles distintos")

# ── O rastro de saída pulsante é instanciado (boca de toca + luz) ──
func test_exit_marker_spawned() -> void:
	await _instantiate()
	assert_gte(_hub._objects.get_child_count(), 2, "toca de saída + luz em Objects")

# ── Destino do rastro: run em andamento segue a exploração pendente ──
func test_exit_follows_pending_when_run_active() -> void:
	await _instantiate()
	GameState.run_active = true
	GameState.pending_exploration = SignalBus.Screen.EXPLORATION_PHASE3
	assert_eq(_hub._exit_destination(), SignalBus.Screen.EXPLORATION_PHASE3,
		"entre fases: rastro leva à exploração pendente")

# ── Início da run pelo acampamento: start_run() leva o rastro à Fase 1 ──
# A run começa no HUB (main_menu abre o acampamento antes da mata); como start_run() define
# pending_exploration = EXPLORATION, o rastro de saída cai direto na Exploração da Fase 1.
func test_launch_via_hub_leads_to_phase1() -> void:
	await _instantiate()
	GameState.start_run()
	assert_true(GameState.run_active, "run ativa ao iniciar pelo acampamento")
	assert_eq(_hub._exit_destination(), SignalBus.Screen.EXPLORATION,
		"abertura: do acampamento o rastro leva à Fase 1")

# ── Destino do rastro: santuário pós-derrota recomeça na Fase 1 ──
func test_exit_starts_fresh_when_no_run() -> void:
	await _instantiate()
	GameState.run_active = false
	GameState.pending_exploration = SignalBus.Screen.EXPLORATION_PHASE4
	assert_eq(_hub._exit_destination(), SignalBus.Screen.EXPLORATION,
		"santuário: rastro recomeça a caçada na Fase 1")

# ── Santuário dos Encantados: espíritos dos bosses libertados vivem no acampamento ──
func test_no_spirits_when_none_freed() -> void:
	MetaProgression.freed_bosses = []
	await _instantiate()
	assert_eq(_count_spirits(), 0, "sem libertação, sem espírito no acampamento")

func test_one_spirit_per_freed_boss_wanders_clearing() -> void:
	MetaProgression.freed_bosses = [1, 2, 3, 4] as Array[int]
	await _instantiate()
	assert_eq(_count_spirits(), 4, "um espírito por encantado libertado")
	var bounds: Rect2 = _hub._clearing_bounds()
	for spirit: CampSpirit in _spirits():
		assert_true(spirit._wandering,
			"espírito da fase %d perambula livremente" % spirit.phase)
		assert_true(bounds.has_point(spirit.position),
			"espírito nasce dentro da clareira (fase %d)" % spirit.phase)

func test_partial_sanctuary_spawns_only_freed() -> void:
	MetaProgression.freed_bosses = [2] as Array[int]
	await _instantiate()
	assert_eq(_count_spirits(), 1, "só o Boitatá libertado tem presença")

func _count_spirits() -> int:
	return _spirits().size()

func _spirits() -> Array:
	var out: Array = []
	for child: Node in _hub._objects.get_children():
		if child is CampSpirit:
			out.append(child)
	return out

# ── Transformações do santuário: cada libertação muda a cena, cumulativo ──
func test_sanctuary_layers_transform_camp() -> void:
	MetaProgression.freed_bosses = [1, 2, 3, 4] as Array[int]
	await _instantiate()
	# Mula: a fogueira virou pira (maior) + luz e brasas de clareira.
	assert_gt(_hub._fire.scale.x, 1.0, "pira da Mula: fogueira cresce")
	assert_not_null(_hub.find_child("LayerMulaPyre", true, false), "camada da pira")
	# Boitatá: perímetro de fogos-fátuos.
	var wisps: Node = _hub.find_child("LayerBoitataWisps", true, false)
	assert_not_null(wisps, "camada de fátuos")
	assert_gte(wisps.get_child_count(), 6, "aro de fátuos circunda a clareira")
	# Curupira: a mata viva brota na clareira.
	var flora: Node = _hub.find_child("LayerCurupiraFlora", true, false)
	assert_not_null(flora, "camada de flora")
	assert_eq(flora.get_child_count(), HubManagerScript.FLORA_COUNT, "flora completa")
	# Saci: o vento entra.
	assert_not_null(_hub.find_child("LayerSaciWind", true, false), "camada de vento")

func test_sanctuary_layers_absent_without_freed() -> void:
	MetaProgression.freed_bosses = []
	await _instantiate()
	assert_eq(_hub._fire.scale, Vector2.ONE, "fogueira baixa sem a Mula")
	for layer_name: String in ["LayerMulaPyre", "LayerBoitataWisps",
			"LayerCurupiraFlora", "LayerSaciWind"]:
		assert_null(_hub.find_child(layer_name, true, false),
			"%s só existe com o encantado libertado" % layer_name)

func test_sanctuary_partial_applies_only_freed_layers() -> void:
	MetaProgression.freed_bosses = [3] as Array[int]
	await _instantiate()
	assert_not_null(_hub.find_child("LayerCurupiraFlora", true, false),
		"Curupira libertado → mata viva")
	assert_null(_hub.find_child("LayerMulaPyre", true, false), "sem pira sem a Mula")
	assert_eq(_hub._fire.scale, Vector2.ONE, "fogueira baixa sem a Mula")

func test_curupira_flora_is_deterministic_per_visit() -> void:
	MetaProgression.freed_bosses = [3] as Array[int]
	await _instantiate()
	var first := _flora_positions()
	_hub.queue_free()
	await _instantiate()
	assert_eq(_flora_positions(), first, "flora não re-sorteia por visita")

func _flora_positions() -> Array:
	var flora: Node = _hub.find_child("LayerCurupiraFlora", true, false)
	var out: Array = []
	for deco: Node2D in flora.get_children():
		out.append(deco.position)
	return out

# ── O rito de chegada: revela o espírito UMA vez, trava o acampamento, enfileira ──
func test_arrival_rite_reveals_and_marks_seen() -> void:
	MetaProgression.freed_bosses = [1] as Array[int]
	MetaProgression.spirits_seen = []
	await _instantiate()
	assert_true(_hub._locked, "rito trava a saída")
	assert_not_null(_hub._rite_overlay, "overlay do rito presente")
	var spirit: CampSpirit = _hub._find_spirit(1)
	assert_eq(spirit.modulate.a, 0.0, "espírito pendente nasce invisível")
	_hub._complete_current_rite()
	await wait_frames(1)
	assert_eq(spirit.modulate.a, 1.0, "rito revela o espírito")
	assert_true(MetaProgression.has_seen_spirit(1), "rito gravado como visto (persiste)")
	assert_false(_hub._locked, "fim dos ritos devolve o acampamento")

func test_no_rite_when_spirit_already_seen() -> void:
	MetaProgression.freed_bosses = [1] as Array[int]
	MetaProgression.spirits_seen = [1] as Array[int]
	await _instantiate()
	assert_null(_hub._rite_overlay, "sem rito pendente, sem overlay")
	assert_false(_hub._locked, "acampamento livre")
	assert_eq(_hub._find_spirit(1).modulate.a, 1.0, "espírito já visto nasce visível")

func test_rites_queue_for_multiple_pending() -> void:
	MetaProgression.freed_bosses = [1, 2] as Array[int]
	MetaProgression.spirits_seen = []
	await _instantiate()
	_hub._complete_current_rite()
	assert_true(_hub._locked, "segundo rito segue na fila")
	_hub._complete_current_rite()
	await wait_frames(1)
	assert_true(MetaProgression.has_seen_spirit(1), "primeiro rito visto")
	assert_true(MetaProgression.has_seen_spirit(2), "segundo rito visto")
	assert_false(_hub._locked, "fila esvaziada devolve o acampamento")

# ── Câmera = exploração: cover/follow (fecha na Caipora, presa ao grid) ──
func test_camp_camera_follows_like_exploration() -> void:
	await _instantiate()
	var cam: Camera2D = _hub._caipora.get_node("Camera2D")
	var vp: Vector2 = _hub.get_viewport().get_visible_rect().size
	# Limites no grid inteiro (idêntico à câmera nativa da Caipora na exploração) — a câmera
	# acompanha a Caipora em vez de pinar o quadro no acampamento.
	assert_eq(cam.limit_left, 0, "limite esquerdo no grid")
	assert_eq(cam.limit_top, 0, "limite superior no grid")
	assert_eq(cam.limit_right, Constants.GRID_WIDTH * Constants.TILE_SIZE,
		"limite direito no grid")
	assert_eq(cam.limit_bottom, Constants.GRID_HEIGHT * Constants.TILE_SIZE,
		"limite inferior no grid")
	# Cover: a área visível cabe DENTRO do mapa nos dois eixos (zoom fecha, não miniaturiza).
	var visible := vp / cam.zoom.x
	assert_lte(visible.x, Constants.GRID_WIDTH * Constants.TILE_SIZE + 0.01,
		"cover: largura visível ≤ mapa")
	assert_lte(visible.y, Constants.GRID_HEIGHT * Constants.TILE_SIZE + 0.01,
		"cover: altura visível ≤ mapa")

# ── O D-pad de toque trata o HUB como gameplay (a Caipora anda no acampamento) ──
func test_hub_is_gameplay_for_dpad() -> void:
	var touch_controls = preload("res://scripts/ui/controls_hud.gd").new()
	add_child_autofree(touch_controls)
	assert_true(touch_controls._is_gameplay_screen(SignalBus.Screen.HUB),
		"D-pad visível no acampamento jogável")
	assert_true(touch_controls._is_gameplay_screen(SignalBus.Screen.EXPLORATION),
		"D-pad visível na exploração (sem regressão)")
	assert_false(touch_controls._is_gameplay_screen(SignalBus.Screen.MAIN_MENU),
		"D-pad oculto no menu (sem regressão)")
