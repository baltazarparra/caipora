extends GutTest

# F1 — BrandFrame: geometria da placa serrilhada (funções estáticas puras).

func test_saw_plate_has_teeth() -> void:
	var pts := BrandFrame.saw_plate(Rect2(0, 0, 100, 40))
	assert_gt(pts.size(), 4, "placa serrilhada deve ter vários vértices (dentes)")

func test_saw_plate_starts_at_left_depth() -> void:
	var pts := BrandFrame.saw_plate(Rect2(0, 0, 100, 40))
	assert_almost_eq(pts[0].x, 0.0, 0.01)
	assert_almost_eq(pts[0].y, Constants.CHROME_SAW_DEPTH, 0.01)

func test_saw_plate_stays_in_bounds() -> void:
	var body := Rect2(10, 5, 120, 50)
	var pts := BrandFrame.saw_plate(body)
	for p: Vector2 in pts:
		assert_between(p.x, body.position.x - 0.01, body.end.x + 0.01)
		assert_between(p.y, body.position.y - 0.01, body.end.y + 0.01)
