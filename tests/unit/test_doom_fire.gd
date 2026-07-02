extends GutTest

func _make_fire() -> DoomFire:
	var fire := DoomFire.new()
	add_child_autofree(fire)
	return fire

func test_palette_bake_roundtrip() -> void:
	var packed := DoomFire._bake_palette()
	assert_eq(packed.size(), DoomFire.PALETTE.size())
	for i in DoomFire.PALETTE.size():
		var c: Color = DoomFire.PALETTE[i]
		var v: int = packed[i]
		assert_eq(v & 0xFF, c.r8, "r do índice %d" % i)
		assert_eq((v >> 8) & 0xFF, c.g8, "g do índice %d" % i)
		assert_eq((v >> 16) & 0xFF, c.b8, "b do índice %d" % i)
		assert_eq((v >> 24) & 0xFF, c.a8, "a do índice %d" % i)

func test_seed_row_uses_top_palette_index() -> void:
	var fire := _make_fire()
	var seed_row: int = (DoomFire.ROWS - 1) * fire._cols
	for col in fire._cols:
		assert_eq(fire._grid[seed_row + col], DoomFire.PALETTE.size() - 1)

func test_fire_propagates_upward() -> void:
	var fire := _make_fire()
	fire._update_fire()
	# decay máximo por passo é DECAY_RANGE-1: a linha acima da fonte nunca apaga
	var row_base: int = (DoomFire.ROWS - 2) * fire._cols
	var max_val: int = 0
	for col in fire._cols:
		max_val = maxi(max_val, fire._grid[row_base + col])
	assert_gte(max_val, DoomFire.PALETTE.size() - DoomFire.DECAY_RANGE)

# ~2× ROWS updates: além do tempo de subida (1 linha por update), o suficiente
# para o regime estacionário em ambos os modos.
func _settle(fire: DoomFire) -> void:
	for i in DoomFire.ROWS * 2:
		fire._update_fire()

func _row_has_flame(fire: DoomFire, row: int) -> bool:
	var base: int = row * fire._cols
	for col in fire._cols:
		if fire._grid[base + col] > 0:
			return true
	return false

func test_tall_flames_reach_near_top() -> void:
	var fire := _make_fire()
	fire.tall_flames = true
	_settle(fire)
	# ~90% do viewport: há chama viva já perto do topo da grade (linha 12%).
	# No modo baixo (arena) tudo acima de ~60% é sempre zero — falharia direto.
	assert_true(_row_has_flame(fire, int(DoomFire.ROWS * 0.12)),
		"chama alta do menu alcança ~90% do viewport")

func test_default_flames_stay_low() -> void:
	var fire := _make_fire()
	_settle(fire)
	# Trava a regressão das ARENAS na MESMA linha do teste tall (12% do topo).
	# Linhas mais baixas (35–50%) ficam flaky: a cauda do random walk do decay
	# uniforme {0..4} acende uma célula lá em ~10% dos snapshots. Aqui a chance
	# é < 1e-4 — determinístico na prática dos dois lados.
	assert_false(_row_has_flame(fire, int(DoomFire.ROWS * 0.12)),
		"modo arena preserva o fogo baixo (~40%)")

func test_blit_writes_full_rgba_buffer() -> void:
	var fire := _make_fire()
	fire._update_fire()
	fire._blit_image()
	assert_eq(fire._image.get_data().size(), fire._cols * DoomFire.ROWS * 4)

func test_blit_matches_palette_colors() -> void:
	var fire := _make_fire()
	fire._update_fire()
	fire._blit_image()
	var row: int = DoomFire.ROWS - 2
	for col in mini(fire._cols, 8):
		var idx: int = fire._grid[row * fire._cols + col]
		var px: Color = fire._image.get_pixel(col, row)
		var expected: Color = DoomFire.PALETTE[idx]
		assert_almost_eq(px.r, expected.r, 0.01, "col %d" % col)
		assert_almost_eq(px.g, expected.g, 0.01, "col %d" % col)
		assert_almost_eq(px.b, expected.b, 0.01, "col %d" % col)
		assert_almost_eq(px.a, expected.a, 0.01, "col %d" % col)
