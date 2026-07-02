extends GutTest

# Contrato visual da Mula sem Cabeça (boss Fase 1) — pipeline premium v3.
# Art law: docs/CONCEITO-mula.md (leitura-espelho da protagonista: corpo
# preto-vazio chapado + coluna de fogo serrilhada como "juba").

const MULA_IDLE := "res://assets/sprites/mula_idle.png"
const MULA_WINDUP := "res://assets/sprites/mula_windup.png"
const MULA_MAP := "res://assets/sprites/mula_map.png"

const SIZE := Vector2(192, 192)
const MAP_SIZE := Vector2(48, 48)
const MIN_OPAQUE_FRACTION := 0.15
# Fração mínima dos pixels opacos que pertencem à família do corpo-vazio
# (VOID_DK/VOID/VOID_EDGE/HOOF): a Mula é uma massa negra, não marrom.
const MIN_VOID_FRACTION := 0.5
# Linha inferior opaca (cascos+ferradura+outline) — mantém os pés na linha de
# chão da Caipora sob o contrato 0.9/-77 de test_boss_scale_proportions.gd.
const FEET_BOTTOM_MIN := 184
const FEET_BOTTOM_MAX := 191

# Palette anchors from gen_mula.py (v3)
const COLOR_VOID_DK := Color8(10, 7, 8)         # #0a0708 far legs / occlusion
const COLOR_VOID := Color8(21, 15, 16)          # #150f10 black-void body
const COLOR_VOID_EDGE := Color8(38, 26, 26)     # #261a1a flat edge accent
const COLOR_HOOF := Color8(16, 10, 9)           # #100a09 hoof
const COLOR_IRON := Color8(122, 124, 138)       # #7a7c8a horseshoe
const COLOR_IRON_LT := Color8(188, 192, 206)    # #bcc0ce horseshoe glint
const COLOR_WOUND := Color8(74, 8, 8)           # #4a0808 raw stump
const COLOR_SADDLE := Color8(40, 22, 14)        # #28160e dark leather
const COLOR_SADDLE_BLOOD := Color8(150, 24, 16) # #961810 blood trim
const COLOR_FIRE_DEEP := Color8(188, 42, 0)     # #bc2a00 fire occlusion
const COLOR_FIRE_MID := Color8(255, 107, 8)     # #ff6b08 fire base
const COLOR_FIRE_HOT := Color8(255, 168, 56)    # #ffa838 fire highlight
const COLOR_FIRE_CORE := Color8(255, 240, 200)  # #fff0c8 white-hot heart

const FIRE_COLORS: Array = [COLOR_FIRE_DEEP, COLOR_FIRE_MID, COLOR_FIRE_HOT, COLOR_FIRE_CORE]
const VOID_COLORS: Array = [COLOR_VOID_DK, COLOR_VOID, COLOR_VOID_EDGE, COLOR_HOOF]

# Brand locks: protagonist-only colors
const COLOR_CAIPORA_EYES := Color8(255, 255, 255)
const COLOR_CAIPORA_MANE := Color8(255, 69, 0)
const COLOR_CAIPORA_MANE_DK := Color8(139, 42, 0)
const COLOR_CAIPORA_CRYSTAL := Color8(0, 250, 154)

func test_mula_sprite_contract_sizes() -> void:
	for path: String in [MULA_IDLE, MULA_WINDUP]:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "%s carrega" % path)
		if texture == null:
			continue
		assert_eq(texture.get_size(), SIZE, "%s mantem contrato 192x192" % path)

func test_mula_sprite_contract_assets_are_not_blank() -> void:
	for path: String in [MULA_IDLE, MULA_WINDUP]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		var min_opaque := int(SIZE.x * SIZE.y * MIN_OPAQUE_FRACTION)
		assert_gt(_count_opaque_pixels(image), min_opaque, "%s tem massa visual suficiente" % path)

func test_mula_idle_keeps_signature_colors() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(MULA_IDLE))
	assert_false(image.is_empty(), "mula idle carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_VOID), "idle preserva o corpo preto-vazio")
	assert_true(_has_color(image, COLOR_FIRE_MID), "idle preserva fogo base")
	assert_true(_has_color(image, COLOR_FIRE_HOT), "idle preserva fogo quente")
	assert_true(_has_color(image, COLOR_FIRE_CORE), "idle preserva o coração branco-quente")
	assert_true(_has_color(image, COLOR_IRON), "idle preserva ferradura de ferro")
	assert_true(_has_color(image, COLOR_IRON_LT), "idle preserva o flash prateado da ferradura")
	assert_true(_has_color(image, COLOR_WOUND), "idle preserva carne do toco decepado")
	assert_true(_has_color(image, COLOR_SADDLE), "idle preserva arreio amaldiçoado")
	assert_true(_has_color(image, COLOR_SADDLE_BLOOD), "idle preserva sangue do arreio")

func test_mula_body_is_void_mass() -> void:
	# Leitura-espelho da Caipora: a massa dominante do corpo é preto-vazio,
	# nunca marrom-lamacento (regressão da v2).
	for path: String in [MULA_IDLE, MULA_WINDUP]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		var opaque := _count_opaque_pixels(image)
		var void_mass := _count_any_color(image, VOID_COLORS)
		assert_gt(float(void_mass) / float(opaque), MIN_VOID_FRACTION,
			"%s: familia void domina a massa opaca (leu %.0f%%)"
			% [path, 100.0 * void_mass / opaque])

func test_mula_feet_line_estavel() -> void:
	# Os cascos assentam na banda que mantém test_boss_scale_proportions verde.
	for path: String in [MULA_IDLE, MULA_WINDUP]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		var bottom := _bottom_opaque_row(image)
		assert_between(bottom, FEET_BOTTOM_MIN, FEET_BOTTOM_MAX,
			"%s: linha inferior opaca (%d) dentro da banda dos pés" % [path, bottom])

func test_mula_windup_inflames_the_column() -> void:
	var idle := Image.load_from_file(ProjectSettings.globalize_path(MULA_IDLE))
	var windup := Image.load_from_file(ProjectSettings.globalize_path(MULA_WINDUP))
	assert_false(idle.is_empty() or windup.is_empty(), "idle/windup carregam como Image")
	if idle.is_empty() or windup.is_empty():
		return
	assert_ne(idle.get_data(), windup.get_data(), "windup difere de idle (telegraph)")
	# Windup should have at least as much fire mass as idle.
	var windup_fire := _count_any_color(windup, FIRE_COLORS)
	var idle_fire := _count_any_color(idle, FIRE_COLORS)
	assert_true(windup_fire >= idle_fire,
		"windup aumenta ou mantem a massa de fogo (idle=%d, windup=%d)" % [idle_fire, windup_fire])

func test_mula_map_variant_contract() -> void:
	# Variante de mapa 48×48 re-renderizada dos MESMOS vetores (KI-016 pago:
	# a Mula sai do clamp interino do map_enemy). Leitura mínima: massa void
	# dominante + coroa de fogo presente, pés na base do canvas.
	var texture := load(MULA_MAP) as Texture2D
	assert_not_null(texture, "mula_map.png carrega")
	if texture == null:
		return
	assert_eq(texture.get_size(), MAP_SIZE, "mula_map mantem contrato 48x48")
	var image := Image.load_from_file(ProjectSettings.globalize_path(MULA_MAP))
	assert_false(image.is_empty(), "mula_map carrega como Image")
	if image.is_empty():
		return
	var min_opaque := int(MAP_SIZE.x * MAP_SIZE.y * MIN_OPAQUE_FRACTION)
	assert_gt(_count_opaque_pixels(image), min_opaque, "mula_map tem massa visual suficiente")
	assert_true(_has_color(image, COLOR_VOID), "mula_map preserva o corpo preto-vazio")
	assert_true(_has_color(image, COLOR_FIRE_MID), "mula_map preserva a coroa de fogo")
	var bottom := _bottom_opaque_row(image)
	assert_between(bottom, 44, 47, "mula_map assenta na base do canvas (leu %d)" % bottom)

func test_mula_never_steals_caipora_brand() -> void:
	for path: String in [MULA_IDLE, MULA_WINDUP, MULA_MAP]:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		assert_false(_has_color(image, COLOR_CAIPORA_EYES),
			"%s sem olhos brancos puros (assinatura da Caipora)" % path)
		assert_false(_has_color(image, COLOR_CAIPORA_MANE),
			"%s sem o laranja vivo da juba" % path)
		assert_false(_has_color(image, COLOR_CAIPORA_MANE_DK),
			"%s sem o laranja escuro da juba" % path)
		assert_false(_has_color(image, COLOR_CAIPORA_CRYSTAL),
			"%s sem o verde do cristal/Fúria" % path)

# ─── Helpers ───────────────────────────────────────
func _count_opaque_pixels(image: Image) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count

func _bottom_opaque_row(image: Image) -> int:
	for y: int in range(image.get_height() - 1, -1, -1):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1:
				return y
	return -1

func _has_color(image: Image, expected: Color) -> bool:
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).is_equal_approx(expected):
				return true
	return false

func _count_any_color(image: Image, colors: Array) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var px := image.get_pixel(x, y)
			for expected: Color in colors:
				if px.is_equal_approx(expected):
					count += 1
					break
	return count
