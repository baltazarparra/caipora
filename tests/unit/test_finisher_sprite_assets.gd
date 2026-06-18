extends GutTest

# Contrato visual do golpe final — pipeline premium gen_feedback_sprites.py
# (_gen_finisher_vfx). A garra preta da Caipora esmaga o coração do inimigo e
# drena o sangue, em 5 frames de 64×64 tocados em câmera lenta sobre o peito.
# Lei de marca: preto (void) + sangue; NUNCA o verde-cristal nem o laranja-juba
# dominantes da Caipora roubam a cena aqui (são reservados ao protagonista).

const FINISHER_PATH := "res://assets/effects/finisher_vfx_sheet.png"
const FRAME := 64
const FRAMES := 5
const SHEET_SIZE := Vector2(FRAME * FRAMES, FRAME)  # 320×64

# Fração mínima do canvas com pixels opacos (garra + coração + sangue).
const MIN_OPAQUE_FRACTION := 0.08

# Paleta do finisher (gen_feedback_sprites.py)
const COLOR_VOID := Color8(10, 8, 12)        # garra/void da Caipora
const COLOR_HEART_HOT := Color8(220, 50, 50) # coração vivo
const COLOR_BLOOD := Color8(139, 0, 0)       # sangue espremido

# Travas de marca (assinaturas exclusivas da Caipora)
const COLOR_CAIPORA_MANE := Color8(255, 69, 0)
const COLOR_CAIPORA_CRYSTAL := Color8(0, 250, 154)

func test_finisher_sheet_exists_and_size() -> void:
	assert_true(ResourceLoader.exists(FINISHER_PATH), "finisher_vfx_sheet existe")
	var texture := load(FINISHER_PATH) as Texture2D
	assert_not_null(texture, "finisher_vfx_sheet carrega como Texture2D")
	if texture == null:
		return
	assert_eq(texture.get_size(), SHEET_SIZE,
		"sheet mantém 5 frames de 64×64 (320×64)")

func test_finisher_sheet_is_not_blank() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(FINISHER_PATH))
	assert_false(image.is_empty(), "finisher carrega como Image")
	if image.is_empty():
		return
	var min_opaque := int(SHEET_SIZE.x * SHEET_SIZE.y * MIN_OPAQUE_FRACTION)
	assert_gt(_count_opaque_pixels(image), min_opaque, "tem massa visual suficiente")

func test_finisher_keeps_claw_and_gore() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(FINISHER_PATH))
	assert_false(image.is_empty(), "finisher carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_VOID), "preserva a garra preta (void) da Caipora")
	assert_true(_has_color(image, COLOR_HEART_HOT), "preserva o coração vivo")
	assert_true(_has_color(image, COLOR_BLOOD), "preserva o sangue espremido")

func test_finisher_never_steals_caipora_brand() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(FINISHER_PATH))
	assert_false(image.is_empty(), "finisher carrega como Image")
	if image.is_empty():
		return
	assert_false(_has_color(image, COLOR_CAIPORA_MANE),
		"sem o laranja vivo da juba (reservado à Caipora)")
	assert_false(_has_color(image, COLOR_CAIPORA_CRYSTAL),
		"sem o verde do cristal/Fúria (reservado ao cajado)")

func _count_opaque_pixels(image: Image) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count

func _has_color(image: Image, expected: Color) -> bool:
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).is_equal_approx(expected):
				return true
	return false
