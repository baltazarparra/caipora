class_name Cacador
extends Criatura

## Inimigo das Fases 1, 2, 4: caçador com tocha.
## Três padrões coerentes com o framework Tier 1-2:
##   BÁSICO (35%):  Tier 1 ↓ — tutorial
##   DUPLO (30%):   Tier 2 MONO ↓↓ — mesmo botão, mais rápido
##   ESPECIAL (35%): Tier 2 PINGPONG ↓↑ — telegraph âmbar, escala naturalmente por fase

const CACADOR_BASIC_PATTERN  := preload("res://resources/attack_patterns/criatura_pattern.tres")
const CACADOR_DOUBLE_PATTERN := preload("res://resources/attack_patterns/criatura_double_block_pattern.tres")
const CACADOR_SPECIAL_PATTERN := preload("res://resources/attack_patterns/cacador_special_pattern.tres")

const SPECIAL_CHANCE: float = 0.35
const DOUBLE_CHANCE: float  = 0.30

var _current_is_special: bool = false

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	super._ready()
	_spawn_torch_embers()

# ─── Public API ────────────────────────────────────
func get_attack_pattern() -> AttackPattern:
	var r := randf()
	var chosen: AttackPattern
	if r < SPECIAL_CHANCE:
		_current_is_special = true
		chosen = CACADOR_SPECIAL_PATTERN
	elif r < SPECIAL_CHANCE + DOUBLE_CHANCE:
		_current_is_special = false
		chosen = CACADOR_DOUBLE_PATTERN
	else:
		_current_is_special = false
		chosen = CACADOR_BASIC_PATTERN
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
	_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_ENEMY_ALT, 0.20)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.10, 0.20)
	_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.20)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.20)

# ─── Private helpers ───────────────────────────────
func _spawn_torch_embers() -> void:
	var embers := CPUParticles2D.new()
	var vp := get_viewport()
	var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
	embers.amount = maxi(1, int(12.0 * ps))  # densidade cheia em desktop; phone corta (Frente E)
	embers.lifetime = 0.8
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 8.0
	embers.gravity = Vector2(0, -30)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 20.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.0
	embers.color = Constants.COLOR_FIRE_HOT
	embers.position = Vector2(-10, -30)
	embers.z_index = 1
	add_child(embers)
