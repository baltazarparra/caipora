extends GutTest

var _menu: MainMenu

func after_each() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	Lang.set_language(Lang.LANG_PT)

func _instantiate_menu() -> void:
	Lang.set_language(Lang.LANG_PT)
	_menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child_autofree(_menu)
	await wait_frames(1)

func test_menu_has_no_removed_exit_control_or_string() -> void:
	await _instantiate_menu()
	var removed_node := "Quit" + "Button"
	var removed_key := StringName("menu." + "quit")
	assert_null(_menu.find_child(removed_node, true, false), "Sair foi removido da cena")
	assert_eq(Lang.t(removed_key), String(removed_key), "string de sair nao existe mais")

func test_menu_uses_hero_start_button_and_options_panel() -> void:
	await _instantiate_menu()
	assert_true(_menu._start_button is BrandButton, "Iniciar é o botao-herói do kit")
	assert_eq(_menu._start_button.variant, BrandButton.Variant.HERO)
	assert_eq(_menu._start_button.label, "DESPERTAR")
	assert_not_null(_menu._options_panel, "OptionsPanel mora na tela inicial")
	assert_eq(_menu._options_button.text, "OPÇÕES")

func test_start_button_label_updates_with_language() -> void:
	await _instantiate_menu()
	Lang.set_language(Lang.LANG_EN)
	assert_eq(_menu._start_button.label, "AWAKEN")
	assert_eq(_menu._options_button.text, "OPTIONS")
