extends GutTest

var _boitata: Boitata

func before_each() -> void:
	_boitata = preload("res://scenes/arena/boitata.tscn").instantiate()
	add_child_autofree(_boitata)

func test_boitata_is_a_boss() -> void:
	assert_true(_boitata is Boss, "Boitata herda de Boss")

func test_boitata_has_correct_health() -> void:
	assert_eq(EnemyStats.max_hp_for(&"boitata", 2), 22, "HP do boss P2")

func test_white_special_pattern_fields() -> void:
	var p := preload("res://resources/attack_patterns/boitata_white_special_pattern.tres")
	assert_eq(p.strike_count, 4)
	assert_true(p.is_special)
	assert_almost_eq(p.damage_multiplier, 3.0, 0.001)
	assert_almost_eq(p.strike_delay, 0.35, 0.001)  # Tier 4: 0.35s

func test_white_special_input_sequence() -> void:
	var p := preload("res://resources/attack_patterns/boitata_white_special_pattern.tres")
	assert_eq(p.input_sequence.size(), 4)
	assert_eq(p.input_sequence[0], "ui_up")
	assert_eq(p.input_sequence[1], "ui_up")
	assert_eq(p.input_sequence[2], "ui_down")
	assert_eq(p.input_sequence[3], "ui_down")

func test_white_special_is_harder_than_chama_falsa() -> void:
	# BRASA_BRANCA (Tier 4) tem janela menor e dano maior que CHAMA_FALSA (Tier 3)
	var white    := preload("res://resources/attack_patterns/boitata_white_special_pattern.tres")
	var falsa    := preload("res://resources/attack_patterns/boitata_chama_falsa_pattern.tres")
	assert_true(white.attack_duration <= falsa.attack_duration,
		"brasa branca tem janela <= chama falsa (Tier 4 ≤ Tier 3)")
	assert_true(white.damage_multiplier > falsa.damage_multiplier,
		"brasa branca bate mais forte que chama falsa")

func test_get_attack_pattern_returns_valid_pattern() -> void:
	var pattern := _boitata.get_attack_pattern()
	assert_not_null(pattern)
	assert_true(pattern is AttackPattern)
