class_name Quality
extends RefCounted

## Flag de qualidade gráfica "HD": liga os efeitos pesados (ParticleRim, rastros
## de boss, densidade cheia de partículas). Classe ESTÁTICA, não autoload — só usa
## ConfigFile/OS/DisplayServer/JavaScriptBridge, então compila em qualquer contexto
## (`godot -s`, headless, GUT — gotcha #14) e não mexe na ordem de boot.
##
## Precedência de resolução (lazy, 1ª consulta):
##   1. web: `?hd=0|1` na URL — autoridade do boot. O `user://` no web é IndexedDB
##      com sync ASSÍNCRONO: o cfg salvo instantes antes do reload pode não ter
##      persistido; a URL carrega a verdade e re-semeia o cfg (self-healing).
##   2. user://settings.cfg [video] hd — escolha explícita do jogador.
##   3. Default por dispositivo: ATIVO em desktop (nativo/web), qualquer Apple ou
##      dispositivo sem touchscreen (= jogando com teclado); INATIVO no resto.

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "video"
const SETTINGS_KEY := "hd"

## Plataformas onde o HD nasce ligado: desktop (nativo e web) e Apple. iPad
## Safari se mascara de macOS ⇒ cai em web_macos, coberto do mesmo jeito.
const HD_DEFAULT_FEATURES: PackedStringArray = [
	"macos", "ios", "windows", "linuxbsd",
	"web_macos", "web_ios", "web_windows", "web_linuxbsd",
]

static var _hd_cache: int = -1  # -1 = não resolvido; 0/1 = decidido

static func hd_enabled() -> bool:
	if _hd_cache < 0:
		_hd_cache = 1 if _resolve() else 0
	return _hd_cache == 1

## Persiste a escolha e atualiza o cache. No web quem garante o boot seguinte é
## a URL `?hd=` (ver cabeçalho); aqui é o backup persistente.
static func set_hd_enabled(enabled: bool) -> void:
	_hd_cache = 1 if enabled else 0
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, enabled)
	cfg.save(SETTINGS_PATH)

static func _resolve() -> bool:
	var override := _url_override()
	if override >= 0:
		var enabled := override == 1
		set_hd_enabled(enabled)
		return enabled
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.has_section_key(SETTINGS_SECTION, SETTINGS_KEY):
		return bool(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, false))
	return _default_hd()

## Lê `?hd=0|1` da URL (só web). Retorna -1 quando ausente/malformado.
static func _url_override() -> int:
	if not OS.has_feature("web"):
		return -1
	var search: Variant = JavaScriptBridge.eval("location.search", true)
	if not (search is String):
		return -1
	return _parse_hd_param(search as String)

## Núcleo puro do parse (testável sem browser).
static func _parse_hd_param(search: String) -> int:
	for pair in search.trim_prefix("?").split("&"):
		if pair == "hd=1":
			return 1
		if pair == "hd=0":
			return 0
	return -1

static func _default_hd() -> bool:
	var present := PackedStringArray()
	for feature in HD_DEFAULT_FEATURES:
		if OS.has_feature(feature):
			present.append(feature)
	return _default_hd_for(present, DisplayServer.is_touchscreen_available())

## Núcleo puro do default (testável sem OS): qualquer feature de desktop/Apple
## liga; sem touchscreen (teclado) liga; touch genérico (Android) desliga.
static func _default_hd_for(features: PackedStringArray, has_touch: bool) -> bool:
	for feature in features:
		if feature in HD_DEFAULT_FEATURES:
			return true
	return not has_touch

## Seams de teste: só o cache, sem tocar o disco (padrão RemoteConfig).
static func _set_for_test(enabled: bool) -> void:
	_hd_cache = 1 if enabled else 0

static func _reset_for_test() -> void:
	_hd_cache = -1
