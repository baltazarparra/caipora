extends Node

## Singleton de localização. Textos de UI passam por t() ou tf().
## Padrão pt-BR — sem mudança de comportamento até o jogador escolher English.
## Persiste em user://settings.cfg (seção "lang"), mesmo arquivo do AudioDirector.

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "lang"
const SETTINGS_KEY := "language"

const LANG_PT := &"pt"
const LANG_EN := &"en"

var _lang: StringName = LANG_PT
var _strings: Dictionary = {}

signal language_changed(lang: StringName)

func _ready() -> void:
	_load_preference()
	_load_dict(_lang)

func current() -> StringName:
	return _lang

func set_language(lang: StringName) -> void:
	if lang not in [LANG_PT, LANG_EN]:
		return
	if lang == _lang:
		return
	_lang = lang
	_load_dict(lang)
	_save_preference()
	language_changed.emit(lang)

## Retorna a string localizada para a chave. Retorna a chave se não encontrada.
func t(key: StringName) -> String:
	return String(_strings.get(key, key))

## Retorna a string localizada com argumentos de formato.
func tf(key: StringName, args: Array) -> String:
	return t(key) % args

func _load_preference() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved := StringName(String(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, String(LANG_PT))))
	if saved in [LANG_PT, LANG_EN]:
		_lang = saved

func _save_preference() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, String(_lang))
	cfg.save(SETTINGS_PATH)

func _load_dict(lang: StringName) -> void:
	var path := "res://scripts/core/lang_%s.gd" % lang
	if not ResourceLoader.exists(path):
		_strings = {}
		return
	var script := load(path) as GDScript
	if script == null:
		_strings = {}
		return
	_strings = script.get_script_constant_map().get("STRINGS", {})
