extends GutTest

# Trava a escada de recompensa por combo (gatilho de vício): quanto maior o streak de
# perfeitos, mais a intensidade escala — mas SÓ em parâmetros baratos e dentro de um
# teto (COMBO_MAX_STEP) que impede shake nauseante. Aqui validamos a lógica pura
# (Constants.combo_scale / combo_hitstop_bonus) e o mapeamento streak->passo do
# FeedbackSystem. O feel em si é manual (/validate-controls + display).

func test_combo_scale_starts_neutral():
	assert_eq(Constants.combo_scale(0), 1.0, "passo 0 (1º perfeito) não escala nada")

func test_combo_scale_is_monotonic_increasing():
	var prev := Constants.combo_scale(0)
	for step in range(1, Constants.COMBO_MAX_STEP + 1):
		var cur := Constants.combo_scale(step)
		assert_gt(cur, prev, "combo_scale deve crescer a cada passo (%d)" % step)
		prev = cur

func test_combo_scale_saturates_at_max():
	var at_max := Constants.combo_scale(Constants.COMBO_MAX_STEP)
	assert_eq(Constants.combo_scale(99), at_max,
		"acima do teto satura (sem shake infinito)")
	assert_eq(Constants.combo_scale(-5), 1.0, "passo negativo faz clamp em 1.0")

func test_combo_hitstop_bonus_range():
	assert_eq(Constants.combo_hitstop_bonus(0), 0, "início não ganha frames extras")
	assert_eq(Constants.combo_hitstop_bonus(Constants.COMBO_MAX_STEP),
		Constants.COMBO_HITSTOP_BONUS_AT_MAX, "topo do streak ganha o bônus cheio")
	assert_eq(Constants.combo_hitstop_bonus(99), Constants.COMBO_HITSTOP_BONUS_AT_MAX,
		"acima do teto satura")

func test_feedback_combo_step_maps_streak():
	var fb := FeedbackSystem.new()
	add_child_autofree(fb)
	# Streak 0 (nenhum perfeito / erro recente) -> passo 0.
	fb._combo_streak = 0
	assert_eq(fb.combo_step(), 0, "sem streak, passo 0")
	# 1º perfeito (streak 1) ainda é passo 0; a escada cresce a partir do 2º.
	fb._combo_streak = 1
	assert_eq(fb.combo_step(), 0, "1º perfeito = passo 0")
	fb._combo_streak = 2
	assert_eq(fb.combo_step(), 1, "2º perfeito = passo 1")

func test_feedback_combo_step_clamps_to_max():
	var fb := FeedbackSystem.new()
	add_child_autofree(fb)
	fb._combo_streak = 999
	assert_eq(fb.combo_step(), Constants.COMBO_MAX_STEP,
		"streak gigante satura no teto da escada")
