extends GutTest

## Roteamento de saída da tela de fim (WIN / GAME_OVER). Regra: morrer/perder NÃO leva ao
## acampamento — o hub só entra ENTRE fases (advance_phase_via_hub). A derrota volta ao MENU
## PRINCIPAL; a vitória terminal mantém o acampamento. _dismiss_target() é puro, então a
## instância roda DESTACADA da árvore (sem _ready, sem exigir os $nós-filhos).

const EndScreenScript := preload("res://scripts/ui/end_screen.gd")

func _make(won: bool) -> EndScreen:
	var es: EndScreen = EndScreenScript.new()
	es.won = won
	autofree(es)
	return es

func test_game_over_goes_to_main_menu() -> void:
	assert_eq(_make(false)._dismiss_target(), SignalBus.Screen.MAIN_MENU,
		"derrota volta ao menu, não ao acampamento")

func test_win_goes_to_initials() -> void:
	assert_eq(_make(true)._dismiss_target(), SignalBus.Screen.INITIALS,
		"vitória vai para tela de iniciais do PODIO antes do acampamento")

func test_game_over_never_routes_to_hub() -> void:
	assert_ne(_make(false)._dismiss_target(), SignalBus.Screen.HUB,
		"o hub só entra em avanço de fase, nunca ao morrer")
