extends GutTest

# F1 — BrandButton: estado por variante (o desenho é validado por preview visual).

var _btn: BrandButton

func before_each() -> void:
	_btn = BrandButton.new()
	add_child_autofree(_btn)

func test_is_base_button() -> void:
	assert_is(_btn, BaseButton)

func test_variant_defaults_primary() -> void:
	assert_eq(_btn.variant, BrandButton.Variant.PRIMARY)

func test_hero_gets_min_size() -> void:
	var hero := BrandButton.new()
	hero.variant = BrandButton.Variant.HERO
	add_child_autofree(hero)
	assert_eq(hero.custom_minimum_size, BrandButton.HERO_MIN)

func test_label_assignment() -> void:
	_btn.label = "DESPERTAR"
	assert_eq(_btn.label, "DESPERTAR")

func test_hero_label_font_size_scales_with_height() -> void:
	assert_eq(BrandButton.hero_label_font_size(208.0), 26, "hero 2x atinge o teto LABEL_FONT_MAX")
	assert_eq(BrandButton.hero_label_font_size(104.0), 16, "altura histórica do retrato")
	assert_eq(BrandButton.hero_label_font_size(0.0), Constants.FONT_SM, "piso é FONT_SM")

func test_press_lunges_and_release_returns() -> void:
	_btn.button_down.emit()
	assert_eq(_btn.scale, Vector2(Constants.CHROME_PRESS_SCALE, Constants.CHROME_PRESS_SCALE),
		"press dá o bote (escala)")
	_btn.button_up.emit()
	await wait_seconds(Constants.CHROME_PRESS_SECS + 0.1)
	assert_almost_eq(_btn.scale.x, 1.0, 0.01, "release volta ao repouso")
