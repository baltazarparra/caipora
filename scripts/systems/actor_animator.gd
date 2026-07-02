class_name ActorAnimator
extends Node

## Linguagem corporal do combate: poses (windup/strike/recover), squash&stretch
## de impacto, flash branco de dano, afterimage da esquiva perfeita e respiração
## de idle. Serviço do ArenaManager — track() registra cada ator ao spawnar.
##
## O flash de dano é automático: escuta health_changed e dispara quando o HP cai
## (cobre todos os caminhos de dano, incluindo especiais de boss). Poses só tocam
## se a animação existir no SpriteFrames do ator (bosses sem windup ficam no idle).

const FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")

const STRIKE_HOLD_S: float = 0.22
const RECOVER_HOLD_S: float = 0.25
const FLASH_DECAY_S: float = 0.18
const FLASH_HOLD_S: float = 0.13
const FLASH_RELEASE_S: float = 0.07
const SQUASH_IN_S: float = 0.04
const SQUASH_OUT_S: float = 0.12
const BREATH_PERIOD_S: float = 1.1
const AFTERIMAGE_COUNT: int = 3
const DODGE_STEP_PX: float = 24.0

var _base_scales: Dictionary = {}   # CombatActor → Vector2 (escala original do sprite)
var _flash_mats: Dictionary = {}    # CombatActor → Array[ShaderMaterial]
var _breath_tweens: Dictionary = {} # CombatActor → Tween (pausado durante squash)
var _last_hp: Dictionary = {}
var _flash_held: Dictionary = {} # actor -> true enquanto a silhueta branca esta segura

func track(actor: CombatActor) -> void:
	if actor == null or actor.animated_sprite == null:
		return
	var sprite := actor.animated_sprite
	_base_scales[actor] = sprite.scale
	_flash_mats[actor] = _apply_flash_material(sprite)
	_last_hp[actor] = actor.health.current_health
	actor.health.health_changed.connect(_on_health_changed.bind(actor))
	_start_breathing(actor)

func _apply_flash_material(sprite: AnimatedSprite2D) -> Array:
	var mats: Array = []
	var mat := ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("outline_color", Constants.COLOR_ACTOR_OUTLINE)
	mat.set_shader_parameter("outline_thickness_px", Constants.ACTOR_OUTLINE_THICKNESS)
	sprite.material = mat
	mats.append(mat)
	return mats

# ─── Poses ─────────────────────────────────────────

func play_pose(actor: CombatActor, anim: StringName) -> void:
	if not _usable(actor):
		return
	var sprite := actor.animated_sprite
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

## Golpe completo: strike (smear) → recover → idle, com avanço temporal fixo —
## as animações são frames únicos sem loop, o ritmo vem dos timers.
func strike(actor: CombatActor) -> void:
	play_pose(actor, &"strike")
	get_tree().create_timer(STRIKE_HOLD_S).timeout.connect(_settle.bind(actor, &"strike"))

## Golpe do INIMIGO na resolução da janela de defesa: quem tem frames de strike
## (Mula v3+) toca a cadeia completa; os demais voltam ao idle como antes.
func strike_or_idle(actor: CombatActor) -> void:
	if not _usable(actor):
		return
	var frames := actor.animated_sprite.sprite_frames
	if frames != null and frames.has_animation(&"strike"):
		strike(actor)
	else:
		play_pose(actor, &"idle")

## Erro/fim de janela sem golpe: o cipó assenta direto (recover → idle).
func settle(actor: CombatActor) -> void:
	play_pose(actor, &"recover")
	get_tree().create_timer(RECOVER_HOLD_S).timeout.connect(_back_to_idle.bind(actor, &"recover"))

func _settle(actor: CombatActor, expected: StringName) -> void:
	if not _usable(actor) or actor.animated_sprite.animation != expected:
		return
	settle(actor)

func _back_to_idle(actor: CombatActor, expected: StringName) -> void:
	if not _usable(actor) or actor.animated_sprite.animation != expected:
		return
	play_pose(actor, &"idle")

# ─── Impacto (flash + squash) ──────────────────────

func _on_health_changed(new_health: float, _max_health: float, actor: CombatActor) -> void:
	var last: float = _last_hp.get(actor, new_health)
	_last_hp[actor] = new_health
	if new_health < last:
		# O flash-hold (impact frame do critico) tem prioridade: nao sobrepor com o
		# fade automatico enquanto ele segura a silhueta branca.
		if not _flash_held.get(actor, false):
			flash(actor)
		impact_squash(actor)

func flash(actor: CombatActor, strength: float = 1.0) -> void:
	if not _usable(actor):
		return
	for mat: ShaderMaterial in _flash_mats.get(actor, []):
		mat.set_shader_parameter("flash_amount", strength)
		var tween := actor.animated_sprite.create_tween()
		tween.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
			strength, 0.0, FLASH_DECAY_S)

## Impact frame (HK): SEGURA a silhueta branca no impacto e solta rapido, em vez do
## fade do flash automatico. Enquanto ativo, _on_health_changed nao dispara o auto-flash.
func flash_hold(actor: CombatActor) -> void:
	if not _usable(actor):
		return
	_flash_held[actor] = true
	for mat: ShaderMaterial in _flash_mats.get(actor, []):
		mat.set_shader_parameter("flash_amount", 1.0)
		var tween := actor.animated_sprite.create_tween()
		tween.tween_interval(FLASH_HOLD_S)
		tween.tween_method(
			func(v: float) -> void: mat.set_shader_parameter("flash_amount", v),
			1.0, 0.0, FLASH_RELEASE_S)
		tween.tween_callback(func() -> void: _flash_held.erase(actor))

func impact_squash(actor: CombatActor) -> void:
	if not _usable(actor):
		return
	var sprite := actor.animated_sprite
	var base: Vector2 = _base_scales.get(actor, sprite.scale)
	# Respiração pausa durante o squash — os dois tweens disputariam scale.
	var breath: Tween = _breath_tweens.get(actor)
	if breath != null and breath.is_valid():
		breath.pause()
	# Tween no próprio sprite: morre com o nó; o último squash vence o anterior.
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector2(base.x * 1.15, base.y * 0.85), SQUASH_IN_S)
	tween.tween_property(sprite, "scale", base, SQUASH_OUT_S) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		if breath != null and breath.is_valid():
			breath.play())

# ─── Esquiva perfeita (afterimage + sidestep) ──────

func perfect_dodge(actor: CombatActor, dir: Vector2 = Vector2(-1.0, 0.0)) -> void:
	if not _usable(actor):
		return
	_spawn_afterimages(actor, dir)
	var home_x := actor.position.x
	var tween := actor.create_tween()
	tween.tween_property(actor, "position:x", home_x + dir.x * DODGE_STEP_PX, 0.07)
	tween.tween_property(actor, "position:x", home_x, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Recuo de impacto: o alvo e empurrado em `dir` (px) e volta. A reacao do alvo e
## metade do peso sentido no golpe. Puramente cosmetico (position tween) — NAO toca
## o timing de combate.
func recoil(actor: CombatActor, dir: Vector2, px: float) -> void:
	if not _usable(actor):
		return
	var home_x := actor.position.x
	var tween := actor.create_tween()
	tween.tween_property(actor, "position:x", home_x + dir.x * px, 0.05) \
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "position:x", home_x, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_afterimages(actor: CombatActor, dir: Vector2) -> void:
	var sprite := actor.animated_sprite
	if sprite.sprite_frames == null:
		return
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var parent := actor.get_parent()
	if parent == null:
		return
	for i: int in AFTERIMAGE_COUNT:
		var ghost := Sprite2D.new()
		ghost.texture = tex
		ghost.offset = sprite.offset
		ghost.scale = sprite.scale
		ghost.flip_h = sprite.flip_h
		ghost.position = actor.position + dir * (14.0 * (i + 1))
		ghost.z_index = -1
		ghost.modulate = Color(0.9, 0.95, 1.0, 0.5 - i * 0.12)
		ghost.material = Constants.ADDITIVE_MATERIAL
		parent.add_child(ghost)
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.22 + i * 0.06)
		tween.tween_callback(ghost.queue_free)

# ─── Respiração de idle ────────────────────────────

func _start_breathing(actor: CombatActor) -> void:
	var sprite := actor.animated_sprite
	var base: Vector2 = _base_scales[actor]
	# Loop infinito amarrado ao sprite (morre com ele). Amplitude sutil: o ator
	# nunca está parado de verdade — a mata respira, a presa também.
	var tween := sprite.create_tween().set_loops()
	tween.tween_property(sprite, "scale:y", base.y * 1.015, BREATH_PERIOD_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale:y", base.y * 0.995, BREATH_PERIOD_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tweens[actor] = tween

func _usable(actor: CombatActor) -> bool:
	return actor != null and is_instance_valid(actor) and not actor.is_dying() \
		and actor.animated_sprite != null
