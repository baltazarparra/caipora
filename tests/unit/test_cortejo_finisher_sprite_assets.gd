extends GutTest

# Contrato visual do finisher do Cortejo — pipeline premium gen_feedback_sprites.py
# (_gen_finisher_cortejo_vfx). Os quatro espíritos ESQUARTEJAM o inimigo: o corpo
# (massa void) rasga em quatro direções, vísceras jorram e o fogo verde-fantasma
# do cortejo consome o tronco oco. 6 frames de 96×96, tocados em câmera lenta no
# clímax do Golpe Carregado.
# Lei de marca: o verde da chama é o verde espectral PRÓPRIO do cortejo — NUNCA o
# verde-cristal nem o laranja-juba dominantes da Caipora (reservados ao protagonista).

const SHEET_PATH := "res://assets/effects/finisher_cortejo_vfx_sheet.png"
const FRAME := 96
const FRAMES := 6
const SHEET_SIZE := Vector2(FRAME * FRAMES, FRAME)  # 576×96

# Fração mínima do canvas com pixels opacos (pedaços + vísceras + chama + sangue).
const MIN_OPAQUE_FRACTION := 0.08

# Paleta do finisher do cortejo (gen_feedback_sprites.py)
const COLOR_VOID := Color8(10, 8, 12)          # corpo/pedaços (void da Caipora)
const COLOR_HEART_HOT := Color8(220, 50, 50)   # coração/vísceras vivas
const COLOR_BLOOD := Color8(139, 0, 0)         # sangue
const COLOR_SPIRIT := Color8(130, 255, 190)    # chama/garra fantasma do cortejo

# Travas de marca (assinaturas exclusivas da Caipora)
const COLOR_CAIPORA_MANE := Color8(255, 69, 0)
const COLOR_CAIPORA_CRYSTAL := Color8(0, 250, 154)

func test_cortejo_finisher_sheet_exists_and_size() -> void:
	assert_true(ResourceLoader.exists(SHEET_PATH), "finisher_cortejo_vfx_sheet existe")
	var texture := load(SHEET_PATH) as Texture2D
	assert_not_null(texture, "finisher_cortejo_vfx_sheet carrega como Texture2D")
	if texture == null:
		return
	assert_eq(texture.get_size(), SHEET_SIZE,
		"sheet mantém 6 frames de 96×96 (576×96)")

func test_cortejo_finisher_sheet_is_not_blank() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	assert_false(image.is_empty(), "finisher_cortejo carrega como Image")
	if image.is_empty():
		return
	var min_opaque := int(SHEET_SIZE.x * SHEET_SIZE.y * MIN_OPAQUE_FRACTION)
	assert_gt(_count_opaque_pixels(image), min_opaque, "tem massa visual suficiente")

func test_cortejo_finisher_keeps_gore_and_spirit() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	assert_false(image.is_empty(), "finisher_cortejo carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_VOID), "preserva os pedaços do corpo (void)")
	assert_true(_has_color(image, COLOR_HEART_HOT), "preserva as vísceras vivas")
	assert_true(_has_color(image, COLOR_BLOOD), "preserva o sangue")
	assert_true(_has_color(image, COLOR_SPIRIT), "preserva o fogo verde-fantasma do cortejo")

func test_cortejo_finisher_never_steals_caipora_brand() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	assert_false(image.is_empty(), "finisher_cortejo carrega como Image")
	if image.is_empty():
		return
	assert_false(_has_color(image, COLOR_CAIPORA_MANE),
		"sem o laranja vivo da juba (reservado à Caipora)")
	assert_false(_has_color(image, COLOR_CAIPORA_CRYSTAL),
		"sem o verde do cristal/Fúria (reservado ao cajado) — usa verde espectral próprio")

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
