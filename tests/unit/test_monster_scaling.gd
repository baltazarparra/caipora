extends GutTest

# Escalonamento por fase (PRD: comuns com HP uniforme, dano da Caipora vem da Fúria).
#  - Comuns (não-boss): mesmo HP — 5 nas fases 1-2, 8 nas fases 3-5.
#  - Cada golpe da Caipora parte de 1 em toda fase; upgrades/CHAMA somam por cima.

func test_common_health_uniform_per_phase_band() -> void:
	assert_eq(EnemyStats.common_hp_for_phase(1), 5, "fase 1 → 5")
	assert_eq(EnemyStats.common_hp_for_phase(2), 5, "fase 2 → 5")
	assert_eq(EnemyStats.common_hp_for_phase(3), 8, "fase 3 → 8")
	assert_eq(EnemyStats.common_hp_for_phase(4), 8, "fase 4 → 8")
	assert_eq(EnemyStats.common_hp_for_phase(5), 8, "fase 5 → 8")

func test_caipora_damage_does_not_scale_with_phase() -> void:
	assert_eq(Constants.caipora_base_damage_for_phase(1), 1, "1 de dano por golpe na P1")
	assert_eq(Constants.caipora_base_damage_for_phase(2), 1, "fase não soma dano")
	assert_eq(Constants.caipora_base_damage_for_phase(3), 1, "fase não soma dano")
	assert_eq(Constants.caipora_base_damage_for_phase(4), 1, "fase não soma dano")
	assert_eq(Constants.caipora_base_damage_for_phase(5), 1, "fase não soma dano")

func test_damage_never_below_one() -> void:
	# Guarda defensiva: fase inválida (0) não zera o dano da Caipora.
	assert_eq(Constants.caipora_base_damage_for_phase(0), 1)
