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
