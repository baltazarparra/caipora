extends GutTest

# Trava o contrato de variação anti-repetição do SfxSystem:
#   - no _ready, descobre as variantes por convenção de nome (hit.wav -> hit_2/_3)
#   - play() roteia para o bus "SFX"
#   - o round-robin percorre todas as variantes sem repetir em sequência
# Não valida áudio audível (isso é manual), só a lógica de seleção.

const HIT_PATH := "res://assets/audio/sfx/hit.wav"

var _sfx: SfxSystem

func before_each():
	_sfx = SfxSystem.new()
	_sfx.hit_sound = load(HIT_PATH)
	add_child_autofree(_sfx)  # dispara _ready -> _register_variants

func test_discovers_all_three_variants():
	var list: Array = _sfx._variants.get(HIT_PATH, [])
	assert_eq(list.size(), 3, "hit deve ter primário + 2 variantes (_2, _3)")

func test_round_robin_cycles_through_variants():
	var seen := {}
	for _i in 6:
		seen[_sfx._next_variant(_sfx.hit_sound)] = true
	assert_eq(seen.size(), 3, "round-robin deve tocar as 3 variantes ao longo do ciclo")

func test_play_routes_to_sfx_bus():
	_sfx.play(_sfx.hit_sound)
	var player: AudioStreamPlayer = null
	for child in _sfx.get_children():
		if child is AudioStreamPlayer:
			player = child
			break
	assert_not_null(player, "play() deve criar um AudioStreamPlayer")
	assert_eq(player.bus, SfxSystem.SFX_BUS)

func test_play_named_resolves_and_discovers_variants():
	assert_true(_sfx.play_named("hurt_caipora"), "asset existente deve tocar")
	var list: Array = _sfx._variants.get("res://assets/audio/sfx/hurt_caipora.wav", [])
	assert_eq(list.size(), 3, "play_named deve descobrir primário + _2/_3 por convenção")

func test_play_named_missing_asset_is_silent_noop():
	assert_false(_sfx.play_named("som_que_nao_existe"),
		"asset ausente devolve false (fallback fica no chamador) e não quebra")
	var players := 0
	for child in _sfx.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_eq(players, 0, "no-op não deve criar player")

func test_step_assets_exist_for_both_grounds():
	# S3: serrapilheira (fases 1-4 e hub) e laje da igreja (fase 5).
	for sound_name in ["step_grass", "step_stone"]:
		assert_true(_sfx.play_named(sound_name, Constants.STEP_VOLUME_DB),
			"%s deve existir com geração procedural" % sound_name)

func test_p1_tactile_assets_exist():
	# S4: hub/UI premium — colher a erva, fumar o cachimbo, tick de hover.
	for sound_name in ["herb_pickup", "pipe_smoke", "ui_hover"]:
		assert_true(_sfx.play_named(sound_name),
			"%s deve existir com geração procedural" % sound_name)

# ─── Áudio v4 Etapa 1: a escada de impacto do combate ──
func test_combat_outcome_assets_exist():
	# Os dois sons novos da escada (errou / crítico) com primário + _2/_3.
	for sound_name in ["combat_miss", "hit_heavy"]:
		assert_true(_sfx.play_named(sound_name),
			"%s deve existir com geração procedural" % sound_name)
		var list: Array = _sfx._variants.get("res://assets/audio/sfx/%s.wav" % sound_name, [])
		assert_eq(list.size(), 3, "%s deve ter primário + _2/_3" % sound_name)

func test_play_outcome_routes_every_result():
	# O dispatch declara o resultado; o vocabulário sonoro vive no SfxSystem. Aqui
	# provamos que os 5 resultados tocam sem erro (com os assets presentes).
	_sfx.dodge_sound = load("res://assets/audio/sfx/dodge.wav")
	_sfx.timing_perfect_sound = load("res://assets/audio/sfx/timing_perfect.wav")
	_sfx.ui_click_sound = load("res://assets/audio/sfx/ui_click.wav")
	for outcome in [SfxSystem.Outcome.MISS, SfxSystem.Outcome.HIT,
			SfxSystem.Outcome.CRIT, SfxSystem.Outcome.DODGE, SfxSystem.Outcome.HURT]:
		_sfx.play_outcome(outcome)
	var players := 0
	for child in _sfx.get_children():
		if child is AudioStreamPlayer:
			players += 1
	assert_gt(players, 0, "play_outcome deve ter criado players de SFX")

func test_play_outcome_miss_falls_back_when_asset_missing():
	# Se combat_miss não existir, o MISS cai no ui_click (sem quebrar) — o drop-in
	# do asset apenas substitui o fallback.
	var bare := SfxSystem.new()
	bare.ui_click_sound = load("res://assets/audio/sfx/ui_click.wav")
	add_child_autofree(bare)
	# Não registramos combat_miss propositalmente; força o ramo de fallback.
	bare._named["combat_miss"] = null
	bare.play_outcome(SfxSystem.Outcome.MISS)
	var played := false
	for child in bare.get_children():
		if child is AudioStreamPlayer:
			played = true
	assert_true(played, "MISS sem combat_miss deve tocar o fallback ui_click")
