extends Node

## Overrides remotos de aprimoramentos do cachimbo (custo em fragmentos e valor
## do atributo por erva), editados em site/upgrades.html e servidos pela Edge Function.
##
## Camada OPCIONAL na frente de MetaProgression.UPGRADE_DEFS. Se o fetch falhar,
## o jogo usa os valores baked. Offline-first: aplica cache conhecido na hora.
##
## apply_pending() NÃO recarrega a página — RemoteConfig.apply_pending() recarrega
## depois. Um único reload aplica upgrades + patterns + config.

const CACHE_PATH := "user://remote_upgrades.json"

# "forca" -> { "fragment_cost": int, "value": int }
var _overrides: Dictionary = {}
var _applied_version: int = 0
var _pending: Dictionary = {}
var _pending_version: int = 0

var _http: HTTPRequest

func _ready() -> void:
	_load_cache()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	if OS.has_feature("template"):
		_fetch()

func _fetch() -> void:
	var body := JSON.stringify({"action": "get_upgrades"})
	var err := _http.request(
		SupabaseConfig.endpoint(),
		SupabaseConfig.headers(),
		HTTPClient.METHOD_POST,
		body,
	)
	if err != OK:
		push_warning("RemoteUpgrades: fetch não iniciou (err %d); usando cache/defaults." % err)

func _on_request_completed(_result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray) -> void:
	if code != 200:
		return
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary) or not (parsed.get("data") is Dictionary):
		return
	var sanitized := _sanitize(parsed["data"])
	var version := int(parsed.get("version", 0))
	if version > _applied_version and _applied_version > 0:
		_pending = sanitized
		_pending_version = version
		SignalBus.remote_upgrades_update_available.emit(version)
	else:
		_overrides = sanitized
		_applied_version = version
		_save_cache()

## Troca os overrides ativos pelos pendentes. NÃO recarrega a página.
func apply_pending() -> void:
	if _pending.is_empty():
		return
	_overrides = _pending
	_applied_version = _pending_version
	_pending = {}
	_pending_version = 0
	_save_cache()

func has_pending() -> bool:
	return not _pending.is_empty()

# ─── API consumida por MetaProgression ─────────────
func has_override(key: String) -> bool:
	return _overrides.has(key)

func cost_override(key: String) -> int:
	return int(_overrides[key]["fragment_cost"])

func attr_override(key: String) -> int:
	return int(_overrides[key]["value"])

# ─── Seam de teste (sem rede) ──────────────────────
func _set_overrides_for_test(d: Dictionary) -> void:
	_overrides = _sanitize(d)
	_applied_version = 1

# ─── Internos ──────────────────────────────────────
func _sanitize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw:
		var v: Variant = raw[k]
		if not (v is Dictionary):
			continue
		var d: Dictionary = v as Dictionary
		var cost := int(d.get("fragment_cost", 0))
		var value := int(d.get("value", 0))
		if cost < 1 or value < 1:
			continue
		out[String(k)] = {"fragment_cost": cost, "value": value}
	return out

func _save_cache() -> void:
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": _applied_version, "overrides": _overrides}))
	file.flush()
	file.close()

func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.get("overrides") is Dictionary:
		_overrides = _sanitize(parsed["overrides"])
		_applied_version = int(parsed.get("version", 0))
