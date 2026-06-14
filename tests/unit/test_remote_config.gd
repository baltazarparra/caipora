extends GutTest

# RemoteConfig é a camada de override remoto na frente de EnemyStats. Aqui injetamos
# overrides via o seam de teste (sem rede) e confirmamos a precedência e o fallback.
# IMPORTANTE: limpar no after_each para não vazar overrides para os outros testes.

func after_each() -> void:
	RemoteConfig._set_overrides_for_test({})

func test_hp_and_damage_override_win() -> void:
	RemoteConfig._set_overrides_for_test({
		"mula@1": {"hp": 99, "damage": 7.0},
	})
	assert_eq(EnemyStats.max_hp_for(&"mula", 1), 99, "HP do override vence o fixo")
	assert_almost_eq(EnemyStats.bonus_damage_for(&"mula", 1), 7.0, 0.001, "dano do override é o total")

func test_empty_overrides_fall_back_to_defaults() -> void:
	RemoteConfig._set_overrides_for_test({})
	assert_eq(EnemyStats.max_hp_for(&"mula", 1), 12, "sem override → HP fixo do boss")
	# cacador fase 2: fixo 0 + delta fase 2 (+1) = 1.0
	assert_almost_eq(EnemyStats.bonus_damage_for(&"cacador", 2), 1.0, 0.001, "sem override → fixo+fase")

func test_hp_zero_override_is_ignored() -> void:
	RemoteConfig._set_overrides_for_test({
		"mula@1": {"hp": 0, "damage": 0.0},
	})
	assert_eq(EnemyStats.max_hp_for(&"mula", 1), 12, "HP de override <= 0 cai no default")

func test_override_is_isolated_per_phase() -> void:
	RemoteConfig._set_overrides_for_test({
		"mula@1": {"hp": 50, "damage": 3.0},
	})
	assert_eq(EnemyStats.max_hp_for(&"mula", 1), 50, "fase 1 usa o override")
	assert_eq(EnemyStats.max_hp_for(&"mula", 5), 12, "fase 5 não é afetada pelo override da fase 1")

func test_has_override_keys_by_id_and_phase() -> void:
	RemoteConfig._set_overrides_for_test({
		"bruxo@3": {"hp": 8, "damage": 1.0},
	})
	assert_true(RemoteConfig.has_override(&"bruxo", 3), "override de bruxo@3 existe")
	assert_false(RemoteConfig.has_override(&"bruxo", 2), "não há override de bruxo@2")
