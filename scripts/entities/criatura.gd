class_name Criatura
extends CombatActor

## Inimigo da arena. Possui uma EnemyStateMachine (nó filho) que dirige seu
## ciclo de ataque a partir de um AttackPattern. O ArenaManager apenas escuta.
## O telegraph visual (pulso + lunge) reage aos estados da própria StateMachine.

@export var attack_pattern: AttackPattern
@export var double_block_pattern: AttackPattern
@export var sprite_scale: float = 2.0

const DOUBLE_BLOCK_CHANCE: float = 0.35

@onready var state_machine: EnemyStateMachine = $EnemyStateMachine

var _base_scale: Vector2 = Vector2.ONE
var _base_modulate: Color = Color.WHITE
var _telegraph_tween: Tween
var _home_x: float = 0.0
var _active_pattern: AttackPattern

func _ready() -> void:
	super._ready()
	collision_layer = 1 << (Constants.LAYER_ENEMY - 1)
	collision_mask = 1 << (Constants.LAYER_PLAYER - 1)

	_base_scale = Vector2(sprite_scale, sprite_scale)
	if animated_sprite:
		animated_sprite.scale = _base_scale
		_base_modulate = animated_sprite.modulate  # preserva tom base (ex: Boss)

	if attack_pattern == null:
		attack_pattern = preload("res://resources/attack_patterns/criatura_pattern.tres")
	if double_block_pattern == null:
		double_block_pattern = preload("res://resources/attack_patterns/criatura_double_block_pattern.tres")

	_active_pattern = attack_pattern

	if state_machine != null:
		state_machine.state_changed.connect(_on_state_changed)
	health.died.connect(_kill_telegraph)

	_spawn_shadow()
	_spawn_front_light()
	_apply_outline_shader()
	_spawn_particle_rim()

# ─── Telegraph ─────────────────────────────────────
func _on_state_changed(new_state: EnemyStateMachine.State) -> void:
	match new_state:
		EnemyStateMachine.State.WIND_UP:
			_play_windup_telegraph()
		EnemyStateMachine.State.ATTACK:
			_play_attack_lunge()

## Pulso vermelho crescente — ou pulo laranja se o padrão ativo pede jump_telegraph.
func _play_windup_telegraph() -> void:
	if animated_sprite == null:
		return
	_kill_telegraph()
	if _active_pattern != null and _active_pattern.jump_telegraph:
		_play_jump_telegraph()
		return
	_telegraph_tween = create_tween().set_loops()
	_telegraph_tween.tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_ENEMY, 0.18)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.12, 0.18)
	_telegraph_tween.tween_property(animated_sprite, "modulate", _base_modulate, 0.18)
	_telegraph_tween.parallel().tween_property(animated_sprite, "scale", _base_scale, 0.18)

## Pulo vertical + flash laranja: sinaliza ataque duplo.
func _play_jump_telegraph() -> void:
	var home_y := position.y
	_telegraph_tween = create_tween()
	_telegraph_tween.tween_property(self, "position:y", home_y - 40.0, 0.12)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", Constants.COLOR_TELEGRAPH_ENEMY_ALT, 0.12)
	_telegraph_tween.tween_property(self, "position:y", home_y, 0.10)
	_telegraph_tween.parallel().tween_property(animated_sprite, "modulate", _base_modulate, 0.10)

## Lunge curto em direção à Caipora (esquerda) no início do ataque.
func _play_attack_lunge() -> void:
	if animated_sprite == null:
		return
	_kill_telegraph()
	animated_sprite.modulate = _base_modulate
	animated_sprite.scale = _base_scale
	_home_x = position.x
	var lunge := create_tween()
	lunge.tween_property(self, "position:x", _home_x - 80.0, 0.1)
	lunge.tween_property(self, "position:x", _home_x, 0.1)

func get_attack_pattern() -> AttackPattern:
	if double_block_pattern != null and randf() < DOUBLE_BLOCK_CHANCE:
		_active_pattern = double_block_pattern
	else:
		_active_pattern = attack_pattern
	return _active_pattern

func _kill_telegraph() -> void:
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	if animated_sprite != null:
		animated_sprite.modulate = _base_modulate
		animated_sprite.scale = _base_scale

## Sombra oval no chão, atrás do sprite — ancora visual contra o fundo escuro.
func _spawn_shadow() -> void:
	# Posiciona nos pés do ator (origem do CharacterBody2D).
	# Escala proporcional à massa do sprite, achatada para ler como pool no chão.
	ActorContrast.add_ground_shadow(self, Vector2(sprite_scale * 1.25, sprite_scale * 0.55),
		Vector2(0.0, 2.0))

## Luz frontal que destaca o contorno do inimigo sobre o CanvasModulate escuro.
## Pode ser sobrescrita por subclasses (ex: Boss reduz energy para não competir com aura).
func _spawn_front_light() -> void:
	# O inimigo encara a Caipora pela esquerda; a luz vem da frente (esquerda).
	ActorContrast.add_front_light(self, Vector2(-18.0 * sprite_scale, -22.0))

## Outline brilhante ao redor do sprite — separação de silhueta em fundo escuro.
func _apply_outline_shader() -> void:
	if animated_sprite == null:
		return
	ActorContrast.apply_outline(animated_sprite)

## Contorno de brasas do modo HD (no-op sem HD). Nó de partículas irmão do
## material do sprite: sobrevive ao swap p/ hit_flash do ActorAnimator.track().
func _spawn_particle_rim() -> void:
	if animated_sprite == null:
		return
	ParticleRim.attach_to(animated_sprite, _rim_color(), 1.0, Color.TRANSPARENT,
		_rim_with_light(), _rim_with_halo())

## Cor do rim HD. Lei da marca: inimigo comum fica FORA da paleta da
## protagonista (sem laranja-juba, sem verde-cristal); bosses sobrescrevem
## com seus COLOR_AURA_* canônicos.
func _rim_color() -> Color:
	return Constants.COLOR_RIM_ENEMY

## Luz de rim HD: a arena tem UM inimigo por vez — cabe no orçamento de luzes.
func _rim_with_light() -> bool:
	return true

## Halo volumétrico: só chefes — comum fica nas brasas nítidas.
func _rim_with_halo() -> bool:
	return false
