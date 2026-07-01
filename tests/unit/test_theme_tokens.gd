extends GutTest

# F0 — trava a paridade entre o tema da UI (assets/fonts/theme.tres) e os tokens
# canônicos de Constants. Se o .tres destoar dos tokens (accent de texto, escala
# tipográfica, cantos retos, fonte de marca), este teste quebra. Fonte única: Constants.
# Cores comparadas com is_equal_approx (o .tres guarda floats arredondados).

const THEME_PATH := "res://assets/fonts/theme.tres"

var _theme: Theme

func before_each() -> void:
	_theme = load(THEME_PATH) as Theme

func test_theme_loads() -> void:
	assert_not_null(_theme, "theme.tres deve carregar como Theme")

func test_default_font_is_pixel_font() -> void:
	assert_not_null(_theme.default_font, "tema deve ter fonte default")
	assert_string_contains(_theme.default_font.resource_path, "PressStart2P")

func test_default_font_size_is_token() -> void:
	assert_eq(_theme.default_font_size, Constants.FONT_MD)

func test_label_font_size_is_token() -> void:
	assert_eq(_theme.get_font_size("font_size", "Label"), Constants.FONT_MD)

func test_linkbutton_font_size_is_token() -> void:
	assert_eq(_theme.get_font_size("font_size", "LinkButton"), Constants.FONT_SM)

func test_button_text_accent_is_amber() -> void:
	# Accent de TEXTO = AMBER (fim do "dois laranjas"; antes era JUBA).
	assert_true(_theme.get_color("font_hover_color", "Button").is_equal_approx(Constants.COLOR_AMBER),
		"Button hover font_color deve ser COLOR_AMBER")
	assert_true(_theme.get_color("font_pressed_color", "Button").is_equal_approx(Constants.COLOR_AMBER),
		"Button pressed font_color deve ser COLOR_AMBER")

func test_linkbutton_hover_accent_is_amber() -> void:
	assert_true(_theme.get_color("font_hover_color", "LinkButton").is_equal_approx(Constants.COLOR_AMBER),
		"LinkButton hover font_color deve ser COLOR_AMBER")

func test_ui_corners_are_square() -> void:
	# Cantos retos (UI_CORNER_RADIUS = 0) — direção de arte da UI.
	for stylebox_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := _theme.get_stylebox(stylebox_name, "Button") as StyleBoxFlat
		if sb == null:
			continue
		assert_eq(sb.corner_radius_top_left, Constants.UI_CORNER_RADIUS,
			"stylebox '%s' do Button deve ter canto reto" % stylebox_name)
