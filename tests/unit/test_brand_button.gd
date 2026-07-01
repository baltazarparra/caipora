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
