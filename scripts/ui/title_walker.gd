class_name TitleWalker
extends Node2D

## A Caipora atravessando a tela na abertura, em loop ("atravessa e reaparece",
## sempre no mesmo sentido). Sprite normal (não silhueta), com sombra no chão e um
## leve bob vertical para dar peso/vida. Reusa caipora_sprite_frames.tres (anim
## "walk"). Puramente decorativo — sem física, colisão ou input.

# ─── Exports ───────────────────────────────────────
@export var ground_path: NodePath
@export var foot_y: float = 600.0
@export var layer_z: int = -40
## O bando dos libertados marcha junto (menu). O ending desliga: lá a Caipora
## atravessa sozinha.
@export var companions_enabled := true

# ─── Constants ─────────────────────────────────────
const SPRITE_HALF: float = 48.0  # Caipora é 96×96 (assets/AGENTS.md)
const WALK_SCALE: float = 1.733333
const START_MARGIN: float = 120.0
const CROSS_DURATION: float = 22.0
const BOB_AMPLITUDE: float = 4.0
const BOB_SPEED: float = 3.4
const WALK_ANIM_SPEED: float = 0.45
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)
# Bando: espaçamento entre encantados e desnível de profundidade (quem vai à
# frente pisa um passo abaixo e desenha por cima).
const COMPANION_GAP: float = 150.0
const COMPANION_DEPTH_DY: float = 6.0
# flip_h para ENCARAR A DIREITA (sentido da marcha): Mula/Boitatá/Curupira
# encaram a ESQUERDA no PNG (lei do CONCEITO; ver gen_mula/gen_boitata/gen_bosses),
# o Saci encara a direita. NÃO é o CampSpirit.DEFS["flip"] — aquele é semântica
# de POSIÇÃO na clareira, não orientação canônica.
const COMPANION_FACE_RIGHT_FLIP := {1: true, 2: true, 3: true, 4: false}

# ─── State ─────────────────────────────────────────
var _end_x: float = 1400.0
var _walk_tween: Tween = null
var _sprite: AnimatedSprite2D
var _rest_y: float = 0.0
var _bob_t: float = 0.0
var _pack_half_width: float = 0.0

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	z_index = layer_z
	if not ground_path.is_empty():
		var g := get_node_or_null(ground_path)
		if g != null and "crest_y" in g:
			foot_y = g.crest_y
	var eff_foot_y: float = foot_y / 720.0 * vp.y
	position = Vector2(-START_MARGIN, eff_foot_y)

	_rest_y = -SPRITE_HALF * WALK_SCALE
	_sprite = AnimatedSprite2D.new()
	# Frames conforme a meta-progressão: com a CHAMA, ela atravessa a tela em brasa.
	CaiporaSkin.apply(_sprite)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(WALK_SCALE, WALK_SCALE)
	_sprite.flip_h = false  # andando para a direita
	_sprite.position = Vector2(0, _rest_y)  # pés na origem (sobre a crista)
	_sprite.speed_scale = WALK_ANIM_SPEED
	_sprite.play("walk")
	add_child(_sprite)

	_spawn_companions()
	_start_loop()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_start_loop()

func _process(delta: float) -> void:
	_bob_t += delta * BOB_SPEED
	_sprite.position.y = _rest_y + sin(_bob_t) * BOB_AMPLITUDE
	queue_redraw()

# ─── Drawing (sombra) ──────────────────────────────
func _draw() -> void:
	# Elipse achatada sob os pés (origem local). Escala vertical = "esmagamento".
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, SPRITE_HALF * WALK_SCALE * 0.55, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── Private helpers ───────────────────────────────
## O bando dos libertados: cada chefe libertado (MetaProgression.freed_bosses)
## marcha INTERCALADO na frente e atrás da Caipora — filhos deste nó, então o
## tween da travessia move o bando inteiro junto.
func _spawn_companions() -> void:
	if not companions_enabled:
		return
	var slot := 0
	for phase: int in MetaProgression.freed_bosses:
		var companion := TitleCompanion.new()
		var ahead := slot % 2 == 0
		var offset_x := float((slot >> 1) + 1) * COMPANION_GAP * (1.0 if ahead else -1.0)
		companion.position = Vector2(offset_x,
			COMPANION_DEPTH_DY if ahead else -COMPANION_DEPTH_DY)
		companion.z_index = 1 if ahead else -1
		add_child(companion)  # contrato: na árvore ANTES de setup()
		if not companion.setup(phase, WALK_SCALE, COMPANION_FACE_RIGHT_FLIP.get(phase, true)):
			companion.queue_free()
			continue
		_pack_half_width = maxf(_pack_half_width, absf(offset_x) + companion.half_width())
		slot += 1

func _start_loop() -> void:
	var vp := get_viewport().get_visible_rect().size
	# O bando inteiro nasce e morre fora da tela, não só a Caipora.
	var margin := START_MARGIN + _pack_half_width
	_end_x = vp.x + margin
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween().set_loops()
	_walk_tween.tween_property(self, "position:x", _end_x, CROSS_DURATION).from(-margin)
