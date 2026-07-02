class_name Curupira
extends Boss

## Boss da Fase 3: Curupira, o mais antigo protetor da mata.
## Indiferente e letal. Pés-para-trás. Verde profundo. Sem fogo.
##
## Quatro padrões com identidade própria — sem padrões genéricos herdados do Boss:
##   MATA (20%):    Tier 2 MISTO ↑→ — wind_up curto, surpresa de direções
##   TRILHA (25%):  Tier 3 SEQUENCIAL ←↑→ — três direções em U
##   RASTRO (30%):  Tier 4 PINGPONG →←→← — rastros invertidos, 2.5x dano
##   ASSOBIO (25%): Tier 1 especial — wind_up longo, janela assassina, 3.0x dano

const MATA_PATTERN   := preload("res://resources/attack_patterns/curupira_mata_pattern.tres")
const TRILHA_PATTERN := preload("res://resources/attack_patterns/curupira_trilha_pattern.tres")
const RASTRO_PATTERN := preload("res://resources/attack_patterns/rastro_pattern.tres")
const ASSOBIO_PATTERN := preload("res://resources/attack_patterns/assobio_pattern.tres")

var _current_is_rastro: bool = false
var _current_is_assobio: bool = false

func _ready() -> void:
	super._ready()

func get_attack_pattern() -> AttackPattern:
	var r := randf()
	_current_is_rastro = false
	_current_is_assobio = false
	_current_is_special = false

	if r < 0.20:
		_active_pattern = MATA_PATTERN           # telegraph vermelho normal
	elif r < 0.45:
		_current_is_rastro = true
		_active_pattern = TRILHA_PATTERN         # telegraph verde (reusa visual do rastro)
	elif r < 0.75:
		_current_is_rastro = true
		_active_pattern = RASTRO_PATTERN
	else:
		_current_is_assobio = true
		_active_pattern = ASSOBIO_PATTERN
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
		_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_CURUPIRA, 0.22)
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
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_CURUPIRA, 0.12)
	_telegraph_tween.tween_property(self, "position:y", home_y, 0.10)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", _base_modulate, 0.10)
	_telegraph_tween.tween_interval(0.06)
	# Salto 2
	_telegraph_tween.tween_property(self, "position:y", home_y - 40.0, 0.12)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_CURUPIRA, 0.12)
	_telegraph_tween.tween_property(self, "position:y", home_y, 0.10)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", _base_modulate, 0.10)

func _spawn_shadow_aura() -> void:
	var aura := CPUParticles2D.new()
	aura.amount = 24
	aura.lifetime = 2.0
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 32.0
	aura.gravity = Vector2(0, -12)
	aura.initial_velocity_min = 3.0
	aura.initial_velocity_max = 10.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = 6.0
	aura.color = Constants.COLOR_AURA_CURUPIRA
	aura.z_index = -1
	add_child(aura)
