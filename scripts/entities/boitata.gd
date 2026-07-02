class_name Boitata
extends Boss

## Boss da Fase 2: Boitatá, serpente de fogo. Introduz Tier 3 (3 botões).
## Padrões com identidade de "fogo que engana": sequências que começam iguais
## mas terminam diferente (CHAMA_FALSA ↑↑↓ vs BRASA_BRANCA ↑↑↓↓).
##
## CHAMA (15%):       Tier 1, wind_up curto — surpresa rápida
## LABAREDA (25%):    Tier 2 PINGPONG ↓↑ — familiar mas num boss novo
## CHAMA_FALSA (35%): Tier 3 ↑↑↓ — começa igual à brasa, termina diferente
## BRASA_BRANCA (25%): Tier 4 ↑↑↓↓ — devastador, overbright

const BOITATA_CHAMA_PATTERN      := preload("res://resources/attack_patterns/boitata_chama_pattern.tres")
const BOITATA_LABAREDA_PATTERN   := preload("res://resources/attack_patterns/boitata_labareda_pattern.tres")
const BOITATA_CHAMA_FALSA_PATTERN := preload("res://resources/attack_patterns/boitata_chama_falsa_pattern.tres")
const WHITE_SPECIAL_PATTERN      := preload("res://resources/attack_patterns/boitata_white_special_pattern.tres")

var _current_is_white_special: bool = false

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	super._ready()

# ─── Public API ────────────────────────────────────
func get_attack_pattern() -> AttackPattern:
	var r := randf()
	_current_is_white_special = false
	_current_is_special = false
	if r < 0.15:
		_active_pattern = BOITATA_CHAMA_PATTERN
	elif r < 0.40:
		_active_pattern = BOITATA_LABAREDA_PATTERN
	elif r < 0.75:
		_active_pattern = BOITATA_CHAMA_FALSA_PATTERN
	else:
		_current_is_white_special = true
		_active_pattern = WHITE_SPECIAL_PATTERN
	return _active_pattern

# ─── Telegraph override ─────────────────────────────
func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	if _current_is_white_special:
		_kill_telegraph()
		_telegraph_tween = create_tween().set_loops()
		_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_BOITATA_WHITE, 0.22)
		_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.08, 0.22)
		_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.22)
		_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.22)
		return
	super._play_windup_telegraph()

# ─── Private helpers ───────────────────────────────
func _spawn_shadow_aura() -> void:
	var aura := CPUParticles2D.new()
	var vp := get_viewport()
	var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
	aura.amount = maxi(1, int(28.0 * ps))
	aura.lifetime = 1.0 if ps < 1.0 else 1.4
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 30.0
	aura.gravity = Vector2(0, -22)
	aura.initial_velocity_min = 6.0
	aura.initial_velocity_max = 16.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = 5.5
	aura.color = Constants.COLOR_AURA_BOITATA
	aura.z_index = -1
	add_child(aura)
