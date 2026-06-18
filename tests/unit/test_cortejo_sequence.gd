extends GutTest

# Cobre o seam puro do Batuque do Cortejo: o mapeamento fase→chamado direcional e a
# montagem da sequência a partir das fases libertadas (ordem + crescimento pela cauda
# + corte no teto). Determinístico, sem arena.

const FREEABLE_PHASES: Array[int] = [1, 2, 3, 4]

func test_call_for_phase_covers_all_freeable() -> void:
	for phase: int in FREEABLE_PHASES:
		assert_true(Constants.CORTEJO_CALL_FOR_PHASE.has(phase),
			"chamado direcional mapeado para a fase %d" % phase)

func test_calls_are_the_clockwise_sweep() -> void:
	# ↑ → ↓ ← — varredura horária, memorizável.
	assert_eq(Constants.CORTEJO_CALL_FOR_PHASE[1], "ui_up")
	assert_eq(Constants.CORTEJO_CALL_FOR_PHASE[2], "ui_right")
	assert_eq(Constants.CORTEJO_CALL_FOR_PHASE[3], "ui_down")
	assert_eq(Constants.CORTEJO_CALL_FOR_PHASE[4], "ui_left")

func test_full_sequence_in_order() -> void:
	var calls := Constants.cortejo_calls_for([1, 2, 3, 4])
	assert_eq(calls, ["ui_up", "ui_right", "ui_down", "ui_left"] as Array[String])

func test_sequence_grows_by_the_tail() -> void:
	assert_eq(Constants.cortejo_calls_for([1]), ["ui_up"] as Array[String])
	assert_eq(Constants.cortejo_calls_for([1, 2]), ["ui_up", "ui_right"] as Array[String])

func test_sequence_follows_sorted_freed_order() -> void:
	# freed_bosses é mantido ordenado; a função reordena por garantia.
	var calls := Constants.cortejo_calls_for([3, 1])
	assert_eq(calls, ["ui_up", "ui_down"] as Array[String],
		"a ordem da procissão segue a fase, não a ordem de libertação")

func test_sequence_caps_at_max_links() -> void:
	var calls := Constants.cortejo_calls_for([1, 2, 3, 4])
	assert_lte(calls.size(), Constants.CORTEJO_MAX_LINKS,
		"a sequência nunca passa do teto de elos")
