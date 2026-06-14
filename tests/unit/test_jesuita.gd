extends GutTest

# Boss FINAL — Jesuíta Bandeirante Catequizador. O contrato central: seu moveset
# é a UNIÃO dos padrões mais difíceis de cada chefe + 2 exclusivos, com a mesma chance.
# Pool de 9: mula_cabecada, boitata_chama_falsa, boitata_white_special, rastro,
#            assobio, saci_rastro, saci_pirulito, jesuita_cruz, jesuita_espada.

var _jesuita: Jesuita

const MULA_CABECADA := "res://resources/attack_patterns/mula_cabecada_pattern.tres"
const CHAMA_FALSA   := "res://resources/attack_patterns/boitata_chama_falsa_pattern.tres"
const WHITE         := "res://resources/attack_patterns/boitata_white_special_pattern.tres"
const RASTRO        := "res://resources/attack_patterns/rastro_pattern.tres"
const ASSOBIO       := "res://resources/attack_patterns/assobio_pattern.tres"
const SACI_RAST     := "res://resources/attack_patterns/saci_rastro_pattern.tres"
const SACI_PIRUL    := "res://resources/attack_patterns/saci_pirulito_pattern.tres"
const CRUZ          := "res://resources/attack_patterns/jesuita_cruz_pattern.tres"
const ESPADA        := "res://resources/attack_patterns/jesuita_espada_pattern.tres"

const EXPECTED := [MULA_CABECADA, CHAMA_FALSA, WHITE, RASTRO, ASSOBIO, SACI_RAST, SACI_PIRUL, CRUZ, ESPADA]

func before_each() -> void:
	_jesuita = preload("res://scenes/arena/jesuita.tscn").instantiate()
	add_child_autofree(_jesuita)

func test_jesuita_inherits_saci_and_boss() -> void:
	assert_true(_jesuita is Saci, "Jesuíta herda de Saci (cadeia de telegraphs)")
	assert_true(_jesuita is Boss, "Jesuíta é um Boss")

func test_jesuita_health_is_44() -> void:
	assert_eq(EnemyStats.max_hp_for(&"jesuita", 5), 44, "HP do boss final")

func test_get_attack_pattern_always_valid() -> void:
	for _i in 50:
		var p := _jesuita.get_attack_pattern()
		assert_not_null(p)
		assert_true(p is AttackPattern)
		assert_true(p.resource_path in EXPECTED,
			"padrão sorteado é de algum chefe: %s" % p.resource_path)

func test_moveset_is_exactly_the_union_of_all_boss_patterns() -> void:
	# Amostragem ampla: cada um dos 9 padrões aparece (mesma chance) e nada além.
	var seen := {}
	for _i in 900:
		seen[_jesuita.get_attack_pattern().resource_path] = true
	for path: String in EXPECTED:
		assert_true(seen.has(path), "moveset inclui %s" % path)
	assert_eq(seen.size(), EXPECTED.size(),
		"moveset é exatamente a união dos padrões dos chefes (sem extras)")

func test_white_special_telegraph_emits_agua_benta_signal() -> void:
	# O wind-up do especial branco anuncia o sibilo de água benta via SignalBus
	# (o AudioDirector escuta — zero acoplamento direto com o áudio).
	watch_signals(SignalBus)
	_jesuita._current_is_white_special = true
	_jesuita._play_windup_telegraph()
	assert_signal_emitted_with_parameters(SignalBus, "boss_special_telegraph", ["jesuita"])

func test_inherited_telegraphs_do_not_emit_special_signal() -> void:
	watch_signals(SignalBus)
	_jesuita._current_is_white_special = false
	_jesuita._play_windup_telegraph()
	assert_signal_not_emitted(SignalBus, "boss_special_telegraph",
		"telegraphs herdados do Saci não têm cue de água benta")

func test_telegraph_flags_match_chosen_pattern() -> void:
	# Os flags de telegraph batem com o padrão retornado — garante o telegraph certo.
	for _i in 900:
		var path := _jesuita.get_attack_pattern().resource_path
		match path:
			WHITE:
				assert_true(_jesuita._current_is_white_special, "branco → flag branco")
				assert_false(_jesuita._current_is_special)
				assert_false(_jesuita._current_is_rastro)
				assert_false(_jesuita._current_is_assobio)
			ASSOBIO:
				assert_true(_jesuita._current_is_assobio, "assobio → flag assobio")
				assert_false(_jesuita._current_is_white_special)
			RASTRO, SACI_RAST:
				assert_true(_jesuita._current_is_rastro, "rastro → flag rastro")
				assert_false(_jesuita._current_is_white_special)
				assert_false(_jesuita._current_is_assobio)
			_:
				# mula_cabecada, chama_falsa, saci_pirulito, cruz, espada: nenhum flag especial.
				assert_false(_jesuita._current_is_special)
				assert_false(_jesuita._current_is_white_special)
				assert_false(_jesuita._current_is_rastro)
				assert_false(_jesuita._current_is_assobio)
