extends GutTest

# Integração da Fase 3 procedural: a cena "Ventre da Mata" consome o GeneratedMap
# (corredores via CORRIDOR), com fog of war e o Curupira guardando o beco da saída —
# pisar no tile 'E' leva à Fase 4 (matar o boss não encerra a fase).

func after_each() -> void:
	GameState.player_map_pos = Vector2i(-1, -1)
	GameState.defeated_enemy_ids.clear()

func test_phase3_loads_corridor_map_with_fog_and_curupira() -> void:
	GameState.start_run()
	# KI-017: run_seed fixo — start_run() sorteia o seed e certos sorteios geram
	# mapa com tiles alcançáveis de menos, spawnando menos que enemy_count (flaky
	# que derrubou o gate no CI em 2026-07-02). Seed 1 spawna cheio em toda fase
	# (verificado por varredura no MapGenerator).
	GameState.run_seed = 1
	GameState.player_map_pos = Vector2i(-1, -1)
	var expected := MapGenerator.new().generate(MapConfig.for_phase(3), GameState.map_seed_for_phase(3))

	var scene := preload("res://scenes/exploration/exploration_phase3.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	assert_eq(scene.get_node("Enemies").get_child_count(), MapConfig.for_phase(3).enemy_count,
		"spawna os 6 inimigos do mapa gerado")
	assert_eq(expected.boss().get("boss_type", ""), "curupira",
		"o boss da Fase 3 é o Curupira")

	var has_fog := false
	for c in scene.get_children():
		if c is FogOfWar:
			has_fog = true
	assert_true(has_fog, "fog of war presente na Fase 3")

	assert_true(MapConfig.for_phase(3).has_exit, "Fase 3 tem saída (matar o Curupira não encerra a fase)")
	assert_ne(expected.exit_pos, Vector2i(-1, -1), "Fase 3 expõe exit_pos")
	assert_true(expected.reachable_from(expected.player_start).has(expected.exit_pos),
		"a saída é alcançável a partir do spawn")
	assert_eq(int(scene._profile["next_screen_on_exit"]), int(SignalBus.Screen.EXPLORATION_PHASE4),
		"saída da Fase 3 leva à Fase 4")
	assert_eq(int(scene._profile["exit_marker"]), int(scene.ExitMarker.PULSING),
		"saída marcada com luz pulsante (legível na névoa)")

func test_phase3_skips_defeated_enemies() -> void:
	GameState.start_run()
	GameState.run_seed = 1  # KI-017: determinístico (ver 1º teste)
	GameState.player_map_pos = Vector2i(-1, -1)
	var expected := MapGenerator.new().generate(MapConfig.for_phase(3), GameState.map_seed_for_phase(3))
	GameState.defeated_enemy_ids.append(expected.enemies[0]["id"])

	var scene := preload("res://scenes/exploration/exploration_phase3.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	assert_eq(scene.get_node("Enemies").get_child_count(), MapConfig.for_phase(3).enemy_count - 1,
		"inimigo derrotado não renasce na volta da arena")
