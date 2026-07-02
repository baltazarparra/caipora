class_name CombatActor
extends CharacterBody2D

signal attack_ready
signal attack_executed(damage: float, is_critical: bool)
signal dodge_performed

@onready var health: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var base_attack_damage: int = Constants.DAMAGE_BASE
@export var attack_cooldown: float = Constants.ATTACK_COOLDOWN_SECONDS
@export var critical_multiplier: float = Constants.DAMAGE_CRIT_MULTIPLIER

var _attack_timer: Timer
var _can_attack: bool = true
var _is_dying: bool = false

func _ready() -> void:
	_attack_timer = Timer.new()
	_attack_timer.one_shot = true
	_attack_timer.wait_time = maxf(0.01, attack_cooldown)
	_attack_timer.timeout.connect(_on_attack_cooldown_ready)
	add_child(_attack_timer)
	health.died.connect(_on_health_died)

func start_attack_window() -> void:
	pass

## Executa o ataque e retorna o dano calculado (fonte única de verdade).
## O chamador deve aplicar esse valor via take_damage() em vez de recomputar.
func execute_attack(is_critical: bool = false, multiplier_override: float = 0.0) -> float:
	if _is_dying:
		return 0.0
	var damage: float = float(base_attack_damage)
	if multiplier_override > 0.0:
		damage = damage * multiplier_override
	elif is_critical:
		damage = damage * critical_multiplier
	attack_executed.emit(damage, is_critical)
	_can_attack = false
	_attack_timer.wait_time = maxf(0.01, attack_cooldown)
	_attack_timer.start()
	return damage

func _on_attack_cooldown_ready() -> void:
	_can_attack = true
	attack_ready.emit()

func take_damage(amount: float) -> void:
	if _is_dying:
		return
	health.take_damage(amount)

func is_dying() -> bool:
	return _is_dying

# ─── Morte ─────────────────────────────────────────
## Death animation: flash branco + fade out, então libera o nó.
func _on_health_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	if animated_sprite == null:
		return
	# Quem tem frames de morte (Mula v3+) DESABA sob o flash/fade — 3f a 6fps
	# preenchem os 0.55s do tween; no killing blow o slow-mo do finisher estica
	# a queda de graça.
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"death"):
		animated_sprite.play(&"death")
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(2, 2, 2, 1), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(queue_free)
