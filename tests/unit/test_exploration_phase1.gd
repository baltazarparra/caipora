extends GutTest

# Integração da Fase 1 procedural: a cena de exploração consome o GeneratedMap
# (em vez do MAP_LAYOUT estático) e fia spawn/inimigos a partir dele.

func after_each() -> void:
	GameState.player_map_pos = Vector2i(-1, -1)
	GameState.defeated_enemy_ids.clear()
	MetaProgression.freed_bosses = []

func test_phase1_loads_and_spawns_generated_map() -> void:
	GameState.start_run()
	# KI-017: run_seed fixo — start_run() sorteia o seed e certos sorteios geram
	# mapa com tiles alcançáveis de menos, spawnando menos que enemy_count (flaky
	# que derrubou o gate no CI em 2026-07-02). Seed 1 spawna cheio em toda fase
	# (verificado por varredura no MapGenerator).
	GameState.run_seed = 1
	GameState.player_map_pos = Vector2i(-1, -1)
	# Mesmo seed+fase que o manager usa → mapa idêntico (contrato determinístico).
	var expected := MapGenerator.new().generate(MapConfig.for_phase(1), GameState.map_seed_for_phase(1))

	var scene := preload("res://scenes/exploration/exploration.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var enemies := scene.get_node("Enemies")
	assert_eq(enemies.get_child_count(), MapConfig.for_phase(1).enemy_count,
		"spawna todos os inimigos do mapa gerado (sem derrotados)")

	var caipora := scene.get_node("Caipora")
	assert_eq(caipora.position, Vector2(expected.player_start) * Constants.TILE_SIZE,
		"Caipora nasce no player_start do mapa gerado")
	assert_eq(scene._profile["step_sfx"], "step_grass",
		"fases de mata pisam em serrapilheira (S3)")

func test_phase1_tilemap_keeps_forest_atlases() -> void:
	# Protege o default do _profile.get(): só a Fase 5 troca para os tiles de igreja.
	GameState.start_run()
	GameState.run_seed = 1  # KI-017: determinístico (ver 1º teste)
	GameState.player_map_pos = Vector2i(-1, -1)
	var scene := preload("res://scenes/exploration/exploration.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	var tile_set: TileSet = scene.get_node("TileMap").tile_set
	var floor_source := tile_set.get_source(0) as TileSetAtlasSource
	assert_eq(floor_source.texture.resource_path, "res://assets/sprites/tile_floor.png",
		"Fase 1 mantém o chão de floresta")
	var shade_source := tile_set.get_source(2) as TileSetAtlasSource
	assert_eq(shade_source.texture.resource_path, "res://assets/sprites/tile_shade.png",
		"Fase 1 usa atlas de sombra de contato")
	var tilemap := scene.get_node("TileMap") as TileMap
	assert_gt(tilemap.get_used_cells(1).size(), 0,
		"Fase 1 pinta sombra de contato nos encontros de chao e parede")

func test_phase1_skips_defeated_enemies() -> void:
	GameState.start_run()
	GameState.run_seed = 1  # KI-017: determinístico (ver 1º teste)
	GameState.player_map_pos = Vector2i(-1, -1)
	var expected := MapGenerator.new().generate(MapConfig.for_phase(1), GameState.map_seed_for_phase(1))
	# Marca o primeiro inimigo como derrotado: não deve renascer.
	GameState.defeated_enemy_ids.append(expected.enemies[0]["id"])

	var scene := preload("res://scenes/exploration/exploration.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var enemies := scene.get_node("Enemies")
	assert_eq(enemies.get_child_count(), MapConfig.for_phase(1).enemy_count - 1,
		"inimigo derrotado não renasce ao voltar da arena")

# Santuário dos Encantados: com a Mula libertada, a fase nasce sem guardião e com a
# marca de paz (TOTEM) na cela onde ela postaria — a toca virou passagem.
func test_phase1_freed_mula_leaves_map_with_peace_totem() -> void:
	GameState.start_run()
	GameState.run_seed = 1  # KI-017: determinístico (ver 1º teste)
	GameState.player_map_pos = Vector2i(-1, -1)
	MetaProgression.freed_bosses = [1] as Array[int]
	var cfg := MapConfig.for_phase(1)
	cfg.boss_freed = true
	var expected := MapGenerator.new().generate(cfg, GameState.map_seed_for_phase(1))

	var scene := preload("res://scenes/exploration/exploration.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var enemies := scene.get_node("Enemies")
	assert_eq(enemies.get_child_count(), MapConfig.for_phase(1).enemy_count - 1,
		"guardiã libertada não spawna; só os comuns")
	for enemy: MapEnemy in enemies.get_children():
		assert_false(enemy.is_boss, "nenhum boss no mapa com a Mula libertada")

	var peace_world := Vector2(expected.peace_pos) * Constants.TILE_SIZE
	var totem_found := false
	for obj: Node in scene.get_node("Objects").get_children():
		if obj is MapObject and obj.position == peace_world \
				and obj._type == MapObject.Type.TOTEM:
			totem_found = true
	assert_true(totem_found, "marca de paz (TOTEM) na cela do guardião libertado")
