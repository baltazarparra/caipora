extends GutTest

# HdConfirmPanel: chaves i18n nos dois idiomas, textos por direção e persistência
# da escolha ao confirmar. O fade/reload não é exercitado — apply_choice é o seam
# que separa a decisão da navegação.

const HD_KEYS: Array[StringName] = [
	&"hd.confirm.title.on", &"hd.confirm.title.off",
	&"hd.confirm.body.on", &"hd.confirm.body.off",
	&"hd.confirm.ok", &"hd.confirm.cancel",
]

var _panel: HdConfirmPanel

func before_each() -> void:
	_panel = HdConfirmPanel.new()
	add_child_autofree(_panel)

func after_each() -> void:
	Quality._reset_for_test()
	var cfg := ConfigFile.new()
	if cfg.load(Quality.SETTINGS_PATH) == OK and cfg.has_section(Quality.SETTINGS_SECTION):
		cfg.erase_section(Quality.SETTINGS_SECTION)
		cfg.save(Quality.SETTINGS_PATH)

func test_i18n_keys_exist_in_both_langs() -> void:
	for lang in ["pt", "en"]:
		var script := load("res://scripts/core/lang_%s.gd" % lang) as GDScript
		var strings: Dictionary = script.get_script_constant_map().get("STRINGS", {})
		for key in HD_KEYS:
			assert_true(strings.has(key), "%s tem a chave %s" % [lang, key])

func test_open_sets_direction_texts() -> void:
	_panel.open(true)
	assert_true(_panel.visible, "open mostra o painel")
	assert_eq(_panel._title_label.text, Lang.t(&"hd.confirm.title.on"), "título de ligar")
	assert_eq(_panel._body_label.text, Lang.t(&"hd.confirm.body.on"), "corpo de ligar")
	_panel.open(false)
	assert_eq(_panel._title_label.text, Lang.t(&"hd.confirm.title.off"), "título de desligar")
	assert_eq(_panel._body_label.text, Lang.t(&"hd.confirm.body.off"), "corpo de desligar")

func test_apply_choice_persists_hd() -> void:
	_panel.open(true)
	_panel.apply_choice()
	assert_true(Quality.hd_enabled(), "confirmar ligar persiste hd=true")
	_panel.open(false)
	_panel.apply_choice()
	assert_false(Quality.hd_enabled(), "confirmar desligar persiste hd=false")

func test_cancel_closes_without_touching_flag() -> void:
	Quality._set_for_test(false)
	_panel.open(true)
	_panel.close()
	assert_false(_panel.visible, "cancelar fecha o painel")
	assert_false(Quality.hd_enabled(), "cancelar não muda o flag")
