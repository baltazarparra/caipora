extends GutTest

var _panel: OptionsPanel

func after_each() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
	AudioDirector.set_bus_volume("Master", 1.0)
	Lang.set_language(Lang.LANG_PT)

func _instantiate_panel() -> void:
	Lang.set_language(Lang.LANG_PT)
	_panel = OptionsPanel.new()
	add_child_autofree(_panel)
	await wait_frames(1)

func test_panel_has_single_master_volume_slider_and_no_option_buttons() -> void:
	await _instantiate_panel()
	assert_eq(_count_children_of_type(_panel, HSlider), 1, "somente um slider")
	assert_eq(_count_children_of_type(_panel, OptionButton), 0, "sem idioma/touch tecnico")
	assert_eq(_panel._volume_label.text, "Volume")
	assert_eq(_panel._reset_button.text, "Apagar progresso")

func test_volume_slider_controls_master_bus() -> void:
	await _instantiate_panel()
	_panel._volume_slider.value = 0.37
	assert_almost_eq(AudioDirector.get_bus_volume("Master"), 0.37, 0.001)

func _count_children_of_type(root: Node, type_ref: Variant) -> int:
	var count := 0
	for child in root.get_children():
		if is_instance_of(child, type_ref):
			count += 1
		count += _count_children_of_type(child, type_ref)
	return count
