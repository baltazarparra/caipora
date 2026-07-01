extends GutTest

const SPRITE_PATHS: Array[String] = [
	"res://assets/sprites/player_idle.png",
	"res://assets/sprites/player_idle_01.png",
	"res://assets/sprites/player_idle_02.png",
	"res://assets/sprites/player_idle_03.png",
	"res://assets/sprites/player_idle_04.png",
	"res://assets/sprites/player_idle_dim_1.png",
	"res://assets/sprites/player_idle_dim_2.png",
	"res://assets/sprites/player_walk_1.png",
	"res://assets/sprites/player_walk_2.png",
	"res://assets/sprites/player_walk_3.png",
	"res://assets/sprites/player_walk_4.png",
	"res://assets/sprites/player_walk_5.png",
	"res://assets/sprites/player_walk_6.png",
	"res://assets/sprites/player_windup.png",
	"res://assets/sprites/player_windup_1.png",
	"res://assets/sprites/player_windup_2.png",
	"res://assets/sprites/player_strike.png",
	"res://assets/sprites/player_recover.png",
	"res://assets/sprites/player_back.png",
	"res://assets/sprites/player_dead.png",
	"res://assets/sprites/player_idle_chama.png",
	"res://assets/sprites/player_idle_01_chama.png",
	"res://assets/sprites/player_idle_02_chama.png",
	"res://assets/sprites/player_idle_03_chama.png",
	"res://assets/sprites/player_idle_04_chama.png",
	"res://assets/sprites/player_idle_dim_1_chama.png",
	"res://assets/sprites/player_idle_dim_2_chama.png",
	"res://assets/sprites/player_walk_1_chama.png",
	"res://assets/sprites/player_walk_2_chama.png",
	"res://assets/sprites/player_walk_3_chama.png",
	"res://assets/sprites/player_walk_4_chama.png",
	"res://assets/sprites/player_walk_5_chama.png",
	"res://assets/sprites/player_walk_6_chama.png",
	"res://assets/sprites/player_windup_chama.png",
	"res://assets/sprites/player_windup_1_chama.png",
	"res://assets/sprites/player_windup_2_chama.png",
	"res://assets/sprites/player_strike_chama.png",
	"res://assets/sprites/player_recover_chama.png",
	"res://assets/sprites/player_back_chama.png",
	"res://assets/sprites/player_dead_chama.png",
]

const PLAYER_BACK := "res://assets/sprites/player_back.png"
const PLAYER_DEAD := "res://assets/sprites/player_dead.png"

const PLAYER_IDLE := "res://assets/sprites/player_idle.png"
const PLAYER_IDLE_CHAMA := "res://assets/sprites/player_idle_chama.png"

const COLOR_MANE := Color8(255, 69, 0)
const COLOR_VOID := Color8(0, 0, 0)
const COLOR_EYES := Color8(255, 255, 255)
const COLOR_CRYSTAL := Color8(0, 250, 154)
const COLOR_CHAMA := Color8(255, 176, 50)

# Famílias de tom (F0: sanciona 3–4 tons/material via selout chapado). Medir a
# família laranja × a família escura mantém a trava de dominância honesta quando
# o selout adiciona oclusão/realce — senão o teste compararia só #ff4500 vs #000000
# e o selout derrubaria a contagem artificialmente.
const COLOR_MANE_DK := Color8(139, 42, 0)    # #8b2a00 sombra
const COLOR_MANE_OCC := Color8(90, 26, 0)    # #5a1a00 oclusão
const COLOR_MANE_HI := Color8(255, 122, 51)  # #ff7a33 realce

# Rampa CHAMA — nenhuma pode aparecer num sprite BASE (paleta fechada por variante).
const FIRE_OCC := Color8(194, 74, 8)      # #c24a08
const FIRE_BASE := Color8(255, 104, 8)    # #ff6808
const FIRE_CORE := Color8(255, 239, 178)  # #ffefb2
const FIRE_COLORS: Array[Color] = [FIRE_OCC, FIRE_BASE, COLOR_CHAMA, FIRE_CORE]

func test_caipora_sprite_contract_assets_are_96x96() -> void:
	for path: String in SPRITE_PATHS:
		var texture := load(path) as Texture2D
		assert_not_null(texture, "%s carrega" % path)
		if texture == null:
			continue
		assert_eq(texture.get_size(), Vector2(96, 96), "%s mantem contrato 96x96" % path)

func test_caipora_sprite_contract_assets_are_not_blank() -> void:
	for path: String in SPRITE_PATHS:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		assert_false(image.is_empty(), "%s carrega como Image" % path)
		if image.is_empty():
			continue
		assert_gt(_count_opaque_pixels(image), 180, "%s tem massa visual suficiente" % path)

func test_caipora_idle_keeps_concept_signature_colors() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(PLAYER_IDLE))
	assert_false(image.is_empty(), "idle carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_MANE), "idle preserva juba-capa laranja da prancha")
	assert_true(_has_color(image, COLOR_VOID), "idle preserva rosto-vazio preto")
	assert_true(_has_color(image, COLOR_EYES), "idle preserva olhos brancos puros")
	assert_true(_has_color(image, COLOR_CRYSTAL), "idle preserva cristal verde")

func test_caipora_idle_is_orange_black_silhouette_first() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(PLAYER_IDLE))
	assert_false(image.is_empty(), "idle carrega como Image")
	if image.is_empty():
		return
	var orange_pixels := _count_orange_family(image)
	var black_pixels := _count_dark_family(image)
	var green_pixels := _count_color(image, COLOR_CRYSTAL)
	assert_gt(orange_pixels, black_pixels, "juba-capa laranja domina a leitura da silhueta")
	assert_lte(green_pixels, 12, "cristal verde fica mínimo; cajado lê preto como na referência")

func test_caipora_chama_idle_keeps_fire_variant_color() -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(PLAYER_IDLE_CHAMA))
	assert_false(image.is_empty(), "idle CHAMA carrega como Image")
	if image.is_empty():
		return
	assert_true(_has_color(image, COLOR_CHAMA), "CHAMA preserva juba incendiada")
	assert_true(_has_color(image, COLOR_VOID), "CHAMA preserva rosto-vazio preto")
	assert_true(_has_color(image, COLOR_EYES), "CHAMA preserva olhos brancos puros")

func test_caipora_base_sprites_are_fire_disjoint() -> void:
	# F1.2.1 P1: paleta fechada por variante — os player_*.png BASE nao podem
	# conter cor da rampa CHAMA (senao o snap misturou base+chama, gerando franja).
	for path: String in SPRITE_PATHS:
		if path.contains("_chama"):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image.is_empty():
			continue
		for fire: Color in FIRE_COLORS:
			assert_false(_has_color(image, fire), "%s (base) livre da rampa CHAMA" % path)

func test_caipora_idle_eyes_are_symmetric() -> void:
	# F1.3 / trava de marca: os DOIS olhos brancos sao IGUAIS — simetricos no eixo
	# do rosto (antes divergiam em rx/ry/y no gerador).
	var image := Image.load_from_file(ProjectSettings.globalize_path(PLAYER_IDLE))
	if image.is_empty():
		return
	var cols: Dictionary = {}
	var min_x := 96
	var max_x := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).is_equal_approx(COLOR_EYES):
				cols[x] = int(cols.get(x, 0)) + 1
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	assert_gt(cols.size(), 0, "idle tem olhos brancos")
	var axis := float(min_x + max_x) / 2.0
	var left := 0
	var right := 0
	for x: int in cols:
		if float(x) < axis:
			left += int(cols[x])
		elif float(x) > axis:
			right += int(cols[x])
	assert_almost_eq(left, right, 2, "olhos brancos simetricos (iguais) no eixo do rosto")

func test_caipora_back_view_has_no_eyes_and_keeps_orange_first() -> void:
	# De costas (cena da escolha final) ela olha para DENTRO da cena: os olhos
	# brancos não podem existir — e a juba-capa laranja segue dominando.
	var image := Image.load_from_file(ProjectSettings.globalize_path(PLAYER_BACK))
	assert_false(image.is_empty(), "back carrega como Image")
	if image.is_empty():
		return
	assert_false(_has_color(image, COLOR_EYES), "de costas não há olhos brancos")
	var orange_pixels := _count_orange_family(image)
	var black_pixels := _count_dark_family(image)
	assert_gt(orange_pixels, black_pixels, "a capa serrilhada domina a vista de costas")

func test_caipora_dead_pose_has_no_eyes() -> void:
	# Tombada (final do sacrifício) o vazio se fechou: nenhum olho branco aberto.
	var image := Image.load_from_file(ProjectSettings.globalize_path(PLAYER_DEAD))
	assert_false(image.is_empty(), "dead carrega como Image")
	if image.is_empty():
		return
	assert_false(_has_color(image, COLOR_EYES), "morta, os olhos brancos apagaram")
	assert_true(_has_color(image, COLOR_MANE), "a mortalha ainda é a juba laranja")

func test_caipora_idle_dim_has_no_eyes() -> void:
	# Blink "olhos que apagam": o vazio engole os olhos (sem branco), NUNCA palpebra.
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/player_idle_dim_1.png"))
	if image.is_empty():
		return
	assert_false(_has_color(image, COLOR_EYES), "idle_dim apaga os olhos brancos")
	assert_true(_has_color(image, COLOR_MANE), "idle_dim mantem a juba laranja")

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

func _count_color(image: Image, expected: Color) -> int:
	var count := 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).is_equal_approx(expected):
				count += 1
	return count

func _count_orange_family(image: Image) -> int:
	var n := _count_color(image, COLOR_MANE)
	n += _count_color(image, COLOR_MANE_DK)
	n += _count_color(image, COLOR_MANE_OCC)
	n += _count_color(image, COLOR_MANE_HI)
	return n

func _count_dark_family(image: Image) -> int:
	# So #000000 por ora; re-adicionar #140f14 quando o body-selout de fato o pintar.
	return _count_color(image, COLOR_VOID)
