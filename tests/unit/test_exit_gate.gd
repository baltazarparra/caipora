extends GutTest

# Gate do boss (souls-like): pisar no tile de saída só AVANÇA de fase quem libertou o guardião
# da fase; senão a Caipora volta à MESMA fase (sempre passando pelo aprimoramento no HUB). Cobre
# a função pura GameState.exit_destination + o mapeamento fase → tela de exploração.

func test_boss_freed_advances_to_next_screen() -> void:
	var nxt := SignalBus.Screen.EXPLORATION_PHASE3
	assert_eq(GameState.exit_destination(2, true, nxt), nxt,
		"guardião libertado: a saída avança de fase")

func test_boss_alive_returns_to_same_phase() -> void:
	assert_eq(GameState.exit_destination(1, false, SignalBus.Screen.EXPLORATION_PHASE2),
		SignalBus.Screen.EXPLORATION, "P1 com boss vivo volta à mesma fase")
	assert_eq(GameState.exit_destination(2, false, SignalBus.Screen.EXPLORATION_PHASE3),
		SignalBus.Screen.EXPLORATION_PHASE2)
	assert_eq(GameState.exit_destination(3, false, SignalBus.Screen.EXPLORATION_PHASE4),
		SignalBus.Screen.EXPLORATION_PHASE3)
	assert_eq(GameState.exit_destination(4, false, SignalBus.Screen.EXPLORATION_PHASE5),
		SignalBus.Screen.EXPLORATION_PHASE4)

func test_exploration_screen_for_phase_mapping() -> void:
	assert_eq(GameState.exploration_screen_for_phase(1), SignalBus.Screen.EXPLORATION)
	assert_eq(GameState.exploration_screen_for_phase(2), SignalBus.Screen.EXPLORATION_PHASE2)
	assert_eq(GameState.exploration_screen_for_phase(3), SignalBus.Screen.EXPLORATION_PHASE3)
	assert_eq(GameState.exploration_screen_for_phase(4), SignalBus.Screen.EXPLORATION_PHASE4)
	assert_eq(GameState.exploration_screen_for_phase(5), SignalBus.Screen.EXPLORATION_PHASE5)
