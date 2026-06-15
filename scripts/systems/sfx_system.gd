class_name SfxSystem
extends Node

## Reproduz SFX de combate. Cada som toca num AudioStreamPlayer descartável (bus "SFX"),
## permitindo sobreposição (ex: hit + timing_perfect) sem pool dedicado.
##
## Variação anti-repetição: no _ready, descobre variantes por convenção de nome
## (hit.wav -> hit_2.wav, hit_3.wav) via ResourceLoader.exists e faz round-robin entre
## elas a cada play, com leve jitter de pitch/volume. A API play() é a mesma — o
## arena_manager continua chamando _sfx.play(_sfx.hit_sound, vol) sem saber das variantes.

# ─── Outcome (escada de impacto do combate) ────────
## Resultado de uma troca de golpes. O arena_manager só DECLARA o resultado; o
## vocabulário sonoro (quais SFX, em que volume, com ou sem duck) vive aqui, num
## lugar só — assim o "errou" nunca volta a soar como o clique de menu.
enum Outcome { MISS, HIT, CRIT, DODGE, HURT }

# ─── Constants ─────────────────────────────────────
const SFX_BUS: String = "SFX"
const SFX_DIR: String = "res://assets/audio/sfx"
const MAX_VARIANTS: int = 8
const PITCH_JITTER: float = 0.05  # ±5%
const VOLUME_JITTER_DB: float = 1.0  # ±1 dB

# ─── Exports ───────────────────────────────────────
@export var attack_sound: AudioStream
@export var hit_sound: AudioStream
@export var dodge_sound: AudioStream
@export var timing_perfect_sound: AudioStream
@export var timing_alert_sound: AudioStream
@export var death_sound: AudioStream
@export var ui_click_sound: AudioStream

# ─── State ─────────────────────────────────────────
## resource_path do som primário -> Array[AudioStream] de variantes (inclui o primário).
var _variants: Dictionary = {}
## resource_path -> índice atual do round-robin.
var _rr_index: Dictionary = {}
## nome (play_named) -> stream primário resolvido (ou null se o asset não existe).
var _named: Dictionary = {}

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	for sound in [attack_sound, hit_sound, dodge_sound, timing_perfect_sound,
			timing_alert_sound, death_sound, ui_click_sound]:
		_register_variants(sound)

func _register_variants(primary: AudioStream) -> void:
	if primary == null or primary.resource_path.is_empty():
		return
	var key := primary.resource_path
	if _variants.has(key):
		return
	var list: Array[AudioStream] = [primary]
	var base := key.get_basename()  # tira .wav
	var ext := "." + key.get_extension()
	for i in range(2, MAX_VARIANTS + 1):
		var path := "%s_%d%s" % [base, i, ext]
		if ResourceLoader.exists(path):
			list.append(load(path))
		else:
			break
	_variants[key] = list
	_rr_index[key] = 0

# ─── Public API ────────────────────────────────────
## `pitch_bonus` soma ao pitch base (além do jitter anti-repetição). Usado pela escada
## de combo para fazer a camada de recompensa "subir" de tom a cada perfeito.
func play(sound: AudioStream, volume_db: float = 0.0, pitch_bonus: float = 0.0) -> void:
	if sound == null:
		return
	var to_play := _next_variant(sound)
	var player := AudioStreamPlayer.new()
	player.stream = to_play
	player.bus = SFX_BUS
	player.volume_db = volume_db + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	player.pitch_scale = 1.0 + pitch_bonus + randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## Toca um SFX por nome de arquivo (sem export): "hurt_caipora" -> sfx/hurt_caipora.wav.
## Resolve com ResourceLoader.exists e cacheia; asset ausente é no-op silencioso
## (fallback fica no chamador). Devolve true se tocou.
func play_named(sound_name: String, volume_db: float = 0.0) -> bool:
	if not _named.has(sound_name):
		var path := "%s/%s.wav" % [SFX_DIR, sound_name]
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		_named[sound_name] = stream
		_register_variants(stream)
	var primary: AudioStream = _named[sound_name]
	if primary == null:
		return false
	play(primary, volume_db)
	return true

## Toca a resposta sonora completa (SFX + duck) de um resultado de combate. Os sons
## novos (combat_miss/hit_heavy) chegam por play_named — sem @export novo, sem mexer
## nos .tscn de arena. Cada ramo tem fallback ao comportamento anterior, então o
## roteamento funciona mesmo antes dos assets existirem (drop-in depois).
const PERFECT_LAYER_DB: float = -4.0  ## timing_perfect empilhado por cima do impacto
const MISS_FALLBACK_DB: float = -6.0  ## fallback do "errou" enquanto não há combat_miss
## `combo_step` (0..N) faz a camada de recompensa (timing_perfect) SUBIR de tom a cada
## perfeito encadeado — o "ka-ching" que sobe, gatilho clássico de vício. O impacto
## pesado (hit_heavy) mantém o pitch base: o peso é constante, só a recompensa escala.
func play_outcome(outcome: Outcome, combo_step: int = 0) -> void:
	var reward_pitch := combo_step * Constants.COMBO_PITCH_STEP
	match outcome:
		Outcome.MISS:
			# O "furou a janela": som próprio, seco e negativo — NUNCA o clique de menu.
			if not play_named("combat_miss"):
				play(ui_click_sound, MISS_FALLBACK_DB)
		Outcome.HIT:
			play(hit_sound)
		Outcome.CRIT:
			# Crítico = topo da escada: impacto pesado + recompensa + o mundo cala.
			if not play_named("hit_heavy"):
				play(hit_sound)
			play(timing_perfect_sound, PERFECT_LAYER_DB, reward_pitch)
			AudioDirector.duck(AudioDirector.PERFECT_DUCK_DB, AudioDirector.PERFECT_DUCK_SECS)
		Outcome.DODGE:
			play(dodge_sound)
			play(timing_perfect_sound, PERFECT_LAYER_DB, reward_pitch)
			AudioDirector.duck(AudioDirector.PERFECT_DUCK_DB, AudioDirector.PERFECT_DUCK_SECS)
		Outcome.HURT:
			# A guardiã sangra: voz própria; hit_sound é o impacto NO inimigo.
			if not play_named("hurt_caipora"):
				play(hit_sound)

# ─── Private helpers ───────────────────────────────
## Round-robin entre as variantes do som; se não houver registro, devolve o próprio.
func _next_variant(sound: AudioStream) -> AudioStream:
	var key := sound.resource_path
	if not _variants.has(key):
		return sound
	var list: Array = _variants[key]
	if list.size() <= 1:
		return sound
	var idx: int = (_rr_index[key] + 1) % list.size()
	_rr_index[key] = idx
	return list[idx]
