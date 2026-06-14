extends Node

## Overrides remotos de balanceamento de inimigo (HP/dano por inimigo × fase),
## editados no painel admin e servidos pela Edge Function `caipora-api`.
##
## Camada OPCIONAL na frente de EnemyStats: se o fetch falhar, estiver offline ou
## vier vazio, o jogo usa as constantes baked de EnemyStats (fallback total) — nada
## quebra. Offline-first: aplica o último cache conhecido na hora e tenta atualizar.
##
## Versionamento: na primeira vez aplica em silêncio; se o servidor tem uma version
## mais nova que a já aplicada, segura os valores novos e emite
## SignalBus.remote_config_update_available — o menu mostra o banner "Atualizar".

const CACHE_PATH := "user://remote_config.json"

# "<id>@<fase>" -> { "hp": int, "damage": float }
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
	# Só busca ao vivo em build exportado (web/desktop). No editor e em testes headless
	# (rodados da fonte) NÃO toca a rede — CI fica determinístico e offline.
	if OS.has_feature("template"):
		_fetch()

func _fetch() -> void:
	var body := JSON.stringify({"action": "get_enemy_stats"})
	var err := _http.request(
		SupabaseConfig.endpoint(),
		SupabaseConfig.headers(),
		HTTPClient.METHOD_POST,
		body,
	)
	if err != OK:
		push_warning("RemoteConfig: fetch não iniciou (err %d); usando cache/defaults." % err)

func _on_request_completed(_result: int, code: int, _headers: PackedStringArray, raw: PackedByteArray) -> void:
	if code != 200:
		return  # mantém cache/defaults em silêncio
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary) or not (parsed.get("data") is Dictionary):
		return
	var sanitized := _sanitize(parsed["data"])
	var version := int(parsed.get("version", 0))
	if version > _applied_version and _applied_version > 0:
		# Já havia balanceamento aplicado: segura o novo e avisa o menu.
		_pending = sanitized
		_pending_version = version
		SignalBus.remote_config_update_available.emit(version)
	else:
		_overrides = sanitized
		_applied_version = version
		_save_cache()

## Troca os overrides ativos pelos pendentes (chamado pelo banner do menu). No web
## recarrega a página para garantir consistência total do build cacheado.
func apply_pending() -> void:
	if _pending.is_empty():
		return
	_overrides = _pending
	_applied_version = _pending_version
	_pending = {}
	_pending_version = 0
	_save_cache()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.reload()", true)

func has_pending() -> bool:
	return not _pending.is_empty()

# ─── API consumida por EnemyStats ──────────────────
func has_override(enemy_id: StringName, phase: int) -> bool:
	return _overrides.has("%s@%d" % [enemy_id, phase])

func hp_override(enemy_id: StringName, phase: int) -> int:
	return int(_overrides["%s@%d" % [enemy_id, phase]]["hp"])

func damage_override(enemy_id: StringName, phase: int) -> float:
	return float(_overrides["%s@%d" % [enemy_id, phase]]["damage"])

# ─── Seam de teste (sem rede) ──────────────────────
func _set_overrides_for_test(d: Dictionary) -> void:
	_overrides = _sanitize(d)
	_applied_version = 1

# ─── Internos ──────────────────────────────────────
func _sanitize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in raw:
		var v: Variant = raw[k]
		if v is Dictionary and v.has("hp"):
			out[String(k)] = {
				"hp": int(v["hp"]),
				"damage": float(v.get("damage", 0.0)),
			}
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
