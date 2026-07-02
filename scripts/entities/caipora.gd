class_name Caipora
extends CharacterBody2D

# ─── Exports ───────────────────────────────────────
@export var tilemap: TileMap
@export var move_duration: float = 0.15

# ─── Signals ───────────────────────────────────────
signal move_finished(new_grid_pos: Vector2i)

# ─── State ─────────────────────────────────────────
var _is_moving: bool = false

# Blink "olhos que apagam" (estilo Hollow Knight): intervalo IRREGULAR, so no idle.
const BLINK_MIN_S: float = 3.0
const BLINK_MAX_S: float = 6.5
var _blink_timer: Timer

# ─── Onready ───────────────────────────────────────
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	collision_layer = 1 << (Constants.LAYER_PLAYER - 1)
	collision_mask = 1 << (Constants.LAYER_WALL - 1)

	# Camera limits
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = Constants.GRID_WIDTH * Constants.TILE_SIZE
	_camera.limit_bottom = Constants.GRID_HEIGHT * Constants.TILE_SIZE
	_camera.limit_smoothed = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 10.0

	# Zoom que "cobre" o viewport: a câmera fica fechada na Caipora (não miniaturiza o mapa
	# inteiro em retrato) e rola nos dois eixos conforme ela anda, presa pelos limit_*. A área
	# visível (vp/zoom) fica <= mapa nos dois eixos, então os limit_* mantêm a câmera dentro.
	_update_camera_zoom()
	get_viewport().size_changed.connect(_update_camera_zoom)
	CaiporaSkin.apply(_animated_sprite)
	_setup_blink()
	ActorContrast.apply_outline(_animated_sprite)
	_apply_furia_visual()
	_spawn_shadow()
	ActorContrast.add_front_light(self, Vector2(0.0, -8.0), 0.7, 1.4)

func _process(_delta: float) -> void:
	if _is_moving:
		return
	var input_dir := _get_cardinal_input()
	if input_dir != Vector2.ZERO:
		_try_move(input_dir)

# ─── Public API ────────────────────────────────────
func try_move(direction: Vector2) -> void:
	_try_move(direction)

# ─── Private helpers ───────────────────────────────
func _apply_furia_visual() -> void:
	FuriaVisual.attach_to(_animated_sprite)
	# Rim HD junto do refresh da Fúria: mesma evolução (tier/CHAMA), mesmo gatilho.
	ParticleRim.attach_caipora(_animated_sprite)

func _spawn_shadow() -> void:
	ActorContrast.add_ground_shadow(self, Vector2(0.62, 0.22), Vector2(0.0, 2.0))

func _get_cardinal_input() -> Vector2:
	var x := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	var y := int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))
	# Cardinal puro: nunca move na diagonal (evita cortar cantos de parede).
	if x != 0 and y != 0:
		return Vector2(x, 0)
	return Vector2(x, y)

func _try_move(dir: Vector2) -> void:
	var target := position + dir * Constants.TILE_SIZE

	if _would_collide(target):
		return

	_is_moving = true
	_animated_sprite.flip_h = dir.x < 0
	_animated_sprite.play("walk")

	var tween := create_tween()
	tween.tween_property(self, "position", target, move_duration)
	tween.tween_callback(_on_move_finished)

func _update_camera_zoom() -> void:
	var map := Vector2(
		Constants.GRID_WIDTH * Constants.TILE_SIZE,
		Constants.GRID_HEIGHT * Constants.TILE_SIZE,
	)
	var vp := get_viewport().get_visible_rect().size
	# Cover: o eixo mais "apertado" preenche a tela; a Caipora fica em close e a câmera rola
	# nos dois eixos dentro dos limit_*. Em retrato isto enquadra de perto em vez de espremer
	# as 26 colunas inteiras numa tira minúscula.
	var z: float = maxf(vp.x / map.x, vp.y / map.y)
	# Texel inteiro arredondando pra CIMA: cover exige z >= raw, senão a área
	# visível excede o mapa e vaza além dos limit_*.
	z = PixelScale.snap_cover(z, PixelScale.device_scale(get_viewport()))
	_camera.zoom = Vector2(z, z)

func _would_collide(target: Vector2) -> bool:
	if tilemap == null:
		return true
	var grid_pos := tilemap.local_to_map(target)
	var tile_data := tilemap.get_cell_tile_data(0, grid_pos)
	if tile_data == null:
		return true
	return tilemap.get_cell_source_id(0, grid_pos) == 1

func _on_move_finished() -> void:
	_is_moving = false
	_animated_sprite.play("idle")
	if tilemap != null:
		move_finished.emit(tilemap.local_to_map(position))

# ─── Blink (olhos que apagam) ──────────────────────
func _setup_blink() -> void:
	_animated_sprite.animation_finished.connect(_on_anim_finished)
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	add_child(_blink_timer)
	_blink_timer.timeout.connect(_on_blink_timeout)
	_schedule_blink()

func _schedule_blink() -> void:
	_blink_timer.start(randf_range(BLINK_MIN_S, BLINK_MAX_S))

func _on_blink_timeout() -> void:
	# So apaga os olhos parada e em idle; mover interrompe naturalmente.
	if not _is_moving and _animated_sprite.animation == &"idle":
		_animated_sprite.play("idle_dim")
	_schedule_blink()

func _on_anim_finished() -> void:
	# idle_dim nao da loop: ao terminar, os olhos reacendem (volta ao idle).
	# Se ja voltou a andar, deixa o walk seguir (evita corrida com _try_move).
	if _is_moving:
		return
	if _animated_sprite.animation == &"idle_dim":
		_animated_sprite.play("idle")
