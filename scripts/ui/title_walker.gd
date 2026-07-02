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

# ─── Constants ─────────────────────────────────────
const SPRITE_HALF: float = 48.0  # Caipora é 96×96 (assets/AGENTS.md)
const WALK_SCALE: float = 1.733333
const START_MARGIN: float = 120.0
const CROSS_DURATION: float = 22.0
const BOB_AMPLITUDE: float = 4.0
const BOB_SPEED: float = 3.4
const WALK_ANIM_SPEED: float = 0.45
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)

# ─── State ─────────────────────────────────────────
var _end_x: float = 1400.0
var _walk_tween: Tween = null
var _sprite: AnimatedSprite2D
var _rest_y: float = 0.0
var _bob_t: float = 0.0

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

	_start_loop()
	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()  # 1ª pintura da sombra (o _process não redesenha mais)

func _on_viewport_resized() -> void:
	_start_loop()

func _process(delta: float) -> void:
	# Bob move só o filho _sprite (transform); a sombra do _draw é estática —
	# sem queue_redraw por frame (RF-D1).
	_bob_t += delta * BOB_SPEED
	_sprite.position.y = _rest_y + sin(_bob_t) * BOB_AMPLITUDE

# ─── Drawing (sombra) ──────────────────────────────
func _draw() -> void:
	# Elipse achatada sob os pés (origem local). Escala vertical = "esmagamento".
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, SPRITE_HALF * WALK_SCALE * 0.55, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─── Private helpers ───────────────────────────────
func _start_loop() -> void:
	var vp := get_viewport().get_visible_rect().size
	_end_x = vp.x + START_MARGIN
	if _walk_tween != null:
		_walk_tween.kill()
	_walk_tween = create_tween().set_loops()
	_walk_tween.tween_property(self, "position:x", _end_x, CROSS_DURATION).from(-START_MARGIN)
