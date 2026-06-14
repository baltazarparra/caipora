extends GutTest

# Trava a FONTE ÚNICA de HP e dano de inimigo (EnemyStats). Edite balanceamento lá.
# O guard crítico é test_scene_script_id_keys_the_table: garante que a chave da
# tabela (nome do script) bate com a cena real — se alguém renomear um script de
# inimigo sem atualizar STATS, este teste falha antes de o jogo aplicar HP errado.

const ENEMY_SCENES := {
	"mula":        "res://scenes/arena/mula.tscn",
	"boitata":     "res://scenes/arena/boitata.tscn",
	"curupira":    "res://scenes/arena/curupira.tscn",
	"saci":        "res://scenes/arena/saci.tscn",
	"jesuita":     "res://scenes/arena/jesuita.tscn",
	"criatura":    "res://scenes/arena/criatura.tscn",
	"cacador":     "res://scenes/arena/cacador.tscn",
	"assombracao": "res://scenes/arena/assombracao.tscn",
	"bruxo":       "res://scenes/arena/bruxo.tscn",
}

func test_scene_script_id_keys_the_table() -> void:
	for expected_id in ENEMY_SCENES:
		var inst: Node = load(ENEMY_SCENES[expected_id]).instantiate()
		add_child_autofree(inst)
		assert_eq(String(EnemyStats.id_for(inst)), expected_id,
			"script de %s deve chavear EnemyStats" % expected_id)
		assert_true(EnemyStats.STATS.has(expected_id),
			"EnemyStats.STATS precisa de uma entrada para %s" % expected_id)

func test_boss_hp_is_fixed_per_phase() -> void:
	assert_eq(EnemyStats.max_hp_for(&"mula", 1), 12, "P1 Mula")
	assert_eq(EnemyStats.max_hp_for(&"boitata", 2), 22, "P2 Boitatá")
	assert_eq(EnemyStats.max_hp_for(&"curupira", 3), 30, "P3 Curupira")
	assert_eq(EnemyStats.max_hp_for(&"saci", 4), 36, "P4 Saci")
	assert_eq(EnemyStats.max_hp_for(&"jesuita", 5), 44, "P5 Jesuíta")

func test_common_hp_scales_by_phase_band() -> void:
	# Comuns ignoram o número fixo e seguem a banda de fase (5 nas 1-2, 8 nas 3-5).
	assert_eq(EnemyStats.max_hp_for(&"criatura", 1), 5, "comum fase 1 → 5")
	assert_eq(EnemyStats.max_hp_for(&"criatura", 2), 5, "comum fase 2 → 5")
	assert_eq(EnemyStats.max_hp_for(&"criatura", 3), 8, "comum fase 3 → 8")
	assert_eq(EnemyStats.max_hp_for(&"bruxo", 5), 8, "comum fase 5 → 8")

func test_unknown_id_falls_back_to_phase_band() -> void:
	assert_eq(EnemyStats.max_hp_for(&"desconhecido", 1), 5, "id desconhecido fase 1 → 5")
	assert_eq(EnemyStats.max_hp_for(&"desconhecido", 4), 8, "id desconhecido fase 4 → 8")

func test_bonus_damage_combines_fixed_and_phase() -> void:
	# bonus_damage_for = fixo da criatura + delta de fase (sem override remoto nos testes).
	assert_almost_eq(EnemyStats.bonus_damage_for(&"bruxo", 1), 1.0, 0.001, "Bruxo +1 fixo, fase 1 sem delta")
	assert_almost_eq(EnemyStats.bonus_damage_for(&"bruxo", 2), 2.0, 0.001, "Bruxo +1 fixo + fase 2 +1")
	assert_almost_eq(EnemyStats.bonus_damage_for(&"cacador", 1), 0.0, 0.001, "Caçador sem bônus, fase 1")
	assert_almost_eq(EnemyStats.bonus_damage_for(&"cacador", 4), 1.0, 0.001, "Caçador + fase 4 +1")
	assert_almost_eq(EnemyStats.bonus_damage_for(&"jesuita", 5), -1.0, 0.001, "Jesuíta + fase 5 -1")
	assert_almost_eq(EnemyStats.bonus_damage_for(&"desconhecido", 3), 0.0, 0.001, "id desconhecido, fase sem delta → 0")

func test_phase_damage_bonus() -> void:
	assert_almost_eq(EnemyStats.phase_damage_bonus(1), 0.0, 0.001, "Fase 1 sem bônus")
	assert_almost_eq(EnemyStats.phase_damage_bonus(2), 1.0, 0.001, "Fase 2 +1")
	assert_almost_eq(EnemyStats.phase_damage_bonus(3), 0.0, 0.001, "Fase 3 sem bônus")
	assert_almost_eq(EnemyStats.phase_damage_bonus(4), 1.0, 0.001, "Fase 4 +1")
	assert_almost_eq(EnemyStats.phase_damage_bonus(5), -1.0, 0.001, "Fase 5 -1 (rebalance)")
