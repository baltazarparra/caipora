class_name Jesuita
extends Saci

## Boss FINAL — Fase 5: Jesuíta Bandeirante Catequizador.
## "converti todos eles com espelhos e água benta. a floresta pertence ao vaticano."
##
## Moveset = os padrões mais difíceis/identitários de cada boss + 2 exclusivos,
## com a MESMA chance (1/9 cada). O tuning da fase (janela igual à Fase 4,
## −1 de dano por golpe com piso de 1) NÃO vive aqui — é da Fase 5
## (Constants.PHASE5_*), aplicado igualmente a ele e aos 4 chefes-monstro.
##
## Telegraph: BRASA_BRANCA → branco (flag própria); RASTRO/TRILHA/PIRULITO →
## verde/fogo via _current_is_rastro; ASSOVIO → salto duplo; resto → vermelho.

## Padrões herdados fora da cadeia Saci→Curupira→Boss
const MULA_CABECADA_PATTERN      := preload("res://resources/attack_patterns/mula_cabecada_pattern.tres")
const BOITATA_CHAMA_FALSA_PATTERN := preload("res://resources/attack_patterns/boitata_chama_falsa_pattern.tres")
const WHITE_SPECIAL_PATTERN      := preload("res://resources/attack_patterns/boitata_white_special_pattern.tres")
const JESUITA_CRUZ_PATTERN       := preload("res://resources/attack_patterns/jesuita_cruz_pattern.tres")
const JESUITA_ESPADA_PATTERN     := preload("res://resources/attack_patterns/jesuita_espada_pattern.tres")

var _current_is_white_special: bool = false

func get_attack_pattern() -> AttackPattern:
	_current_is_special = false
	_current_is_rastro = false
	_current_is_assobio = false
	_current_is_white_special = false

	# Pool uniforme: 7 herdados (os mais difíceis de P1-P4) + 2 exclusivos = 9
	var pool: Array[AttackPattern] = [
		MULA_CABECADA_PATTERN,       # Mula: PINGPONG ↓↑
		BOITATA_CHAMA_FALSA_PATTERN, # Boitatá: MONO→MISTO ↑↑↓
		WHITE_SPECIAL_PATTERN,       # Boitatá: MONO ↑↑↓↓ (overbright)
		RASTRO_PATTERN,              # Curupira: PINGPONG →←→←
		ASSOBIO_PATTERN,             # Curupira: janela assassina
		SACI_RASTRO_PATTERN,         # Saci: rastro acelerado
		SACI_PIRULITO_PATTERN,       # Saci: SEQUENCIAL ↑→↓←
		JESUITA_CRUZ_PATTERN,        # Jesuíta: SEQUENCIAL ↑↓→ (L)
		JESUITA_ESPADA_PATTERN,      # Jesuíta: MISTO ↑→↓→ (mais letal)
	]
	var idx := randi() % pool.size()
	match idx:
		2: _current_is_white_special = true
		3: _current_is_rastro = true
		4: _current_is_assobio = true
		5: _current_is_rastro = true  # rastro do Saci reusa telegraph de rastro
	_active_pattern = pool[idx]
	return _active_pattern

func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	# O branco do Boitatá é o único telegraph fora da cadeia herdada do Saci.
	if _current_is_white_special:
		SignalBus.boss_special_telegraph.emit("jesuita")  # sibilo de água benta
		_kill_telegraph()
		_telegraph_tween = create_tween().set_loops()
		_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_JESUITA, 0.22)
		_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.10, 0.22)
		_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.22)
		_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.22)
		return
	super._play_windup_telegraph()

func _spawn_shadow_aura() -> void:
	# Fumaça de incenso podre subindo — dourado-acinzentado corrompido.
	var aura := CPUParticles2D.new()
	aura.amount = 28
	aura.lifetime = 1.9
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 32.0
	aura.gravity = Vector2(0, -14)
	aura.initial_velocity_min = 3.0
	aura.initial_velocity_max = 11.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = 6.0
	aura.color = Constants.COLOR_AURA_JESUITA
	aura.z_index = -1
	add_child(aura)
