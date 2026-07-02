class_name Saci
extends Curupira

## Boss da Fase 4: Saci Pererê. A casa arde; ele já não pertence a ela.
## Velocidade e caos — quatro padrões próprios, tudo mais rápido que o Curupira.
##
## ASSOVIO (20%):  Tier 1 especial — wind_up 0.85s, janela 0.4s (piso 0.2s na P4)
## PULA (25%):     Tier 3 PINGPONG ↑↓↑ — strike_delay 0.3s (apertado)
## RASTRO (30%):   Tier 4 PINGPONG →←→← — attack 0.65s, strike_delay 0.25s
## PIRULITO (25%): Tier 4 SEQUENCIAL ↑→↓← — 4 direções horárias, 3.0x dano

const SACI_ASSOVIO_PATTERN  := preload("res://resources/attack_patterns/saci_assovio_pattern.tres")
const SACI_PULA_PATTERN     := preload("res://resources/attack_patterns/saci_pula_pattern.tres")
const SACI_RASTRO_PATTERN   := preload("res://resources/attack_patterns/saci_rastro_pattern.tres")
const SACI_PIRULITO_PATTERN := preload("res://resources/attack_patterns/saci_pirulito_pattern.tres")

func get_attack_pattern() -> AttackPattern:
	var r := randf()
	_current_is_rastro = false
	_current_is_assobio = false
	_current_is_special = false

	if r < 0.20:
		_current_is_assobio = true
		_active_pattern = SACI_ASSOVIO_PATTERN   # salto duplo (telegraph herdado)
	elif r < 0.45:
		_active_pattern = SACI_PULA_PATTERN      # telegraph vermelho normal
	elif r < 0.75:
		_current_is_rastro = true
		_active_pattern = SACI_RASTRO_PATTERN    # telegraph fogo (herdado)
	else:
		_active_pattern = SACI_PIRULITO_PATTERN  # telegraph vermelho normal
	return _active_pattern

func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	if _current_is_assobio:
		_kill_telegraph()
		_play_double_jump_telegraph()
		return
	if _current_is_rastro:
		_kill_telegraph()
		_telegraph_tween = create_tween().set_loops()
		_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_SACI, 0.22)
		_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.10, 0.22)
		_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.22)
		_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.22)
		return
	super._play_windup_telegraph()

func _play_double_jump_telegraph() -> void:
	var home_y := position.y
	_telegraph_tween = create_tween()
	# Salto 1
	_telegraph_tween.tween_property(self, "position:y", home_y - 40.0, 0.12)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_SACI, 0.12)
	_telegraph_tween.tween_property(self, "position:y", home_y, 0.10)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", _base_modulate, 0.10)
	_telegraph_tween.tween_interval(0.06)
	# Salto 2
	_telegraph_tween.tween_property(self, "position:y", home_y - 40.0, 0.12)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_SACI, 0.12)
	_telegraph_tween.tween_property(self, "position:y", home_y, 0.10)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", _base_modulate, 0.10)

func _spawn_shadow_aura() -> void:
	var aura := CPUParticles2D.new()
	aura.amount = 26
	aura.lifetime = 1.8
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 30.0
	aura.gravity = Vector2(0, -16)
	aura.initial_velocity_min = 4.0
	aura.initial_velocity_max = 12.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = 6.0
	aura.color = Constants.COLOR_AURA_SACI
	aura.z_index = -1
	add_child(aura)
