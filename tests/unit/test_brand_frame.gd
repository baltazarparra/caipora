extends GutTest

# Chrome v2 — BrandFrame: crista de juba (geometria pura, funções estáticas).

func test_plate_has_teeth() -> void:
	var pts := BrandFrame.plate_points(Rect2(0, 0, 100, 60))
	assert_gt(pts.size(), 8, "a crista deve ter vários degraus (dentes)")

func test_plate_stays_in_bounds() -> void:
	var body := Rect2(10, 5, 120, 60)
	var pts := BrandFrame.plate_points(body)
	for p: Vector2 in pts:
		assert_between(p.x, body.position.x - 0.01, body.end.x + 0.01)
		assert_between(p.y, body.position.y - 0.01, body.end.y + 0.01)

func test_plate_is_axis_aligned() -> void:
	# Lei da pixel-art chapada: todo segmento é horizontal ou vertical (zero diagonais).
	var pts := BrandFrame.plate_points(Rect2(0, 0, 200, 80))
	for i: int in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var horizontal := absf(a.y - b.y) < 0.01
		var vertical := absf(a.x - b.x) < 0.01
		assert_true(horizontal or vertical,
			"segmento %d (%s → %s) deve ser axis-aligned" % [i, a, b])

func test_tallest_tooth_touches_top() -> void:
	# O dente mais alto (h == CHROME_CREST_H) encosta no topo do body.
	var body := Rect2(0, 0, 200, 80)
	var pts := BrandFrame.plate_points(body)
	var min_y := INF
	for p: Vector2 in pts:
		min_y = minf(min_y, p.y)
	assert_almost_eq(min_y, body.position.y, 0.01)

func test_crest_clearance_scales_and_snaps() -> void:
	var full := BrandFrame.crest_clearance(1.0)
	var small := BrandFrame.crest_clearance(0.6)
	assert_lt(small, full, "crista reduzida em placas pequenas")
	assert_almost_eq(fmod(full, 2.0), 0.0, 0.01, "snap de 2px (degrau de pixel)")
	assert_almost_eq(fmod(small, 2.0), 0.0, 0.01, "snap de 2px (degrau de pixel)")

func test_crest_peaks_exist_for_hero_embers() -> void:
	var peaks := BrandFrame.crest_peaks(Rect2(0, 0, 280, 96))
	assert_gt(peaks.size(), 0, "picos altos para a brasa das pontas")
