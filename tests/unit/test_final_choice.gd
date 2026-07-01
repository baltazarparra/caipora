extends GutTest

# A escolha final ("Poupar ele?") e os dois finais. Roteamento puro + contrato
# de cena das três telas novas/alteradas, tudo headless:
#   - FINAL_CHOICE roteia SIM → ENDING_SACRIFICE e NÃO → ENDING
#   - a cena da escolha monta a pergunta, os dois botões e os dois atores
#     (Caipora de costas + Jesuíta caído)
#   - escolher é idempotente (um clique decide; o segundo é ignorado)
#   - o final do sacrifício encerra a run como vitória (jogo terminado)

const FinalChoiceScene := preload("res://scenes/ui/final_choice_screen.tscn")
const SacrificeScene := preload("res://scenes/ui/ending_sacrifice_screen.tscn")

var _saved_screen: int
var _saved_run_active: bool
var _saved_runs: int
var _saved_wins: int
var _saved_phase_reached: int
var _original_save_path: String

func before_each() -> void:
	_saved_screen = GameState.current_screen
	_saved_run_active = GameState.run_active
	_saved_runs = MetaProgression.total_runs
	_saved_wins = MetaProgression.total_wins
	_saved_phase_reached = MetaProgression.phase_reached
	# end_run salva: redireciona o save para não tocar o progresso real.
	_original_save_path = MetaProgression.SAVE_PATH
	MetaProgression.SAVE_PATH = "user://test_final_choice_savegame.json"

func after_each() -> void:
	if FileAccess.file_exists(MetaProgression.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgression.SAVE_PATH))
	MetaProgression.SAVE_PATH = _original_save_path
	GameState.current_screen = _saved_screen
	GameState.run_active = _saved_run_active
	MetaProgression.total_runs = _saved_runs
	MetaProgression.total_wins = _saved_wins
	MetaProgression.phase_reached = _saved_phase_reached
	# Mata qualquer transição agendada por change_screen ANTES do swap real de cena.
	if SceneTransition._tween != null and SceneTransition._tween.is_valid():
		SceneTransition._tween.kill()

# ── Roteamento puro da escolha ──
func test_screen_for_choice_routes_both_endings() -> void:
	assert_eq(FinalChoiceScreen.screen_for_choice(true), SignalBus.Screen.ENDING_SACRIFICE,
		"poupar → o final do sacrifício (a caipora morre, a floresta vira cristã)")
	assert_eq(FinalChoiceScreen.screen_for_choice(false), SignalBus.Screen.ENDING,
		"não poupar → o final atual (a floresta segue respirando)")

# ── Contrato da cena da escolha ──
func test_final_choice_scene_builds_question_and_buttons() -> void:
	var screen: FinalChoiceScreen = FinalChoiceScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen._question.text, "Poupar ele?", "a pergunta final é literal")
	assert_eq(screen._btn_spare.text, "SIM", "botão de poupar")
	assert_eq(screen._btn_kill.text, "NÃO", "botão de executar")
	assert_true(screen._btn_spare.disabled and screen._btn_kill.disabled,
		"os botões nascem travados — a pergunta aparece antes da resposta")
	assert_not_null(screen._caipora.texture, "a Caipora de costas está em cena")
	assert_true(screen._caipora.texture.resource_path.contains("player_back"),
		"a protagonista usa a pose de costas do gen_caipora.py")
	assert_not_null(screen._jesuita.texture, "o Jesuíta caído está em cena")

func test_final_choice_buttons_route_to_each_ending() -> void:
	var screen: FinalChoiceScreen = FinalChoiceScene.instantiate()
	add_child_autofree(screen)
	screen._enable_buttons()
	screen._choose(false)
	assert_true(screen._chosen, "a escolha foi registrada")
	# O corte é tweened; o destino já está decidido pelo roteador puro.
	assert_eq(FinalChoiceScreen.screen_for_choice(false), SignalBus.Screen.ENDING)

func test_final_choice_is_idempotent() -> void:
	var screen: FinalChoiceScreen = FinalChoiceScene.instantiate()
	add_child_autofree(screen)
	screen._enable_buttons()
	screen._choose(true)
	var was_chosen := screen._chosen
	screen._choose(false)  # segundo clique (outro botão) não pode reabrir a decisão
	assert_true(was_chosen and screen._chosen, "uma escolha só — a primeira vale")
	assert_true(screen._btn_spare.disabled and screen._btn_kill.disabled,
		"após escolher, os dois botões morrem")

func test_final_choice_does_not_end_run() -> void:
	# A run só termina NO final (ENDING/ENDING_SACRIFICE chamam end_run); a tela
	# da escolha é o limiar — não pode mexer na contagem de vitórias.
	var runs_before: int = MetaProgression.total_runs
	var screen: FinalChoiceScreen = FinalChoiceScene.instantiate()
	add_child_autofree(screen)
	assert_eq(MetaProgression.total_runs, runs_before,
		"a pergunta não conta como fim de run")

# ── Contrato do final do sacrifício ──
func test_sacrifice_ending_ends_run_as_completed() -> void:
	GameState.run_active = true
	var wins_before: int = MetaProgression.total_wins
	var screen: EndingSacrificeScreen = SacrificeScene.instantiate()
	add_child_autofree(screen)
	assert_false(GameState.run_active, "o final do sacrifício encerra a run")
	assert_eq(MetaProgression.total_wins, wins_before + 1,
		"terminar o jogo poupando também é terminar o jogo")

func test_sacrifice_ending_body_is_base_dead_pose() -> void:
	# A CHAMA morreu com ela: o corpo tombado usa SEMPRE a pose "dead" base.
	var screen: EndingSacrificeScreen = SacrificeScene.instantiate()
	add_child_autofree(screen)
	assert_true(screen._body.texture.resource_path.ends_with("player_dead.png"),
		"o corpo da guardiã usa a pose tombada do gen_caipora.py")
	assert_eq(screen._body.rotation, 0.0,
		"a pose já nasce deitada — nada de sprite de pé rotacionada")

func test_sacrifice_messages_are_the_inverse_of_the_living_forest() -> void:
	assert_eq(Lang.t(&"sacrifice.msg2"), "a floresta virou cristã",
		"a mensagem do céu convertido")
	assert_eq(Lang.t(&"ending.sky"), "a floresta segue respirando",
		"a mensagem do céu vivo (final canônico)")
