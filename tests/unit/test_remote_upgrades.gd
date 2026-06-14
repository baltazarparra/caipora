extends GutTest

# RemoteUpgrades é a camada de override remoto para custo e valor das ervas do cachimbo.
# Injetamos via seam de teste (_set_overrides_for_test) e verificamos precedência/fallback
# através dos helpers públicos de MetaProgression (upgrade_cost/_upgrade_attr).

func after_each() -> void:
	RemoteUpgrades._set_overrides_for_test({})

func test_cost_override_wins_over_baked() -> void:
	RemoteUpgrades._set_overrides_for_test({
		"forca": {"fragment_cost": 99, "value": 1},
	})
	assert_eq(MetaProgression.upgrade_cost("forca"), 99, "custo do override vence o baked")

func test_attr_override_wins_over_baked() -> void:
	RemoteUpgrades._set_overrides_for_test({
		"forca": {"fragment_cost": 5, "value": 9},
	})
	assert_eq(MetaProgression._upgrade_attr("forca"), 9, "valor do override vence o baked")

func test_empty_override_falls_back_to_upgrade_defs() -> void:
	RemoteUpgrades._set_overrides_for_test({})
	assert_eq(MetaProgression.upgrade_cost("forca"), 5, "sem override → custo baked (5)")
	assert_eq(MetaProgression._upgrade_attr("forca"), 1, "sem override → dmg baked (1)")
	assert_eq(MetaProgression.upgrade_cost("saude"), 6, "sem override → custo baked saude (6)")
	assert_eq(MetaProgression._upgrade_attr("saude"), 2, "sem override → hp baked saude (2)")

func test_override_isolated_per_key() -> void:
	RemoteUpgrades._set_overrides_for_test({
		"forca": {"fragment_cost": 99, "value": 9},
	})
	assert_eq(MetaProgression.upgrade_cost("forca_2"), 10, "override de forca não afeta forca_2 (custo)")
	assert_eq(MetaProgression._upgrade_attr("forca_2"), 1, "override de forca não afeta forca_2 (valor)")

func test_has_override_by_key() -> void:
	RemoteUpgrades._set_overrides_for_test({
		"saude": {"fragment_cost": 20, "value": 3},
	})
	assert_true(RemoteUpgrades.has_override("saude"), "has_override true para saude")
	assert_false(RemoteUpgrades.has_override("saude_2"), "has_override false para saude_2")
