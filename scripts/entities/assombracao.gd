class_name Assombracao
extends Criatura

## Inimigo da Fase 3: espectro de caçador antigo. Rápido e incorpóreo.
## 2 golpes por padrão básico. Aura de partículas fantasmais cinza-azuladas.

const ASSOMBRACAO_PATTERN := preload("res://resources/attack_patterns/assombracao_pattern.tres")
const ASSOMBRACAO_DOUBLE := preload("res://resources/attack_patterns/criatura_double_block_pattern.tres")

const DOUBLE_CHANCE_ASSOMBRACAO: float = 0.30

func _ready() -> void:
	super._ready()
	if attack_pattern == null:
		attack_pattern = ASSOMBRACAO_PATTERN
	if double_block_pattern == null:
		double_block_pattern = ASSOMBRACAO_DOUBLE
	_spawn_spectral_aura()

func get_attack_pattern() -> AttackPattern:
	var chosen: AttackPattern
	if randf() < DOUBLE_CHANCE_ASSOMBRACAO:
		_active_pattern = ASSOMBRACAO_DOUBLE
		chosen = ASSOMBRACAO_DOUBLE
	else:
		_active_pattern = ASSOMBRACAO_PATTERN
		chosen = ASSOMBRACAO_PATTERN
	return chosen

func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	_kill_telegraph()
	var ghost_color := Color(0.6, 0.75, 1.0, 0.9)
	_telegraph_tween = create_tween().set_loops()
	_telegraph_tween.tween_property(animated_sprite, "modulate", ghost_color, 0.15)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.06, 0.15)
	_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.15)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.15)

func _spawn_spectral_aura() -> void:
	var aura := CPUParticles2D.new()
	var vp := get_viewport()
	var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
	aura.amount = maxi(1, int(14.0 * ps))  # densidade cheia em desktop; phone corta (Frente E)
	aura.lifetime = 1.2
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 18.0
	aura.gravity = Vector2(0, -25)
	aura.initial_velocity_min = 5.0
	aura.initial_velocity_max = 14.0
	aura.scale_amount_min = 1.5
	aura.scale_amount_max = 3.5
	aura.color = Color(0.55, 0.68, 0.95, 0.6)
	aura.z_index = -1
	add_child(aura)
