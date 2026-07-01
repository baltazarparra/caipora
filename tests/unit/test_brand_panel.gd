extends GutTest

# F1 — BrandPanel: margens de token e alternância framed/scrim.

var _panel: BrandPanel

func before_each() -> void:
	_panel = BrandPanel.new()
	add_child_autofree(_panel)

func test_is_margin_container() -> void:
	assert_is(_panel, MarginContainer)

func test_framed_by_default() -> void:
	assert_true(_panel.framed)

func test_margins_from_tokens_when_framed() -> void:
	assert_eq(_panel.get_theme_constant("margin_left"), Constants.UI_PADDING_H)
	# Framed: topo/base limpam a crista de juba.
	assert_eq(_panel.get_theme_constant("margin_top"),
		Constants.UI_PADDING_V + int(BrandFrame.crest_clearance()))

func test_unframed_margins_shrink() -> void:
	_panel.framed = false
	assert_eq(_panel.get_theme_constant("margin_top"), Constants.UI_PADDING_V)

func test_pad_extra_adds_breathing_room() -> void:
	_panel.pad_extra = Vector2i(8, 16)
	assert_eq(_panel.get_theme_constant("margin_left"), Constants.UI_PADDING_H + 8)
	assert_eq(_panel.get_theme_constant("margin_top"),
		Constants.UI_PADDING_V + int(BrandFrame.crest_clearance()) + 16)
