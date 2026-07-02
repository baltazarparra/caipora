class_name Boss
extends Criatura

const CRIATURA_PATTERN := preload("res://resources/attack_patterns/criatura_pattern.tres")
const SPECIAL_PATTERN := preload("res://resources/attack_patterns/boss_special_pattern.tres")
const DOUBLE_BLOCK_PATTERN := preload("res://resources/attack_patterns/boss_double_block_pattern.tres")

const SPECIAL_CHANCE: float = 0.35
const DOUBLE_BLOCK_CHANCE_BOSS: float = 0.30

var _current_is_special: bool = false

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	super._ready()
	_spawn_shadow_aura()

# ─── Public API ────────────────────────────────────
func get_attack_pattern() -> AttackPattern:
	var r := randf()
	var chosen: AttackPattern
	if r < SPECIAL_CHANCE:
		_current_is_special = true
		chosen = SPECIAL_PATTERN
	elif r < SPECIAL_CHANCE + DOUBLE_BLOCK_CHANCE_BOSS:
		_current_is_special = false
		chosen = DOUBLE_BLOCK_PATTERN
	else:
		_current_is_special = false
		chosen = CRIATURA_PATTERN
	_active_pattern = chosen
	return chosen

# ─── Telegraph override ─────────────────────────────
func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	if not _current_is_special:
		super._play_windup_telegraph()
		return
	_kill_telegraph()
	_telegraph_tween = create_tween().set_loops()
	_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_BOSS, 0.22)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.08, 0.22)
	_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.22)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.22)

## Luz frontal reduzida para não competir com a aura de partículas do boss.
func _spawn_front_light() -> void:
	var light := ForestLight.make(
		Constants.COLOR_ENEMY_FRONT_LIGHT,
		0.7,
		Constants.ENEMY_FRONT_LIGHT_SCALE
	)
	light.position = Vector2(-18.0 * sprite_scale, -22.0)
	add_child(light)

# ─── Private helpers ───────────────────────────────
func _spawn_shadow_aura() -> void:
	var aura := CPUParticles2D.new()
	aura.amount = 22
	aura.lifetime = 1.8
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 28.0
	aura.gravity = Vector2(0, -18)
	aura.initial_velocity_min = 4.0
	aura.initial_velocity_max = 12.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = 5.0
	aura.color = Constants.COLOR_AURA_BOSS
	aura.z_index = -1
	add_child(aura)
