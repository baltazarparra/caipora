extends GutTest

# Efeitos HD das miniaturas do mapa: coroa orbital + luz só em set piece
# (boss/miniboss), brasa de libertação gated, modo leve intocado.

var _saved_last_defeated: String

func before_each() -> void:
	Quality._set_for_test(true)
	_saved_last_defeated = GameState.last_defeated_enemy_id

func after_each() -> void:
	Quality._reset_for_test()
	GameState.last_defeated_enemy_id = _saved_last_defeated

func _make_enemy(boss: bool, boss_type: String = "", enemy_type: String = "") -> MapEnemy:
	var enemy := MapEnemy.new()
	add_child_autofree(enemy)
	enemy.setup("e_%s" % [boss_type if boss else enemy_type], Vector2i(3, 3),
		boss, boss_type, Vector2i(-1, -1), enemy_type)
	return enemy

func test_boss_has_orbiting_crown_and_map_light() -> void:
	var boss := _make_enemy(true, "boitata")
	var crown := boss.get_node_or_null("AuraRing") as CPUParticles2D
	assert_not_null(crown, "chefe do mapa tem coroa orbital em HD")
	assert_gt(crown.orbit_velocity_max, 0.0, "a coroa ORBITA")
	assert_true(crown.local_coords,
		"órbita em coords locais: acompanha o teleporte por tile")
	assert_eq(crown.material, Constants.ADDITIVE_MATERIAL, "material compartilhado")
	var light := boss._sprite.get_node_or_null("ParticleRim/RimLight") as PointLight2D
	assert_not_null(light, "chefe do mapa tem luz de rim")
	assert_almost_eq(light.texture_scale, Constants.RIM_LIGHT_SCALE_MAP, 0.001,
		"raio de MAPA (tile 32px)")

func test_miniboss_has_crown_common_does_not() -> void:
	var mini := _make_enemy(false, "", "boitata")
	assert_not_null(mini.get_node_or_null("AuraRing"), "convertido é set piece: coroa")
	var common := _make_enemy(false, "", "bruxo")
	assert_null(common.get_node_or_null("AuraRing"), "comum não tem coroa")
	assert_null(common._sprite.get_node_or_null("ParticleRim/RimLight"),
		"comum não tem luz (8 comuns estourariam o orçamento)")

func test_hd_off_leaves_map_untouched() -> void:
	Quality._set_for_test(false)
	var boss := _make_enemy(true, "mula")
	assert_null(boss.get_node_or_null("AuraRing"), "modo leve: sem coroa")
	assert_null(boss._sprite.get_node_or_null("ParticleRim"), "modo leve: sem rim")
