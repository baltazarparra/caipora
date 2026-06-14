extends GutTest

# Boss da Fase 1 refatorado: a Mula sem Cabeça. Mantém os stats do Boss base
# (a primeira luta não muda de dificuldade) e carrega a identidade própria
# (boss_type "mula" → sprite/aura no mapa).

func test_mula_is_a_boss_with_phase1_stats() -> void:
	var mula = preload("res://scenes/arena/mula.tscn").instantiate()
	add_child_autofree(mula)
	assert_true(mula is Boss, "Mula herda do Boss base")
	assert_true(mula is Criatura, "Mula é uma Criatura")
	assert_eq(EnemyStats.max_hp_for(&"mula", 1), 12, "HP do boss P1")
	assert_eq(mula.base_attack_damage, 1)
	assert_eq(mula.attack_pattern.strike_count, 3)

func test_phase1_boss_type_is_mula() -> void:
	assert_eq(MapConfig.for_phase(1).boss_type, "mula",
		"o boss da Fase 1 é a Mula sem Cabeça")
