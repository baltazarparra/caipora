extends GutTest

# RemotePatterns é a camada de override remoto na frente dos .tres de AttackPattern.
# Injetamos overrides via seam de teste (sem rede) e verificamos precedência e fallback.

const SACI_PIRULITO := "res://resources/attack_patterns/saci_pirulito_pattern.tres"
const SACI_ASSOVIO := "res://resources/attack_patterns/saci_assovio_pattern.tres"

func after_each() -> void:
	RemotePatterns._set_overrides_for_test({})

func test_override_wins_over_baked_tres() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"wind_up_duration": 0.1,
			"attack_duration": 0.5,
			"strike_count": 2,
			"strike_delay": 0.2,
			"damage_multiplier": 9.0,
		},
	})
	var base := load(SACI_PIRULITO) as AttackPattern
	var patched := RemotePatterns.apply(base)
	assert_almost_eq(patched.attack_duration, 0.5, 0.001, "attack_duration do override vence")
	assert_almost_eq(patched.damage_multiplier, 9.0, 0.001, "damage_multiplier do override vence")
	assert_eq(patched.strike_count, 2, "strike_count do override vence")

func test_empty_overrides_return_original() -> void:
	RemotePatterns._set_overrides_for_test({})
	var base := load(SACI_PIRULITO) as AttackPattern
	var result := RemotePatterns.apply(base)
	assert_eq(result, base, "sem override → retorna o .tres original")

func test_apply_returns_duplicate_not_original() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.5,
			"strike_count": 2,
			"damage_multiplier": 9.0,
		},
	})
	var base := load(SACI_PIRULITO) as AttackPattern
	var original_duration := base.attack_duration
	var patched := RemotePatterns.apply(base)
	assert_ne(patched, base, "apply com override retorna duplicata, não o original")
	assert_almost_eq(base.attack_duration, original_duration, 0.001, ".tres original não foi modificado")

func test_override_is_isolated_per_pattern() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.2,
			"strike_count": 1,
			"damage_multiplier": 5.0,
		},
	})
	var assobio := load(SACI_ASSOVIO) as AttackPattern
	var result := RemotePatterns.apply(assobio)
	assert_eq(result, assobio, "override de saci_pirulito não afeta saci_assovio")

func test_has_override_key_matches_filename() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.5,
			"strike_count": 2,
			"damage_multiplier": 2.0,
		},
	})
	var pirulito := load(SACI_PIRULITO) as AttackPattern
	var assobio := load(SACI_ASSOVIO) as AttackPattern
	assert_true(RemotePatterns.has_override(pirulito), "has_override true para saci_pirulito_pattern")
	assert_false(RemotePatterns.has_override(assobio), "has_override false para saci_assovio_pattern")

func test_new_fields_override_applies() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.5,
			"strike_count": 3,
			"damage_multiplier": 2.0,
			"strike_intervals": [0.2, 0.4],
			"next_turn_delay": 1.1,
			"action_windows": {"1": 0.9, "4": 0.6},
		},
	})
	var patched := RemotePatterns.apply(load(SACI_PIRULITO) as AttackPattern)
	assert_eq(patched.strike_intervals.size(), 2, "strike_intervals aplicado")
	assert_almost_eq(patched.strike_intervals[1], 0.4, 0.001, "intervalo por hit aplicado")
	assert_almost_eq(patched.next_turn_delay, 1.1, 0.001, "next_turn_delay aplicado")
	assert_almost_eq(float(patched.action_windows["4"]), 0.6, 0.001, "janela de ação da fase 4 aplicada")

func test_action_window_below_min_is_dropped() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.5,
			"strike_count": 1,
			"damage_multiplier": 2.0,
			"action_windows": {"1": 0.05, "2": 0.7},
		},
	})
	var patched := RemotePatterns.apply(load(SACI_PIRULITO) as AttackPattern)
	assert_false(patched.action_windows.has("1"), "janela < TIMING_WINDOW_MIN é descartada no sanitize")
	assert_true(patched.action_windows.has("2"), "janela válida sobrevive")

func test_baked_identity_fields_present() -> void:
	# Fase 1: os .tres carregam nome/som/vfx do PRD moves nomeados.
	var pirulito := load(SACI_PIRULITO) as AttackPattern
	assert_eq(pirulito.display_name, "Travessura", "display_name baked no .tres")
	assert_eq(pirulito.audio_event, "mv_travessura", "audio_event baked no .tres")
	assert_eq(pirulito.vfx_id, "travessura", "vfx_id baked no .tres")

func test_identity_override_applies() -> void:
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.5,
			"strike_count": 1,
			"damage_multiplier": 2.0,
			"display_name": "Outro Nome",
			"audio_event": "mv_outro",
		},
	})
	var patched := RemotePatterns.apply(load(SACI_PIRULITO) as AttackPattern)
	assert_eq(patched.display_name, "Outro Nome", "display_name do override vence")
	assert_eq(patched.audio_event, "mv_outro", "audio_event do override vence")

func test_vfx_id_is_not_remote_overridable() -> void:
	# vfx_id fica baked: nem o sanitize nem o apply propagam o valor remoto.
	RemotePatterns._set_overrides_for_test({
		"saci_pirulito_pattern": {
			"attack_duration": 0.5,
			"strike_count": 1,
			"damage_multiplier": 2.0,
			"vfx_id": "hackeado",
		},
	})
	var patched := RemotePatterns.apply(load(SACI_PIRULITO) as AttackPattern)
	assert_eq(patched.vfx_id, "travessura", "vfx_id permanece o baked, ignorando o override")

func test_transition_window_global() -> void:
	RemotePatterns._set_overrides_for_test({
		"__global__": {"transition_window": 0.8},
	})
	assert_almost_eq(RemotePatterns.transition_window(0.5), 0.8, 0.001, "override global vence o default")

func test_transition_window_default_when_absent() -> void:
	RemotePatterns._set_overrides_for_test({})
	assert_almost_eq(RemotePatterns.transition_window(0.5), 0.5, 0.001, "sem override → default")

func test_global_key_is_not_a_pattern_override() -> void:
	RemotePatterns._set_overrides_for_test({
		"__global__": {"transition_window": 0.8},
	})
	var assobio := load(SACI_ASSOVIO) as AttackPattern
	assert_false(RemotePatterns.has_override(assobio), "__global__ não vira override de pattern")
	assert_eq(RemotePatterns.apply(assobio), assobio, "__global__ não altera nenhum pattern")
