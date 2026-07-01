extends GutTest

# Invariantes do SceneTransition (fade temático em toda troca de cena) e do
# roteamento de telas do GameState. O fade em si precisa de display para o "feel",
# mas a LÓGICA — quando o flavor aparece e se toda tela resolve uma cena — é pura
# e roda headless.

const SceneTransitionScript := preload("res://scripts/core/scene_transition.gd")

var _st: CanvasLayer

func before_each() -> void:
	_st = SceneTransitionScript.new()
	add_child_autofree(_st)  # dispara _ready/_build

# ── _is_exploration reconhece exatamente as 4 telas de exploração ──
func test_is_exploration_recognizes_phase_screens() -> void:
	assert_true(_st._is_exploration(SignalBus.Screen.EXPLORATION), "fase 1")
	assert_true(_st._is_exploration(SignalBus.Screen.EXPLORATION_PHASE2), "fase 2")
	assert_true(_st._is_exploration(SignalBus.Screen.EXPLORATION_PHASE3), "fase 3")
	assert_true(_st._is_exploration(SignalBus.Screen.EXPLORATION_PHASE4), "fase 4")
	assert_true(_st._is_exploration(SignalBus.Screen.EXPLORATION_PHASE5), "fase 5")
	for s: int in [SignalBus.Screen.MAIN_MENU, SignalBus.Screen.HUB,
			SignalBus.Screen.ARENA, SignalBus.Screen.ARENA_PHASE2,
			SignalBus.Screen.WIN, SignalBus.Screen.GAME_OVER, SignalBus.Screen.ENDING]:
		assert_false(_st._is_exploration(s), "tela %d não é exploração" % s)

# ── Flavor dispara ao entrar numa fase de exploração NOVA ──
func test_themed_on_new_exploration_phase() -> void:
	_st._last_exploration = -1
	assert_true(_st._is_themed(SignalBus.Screen.EXPLORATION),
		"run start (sem exploração anterior) é temático")
	_st._last_exploration = SignalBus.Screen.EXPLORATION
	assert_true(_st._is_themed(SignalBus.Screen.EXPLORATION_PHASE2),
		"avanço de fase é temático")

# ── Volta do combate para a MESMA fase NÃO dispara o flavor ──
func test_not_themed_on_combat_return() -> void:
	_st._last_exploration = SignalBus.Screen.EXPLORATION_PHASE2
	assert_false(_st._is_themed(SignalBus.Screen.EXPLORATION_PHASE2),
		"voltar para a mesma exploração não reorganiza a mata")

# ── Telas de menu/arena nunca disparam o flavor ──
func test_not_themed_on_non_exploration() -> void:
	_st._last_exploration = -1
	for s: int in [SignalBus.Screen.ARENA, SignalBus.Screen.ENDING, SignalBus.Screen.MAIN_MENU]:
		assert_false(_st._is_themed(s), "tela %d sem flavor" % s)
	assert_eq(_st._flavor_for(SignalBus.Screen.ARENA), "",
		"arena não mostra texto de luta na transição global; isso pertence ao loader interno")

# ── Entrar no acampamento (HUB) tem flavor próprio, calmo (Fase 9) ──
func test_hub_has_camp_flavor() -> void:
	_st._last_exploration = -1
	assert_true(_st._is_themed(SignalBus.Screen.HUB), "acampamento dispara flavor")
	assert_eq(_st._flavor_for(SignalBus.Screen.HUB), Lang.t(&"transition.camp"),
		"HUB usa o texto calmo do acampamento")
	assert_eq(_st._flavor_for(SignalBus.Screen.EXPLORATION_PHASE2), Lang.t(&"transition.themed"),
		"avanço de fase mantém o texto da mata")

# ── transition_to atualiza a última exploração visitada ──
func test_transition_tracks_last_exploration() -> void:
	# Caminho real → mas NÃO trocamos cena de verdade aqui: o tween só dispara o
	# change_scene_to_file num callback após o fade, e o nó é liberado (autofree)
	# antes disso. Validamos o efeito colateral síncrono: o tracking de fase.
	_st._last_exploration = -1
	_st.transition_to("res://scenes/exploration/exploration_phase3.tscn",
		SignalBus.Screen.EXPLORATION_PHASE3)
	_kill_tween()  # o change_scene_to_file fica num callback pós-fade; mata antes de disparar
	assert_eq(_st._last_exploration, int(SignalBus.Screen.EXPLORATION_PHASE3),
		"última exploração registrada")
	# Tela não-exploração não altera o tracking.
	_st.transition_to("res://scenes/arena/arena.tscn", SignalBus.Screen.ARENA)
	_kill_tween()
	assert_eq(_st._last_exploration, int(SignalBus.Screen.EXPLORATION_PHASE3),
		"arena não mexe no tracking de exploração")

# ── Assinatura da marca: olhos abrem no breu APENAS em transição temática ──
func test_eyes_signature_only_on_themed_transitions() -> void:
	_st._last_exploration = -1
	_st.transition_to(GameState._scene_path_for(SignalBus.Screen.HUB), SignalBus.Screen.HUB)
	_kill_tween()
	assert_true(_st._eyes.visible, "flavor temático abre os olhos no breu")
	_st.transition_to(GameState._scene_path_for(SignalBus.Screen.ARENA), SignalBus.Screen.ARENA)
	_kill_tween()
	assert_false(_st._eyes.visible, "entrada em arena fica com fade limpo, sem assinatura")

# ── Os dois olhos são IGUAIS e brancos puros (trava do conceito) ──
func test_eyes_are_equal_and_pure_white() -> void:
	var rects: Array = _st._eyes.get_children()
	assert_eq(rects.size(), 2, "exatamente dois olhos")
	for eye: ColorRect in rects:
		assert_eq(eye.color, Color.WHITE, "olho branco puro, sem halo")
		assert_eq(eye.size, _st.EYE_SIZE, "olhos do mesmo tamanho")

func _kill_tween() -> void:
	if _st._tween != null and _st._tween.is_valid():
		_st._tween.kill()

# ── Roteamento: TODA tela do enum resolve uma cena (nada cai no vazio) ──
func test_every_screen_resolves_a_scene() -> void:
	for s: int in SignalBus.Screen.values():
		var path: String = GameState._scene_path_for(s)
		assert_false(path.is_empty(), "tela %d tem cena" % s)
		assert_true(path.begins_with("res://") and path.ends_with(".tscn"),
			"tela %d → caminho .tscn válido (%s)" % [s, path])

# ── Caminhos distintos: nenhuma colisão de rota entre telas ──
func test_screen_paths_are_unique() -> void:
	var seen := {}
	for s: int in SignalBus.Screen.values():
		var path: String = GameState._scene_path_for(s)
		assert_false(seen.has(path), "caminho único por tela (%s)" % path)
		seen[path] = true
