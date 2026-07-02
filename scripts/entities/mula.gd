class_name Mula
extends Boss

## Boss da Fase 1: a Mula sem Cabeça. Fase de aprendizado — máximo Tier 2 (2 botões).
## Três padrões com identidade própria: COICE (tutorial), GALOPE (MONO duplo),
## CABEÇADA (PINGPONG ↓↑ — primeira sequência real do jogo).

const MULA_COICE_PATTERN    := preload("res://resources/attack_patterns/criatura_pattern.tres")
const MULA_GALOPE_PATTERN   := preload("res://resources/attack_patterns/mula_galope_pattern.tres")
const MULA_CABECADA_PATTERN := preload("res://resources/attack_patterns/mula_cabecada_pattern.tres")

# ─── Public API ────────────────────────────────────
func get_attack_pattern() -> AttackPattern:
	var r := randf()
	_current_is_special = false
	if r < 0.40:
		_active_pattern = MULA_COICE_PATTERN
	elif r < 0.75:
		_active_pattern = MULA_GALOPE_PATTERN
	else:
		_current_is_special = true  # ativa telegraph laranja
		_active_pattern = MULA_CABECADA_PATTERN
	return _active_pattern

# ─── Animation override ─────────────────────────────
func _on_state_changed(new_state: EnemyStateMachine.State) -> void:
	super._on_state_changed(new_state)
	if animated_sprite == null:
		return
	match new_state:
		EnemyStateMachine.State.WIND_UP:
			animated_sprite.play(&"windup")
		EnemyStateMachine.State.ATTACK, EnemyStateMachine.State.IDLE, EnemyStateMachine.State.COOLDOWN:
			animated_sprite.play(&"idle")

# ─── Telegraph override ─────────────────────────────
func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	if not _current_is_special:
		super._play_windup_telegraph()
		return
	_kill_telegraph()
	_telegraph_tween = create_tween().set_loops()
	_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_MULA, 0.22)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.08, 0.22)
	_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.22)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.22)

# ─── Private helpers ───────────────────────────────
func _spawn_shadow_aura() -> void:
	# Brasas e fumaça subindo do toco em chamas (substitui a aura roxa do Boss base).
	var aura := CPUParticles2D.new()
	aura.amount = 24
	aura.lifetime = 1.5
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 26.0
	aura.gravity = Vector2(0, -24)
	aura.initial_velocity_min = 6.0
	aura.initial_velocity_max = 18.0
	aura.scale_amount_min = 2.0
	aura.scale_amount_max = 4.5
	aura.color = Constants.COLOR_AURA_MULA
	aura.z_index = -1
	add_child(aura)
