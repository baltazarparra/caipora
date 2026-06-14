extends GutTest

var _cacador: Cacador

func before_each() -> void:
	_cacador = preload("res://scenes/arena/cacador.tscn").instantiate()
	add_child_autofree(_cacador)

func test_cacador_is_a_criatura() -> void:
	assert_true(_cacador is Criatura, "Cacador herda de Criatura")

func test_cacador_has_correct_health() -> void:
	# Comuns têm HP uniforme por banda de fase (5 nas fases 1-2, 8 nas 3-5);
	# o ArenaManager aplica EnemyStats por fase no spawn (a cena não conta).
	assert_eq(EnemyStats.max_hp_for(&"cacador", 1), 5, "fases 1-2 → 5")
	assert_eq(EnemyStats.max_hp_for(&"cacador", 3), 8, "fases 3-5 → 8")
	assert_eq(EnemyStats.COMMON_HP_EARLY, 5)
	assert_eq(EnemyStats.COMMON_HP_LATE, 8)

func test_special_pattern_fields() -> void:
	# Tier 2 PINGPONG ↓↑ — redesenhado de Tier 4 para ser coerente com Fase 1
	var p := preload("res://resources/attack_patterns/cacador_special_pattern.tres")
	assert_eq(p.strike_count, 2)
	assert_true(p.is_special)
	assert_almost_eq(p.damage_multiplier, 1.5, 0.001)
	assert_almost_eq(p.strike_delay, 0.45, 0.001)

func test_special_pattern_input_sequence() -> void:
	var p := preload("res://resources/attack_patterns/cacador_special_pattern.tres")
	assert_eq(p.input_sequence.size(), 2)
	assert_eq(p.input_sequence[0], "ui_down")
	assert_eq(p.input_sequence[1], "ui_up")

func test_get_attack_pattern_returns_valid_pattern() -> void:
	var pattern := _cacador.get_attack_pattern()
	assert_not_null(pattern)
	assert_true(pattern is AttackPattern)
