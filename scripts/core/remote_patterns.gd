extends Node

## Overrides remotos de padrões de ataque (timing/sequência por padrão), editados
## em site/sequences.html e servidos pela Edge Function `caipora-api`.
##
## Camada OPCIONAL na frente do .tres baked: se o fetch falhar, estiver offline ou
## vier vazio, ArenaManager usa o AttackPattern original sem alteração.
## Offline-first: aplica o último cache na hora e tenta atualizar.
##
## Versionamento: na primeira vez aplica em silêncio; se o servidor tem version mais
## nova, segura os valores novos e emite SignalBus.remote_patterns_update_available —
## o menu mostra o banner "Atualizar" (junto com RemoteConfig, se houver).
## apply_pending() NÃO recarrega a página — RemoteConfig.apply_pending() faz isso
## logo depois e o único reload aplica ambos os overrides.

const CACHE_PATH := "user://remote_patterns.json"

# "pattern_filename_sem_tres" -> { wind_up_duration, attack_duration, ... }
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
	var body := JSON.stringify({"action": "get_attack_patterns"})
	var err := _http.request(
		SupabaseConfig.endpoint(),
		SupabaseConfig.headers(),
		HTTPClient.METHOD_POST,
		body,
	)
	if err != OK:
		push_warning("RemotePatterns: fetch não iniciou (err %d); usando cache/defaults." % err)

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
		SignalBus.remote_patterns_update_available.emit(version)
	else:
		_overrides = sanitized
		_applied_version = version
		_save_cache()

## Troca os overrides ativos pelos pendentes. NÃO recarrega a página — o banner
## chama RemotePatterns.apply_pending() ANTES de RemoteConfig.apply_pending(),
## que faz o reload único no web. Assim um único reload aplica ambos.
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

# ─── API consumida por ArenaManager ────────────────
func has_override(pattern: AttackPattern) -> bool:
	return _overrides.has(_key(pattern))

## Retorna o padrão com overrides aplicados. Se não houver override, devolve o
## original (sem cópia). Se houver, faz duplicate() para não modificar o .tres
## compartilhado pelo ResourceLoader.
func apply(pattern: AttackPattern) -> AttackPattern:
	var key := _key(pattern)
	if not _overrides.has(key):
		return pattern
	var ov: Dictionary = _overrides[key]
	var p: AttackPattern = pattern.duplicate() as AttackPattern
	# Identidade do golpe (PRD moves nomeados): nome e som são editáveis ao vivo;
	# vfx_id fica baked (não sobreposto remotamente).
	if ov.has("display_name"):
		p.display_name = String(ov["display_name"])
	if ov.has("audio_event"):
		p.audio_event = String(ov["audio_event"])
	if ov.has("wind_up_duration"):
		p.wind_up_duration = float(ov["wind_up_duration"])
	if ov.has("attack_duration"):
		p.attack_duration = float(ov["attack_duration"])
	if ov.has("strike_count"):
		p.strike_count = int(ov["strike_count"])
	if ov.has("strike_delay"):
		p.strike_delay = float(ov["strike_delay"])
	if ov.has("damage_multiplier"):
		p.damage_multiplier = float(ov["damage_multiplier"])
	if ov.has("input_sequence") and ov["input_sequence"] is Array:
		var seq: Array[String] = []
		for s: Variant in (ov["input_sequence"] as Array):
			seq.append(String(s))
		p.input_sequence = seq
	if ov.has("strike_intervals") and ov["strike_intervals"] is Array:
		var intervals: Array[float] = []
		for x: Variant in (ov["strike_intervals"] as Array):
			intervals.append(float(x))
		p.strike_intervals = intervals
	if ov.has("next_turn_delay"):
		p.next_turn_delay = float(ov["next_turn_delay"])
	if ov.has("action_windows") and ov["action_windows"] is Dictionary:
		p.action_windows = (ov["action_windows"] as Dictionary).duplicate(true)
	return p

## Janela de transição GLOBAL (início do combate → primeiro turno), editável em
## site/sequences.html sob a chave reservada "__global__". Sem override → default.
func transition_window(default_value: float) -> float:
	var g: Variant = _overrides.get("__global__", null)
	if g is Dictionary and (g as Dictionary).has("transition_window"):
		var tw := float((g as Dictionary)["transition_window"])
		if tw >= 0.0:
			return tw
	return default_value

# ─── Seam de teste (sem rede) ──────────────────────
func _set_overrides_for_test(d: Dictionary) -> void:
	_overrides = _sanitize(d)
	_applied_version = 1

# ─── Internos ──────────────────────────────────────
func _key(pattern: AttackPattern) -> String:
	return pattern.resource_path.get_file().get_basename()

func _sanitize(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw:
		var v: Variant = raw[k]
		if not (v is Dictionary):
			continue
		var d: Dictionary = v as Dictionary
		# Chave reservada: config global (janela de transição), não é um pattern.
		if String(k) == "__global__":
			var tw := float(d.get("transition_window", -1.0))
			if tw >= 0.0:
				out["__global__"] = {"transition_window": tw}
			continue
		var attack_duration := float(d.get("attack_duration", 0.0))
		var strike_count := int(d.get("strike_count", 0))
		var damage_multiplier := float(d.get("damage_multiplier", 0.0))
		if attack_duration < 0.1 or strike_count < 1 or damage_multiplier <= 0.0:
			continue
		var entry: Dictionary = {
			"wind_up_duration": float(d.get("wind_up_duration", 0.0)),
			"attack_duration": attack_duration,
			"strike_count": strike_count,
			"strike_delay": float(d.get("strike_delay", 0.0)),
			"damage_multiplier": damage_multiplier,
		}
		# Identidade do golpe: strings passam adiante (senão o override as descarta).
		if d.has("display_name"):
			entry["display_name"] = String(d["display_name"])
		if d.has("audio_event"):
			entry["audio_event"] = String(d["audio_event"])
		if d.has("input_sequence") and d["input_sequence"] is Array:
			var seq: Array[String] = []
			for s: Variant in (d["input_sequence"] as Array):
				seq.append(String(s))
			entry["input_sequence"] = seq
		if d.has("strike_intervals") and d["strike_intervals"] is Array:
			var intervals: Array = []
			for x: Variant in (d["strike_intervals"] as Array):
				intervals.append(maxf(0.0, float(x)))
			entry["strike_intervals"] = intervals
		if d.has("next_turn_delay"):
			entry["next_turn_delay"] = maxf(0.0, float(d["next_turn_delay"]))
		if d.has("action_windows") and d["action_windows"] is Dictionary:
			var windows: Dictionary = {}
			for pk: Variant in (d["action_windows"] as Dictionary):
				var w := float((d["action_windows"] as Dictionary)[pk])
				if w >= Constants.TIMING_WINDOW_MIN:
					windows[String(pk)] = w
			if not windows.is_empty():
				entry["action_windows"] = windows
		out[String(k)] = entry
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
