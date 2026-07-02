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
	_spawn_ember_trail()

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
	# ambient: o amount já escalava por device — o modo leve fica idêntico e o
	# HD dobra (Quality.heavy) e clareia (overbright).
	var ps: float = Constants.ambient_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
	aura.amount = maxi(1, int(28.0 * ps))
	aura.lifetime = 1.0 if ps < 1.0 else 1.4
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 30.0
	aura.gravity = Vector2(0, -22)
	aura.initial_velocity_min = 6.0
	aura.initial_velocity_max = 16.0
	aura.scale_amount_min = 2.5
	aura.scale_amount_max = Quality.pick(5.5, 6.5)
	aura.color = ParticleRim._overbright(Constants.COLOR_AURA_BOITATA) \
		if Quality.hd_enabled() else Constants.COLOR_AURA_BOITATA
	aura.z_index = -1
	add_child(aura)

## Rim HD na cor da aura canônica do chefe.
func _rim_color() -> Color:
	return Constants.COLOR_AURA_BOITATA

# ─── Rastro de fogo (modo HD) ───────────────────────
## Ghost frames de fogo somados ao bote: o corpo da serpente queima no ar.
func _play_attack_lunge() -> void:
	super._play_attack_lunge()
	_spawn_fire_ghosts()

## Brasas em coords GLOBAIS ancoradas no corpo: parada, a serpente pinga fogo;
## no bote as brasas ficam para trás e viram rastro — zero hook no ActorAnimator.
func _spawn_ember_trail() -> void:
	if not Quality.hd_enabled() or animated_sprite == null:
		return
	var vp := get_viewport()
	var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
	var trail := CPUParticles2D.new()
	trail.name = "EmberTrail"
	trail.amount = maxi(1, int(20.0 * ps))
	trail.lifetime = 0.9
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	# Corpo horizontal da serpente (sprite 160×128 @1.2, offset -38).
	trail.emission_rect_extents = Vector2(70.0, 22.0)
	trail.position = Vector2(0.0, -45.0)
	trail.gravity = Vector2(0, 25)
	trail.initial_velocity_min = 2.0
	trail.initial_velocity_max = 8.0
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.6
	trail.color = Constants.COLOR_FIRE_HOT
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Constants.COLOR_FIRE_HOT)
	ramp.add_point(0.5, Constants.COLOR_AURA_BOITATA)
	ramp.add_point(1.0, Color(Constants.COLOR_AURA_BOITATA.r,
		Constants.COLOR_AURA_BOITATA.g, Constants.COLOR_AURA_BOITATA.b, 0.0))
	trail.color_ramp = ramp
	trail.material = Constants.ADDITIVE_MATERIAL
	trail.z_index = 1
	add_child(trail)

## Cópias aditivas do frame atual ao longo do trajeto do bote, tintadas de fogo
## (receita do ActorAnimator._spawn_afterimages, cores da aura do Boitatá).
func _spawn_fire_ghosts() -> void:
	if not Quality.hd_enabled() or animated_sprite == null:
		return
	var frames := animated_sprite.sprite_frames
	if frames == null:
		return
	var tex := frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if tex == null:
		return
	var parent := get_parent()
	if parent == null:
		return
	for i: int in 3:
		var ghost := Sprite2D.new()
		ghost.texture = tex
		ghost.offset = animated_sprite.offset
		ghost.scale = animated_sprite.scale
		ghost.flip_h = animated_sprite.flip_h
		# O bote avança 80px para a esquerda: o fogo fica suspenso no caminho.
		ghost.position = position + Vector2(-20.0 * (i + 1), 0.0)
		ghost.z_index = -1
		ghost.modulate = Color(1.4, 0.63, 0.07, 0.5 - i * 0.12)
		ghost.material = Constants.ADDITIVE_MATERIAL
		parent.add_child(ghost)
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.24 + i * 0.07)
		tween.tween_callback(ghost.queue_free)
