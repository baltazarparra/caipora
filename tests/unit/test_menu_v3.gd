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

func test_top_bar_has_flags_and_master_mute_speaker() -> void:
	await _instantiate_menu()
	assert_true(_menu._speaker_btn is SpeakerButton, "speaker de mute geral no topo")
	assert_eq(_menu._speaker_btn.muted, AudioDirector.is_master_muted(),
		"ícone reflete o estado persistido do mute")
	assert_ne(_menu._lang_row.get_parent(), _menu._footer_row, "bandeiras saíram do rodapé")
	assert_eq(_menu._lang_row.get_parent(), _menu.get_node("Ui"), "bandeiras vivem no topo do Ui")

func test_options_font_matches_hero_label() -> void:
	await _instantiate_menu()
	var expected: int = BrandButton.hero_label_font_size(_menu._start_button.size.y)
	assert_eq(_menu._options_button.get_theme_font_size("font_size"), expected,
		"Opções casa a fonte com o rótulo do hero")
