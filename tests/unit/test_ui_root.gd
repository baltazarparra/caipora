extends GutTest

# F3 — UiRoot: propriedade do header por tela (owns) + z-order canônico.
# Testa o singleton autoload diretamente (owns é puro/estável).

func test_owns_gameplay_screens() -> void:
	assert_true(UiRoot.owns(SignalBus.Screen.EXPLORATION))
	assert_true(UiRoot.owns(SignalBus.Screen.EXPLORATION_PHASE3))
	assert_true(UiRoot.owns(SignalBus.Screen.ARENA), "combate migrado ao UiRoot")
	assert_true(UiRoot.owns(SignalBus.Screen.ARENA_PHASE2))
	assert_true(UiRoot.owns(SignalBus.Screen.HUB), "acampamento migrado ao UiRoot (C5)")

func test_does_not_own_menu() -> void:
	assert_false(UiRoot.owns(SignalBus.Screen.MAIN_MENU))
	assert_false(UiRoot.owns(SignalBus.Screen.GAME_OVER))

func test_header_layer_above_atmosphere() -> void:
	assert_eq(UiRoot._header_layer.layer, Constants.LAYER_HUD)
	assert_gt(UiRoot._header_layer.layer, Constants.LAYER_ATMOSPHERE, "header nítido acima da vinheta")
