extends GutTest

# Trava o GlyphAtlas (fonte única do glifo Garra Tribal + máscaras por papel):
# forma da matriz, papéis→pixels EXATOS (branco-opaco ⟺ char do papel),
# disjunção/cobertura, rotações (tabela replicada) e cache. A propriedade
# "pixel opaco é exatamente (1,1,1,1)" é o que garante identidade tonal no
# refactor da Frente C (texel × modulate == modulate).

const ROLES := [
	GlyphAtlas.Role.BRIGHT, GlyphAtlas.Role.DARK,
	GlyphAtlas.Role.OUTLINE, GlyphAtlas.Role.BODY,
]
const ORIENTATIONS := [
	GlyphAtlas.Orientation.UP, GlyphAtlas.Orientation.RIGHT,
	GlyphAtlas.Orientation.DOWN, GlyphAtlas.Orientation.LEFT,
]


func test_matrix_shape_and_alphabet() -> void:
	assert_eq(GlyphAtlas.GLYPH.size(), GlyphAtlas.GRID, "matriz tem GRID linhas")
	for r: int in GlyphAtlas.GRID:
		var row: String = GlyphAtlas.GLYPH[r]
		assert_eq(row.length(), GlyphAtlas.GRID, "linha %d tem GRID chars" % r)
		for c: int in GlyphAtlas.GRID:
			assert_true(row[c] in [".", "K", "O", "D"],
				"alfabeto do glifo em (%d,%d): '%s'" % [r, c, row[c]])


func test_masks_match_roles_up() -> void:
	var images: Dictionary = {}
	for role: int in ROLES:
		images[role] = GlyphAtlas.mask_image(role, GlyphAtlas.Orientation.UP)
		assert_eq((images[role] as Image).get_width(), GlyphAtlas.GRID)
		assert_eq((images[role] as Image).get_height(), GlyphAtlas.GRID)
	var expected_char: Dictionary = {
		GlyphAtlas.Role.BRIGHT: "O",
		GlyphAtlas.Role.DARK: "D",
		GlyphAtlas.Role.OUTLINE: "K",
	}
	for r: int in GlyphAtlas.GRID:
		var row: String = GlyphAtlas.GLYPH[r]
		for c: int in GlyphAtlas.GRID:
			var ch: String = row[c]
			for role: int in expected_char:
				# Orientação UP: célula (r, c) da matriz → pixel (c, r).
				var px: Color = (images[role] as Image).get_pixel(c, r)
				if ch == expected_char[role]:
					assert_eq(px, Color(1.0, 1.0, 1.0, 1.0),
						"papel %d opaco branco em (%d,%d)" % [role, r, c])
				else:
					assert_eq(px.a, 0.0, "papel %d transparente em (%d,%d)" % [role, r, c])
			var body_px: Color = (images[GlyphAtlas.Role.BODY] as Image).get_pixel(c, r)
			if ch == "O" or ch == "D":
				assert_eq(body_px, Color(1.0, 1.0, 1.0, 1.0), "BODY = O∪D em (%d,%d)" % [r, c])
			else:
				assert_eq(body_px.a, 0.0, "BODY transparente em (%d,%d)" % [r, c])


func test_role_counts_cover_all_non_empty_cells() -> void:
	var counts: Dictionary = {"O": 0, "D": 0, "K": 0}
	for row: String in GlyphAtlas.GLYPH:
		for c: int in row.length():
			if counts.has(row[c]):
				counts[row[c]] += 1
	assert_eq(_opaque_count(GlyphAtlas.Role.BRIGHT), counts["O"] as int, "contagem BRIGHT")
	assert_eq(_opaque_count(GlyphAtlas.Role.DARK), counts["D"] as int, "contagem DARK")
	assert_eq(_opaque_count(GlyphAtlas.Role.OUTLINE), counts["K"] as int, "contagem OUTLINE")
	assert_eq(_opaque_count(GlyphAtlas.Role.BODY),
		(counts["O"] as int) + (counts["D"] as int), "contagem BODY = O + D")


func test_rotations_match_reference_table() -> void:
	# Tabela replicada de propósito (não chama _rotated_xy): trava a rotação.
	var g: int = GlyphAtlas.GRID - 1
	for orientation: int in ORIENTATIONS:
		var img: Image = GlyphAtlas.mask_image(GlyphAtlas.Role.BODY, orientation)
		var base: Image = GlyphAtlas.mask_image(GlyphAtlas.Role.BODY, GlyphAtlas.Orientation.UP)
		for r: int in GlyphAtlas.GRID:
			for c: int in GlyphAtlas.GRID:
				var rot: Vector2i
				match orientation:
					GlyphAtlas.Orientation.RIGHT: rot = Vector2i(g - r, c)
					GlyphAtlas.Orientation.DOWN: rot = Vector2i(g - c, g - r)
					GlyphAtlas.Orientation.LEFT: rot = Vector2i(r, g - c)
					_: rot = Vector2i(c, r)
				assert_eq(img.get_pixel(rot.x, rot.y), base.get_pixel(c, r),
					"rotação %d célula (%d,%d)" % [orientation, r, c])


func test_orientation_mappings() -> void:
	assert_eq(GlyphAtlas.orientation_for_action("ui_up"), GlyphAtlas.Orientation.UP)
	assert_eq(GlyphAtlas.orientation_for_action("ui_right"), GlyphAtlas.Orientation.RIGHT)
	assert_eq(GlyphAtlas.orientation_for_action("ui_down"), GlyphAtlas.Orientation.DOWN)
	assert_eq(GlyphAtlas.orientation_for_action("ui_left"), GlyphAtlas.Orientation.LEFT)
	assert_eq(GlyphAtlas.orientation_for_action("qualquer"), GlyphAtlas.Orientation.UP,
		"fallback de action é UP")
	assert_eq(GlyphAtlas.orientation_for_hint("up"), GlyphAtlas.Orientation.UP)
	assert_eq(GlyphAtlas.orientation_for_hint("right"), GlyphAtlas.Orientation.RIGHT)
	assert_eq(GlyphAtlas.orientation_for_hint("down"), GlyphAtlas.Orientation.DOWN)
	assert_eq(GlyphAtlas.orientation_for_hint("left"), GlyphAtlas.Orientation.LEFT)
	assert_eq(GlyphAtlas.orientation_for_hint(""), GlyphAtlas.Orientation.UP,
		"fallback de hint é UP")
	# Coincidência com _ORIENTATIONS do CombatArrowButton (0..3): travada aqui.
	assert_eq(int(GlyphAtlas.orientation_for_action("ui_right")), 1)
	assert_eq(int(GlyphAtlas.orientation_for_action("ui_down")), 2)
	assert_eq(int(GlyphAtlas.orientation_for_action("ui_left")), 3)


func test_mask_cache_returns_same_instance() -> void:
	var a: ImageTexture = GlyphAtlas.mask(GlyphAtlas.Role.BRIGHT, GlyphAtlas.Orientation.UP)
	var b: ImageTexture = GlyphAtlas.mask(GlyphAtlas.Role.BRIGHT, GlyphAtlas.Orientation.UP)
	assert_true(a == b, "mask() cacheia por (papel, orientação)")
	var c: ImageTexture = GlyphAtlas.mask(GlyphAtlas.Role.BRIGHT, GlyphAtlas.Orientation.LEFT)
	assert_true(a != c, "orientações distintas têm texturas distintas")


func _opaque_count(role: int) -> int:
	var img: Image = GlyphAtlas.mask_image(role, GlyphAtlas.Orientation.UP)
	var count: int = 0
	for y: int in GlyphAtlas.GRID:
		for x: int in GlyphAtlas.GRID:
			if img.get_pixel(x, y).a > 0.5:
				count += 1
	return count
