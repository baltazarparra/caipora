extends GutTest

# Integração da Fase 4 procedural (manager único, phase=4): a Casa em chamas,
# boss Saci guardando a saída — pisar no tile 'E' leva à Fase 5 (a igreja).

func after_each() -> void:
	GameState.player_map_pos = Vector2i(-1, -1)
	GameState.defeated_enemy_ids.clear()

func test_phase4_loads_with_saci_and_exit() -> void:
	GameState.start_run()
	# KI-017: run_seed fixo — start_run() sorteia o seed e certos sorteios geram
	# mapa com tiles alcançáveis de menos, spawnando menos que enemy_count (flaky
	# que derrubou o gate no CI em 2026-07-02). Seed 1 spawna cheio em toda fase
	# (verificado por varredura no MapGenerator).
	GameState.run_seed = 1
	GameState.player_map_pos = Vector2i(-1, -1)
	var expected := MapGenerator.new().generate(MapConfig.for_phase(4), GameState.map_seed_for_phase(4))

	var scene := preload("res://scenes/exploration/exploration_phase4.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	assert_eq(scene.get_node("Enemies").get_child_count(), MapConfig.for_phase(4).enemy_count,
		"spawna os inimigos do mapa gerado (6)")
	assert_eq(expected.boss().get("boss_type", ""), "saci", "boss da Fase 4 é o Saci")
	assert_true(MapConfig.for_phase(4).has_exit, "Fase 4 tem saída (matar o Saci não encerra a fase)")
	assert_ne(expected.exit_pos, Vector2i(-1, -1), "Fase 4 expõe exit_pos")
	assert_eq(int(scene._profile["next_screen_on_exit"]), int(SignalBus.Screen.EXPLORATION_PHASE5),
		"saída da Fase 4 leva à Fase 5 (a igreja), não ao ENDING")
	assert_eq(int(scene._profile["exit_marker"]), int(scene.ExitMarker.PULSING),
		"saída marcada com luz pulsante")
