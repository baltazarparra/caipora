extends Node2D

# Manager ÚNICO de exploração para as 4 fases. O comportamento por fase é DADO
# (composição, não herança): geração vem de MapConfig.for_phase(phase) e a
# apresentação/rota vem de _build_profile(). Cada cena .tscn aponta para este
# script e define `phase`. Cores do CanvasModulate ficam na própria cena.

const MapObject := preload("res://scripts/exploration/map_object.gd")
const ForestLight := preload("res://scripts/exploration/forest_light.gd")
const ForestAmbience := preload("res://scripts/exploration/forest_ambience.gd")
const FireEffect := preload("res://scripts/exploration/fire_effect.gd")

# Cenas de arena por fase.
const MULA_SCENE        := preload("res://scenes/arena/mula.tscn")
const BOITATA_SCENE     := preload("res://scenes/arena/boitata.tscn")
const CACADOR_SCENE     := preload("res://scenes/arena/cacador.tscn")
const BRUXO_SCENE       := preload("res://scenes/arena/bruxo.tscn")
const CURUPIRA_SCENE    := preload("res://scenes/arena/curupira.tscn")
const SACI_SCENE        := preload("res://scenes/arena/saci.tscn")
const JESUITA_SCENE     := preload("res://scenes/arena/jesuita.tscn")
const DIALOGUE_SCENE    := preload("res://scenes/ui/dialogue_screen.tscn")
const BOSS_INTRO_SCENE  := preload("res://scenes/ui/boss_intro_screen.tscn")

# SpriteFrames dos bosses — usadas na apresentação (Mega Man) antes do diálogo.
const MULA_FRAMES     := preload("res://assets/sprites/mula_sprite_frames.tres")
const BOITATA_FRAMES  := preload("res://assets/sprites/boitata_sprite_frames.tres")
const CURUPIRA_FRAMES := preload("res://assets/sprites/curupira_sprite_frames.tres")
const SACI_FRAMES     := preload("res://assets/sprites/saci_sprite_frames.tres")
const JESUITA_FRAMES  := preload("res://assets/sprites/jesuita_sprite_frames.tres")

# Inimigos comuns: a cena de arena é escolhida pelo tipo do comum (caçador/bruxo).
# Na Fase 5 os "monstros" são os 4 chefes convertidos → suas cenas de chefe.
const REGULAR_SCENES := {
	"cacador": CACADOR_SCENE,
	"bruxo": BRUXO_SCENE,
	"mula": MULA_SCENE,
	"boitata": BOITATA_SCENE,
	"curupira": CURUPIRA_SCENE,
	"saci": SACI_SCENE,
}

# Tipos de comum que são, na verdade, chefes (Fase 5): mantêm o HP de chefe da
# própria cena e exibem sprite/aura de chefe no mapa.
const MINIBOSS_TYPES := ["mula", "boitata", "curupira", "saci"]

# Variantes de tile no atlas (ver scripts/tools/gen_tiles.py).
const FLOOR_VARIANTS := 4
const WALL_VARIANTS := 2
const SHADE_VARIANTS := 3

# Atlas de piso/parede por tema. O profile da fase escolhe via "floor_texture"/
# "wall_texture"; o default é a floresta (fases 1–4). Fase 5 = igreja colonial.
const FLOOR_TEXTURE := preload("res://assets/sprites/tile_floor.png")
const WALL_TEXTURE := preload("res://assets/sprites/tile_wall.png")
const FLOOR_TEXTURE_CHURCH := preload("res://assets/sprites/tile_floor_church.png")
const WALL_TEXTURE_CHURCH := preload("res://assets/sprites/tile_wall_church.png")
const SHADE_TEXTURE := preload("res://assets/sprites/tile_shade.png")

# Aura da Caipora pela névoa/casa (= sprite.offset.y(-12) × scale(0.8); x=0).
const CAIPORA_AURA_OFFSET := Vector2(0, -10)
const CAIPORA_AURA_LIGHT_SCALE: float = 1.5
const FOG_REVEAL_RADIUS: float = 192.0  # dobro do padrão — Caipora arde na névoa

enum Aura { NONE, TORCH, FIRE }
enum ExitMarker { NONE, SIMPLE, PULSING }

# Paletas de decoração temáticas.
const DECO_FOREST: Array[MapObject.Type] = [
	MapObject.Type.ROOTS, MapObject.Type.MOSS, MapObject.Type.VINE,
	MapObject.Type.FERN, MapObject.Type.MUSHROOM,
]
const DECO_FIRE: Array[MapObject.Type] = [
	MapObject.Type.DEAD_TREE, MapObject.Type.BONES, MapObject.Type.STUMP,
	MapObject.Type.BLOOD_POOL, MapObject.Type.ROCK,
]
# Fase 5 (A Igreja): props litúrgicos + ossos/sangue do altar.
const DECO_CHURCH: Array[MapObject.Type] = [
	MapObject.Type.PEW, MapObject.Type.CROSS, MapObject.Type.MIRROR,
	MapObject.Type.FONT, MapObject.Type.CANDLE,
	MapObject.Type.BONES, MapObject.Type.BLOOD_POOL,
]

# Diálogos: funções em vez de const para que Lang.t() leia o idioma corrente.
func _mula_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": Lang.t(&"dialogue.caipora"), "text": Lang.t(&"dlg.mula.1")},
		{"speaker": Lang.t(&"boss.mula.name"),   "text": Lang.t(&"dlg.mula.2")},
	]
func _boitata_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": Lang.t(&"dialogue.caipora"),  "text": Lang.t(&"dlg.boitata.1")},
		{"speaker": Lang.t(&"boss.boitata.name"), "text": Lang.t(&"dlg.boitata.2")},
	]
func _curupira_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": Lang.t(&"dialogue.caipora"),   "text": Lang.t(&"dlg.curupira.1")},
		{"speaker": Lang.t(&"boss.curupira.name"), "text": Lang.t(&"dlg.curupira.2")},
	]
func _saci_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": Lang.t(&"dialogue.caipora"), "text": Lang.t(&"dlg.saci.1")},
		{"speaker": Lang.t(&"boss.saci.name"),   "text": Lang.t(&"dlg.saci.2")},
	]
# Fase FINAL: a fala marcante do Jesuíta abre a FASE (antes de explorar a igreja),
# não a porta do chefe. Por isso o diálogo de boss é vazio (já falou na abertura).
func _jesuita_intro_dialogue() -> Array[Dictionary]:
	return [
		{"speaker": Lang.t(&"boss.jesuita.name"), "text": Lang.t(&"dlg.jesuita.intro.1")},
		{"speaker": Lang.t(&"dialogue.caipora"),  "text": Lang.t(&"dlg.jesuita.intro.2")},
	]

# ─── Exports ───────────────────────────────────────
@export var phase: int = 1

# ─── Onready ───────────────────────────────────────
@onready var _tilemap: TileMap = $TileMap
@onready var _caipora: Caipora = $Caipora
@onready var _enemies_container: Node2D = $Enemies
@onready var _objects_container: Node2D = $Objects

# ─── State ─────────────────────────────────────────
var _config: MapConfig
var _profile: Dictionary
var _map: GeneratedMap
var _map_enemies: Array[MapEnemy] = []
var _player_grid_pos: Vector2i = Vector2i.ZERO
var _locked: bool = false
var _key_node: Node2D = null
var _chest_node: Node2D = null
var _fog: FogOfWar
# Bolsa de fragmentos (souls-like): nó caído + tile onde a Caipora a recupera ao pisar.
var _bag_node: Node2D = null
var _bag_pos: Vector2i = Vector2i(-1, -1)
# SFX táteis da exploração (passos, dano de hazard). Criado por código: as cenas de
# exploração não têm nó SfxSystem e editar .tscn à mão é proibido (gotcha 7).
var _sfx: SfxSystem

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	GameState.active_phase = phase
	_profile = _build_profile()
	_sfx = SfxSystem.new()
	add_child(_sfx)
	_config = MapConfig.for_phase(phase)
	# Santuário dos Encantados: guardião libertado saiu da fase para sempre — o gerador
	# não o coloca. O estado meta entra AQUI (factory e gerador seguem puros); o avanço
	# da fase segue pelo tile de saída, que já existe em toda fase exceto a FINAL.
	_config.boss_freed = MetaProgression.is_boss_freed(phase)
	var reached: int = _profile["phase_reached_on_enter"]
	if reached > 0 and MetaProgression.phase_reached < reached:
		MetaProgression.phase_reached = reached
		MetaProgression.save_progress()
	_map = MapGenerator.new().generate(_config, GameState.map_seed_for_phase(phase))
	_setup_tilemap()
	_setup_player()
	_spawn_enemies()
	_spawn_objects()
	_spawn_fragment_bag()
	if _config.has_exit:
		_spawn_exit_marker()
	if _profile["has_fog"]:
		_spawn_fog()
	if _profile["ambient_life"]:
		_spawn_ambient_life()
	add_child(Atmosphere.new())
	_maybe_show_intro_dialogue()

func _setup_player() -> void:
	var restoring := GameState.player_map_pos != Vector2i(-1, -1)
	var preferred := GameState.player_map_pos if restoring else _map.player_start
	# Na restauração (volta do combate) a posição é EXATA: o safe_spawn só vale para
	# a entrada fresca na fase — senão o jogador "saltaria" ao retornar do combate.
	var start: Vector2i = preferred
	if not restoring and _profile["safe_spawn"]:
		start = _find_safe_spawn(preferred)
	_player_grid_pos = start
	_caipora.tilemap = _tilemap
	_caipora.position = Vector2(start) * Constants.TILE_SIZE
	_caipora.move_finished.connect(_on_player_moved)
	_attach_aura()

func _attach_aura() -> void:
	match _profile["aura"]:
		Aura.TORCH:
			# Poça de luz fria (luar) que segue a Caipora — leitura na noite fechada.
			var torch := ForestLight.make(Color(0.88, 0.93, 1.0), 1.25, 1.6)
			_caipora.add_child(torch)
		Aura.FIRE:
			# Aura de fogo viva: luz quente + chama/brasas/fumaça.
			FireEffect.attach(_caipora, CAIPORA_AURA_OFFSET, CAIPORA_AURA_LIGHT_SCALE)

func _spawn_enemies() -> void:
	for def: Dictionary in _map.enemies:
		if def["id"] in GameState.defeated_enemy_ids:
			continue
		var spawn := Vector2i(def["x"], def["y"])
		# Restaura a posição salva no último combate; senão, o spawn do mapa gerado.
		var pos: Vector2i = GameState.map_enemy_positions.get(def["id"], spawn)
		var enemy := MapEnemy.new()
		_enemies_container.add_child(enemy)
		enemy.setup(def["id"], pos, def["boss"], def.get("boss_type", ""), spawn,
			def.get("enemy_type", ""))
		_map_enemies.append(enemy)

func _spawn_objects() -> void:
	# Decoração temática (tipos determinísticos da paleta da fase).
	var deco_rng := RandomNumberGenerator.new()
	deco_rng.seed = GameState.map_seed_for_phase(phase) ^ 0xDEC0
	var palette: Array = _profile["deco_palette"]
	for pos: Vector2i in _map.decorations:
		var type: MapObject.Type = palette[deco_rng.randi_range(0, palette.size() - 1)]
		_make_object(type, pos)

	# Marca de paz: um totem na cela onde o guardião libertado postaria — a mata
	# reconhece quem a libertou (a toca virou passagem).
	if _map.peace_pos != Vector2i(-1, -1):
		_make_object(MapObject.Type.TOTEM, _map.peace_pos)

	if _config.has_chest and not GameState.chest_opened and _map.chest_pos != Vector2i(-1, -1):
		_chest_node = _make_object(MapObject.Type.CHEST, _map.chest_pos)
	if _config.has_key and not GameState.has_key and _map.key_pos != Vector2i(-1, -1):
		_key_node = _make_object(MapObject.Type.KEY, _map.key_pos)

	# Hazards do mapa
	for y: int in _map.tiles.size():
		var row: Array = _map.tiles[y]
		for x: int in row.size():
			var ch: String = row[x]
			if ch == "R":
				_make_object(MapObject.Type.FIRE, Vector2i(x, y))
			elif ch == "S":
				_make_object(MapObject.Type.SPIKE, Vector2i(x, y))

## Souls-like: se há uma bolsa derrubada nesta fase, recria-a no tile da morte. O mapa é
## sorteado por run, então o tile pode ter virado parede — reancora no caminhável mais
## próximo. Marca a posição (_bag_pos) e ergue um brilho âmbar pulsante pra guiar a volta.
func _spawn_fragment_bag() -> void:
	if not MetaProgression.has_bag_in_phase(phase):
		return
	var pos := _nearest_walkable(MetaProgression.frag_bag_pos)
	_bag_pos = pos
	_bag_node = _make_object(MapObject.Type.BAG, pos)
	# Brilho âmbar pulsante centrado no tile da bolsa (relativo ao nó, que já está em pos*TILE).
	var light := ForestLight.make(Constants.COLOR_AMBER, 1.0, 1.1)
	light.position = Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
	_bag_node.add_child(light)
	# Tween VINCULADO à luz (não ao manager): ao recuperar a bolsa, `_bag_node.queue_free()`
	# libera a luz e o Godot mata este tween junto. Vinculá-lo ao manager (`create_tween()`)
	# deixava um loop infinito apontando para um nó liberado — o passo do tween girava sem
	# consumir tempo e CONGELAVA o jogo logo após a mensagem de recuperação.
	var tween := light.create_tween().set_loops()
	tween.tween_property(light, "energy", 1.5, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "energy", 0.8, 0.9).set_trans(Tween.TRANS_SINE)

## Reaver a bolsa: devolve todos os fragmentos (a HUD pulsa via fragment_gained) e remove o nó.
func _recover_fragment_bag() -> void:
	MetaProgression.recover_fragment_bag()
	if _bag_node != null:
		_bag_node.queue_free()
		_bag_node = null
	_bag_pos = Vector2i(-1, -1)

## Tile caminhável mais próximo de `pos` (BFS em 4-direções, limitado ao grid). Devolve `pos`
## se nada for encontrado. Usado para reancorar a bolsa quando o mapa novo a deixou na parede.
func _nearest_walkable(pos: Vector2i) -> Vector2i:
	var queue: Array[Vector2i] = [pos]
	var visited: Dictionary = {pos: true}
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if _is_walkable(p):
			return p
		for d in dirs:
			var n := p + d
			if not visited.has(n) and n.x >= 0 and n.x < Constants.GRID_WIDTH \
					and n.y >= 0 and n.y < Constants.GRID_HEIGHT:
				visited[n] = true
				queue.append(n)
	return pos

func _spawn_exit_marker() -> void:
	var pos := _map.exit_pos
	if _profile["exit_marker"] == ExitMarker.SIMPLE:
		var marker := Sprite2D.new()
		marker.texture = preload("res://assets/sprites/tile_floor.png")
		marker.modulate = Constants.COLOR_EXIT
		marker.position = Vector2(pos) * Constants.TILE_SIZE
		add_child(marker)
	elif _profile["exit_marker"] == ExitMarker.PULSING:
		var center := Vector2(pos) * Constants.TILE_SIZE + Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
		var marker := Sprite2D.new()
		marker.texture = preload("res://assets/sprites/tile_floor.png")
		marker.modulate = Constants.COLOR_EXIT
		marker.position = center - Vector2(Constants.TILE_SIZE, Constants.TILE_SIZE) * 0.5
		add_child(marker)
		# Luz âmbar pulsante: marca a saída na escuridão sem texto.
		var light := ForestLight.make(Constants.COLOR_AMBER, 1.0, 1.0)
		light.position = center
		add_child(light)
		var tween := create_tween().set_loops()
		tween.tween_property(light, "energy", 1.4, 1.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(light, "energy", 0.7, 1.1).set_trans(Tween.TRANS_SINE)

func _spawn_ambient_life() -> void:
	# Vaga-lumes + insetos + neblina/esporos/god rays sobre a área interna.
	var t := Constants.TILE_SIZE
	var area := Rect2(t, t, (Constants.GRID_WIDTH - 2) * t, (Constants.GRID_HEIGHT - 2) * t)
	var life := AmbientLife.new()
	add_child(life)
	life.setup(area)
	var ambience := ForestAmbience.new()
	add_child(ambience)
	ambience.setup(area)

func _spawn_fog() -> void:
	_fog = FogOfWar.new()
	add_child(_fog)
	_fog.reveal_radius = FOG_REVEAL_RADIUS
	_fog.track(_caipora)
	_update_fog()

func _update_fog() -> void:
	if _fog == null:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var world_center := Vector2(_player_grid_pos) * Constants.TILE_SIZE + Vector2(Constants.TILE_SIZE * 0.5, Constants.TILE_SIZE * 0.5)
	_fog.update_position(world_center, cam)

# ─── Turn System ───────────────────────────────────
func _on_player_moved(new_grid_pos: Vector2i) -> void:
	if _locked:
		return
	_player_grid_pos = new_grid_pos
	# move_finished só dispara em movimento CONFIRMADO (colisão nem emite) —
	# passo bloqueado nunca soa. Fase 5 pisa em laje; o resto, em serrapilheira.
	_sfx.play_named(_profile["step_sfx"], Constants.STEP_VOLUME_DB)
	if _profile["has_fog"]:
		_update_fog()

	# Saída (fases com tile 'E') → acampamento → próxima fase
	if _config.has_exit and new_grid_pos == _map.exit_pos:
		_locked = true
		# advance_phase_via_hub já zera a continuidade (jogador/inimigos no spawn na fase nova).
		GameState.advance_phase_via_hub(_profile["next_screen_on_exit"])
		return

	# Bolsa de fragmentos (souls-like): pisar nela reaver TODOS os fragmentos derrubados na morte.
	if _bag_node != null and new_grid_pos == _bag_pos:
		_recover_fragment_bag()

	# Chave
	if _config.has_key and new_grid_pos == _map.key_pos and not GameState.has_key:
		GameState.has_key = true
		if _key_node != null:
			_key_node.visible = false

	# Baú
	if _config.has_chest and new_grid_pos == _map.chest_pos and not GameState.chest_opened:
		if GameState.has_key:
			_open_chest()

	# Colisão com inimigo
	for enemy in _map_enemies:
		if enemy.grid_pos == new_grid_pos:
			_trigger_combat(enemy)
			return

	# Hazard
	var ch := _map.char_at(new_grid_pos)
	if ch == "R" or ch == "S":
		_apply_hazard_damage()
		if _locked:
			return

	_run_enemy_turns()

func _open_chest() -> void:
	GameState.chest_opened = true
	GameState.caipora_max_hp += 1
	GameState.caipora_current_hp = mini(GameState.caipora_current_hp + 1, GameState.caipora_max_hp)
	SignalBus.caipora_health_changed.emit(GameState.caipora_current_hp, GameState.caipora_max_hp)
	SignalBus.chest_opened.emit()
	if _chest_node != null:
		_chest_node.visible = false

func _apply_hazard_damage() -> void:
	var dmg: int = _profile["hazard_damage"]
	GameState.caipora_current_hp = maxi(0, GameState.caipora_current_hp - dmg)
	_sfx.play_named("hurt_caipora")
	SignalBus.caipora_health_changed.emit(GameState.caipora_current_hp, GameState.caipora_max_hp)
	if GameState.caipora_current_hp <= 0:
		_locked = true
		# Souls-like: derruba a bolsa de fragmentos no tile onde a Caipora caiu (lugar da morte).
		MetaProgression.drop_fragment_bag(phase, _player_grid_pos)
		GameState.change_screen(SignalBus.Screen.GAME_OVER)

func _run_enemy_turns() -> void:
	for enemy in _map_enemies:
		var hit := enemy.take_turn(_player_grid_pos, _is_walkable, _is_occupied_by_enemy)
		if hit:
			_trigger_combat(enemy)
			return

func _trigger_combat(enemy: MapEnemy) -> void:
	_locked = true
	# Continuidade: congela onde o jogador e os inimigos sobreviventes estão AGORA,
	# para a exploração voltar idêntica depois do combate.
	GameState.player_map_pos = _player_grid_pos
	_snapshot_enemy_positions()
	GameState.active_map_enemy_id = enemy.enemy_id
	GameState.active_combat_is_boss = enemy.is_boss
	if enemy.is_boss:
		GameState.next_enemy_scene = _profile["boss_scene"]
		# Toda boss fight abre com a apresentação (estilo Mega Man); ela encadeia
		# para o diálogo (se houver) e daí para a arena.
		_show_boss_intro()
	else:
		GameState.next_enemy_scene = _regular_scene_for(enemy.enemy_type)
		# Fase 5: chefes-monstro convertidos mantêm o HP de chefe da própria cena.
		GameState.active_combat_keeps_own_hp = enemy.enemy_type in MINIBOSS_TYPES
		GameState.change_screen(_profile["arena_screen"])

## Cena de arena do comum pelo tipo (caçador/bruxo); fallback = caçador.
func _regular_scene_for(etype: String) -> PackedScene:
	return REGULAR_SCENES.get(etype, CACADOR_SCENE)

func _snapshot_enemy_positions() -> void:
	# Salva a posição atual de cada inimigo vivo (inclui o que será lutado — filtrado
	# por defeated_enemy_ids na volta). Sobrescreve o snapshot anterior por completo.
	GameState.map_enemy_positions.clear()
	for e in _map_enemies:
		GameState.map_enemy_positions[e.enemy_id] = e.grid_pos

func _show_boss_intro() -> void:
	var intro: BossIntroScreen = BOSS_INTRO_SCENE.instantiate()
	add_child(intro)
	SignalBus.boss_intro_finished.connect(_on_boss_intro_finished, CONNECT_ONE_SHOT)
	intro.start(_profile["boss_speaker"], _profile["boss_frames"],
		_profile["boss_aura"], _profile["boss_color"])

func _on_boss_intro_finished() -> void:
	# Apresentação encerrada: encadeia para o diálogo, ou direto para a arena se a
	# boss não tiver falas.
	if (_profile["boss_dialogue"] as Array).is_empty():
		GameState.change_screen(_profile["arena_screen"])
	else:
		_show_boss_dialogue()

func _show_boss_dialogue() -> void:
	var dlg: DialogueScreen = DIALOGUE_SCENE.instantiate()
	add_child(dlg)
	SignalBus.dialogue_finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	dlg.start(_profile["boss_speaker"], _profile["boss_dialogue"], Lang.t(&"dialogue.caipora"),
		Constants.COLOR_DIALOGUE_CAIPORA, _profile["boss_color"])

func _on_dialogue_finished() -> void:
	GameState.change_screen(_profile["arena_screen"])

# ─── Diálogo de abertura da FASE (Fase 5) ──────────
## Exibe a fala do chefe ANTES da fase começar, travando o movimento. Só na
## entrada fresca (não na volta de cada combate de mini-boss — aí player_map_pos
## já não é -1). Reusa o DialogueScreen; o SceneTransition cobre a entrada.
func _maybe_show_intro_dialogue() -> void:
	if not _profile.has("intro_dialogue"):
		return
	var intro: Array[Dictionary] = _profile["intro_dialogue"]
	if intro.is_empty():
		return
	if GameState.player_map_pos != Vector2i(-1, -1):
		return  # voltando do combate: a fala de abertura não se repete
	_locked = true
	var dlg: DialogueScreen = DIALOGUE_SCENE.instantiate()
	add_child(dlg)
	SignalBus.dialogue_finished.connect(_on_intro_dialogue_finished, CONNECT_ONE_SHOT)
	dlg.start(_profile["intro_speaker"], intro, Lang.t(&"dialogue.caipora"),
		Constants.COLOR_DIALOGUE_CAIPORA, _profile["boss_color"])

func _on_intro_dialogue_finished() -> void:
	_locked = false

# ─── Spawn Helpers (spawn seguro: longe de fogo) ───
func _spawn_is_safe(pos: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if _map.char_at(pos + d) == "R":
			return false
	return true

func _find_safe_spawn(preferred: Vector2i) -> Vector2i:
	if _is_walkable(preferred) and _spawn_is_safe(preferred):
		return preferred
	var queue: Array[Vector2i] = [preferred]
	var visited: Dictionary = {}
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if visited.has(pos):
			continue
		visited[pos] = true
		if _is_walkable(pos) and _spawn_is_safe(pos):
			return pos
		for d in dirs:
			var next := pos + d
			if not visited.has(next) and _is_walkable(next):
				queue.append(next)
	return preferred

# ─── Walkability Helpers ───────────────────────────
func _is_walkable(pos: Vector2i) -> bool:
	# Fonte ÚNICA de verdade: o mapa gerado (o TileMap é pintado a partir dele).
	return _map.is_walkable(pos)

func _is_occupied_by_enemy(pos: Vector2i) -> bool:
	for enemy in _map_enemies:
		if enemy.grid_pos == pos:
			return true
	return false

func _make_object(type: MapObject.Type, grid_pos: Vector2i) -> Node2D:
	var obj := MapObject.new()
	_objects_container.add_child(obj)
	# `enhanced` só afeta FIRE (luz + partículas). Ligado em fases de poucas fogueiras.
	var enhanced: bool = type == MapObject.Type.FIRE and _profile["enhance_fire"]
	obj.setup(type, grid_pos, enhanced)
	return obj

# ─── TileMap Setup ─────────────────────────────────
func _setup_tilemap() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1 << (Constants.LAYER_WALL - 1))
	tileset.set_physics_layer_collision_mask(0, 1 << (Constants.LAYER_PLAYER - 1))

	var floor_source := TileSetAtlasSource.new()
	floor_source.texture = _profile.get("floor_texture", FLOOR_TEXTURE)
	floor_source.texture_region_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	for i: int in FLOOR_VARIANTS:
		floor_source.create_tile(Vector2i(i, 0))
	tileset.add_source(floor_source, 0)

	var wall_source := TileSetAtlasSource.new()
	wall_source.texture = _profile.get("wall_texture", WALL_TEXTURE)
	wall_source.texture_region_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	for i: int in WALL_VARIANTS:
		wall_source.create_tile(Vector2i(i, 0))
	tileset.add_source(wall_source, 1)

	var shade_source := TileSetAtlasSource.new()
	shade_source.texture = SHADE_TEXTURE
	shade_source.texture_region_size = Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	for i: int in SHADE_VARIANTS:
		shade_source.create_tile(Vector2i(i, 0))
	tileset.add_source(shade_source, 2)

	_tilemap.tile_set = tileset
	_ensure_tilemap_layers()
	_paint_map()

func _ensure_tilemap_layers() -> void:
	while _tilemap.get_layers_count() < 2:
		_tilemap.add_layer(_tilemap.get_layers_count())
	_tilemap.set_layer_z_index(0, 0)
	_tilemap.set_layer_z_index(1, 1)

func _paint_map() -> void:
	for y: int in _map.tiles.size():
		var row: Array = _map.tiles[y]
		for x: int in row.size():
			var pos := Vector2i(x, y)
			if row[x] == "W":
				var wv: int = (x * 5 + y * 11) % WALL_VARIANTS
				_tilemap.set_cell(0, pos, 1, Vector2i(wv, 0))
			else:
				var fv: int = (x * 7 + y * 13) % FLOOR_VARIANTS
				_tilemap.set_cell(0, pos, 0, Vector2i(fv, 0))
				var shade := _shade_variant_for_floor(pos)
				if shade >= 0:
					_tilemap.set_cell(1, pos, 2, Vector2i(shade, 0))

# ─── Perfil de Apresentação/Rota por Fase ──────────
func _shade_variant_for_floor(pos: Vector2i) -> int:
	var north := _map.char_at(pos + Vector2i(0, -1)) == "W"
	var west := _map.char_at(pos + Vector2i(-1, 0)) == "W"
	var east := _map.char_at(pos + Vector2i(1, 0)) == "W"
	if north and (west or east):
		return 1
	if north:
		return 2 if _profile["has_fog"] else 0
	if west or east:
		return 1
	return -1

func _build_profile() -> Dictionary:
	match phase:
		2:
			return {
				"arena_screen": SignalBus.Screen.ARENA_PHASE2,
				"boss_scene": BOITATA_SCENE,
				"boss_dialogue": _boitata_dialogue(),
				"boss_speaker": Lang.t(&"boss.boitata.name"),
				"boss_color": Constants.COLOR_DIALOGUE_BOITATA,
				"boss_frames": BOITATA_FRAMES,
				"boss_aura": Constants.COLOR_AURA_BOITATA,
				"next_screen_on_exit": SignalBus.Screen.EXPLORATION_PHASE3,
				"hazard_damage": Constants.FIRE_TILE_DAMAGE,
				"step_sfx": "step_grass",
				"aura": Aura.NONE,
				"safe_spawn": false,
				"ambient_life": false,
				"phase_reached_on_enter": 2,
				"has_fog": false,
				"enhance_fire": true,
				"exit_marker": ExitMarker.SIMPLE,
				"deco_palette": DECO_FIRE,
			}
		3:
			return {
				"arena_screen": SignalBus.Screen.ARENA_PHASE3,
				"boss_scene": CURUPIRA_SCENE,
				"boss_dialogue": _curupira_dialogue(),
				"boss_speaker": Lang.t(&"boss.curupira.name"),
				"boss_color": Constants.COLOR_DIALOGUE_CURUPIRA,
				"boss_frames": CURUPIRA_FRAMES,
				"boss_aura": Constants.COLOR_AURA_CURUPIRA,
				"next_screen_on_exit": SignalBus.Screen.EXPLORATION_PHASE4,
				"hazard_damage": Constants.FIRE_TILE_DAMAGE,
				"step_sfx": "step_grass",
				"aura": Aura.FIRE,
				"safe_spawn": true,
				"ambient_life": false,
				"phase_reached_on_enter": 0,
				"has_fog": true,
				"enhance_fire": false,
				"exit_marker": ExitMarker.PULSING,
				"deco_palette": DECO_FOREST,
			}
		4:
			return {
				"arena_screen": SignalBus.Screen.ARENA_PHASE4,
				"boss_scene": SACI_SCENE,
				"boss_dialogue": _saci_dialogue(),
				"boss_speaker": Lang.t(&"boss.saci.name"),
				"boss_color": Constants.COLOR_DIALOGUE_SACI,
				"boss_frames": SACI_FRAMES,
				"boss_aura": Constants.COLOR_AURA_SACI,
				"next_screen_on_exit": SignalBus.Screen.EXPLORATION_PHASE5,
				"hazard_damage": Constants.FIRE_TILE_DAMAGE,
				"step_sfx": "step_grass",
				"aura": Aura.FIRE,
				"safe_spawn": true,
				"ambient_life": false,
				"phase_reached_on_enter": 0,
				"has_fog": false,
				"enhance_fire": false,
				"exit_marker": ExitMarker.PULSING,
				"deco_palette": DECO_FIRE,
			}
		5:
			# Fase FINAL — A Igreja na Mata. Diálogo de abertura com o Jesuíta; os
			# "monstros" são os 4 chefes convertidos; o Jesuíta no altar. Progride ao
			# derrotá-lo → FINAL_CHOICE → ENDING/ENDING_SACRIFICE (has_exit=false).
			# O diálogo de boss é vazio: a fala marcante já ocorre na abertura da
			# fase (intro_dialogue).
			return {
				"arena_screen": SignalBus.Screen.ARENA_PHASE5,
				"boss_scene": JESUITA_SCENE,
				"boss_dialogue": [],
				"boss_speaker": Lang.t(&"boss.jesuita.name"),
				"boss_color": Constants.COLOR_DIALOGUE_JESUITA,
				"boss_frames": JESUITA_FRAMES,
				"boss_aura": Constants.COLOR_AURA_JESUITA,
				"next_screen_on_exit": SignalBus.Screen.FINAL_CHOICE,
				"hazard_damage": Constants.FIRE_TILE_DAMAGE,
				"step_sfx": "step_stone",  # laje da igreja, não serrapilheira
				"aura": Aura.TORCH,
				"safe_spawn": true,
				"ambient_life": false,
				"phase_reached_on_enter": 5,
				"has_fog": false,
				"enhance_fire": true,
				"exit_marker": ExitMarker.NONE,
				"deco_palette": DECO_CHURCH,
				"intro_dialogue": _jesuita_intro_dialogue(),
				"intro_speaker": Lang.t(&"boss.jesuita.name"),
				"floor_texture": FLOOR_TEXTURE_CHURCH,
				"wall_texture": WALL_TEXTURE_CHURCH,
			}
		_:
			# Fase 1 (padrão): arena aberta, tocha, baú/chave, vida ambiente.
			# Boss: a Mula sem Cabeça (jato de fogo no lugar da cabeça).
			return {
				"arena_screen": SignalBus.Screen.ARENA,
				"boss_scene": MULA_SCENE,
				"boss_dialogue": _mula_dialogue(),
				"boss_speaker": Lang.t(&"boss.mula.name"),
				"boss_color": Constants.COLOR_DIALOGUE_MULA,
				"boss_frames": MULA_FRAMES,
				"boss_aura": Constants.COLOR_AURA_MULA,
				"next_screen_on_exit": SignalBus.Screen.EXPLORATION_PHASE2,
				"hazard_damage": 1,
				"step_sfx": "step_grass",
				"aura": Aura.TORCH,
				"safe_spawn": false,
				"ambient_life": true,
				"phase_reached_on_enter": 0,
				"has_fog": false,
				"enhance_fire": true,
				"exit_marker": ExitMarker.PULSING,
				"deco_palette": MapObject.DECO_TYPES,
			}
