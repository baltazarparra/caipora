extends GutTest

const LangPt := preload("res://scripts/core/lang_pt.gd")
const LangEn := preload("res://scripts/core/lang_en.gd")

func test_pt_and_en_have_identical_keys() -> void:
	var pt_keys := _sorted_keys(LangPt.STRINGS)
	var en_keys := _sorted_keys(LangEn.STRINGS)
	assert_eq(pt_keys, en_keys,
		"lang_pt.gd e lang_en.gd precisam ter o mesmo conjunto de chaves")

func test_no_empty_i18n_values() -> void:
	for key: StringName in LangPt.STRINGS:
		assert_ne(String(LangPt.STRINGS[key]), "", "pt vazio: %s" % key)
	for key: StringName in LangEn.STRINGS:
		assert_ne(String(LangEn.STRINGS[key]), "", "en vazio: %s" % key)

func test_premium_camp_i18n_keys_exist_in_both_languages() -> void:
	var required: Array[StringName] = [
		&"transition.themed",
		&"transition.camp",
		&"move.caipora.normal",
		&"move.caipora.double",
		&"move.caipora.cortejo",
		&"hub.exit.trail",
		&"combat.timing.good",
	]
	for key: StringName in required:
		assert_true(LangPt.STRINGS.has(key), "pt tem %s" % key)
		assert_true(LangEn.STRINGS.has(key), "en tem %s" % key)

func _sorted_keys(dict: Dictionary) -> Array:
	var keys: Array = dict.keys()
	keys.sort()
	return keys
