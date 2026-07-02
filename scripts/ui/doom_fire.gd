class_name DoomFire
extends CanvasLayer

# ─── Constants ─────────────────────────────────────
# Metade da grade original (90 linhas): ~4x menos células por update. O fogo é
# fundo atrás de céu com alpha — pixels 2x maiores não mudam a leitura, e o
# custo (era o maior pico de CPU recorrente do jogo, em todas as arenas + menu)
# cai junto. Ver PLANO-performance-60fps §4 (G1).
const SCALE: int = 16
const ROWS: int = 45
# Decay médio por linha dobra com a grade pela metade (randi() % 5 → média 2):
# a chama nasce no índice 36 e morre após ~18 linhas ≈ 40% do viewport — a
# MESMA altura proporcional do fogo original (36 de 90 linhas). É o modo das
# arenas (fundo discreto atrás do combate).
const DECAY_RANGE: int = 5

# ─── Exports ───────────────────────────────────────
## Chama alta do menu: decay {0,1} com P(1) = 7/8 → a chama vive ~41 das 45
## linhas ≈ 90% do viewport. Mesma grade, mesmo custo por célula (AND bitwise no
## lugar do %); só o menu liga (main_menu._ready) — as arenas ficam nos ~40%.
@export var tall_flames := false

# Dark doom fire: preto transparente → roxo escuro → carmesim → vermelho sangue
const PALETTE: Array[Color] = [
	Color(0.00, 0.00, 0.00, 0.00),
	Color(0.01, 0.00, 0.02, 1.00),
	Color(0.03, 0.00, 0.05, 1.00),
	Color(0.05, 0.00, 0.09, 1.00),
	Color(0.08, 0.00, 0.12, 1.00),
	Color(0.11, 0.00, 0.14, 1.00),
	Color(0.15, 0.00, 0.14, 1.00),
	Color(0.19, 0.00, 0.13, 1.00),
	Color(0.23, 0.00, 0.11, 1.00),
	Color(0.27, 0.00, 0.08, 1.00),
	Color(0.31, 0.00, 0.06, 1.00),
	Color(0.35, 0.00, 0.04, 1.00),
	Color(0.38, 0.00, 0.02, 1.00),
	Color(0.41, 0.00, 0.01, 1.00),
	Color(0.43, 0.01, 0.01, 1.00),
	Color(0.45, 0.01, 0.01, 1.00),
	Color(0.47, 0.01, 0.01, 1.00),
	Color(0.49, 0.02, 0.01, 1.00),
	Color(0.51, 0.02, 0.01, 1.00),
	Color(0.52, 0.02, 0.01, 1.00),
	Color(0.50, 0.02, 0.01, 1.00),
	Color(0.46, 0.02, 0.01, 1.00),
	Color(0.41, 0.01, 0.00, 1.00),
	Color(0.36, 0.01, 0.00, 1.00),
	Color(0.31, 0.01, 0.00, 1.00),
	Color(0.26, 0.00, 0.00, 1.00),
	Color(0.21, 0.00, 0.00, 1.00),
	Color(0.17, 0.00, 0.00, 1.00),
	Color(0.13, 0.00, 0.00, 1.00),
	Color(0.09, 0.00, 0.00, 1.00),
	Color(0.06, 0.00, 0.00, 1.00),
	Color(0.04, 0.00, 0.00, 1.00),
	Color(0.02, 0.00, 0.00, 1.00),
	Color(0.01, 0.00, 0.00, 1.00),
	Color(0.00, 0.00, 0.00, 0.80),
	Color(0.00, 0.00, 0.00, 0.40),
	Color(0.00, 0.00, 0.00, 0.00),
]

# ─── State ─────────────────────────────────────────
var _cols: int = 0
var _vp_size: Vector2 = Vector2.ZERO
var _grid: PackedInt32Array
var _frame: PackedByteArray
var _palette32: PackedInt32Array = _bake_palette()
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _fire_tick: int = 0

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = -10
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_rebuild(get_viewport().get_visible_rect().size)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == _vp_size:
		return
	_rebuild(vp)

func _rebuild(vp: Vector2) -> void:
	_vp_size = vp
	# Pixel size escala para que os 45 rows cubram sempre a altura total do viewport.
	# Em portrait (2768px): pix=62 → fire 45×62=2790px tall, cobre tudo.
	# Em landscape (720px): pix=16 → mesma cobertura do comportamento original.
	var pix: int = maxi(SCALE, ceili(vp.y / float(ROWS)))
	_cols = ceili(vp.x / float(pix))
	# Em web (gl_compatibility mobile) reduz a grade pela metade — ~55% menos
	# operações por update, sem impacto visual perceptível na tela pequena.
	if OS.has_feature("web"):
		_cols = maxi(1, _cols / 2)
	_grid = PackedInt32Array()
	_grid.resize(_cols * ROWS)
	for col in _cols:
		_grid[(ROWS - 1) * _cols + col] = PALETTE.size() - 1
	_frame = PackedByteArray()
	_frame.resize(_cols * ROWS * 4)
	_image = Image.create(_cols, ROWS, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_sprite.texture = _texture
	_sprite.scale = Vector2(float(pix), float(pix))
	_sprite.position = Vector2(_cols * pix / 2.0, ROWS * pix / 2.0)

func _process(_delta: float) -> void:
	var tick_mod: int = 5 if OS.has_feature("web") else 3
	_fire_tick = (_fire_tick + 1) % tick_mod
	if _fire_tick != 0:
		return
	_update_fire()
	_blit_image()

## Para ou retoma o DoomFire durante o combate, liberando CPU para o timing.
func set_combat_mode(active: bool) -> void:
	set_process(not active)
	visible = not active

# ─── Private helpers ───────────────────────────────
func _update_fire() -> void:
	var tall := tall_flames  # hoist: acesso a membro por célula pesa no inner loop
	for row in range(ROWS - 1):
		var dst_base: int = row * _cols
		var src_base: int = (row + 1) * _cols
		for col in _cols:
			var val: int = _grid[src_base + col]
			if val == 0:
				_grid[dst_base + col] = 0
				continue
			# Um único randi() alimenta drift (bit 0), espalhamento (bit 1) e
			# decay (bits altos) — eram 3 chamadas de RNG por célula.
			var r: int = randi()
			var target: int = clampi(col - (r & 1) + ((r >> 1) & 1), 0, _cols - 1)
			if tall:
				# decay ≤ 1 e val ≥ 1 (continue acima) — dispensa o maxi
				_grid[dst_base + target] = val - (1 if ((r >> 2) & 7) != 0 else 0)
			else:
				_grid[dst_base + target] = maxi(0, val - ((r >> 2) % DECAY_RANGE))

func _blit_image() -> void:
	# Bytes RGBA direto da paleta pré-cozida + um set_data único: sem o
	# overhead por chamada (bounds check + conversão de Color) do set_pixel.
	var off: int = 0
	for i in _grid.size():
		_frame.encode_u32(off, _palette32[_grid[i]])
		off += 4
	_image.set_data(_cols, ROWS, false, Image.FORMAT_RGBA8, _frame)
	_texture.update(_image)

## Paleta como u32 RGBA little-endian (ordem de bytes do FORMAT_RGBA8).
static func _bake_palette() -> PackedInt32Array:
	var packed := PackedInt32Array()
	packed.resize(PALETTE.size())
	for i in PALETTE.size():
		var c: Color = PALETTE[i]
		packed[i] = c.r8 | (c.g8 << 8) | (c.b8 << 16) | (c.a8 << 24)
	return packed
