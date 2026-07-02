extends GutTest

# Contrato visual do Boitatá (boss Fase 2) — pipeline premium v2.
# Art law: docs/CONCEITO-boitata.md (leitura-espelho da protagonista: muralha
# preta-carbonizada chapada + crista de fogo serrilhada como "juba").

const SPRITE_SIZES: Dictionary = {
	"res://assets/sprites/boitata_idle.png": Vector2(160, 128),
	"res://assets/sprites/boitata_windup.png": Vector2(160, 128),
}
const MIN_OPAQUE_FRACTION := 0.12
# Fração mínima dos pixels opacos na família preta-carbonizada
# (CHAR_DK/CHAR/CHAR_EDGE): o Boitatá é muralha negra, não montículo marrom.
const MIN_CHARRED_FRACTION := 0.45
# Linha inferior opaca — mantém a base na linha de chão da Caipora sob o
# contrato 1.2/-38 de test_boss_scale_proportions.gd.
const BOTTOM_MIN := 110
const BOTTOM_MAX := 116
# Massa HORIZONTAL é assinatura (trava exclusiva dele no teste de escala):
# bbox de largura mínimo no canvas.
const MIN_BBOX_WIDTH := 120

const BOITATA_IDLE := "res://assets/sprites/boitata_idle.png"
const BOITATA_WINDUP := "res://assets/sprites/boitata_windup.png"

# Palette anchors from gen_boitata.py (v2)
const COLOR_CHAR_DK := Color8(12, 7, 6)         # #0c0706 oclusão/mandíbula
const COLOR_CHAR := Color8(24, 12, 9)           # #180c09 corpo carbonizado
const COLOR_CHAR_EDGE := Color8(46, 22, 16)     # #2e1610 acento de borda
const COLOR_SCALE := Color8(132, 38, 19)        # #842613 placa de barriga
const COLOR_FIRE_DEEP := Color8(168, 44, 10)    # #a82c0a crista, oclusão
const COLOR_FIRE := Color8(226, 87, 24)         # #e25718 corpo da chama
const COLOR_FIRE_HOT := Color8(255, 178, 72)    # #ffb248 realce
const COLOR_FIRE_WHITE := Color8(255, 232, 174) # #ffe8ae coração espectral
const COLOR_ASH := Color8(126, 119, 98)         # #7e7762 chifres/cinzas
const COLOR_BLOOD := Color8(139, 0, 0)          # #8b0000 cicatrizes
const COLOR_EYE := Color8(250, 203, 83)         # #facb53 olhos em fenda

const CHARRED_COLORS: Array = [COLOR_CHAR_DK, COLOR_CHAR, COLOR_CHAR_EDGE]
const FIRE_COLORS: Array = [COLOR_FIRE_DEEP, COLOR_FIRE, COLOR_FIRE_HOT, COLOR_FIRE_WHITE]

# Brand locks: protagonist-only colors
const COLOR_CAIPORA_EYES := Color8(255, 255, 255)
const COLOR_CAIPORA_MANE := Color8(255, 69, 0)
const COLOR_CAIPORA_MANE_DK := Color8(139, 42, 0)
const COLOR_CAIPORA_CRYSTAL := Color8(0, 250, 154)

func test_boitata_sprite_contract_sizes() -> void:
	for path: String in SPRITE_SIZES:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "%s carrega" % path)
		if texture == null:
			continue
		assert_eq(texture.get_size(), SPRITE_SIZES[path],
			"%s mantem canvas premium %s" % [path, SPRITE_SIZES[path]])

func test_boitata_sprites_are_not_blank() -> void:
	for path: String in SPRITE_SIZES:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		var expected: Vector2 = SPRITE_SIZES[path]
		var min_opaque := int(expected.x * expected.y * MIN_OPAQUE_FRACTION)
		assert_gt(_count_opaque_pixels(image), min_opaque,
			"%s tem massa visual de serpente gigante" % path)

func test_boitata_idle_keeps_signature_colors() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(BOITATA_IDLE))
	assert_false(image.is_empty(), "boitata idle carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_CHAR), "idle preserva corpo carbonizado")
	assert_true(_has_color(image, COLOR_SCALE), "idle preserva placa de barriga queimada")
	assert_true(_has_color(image, COLOR_FIRE_DEEP), "idle preserva a cumeeira da crista")
	assert_true(_has_color(image, COLOR_FIRE), "idle preserva fogo sem usar laranja exato da Caipora")
	assert_true(_has_color(image, COLOR_FIRE_HOT), "idle preserva brasa quente")
	assert_true(_has_color(image, COLOR_ASH), "idle preserva chifres/cinzas")
	assert_true(_has_color(image, COLOR_BLOOD), "idle preserva sangue material")
	assert_true(_has_color(image, COLOR_EYE), "idle preserva olhos em fenda")

func test_boitata_body_is_charred_mass() -> void:
	# Leitura-espelho da Caipora: a massa dominante é preta-carbonizada,
	# nunca o montículo marrom-avermelhado da v1 (regressão).
	for path: String in SPRITE_SIZES:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		var opaque := _count_opaque_pixels(image)
		var charred := _count_any_color(image, CHARRED_COLORS)
		assert_gt(float(charred) / float(opaque), MIN_CHARRED_FRACTION,
			"%s: familia carbonizada domina a massa opaca (leu %.0f%%)"
			% [path, 100.0 * charred / opaque])

func test_boitata_bottom_row_estavel() -> void:
	for path: String in SPRITE_SIZES:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		var bottom := _bottom_opaque_row(image)
		assert_between(bottom, BOTTOM_MIN, BOTTOM_MAX,
			"%s: base opaca (%d) na banda da linha de chao" % [path, bottom])

func test_boitata_massa_horizontal() -> void:
	# A serpente-muralha: a largura é assinatura (espelha a trava de
	# test_boss_scale_proportions com folga local).
	var image := Image.load_from_file(ProjectSettings.globalize_path(BOITATA_IDLE))
	assert_false(image.is_empty(), "boitata idle carrega como Image")
	if image.is_empty():
		return
	assert_gt(_bbox_width(image), MIN_BBOX_WIDTH,
		"idle mantem a massa horizontal de serpente gigante")

func test_boitata_windup_has_white_corpse_fire() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(BOITATA_WINDUP))
	assert_false(image.is_empty(), "boitata windup carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_FIRE_WHITE),
		"windup acende a boca de fogo-fatuo sem usar branco puro da Caipora")

func test_boitata_windup_inflames_the_crest() -> void:
	var idle := Image.load_from_file(ProjectSettings.globalize_path(BOITATA_IDLE))
	var windup := Image.load_from_file(ProjectSettings.globalize_path(BOITATA_WINDUP))
	if idle.is_empty() or windup.is_empty():
		fail_test("boitata idle/windup carregam como Image")
		return
	assert_ne(idle.get_data(), windup.get_data(),
		"windup levanta cabeca/pescoco e telegrafa diferente do idle")
	var windup_fire := _count_any_color(windup, FIRE_COLORS)
	var idle_fire := _count_any_color(idle, FIRE_COLORS)
	assert_true(windup_fire >= idle_fire,
		"windup aumenta ou mantem a massa de fogo (idle=%d, windup=%d)" % [idle_fire, windup_fire])

func test_boitata_does_not_steal_caipora_brand_colors() -> void:
	for path: String in SPRITE_SIZES:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		assert_false(_has_color(image, COLOR_CAIPORA_EYES),
			"%s sem olhos brancos puros" % path)
		assert_false(_has_color(image, COLOR_CAIPORA_MANE),
			"%s sem o laranja vivo da juba" % path)
		assert_false(_has_color(image, COLOR_CAIPORA_MANE_DK),
			"%s sem o laranja escuro da juba" % path)
		assert_false(_has_color(image, COLOR_CAIPORA_CRYSTAL),
			"%s sem o verde do cristal/Furia" % path)

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

func _bbox_width(image: Image) -> int:
	var left := image.get_width()
	var right := -1
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.1:
				left = mini(left, x)
				right = maxi(right, x)
	return right - left + 1

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
