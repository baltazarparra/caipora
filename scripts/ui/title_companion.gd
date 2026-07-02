class_name TitleCompanion
extends Node2D

## Um encantado libertado marchando com a Caipora na tela inicial. Reusa os
## frames premium e a escala do CampSpirit.DEFS (registro canônico dos
## libertados); sem walk cycle nos frames dos chefes, o quique vertical É a
## leitura de passo (mesmo truque do acampamento). Sem aura/glow/partículas —
## leveza web. Puramente decorativo: sem física, colisão ou input.
##
## Contrato: add_child() ANTES de setup() (padrão CampSpirit).

# ─── Constants ─────────────────────────────────────
# Quique de passo dessincronizado: cada encantado no próprio compasso do bando.
const BOB_HEIGHT: float = 6.0
const BOB_SPEED: float = 5.2
const BOB_SPEED_JITTER: float = 0.15
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.35)

# ─── State ─────────────────────────────────────────
var _sprite: AnimatedSprite2D
var _rest_y: float = 0.0
var _half_width: float = 0.0
var _bob_t: float = 0.0
var _bob_speed: float = BOB_SPEED

# ─── Public API ────────────────────────────────────
## Monta o encantado da fase; false para fase sem espírito (Jesuíta/inválida) —
## o caller descarta o nó. `flip_right` vira o sprite para a direita (sentido da
## marcha); pés na origem, como o TitleWalker.
func setup(spirit_phase: int, walk_scale: float, flip_right: bool) -> bool:
	if not CampSpirit.DEFS.has(spirit_phase):
		return false
	var def: Dictionary = CampSpirit.DEFS[spirit_phase]
	var total_scale: float = def["scale"] * walk_scale
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load(def["frames"])
	_sprite.animation = &"idle"
	_sprite.speed_scale = CampSpirit.REST_SPEED
	_sprite.flip_h = flip_right
	_sprite.scale = Vector2(total_scale, total_scale)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	_rest_y = -tex.get_height() * 0.5 * total_scale
	_half_width = tex.get_width() * 0.5 * total_scale
	_sprite.position = Vector2(0.0, _rest_y)
	add_child(_sprite)
	_sprite.play()
	_bob_t = randf() * TAU
	_bob_speed = BOB_SPEED * randf_range(1.0 - BOB_SPEED_JITTER, 1.0 + BOB_SPEED_JITTER)
	return true

## Meia-largura visual (px de canvas) — o dono usa para o bando inteiro nascer
## e morrer fora da tela.
func half_width() -> float:
	return _half_width

# ─── Lifecycle ─────────────────────────────────────
func _process(delta: float) -> void:
	if _sprite == null:
		return
	_bob_t += delta * _bob_speed
	# Quique só para cima: sobe no passo e assenta de volta no chão (origem).
	_sprite.position.y = _rest_y - absf(sin(_bob_t)) * BOB_HEIGHT
	queue_redraw()

# ─── Drawing (sombra) ──────────────────────────────
func _draw() -> void:
	# Mesma elipse achatada do TitleWalker, dimensionada pelo porte real.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, _half_width * 0.55, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
