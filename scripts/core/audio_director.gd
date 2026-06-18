extends Node

## Maestro de áudio persistente (autoload). Diferente do SfxSystem/FeedbackSystem
## (que são por-arena), o AudioDirector vive entre telas e cuida de:
##  - volume dos buses (Master/SFX/Music/Ambience) + persistência em user://settings.cfg
##  - ambiência e música (stems de maracatu) com cross-fade por tela
##  - ducking de Music/Ambience em impactos pesados
##  - unlock de autoplay no HTML5 (1º play só após gesto do usuário)
##
## Os assets de ambiência/música chegam nas Fases C/D; aqui o carregamento é graceful
## (ResourceLoader.exists), então os hooks já existem mas ficam dormentes sem os .wav.

# ─── Constants ─────────────────────────────────────
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"

const BUS_MASTER: String = "Master"
const BUS_SFX: String = "SFX"
const BUS_MUSIC: String = "Music"
const BUS_AMBIENCE: String = "Ambience"
const BUS_REVERB: String = "Reverb"
const VOLUME_BUSES: PackedStringArray = [BUS_MASTER, BUS_SFX, BUS_MUSIC, BUS_AMBIENCE]

## Perfis do espaço acústico (bus Reverb, dry fixo em 1.0 — só o wet/sala variam).
## A folhagem da mata absorve (quase seco); a igreja de pedra responde; a clareira
## da arena fica no meio. Aplicado por tela em _apply_screen_audio.
const SPACE_PROFILES: Dictionary = {
	&"mata": {"room_size": 0.25, "wet": 0.05, "damping": 0.75, "predelay_msec": 10.0},
	&"igreja": {"room_size": 0.90, "wet": 0.35, "damping": 0.20, "predelay_msec": 40.0},
	&"arena": {"room_size": 0.55, "wet": 0.15, "damping": 0.50, "predelay_msec": 15.0},
}

## Trim global aplicado sobre o Master, por cima do volume do usuário. -6 dB ≈ metade
## da amplitude linear (jogo 50% mais baixo) sem mexer no slider nem na persistência.
const MASTER_TRIM_DB: float = -6.0

const AMBIENCE_FADE: float = 1.2
## Silêncio dramático (S7): a mata cala RÁPIDO antes da revelação/morte, segura um
## vazio curto, e o stinger nasce dele. O retorno usa o AMBIENCE_FADE normal.
const AMBIENCE_FAST_FADE: float = 0.25
const SILENCE_BEFORE_STING: float = 0.35
const GAME_OVER_SILENCE: float = 0.5
## Eventos raros da mata: a floresta se mexe a cada 8-20 s, só na exploração.
const MATA_EVENT_MIN_SECS: float = 8.0
const MATA_EVENT_MAX_SECS: float = 20.0
const MATA_EVENT_VOLUME_DB: float = -10.0
const DUCK_AMOUNT_DB: float = -8.0
const DUCK_TIME: float = 0.35
## Duck mais fundo no timing perfeito: o mundo cala para o crítico soar enorme.
const PERFECT_DUCK_DB: float = -14.0
const PERFECT_DUCK_SECS: float = 0.35

const MUSIC_FADE: float = 0.9
const STEM_BASE: String = "base"
const STEM_MID: String = "mid"
const STEM_TOP: String = "top"
const STEM_LAYERS: PackedStringArray = [STEM_BASE, STEM_MID, STEM_TOP]
const STEM_SILENCE_DB: float = -40.0
const CRITICAL_HP_RATIO: float = 0.30
const HEARTBEAT_VOLUME_DB: float = -6.0
const HEART_STEM_BASE_DB: float = -8.0

# Caminhos das ambiências (carregadas só se existirem — graceful). Uma por clima de fase.
const AMB_FOREST: String = "res://assets/audio/ambience/amb_forest.wav"
const AMB_DREAD: String = "res://assets/audio/ambience/amb_dread.wav"
const AMB_FIRE: String = "res://assets/audio/ambience/amb_fire.wav"
const AMB_FOG: String = "res://assets/audio/ambience/amb_fog.wav"
const AMB_CHURCH: String = "res://assets/audio/ambience/amb_church.wav"
const AMB_HEARTBEAT: String = "res://assets/audio/ambience/heartbeat.wav"

# Música por contexto: um loop híbrido (maracatu + chiptune) por tela/fase/boss.
const MUSIC_DIR: String = "res://assets/audio/music/"

# SFX one-shot tocados pelo diretor (persistente): sons que atravessam a morte da
# cena (bolsa de fragmentos) e micro-feedback de UI compartilhado entre telas.
const SFX_DIR: String = "res://assets/audio/sfx/"
const UI_HOVER_VOLUME_DB: float = -14.0
## Foco+mouse disparam juntos no mesmo controle; o cooldown colapsa o par num som só.
const UI_HOVER_COOLDOWN_MSEC: int = 80
## Tick do D-pad de combate: presença tátil baixa, nunca compete com os SFX de
## timing da arena. Variantes em round-robin + jitter de pitch (anti-metralhadora).
const DPAD_TAP_VOLUME_DB: float = -12.0
const DPAD_TAP_COOLDOWN_MSEC: int = 30
const DPAD_TAP_VARIANTS: int = 3
const DPAD_TAP_PITCH_JITTER: float = 0.05

# Stingers de estado (one-shot).
const STING_DIR: String = "res://assets/audio/stingers/"
const STING_ARENA: String = "sting_arena_enter"
const STING_VICTORY: String = "sting_victory"
const STING_GAME_OVER: String = "sting_game_over"
const STING_BOSS_INTRO: String = "sting_boss_intro"
const STING_CHAMA: String = "sting_chama"
# Fase 5 (A Igreja): sino de torre na revelação do Jesuíta, sibilo de água benta
# no telegraph do especial dele, estertor de órgão na vitória (tela ENDING).
const STING_SINO_IGREJA: String = "sting_sino_igreja"
const STING_AGUA_BENTA: String = "sting_agua_benta"
const STING_ORGAO_ESTERTOR: String = "sting_orgao_estertor"
# Bolsa de fragmentos (corpse run): vivem em stingers/ (alvo de loudness emocional),
# mas tocam em player transiente — o _stinger_player é reutilizado pelo GAME_OVER
# logo depois da queda e cortaria o som da perda.
const STING_BAG_DROP: String = "fragment_bag_drop"
const STING_BAG_RECOVER: String = "fragment_bag_recover"
const FINAL_PHASE: int = 5

# ─── Beat-sync experimental (S9) ───────────────────
## KILL SWITCH: telegraphs de inimigo comum alinhados ao pulso. DESLIGADO por
## padrão — ligar só em playtest; se o feel piorar, fica desligado e o experimento
## se encerra documentado. Janela de timing NÃO muda; bosses ficam fora.
const BEAT_SYNC_ENABLED: bool = false
## BPM por faixa de arena (fonte: gen_sfx._arena_layers(bpm, ...)).
const TRACK_BPM: Dictionary = {
	"mus_arena_p1": 100.0,
	"mus_arena_p2": 106.0,
	"mus_arena_p3": 104.0,
	"mus_arena_p4": 112.0,
	"mus_arena_p5": 120.0,
}

# ─── State ─────────────────────────────────────────
## Volume linear (0..1) alvo por bus — fonte da verdade que o ducking respeita.
var _bus_volume: Dictionary = {
	BUS_MASTER: 1.0, BUS_SFX: 1.0, BUS_MUSIC: 0.8, BUS_AMBIENCE: 0.8
}
var _audio_unlocked: bool = false
var _music_enabled: bool = true
var _ambience_player: AudioStreamPlayer
var _heartbeat_player: AudioStreamPlayer
var _current_ambience: String = ""
var _duck_tween: Tween
## Par de players para crossfade de música (bus Music). _music_active é o que toca agora.
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer = null
var _current_music: String = ""
var _music_stem_base: AudioStreamPlayer
var _music_stem_mid: AudioStreamPlayer
var _music_stem_top: AudioStreamPlayer
var _stems_active: bool = false
var _music_intensity: int = 0
var _heart_mode: bool = false
var _stinger_player: AudioStreamPlayer
var _last_hover_msec: int = -UI_HOVER_COOLDOWN_MSEC
var _last_dpad_tap_msec: int = -DPAD_TAP_COOLDOWN_MSEC
var _dpad_tap_variant: int = 0
## Cortejo dos Encantados: loop de carga (pitch sobe com o progresso) + flag que
## acende o STEM_TOP da música durante a corrente. Dormentes até os .wav existirem.
var _cortejo_charge_player: AudioStreamPlayer
var _cortejo_active: bool = false
## Scheduler dos eventos raros da mata. Filho do autoload; morto em toda troca de
## tela por _apply_screen_audio — nenhum timer sobrevive fora da exploração.
var _mata_timer: Timer
## Tween do silêncio dramático (boss intro / game over). Membro de propósito:
## troca de tela mata o tween — sem callback órfão tocando stinger atrasado.
var _silence_tween: Tween

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # áudio segue durante pause/hit-stop

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_AMBIENCE
	add_child(_ambience_player)

	_heartbeat_player = AudioStreamPlayer.new()
	_heartbeat_player.bus = BUS_AMBIENCE
	_heartbeat_player.volume_db = STEM_SILENCE_DB
	add_child(_heartbeat_player)

	_music_a = AudioStreamPlayer.new()
	_music_a.bus = BUS_MUSIC
	_music_a.volume_db = -40.0
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = BUS_MUSIC
	_music_b.volume_db = -40.0
	add_child(_music_b)

	_music_stem_base = _new_music_player()
	_music_stem_mid = _new_music_player()
	_music_stem_top = _new_music_player()

	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.bus = BUS_MUSIC
	add_child(_stinger_player)

	_cortejo_charge_player = AudioStreamPlayer.new()
	_cortejo_charge_player.bus = BUS_SFX
	add_child(_cortejo_charge_player)

	_mata_timer = Timer.new()
	_mata_timer.one_shot = true
	_mata_timer.timeout.connect(_on_mata_event_timeout)
	add_child(_mata_timer)

	_load_settings()
	_apply_all_volumes()

	SignalBus.screen_changed.connect(_on_screen_changed)
	SignalBus.boss_intro_started.connect(_on_boss_intro)
	SignalBus.chama_gained.connect(_on_chama)
	SignalBus.boss_special_telegraph.connect(_on_boss_special_telegraph)
	SignalBus.caipora_health_changed.connect(_on_caipora_health_changed)
	SignalBus.fragment_bag_dropped.connect(_on_fragment_bag_dropped)
	SignalBus.fragment_bag_recovered.connect(_on_fragment_bag_recovered)
	SignalBus.boss_died.connect(_on_boss_died)

# ─── Public API: volume ────────────────────────────
## Define o volume linear (0..1) de um bus, aplica e persiste.
func set_bus_volume(bus_name: String, linear: float) -> void:
	if not _bus_volume.has(bus_name):
		return
	_bus_volume[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus_name)
	_save_settings()

func get_bus_volume(bus_name: String) -> float:
	return _bus_volume.get(bus_name, 1.0)

# ─── Public API: music toggle ─────────────────────
func toggle_music_ambience() -> void:
	_music_enabled = not _music_enabled
	_apply_volume(BUS_MUSIC)
	_apply_volume(BUS_AMBIENCE)
	_save_settings()

func is_music_enabled() -> bool:
	return _music_enabled

## Ajusta a intensidade dos stems verticais: 0=base, 1=base+mid, 2=base+mid+top.
## Single-loops ignoram a intensidade, mas o valor fica guardado para a proxima arena.
func set_music_intensity(level: int) -> void:
	_music_intensity = clampi(level, 0, 2)
	if _stems_active:
		_apply_stem_intensity(MUSIC_FADE)

# ─── Public API: ducking ───────────────────────────
## Abaixa Music+Ambience por um instante (impactos/hit-stop) e recupera com tween.
func duck(amount_db: float = DUCK_AMOUNT_DB, secs: float = DUCK_TIME) -> void:
	if _duck_tween != null and _duck_tween.is_running():
		_duck_tween.kill()
	# Tween não tem property-path no AudioServer, então animamos um fator 0..1 por método:
	# desce rápido, segura, volta ao alvo do usuário.
	_duck_tween = create_tween()
	_duck_tween.tween_method(_duck_apply.bind(amount_db), 0.0, 1.0, secs * 0.25)
	_duck_tween.tween_interval(secs * 0.4)
	_duck_tween.tween_method(_duck_apply.bind(amount_db), 1.0, 0.0, secs * 0.35)

func _duck_apply(t: float, amount_db: float) -> void:
	for bus_name in [BUS_MUSIC, BUS_AMBIENCE]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		if not _music_enabled:
			continue  # já silenciado pelo toggle; não restaurar
		AudioServer.set_bus_volume_db(idx, _linear_to_db(_bus_volume[bus_name]) + amount_db * t)

# ─── Public API: autoplay unlock ───────────────────
## Chamar no 1º gesto do usuário (clique "Iniciar"). Libera o áudio no browser e
## inicia a ambiência da tela atual.
func unlock_audio() -> void:
	if _audio_unlocked:
		return
	_audio_unlocked = true
	_apply_screen_audio(GameState.current_screen)
	_sync_heart_mode_audio()

# ─── Reação às telas ───────────────────────────────
func _on_screen_changed(new_screen: int) -> void:
	if _audio_unlocked:
		_apply_screen_audio(new_screen)

## Casa ambiência, música e stinger ao estado da tela.
func _apply_screen_audio(screen: int) -> void:
	# Toda transição passa por aqui: mata o silêncio pendente (sem stinger órfão)
	# e rearma/para o scheduler da mata — nenhum timer vaza da exploração.
	_kill_silence_tween()
	_update_mata_scheduler(screen)
	_apply_space_profile(screen)
	_refresh_ambience(screen)
	_play_music(_music_for_screen(screen))
	match screen:
		SignalBus.Screen.ARENA, SignalBus.Screen.ARENA_PHASE2, \
		SignalBus.Screen.ARENA_PHASE3, SignalBus.Screen.ARENA_PHASE4, \
		SignalBus.Screen.ARENA_PHASE5:
			set_music_intensity(2 if GameState.active_combat_is_boss else 1)
			_play_stinger(STING_ARENA)
		SignalBus.Screen.WIN:
			set_music_intensity(0)
			_play_stinger(STING_VICTORY)
		SignalBus.Screen.FINAL_CHOICE:
			set_music_intensity(0)
			# O Jesuíta acaba de cair no altar: o órgão dele estertora SOB a
			# pergunta final ("Poupar ele?"). Música em silêncio — só a igreja.
			_play_stinger(STING_ORGAO_ESTERTOR)
		SignalBus.Screen.ENDING_SACRIFICE:
			set_music_intensity(0)
			# Poupado, o Jesuíta venceu: o sino da igreja dobra por uma floresta
			# que não respira mais. Sem música — o mundo convertido é mudo.
			_play_stinger(STING_SINO_IGREJA)
		SignalBus.Screen.GAME_OVER:
			set_music_intensity(0)
			# A morte esvazia o mundo (S7): música já cai via _play_music(""),
			# a ambiência cala rápido, e o stinger nasce do vazio.
			_fade_player(_ambience_player, STEM_SILENCE_DB, true, AMBIENCE_FAST_FADE)
			_silence_tween = create_tween()
			_silence_tween.tween_interval(GAME_OVER_SILENCE)
			_silence_tween.tween_callback(_play_stinger.bind(STING_GAME_OVER))
		_:
			set_music_intensity(0)


## A revelação do boss (overlay durante a exploração) já dispara o tema do boss, que
## atravessa para a arena sem corte (o _play_music no-opa quando a faixa é a mesma).
## S7: a mata cala primeiro — fade rápido da ambiência, um vazio curto, e o stinger
## nasce dele. A ambiência volta por baixo do tema no fade normal (contínua na
## Fase 5, onde a arena é a MESMA igreja e _play_ambience no-oparia).
func _on_boss_intro() -> void:
	if not _audio_unlocked:
		return
	# Fase FINAL: a revelação do Jesuíta toca o sino da torre, não o stinger genérico.
	var sting := STING_SINO_IGREJA if GameState.active_phase == FINAL_PHASE else STING_BOSS_INTRO
	_fade_player(_ambience_player, STEM_SILENCE_DB, false, AMBIENCE_FAST_FADE)
	_kill_silence_tween()
	_silence_tween = create_tween()
	_silence_tween.tween_interval(SILENCE_BEFORE_STING)
	_silence_tween.tween_callback(func() -> void:
		_play_stinger(sting)
		_play_music(_mus(_boss_track(GameState.active_phase)))
		set_music_intensity(2)
		if _ambience_player.playing:
			_fade_player(_ambience_player, 0.0, false))

# ─── Beat-sync experimental (S9) ───────────────────
## Segundos até o próximo beat da faixa atual. 0.0 = sem espera (flag desligada,
## nada tocando ou faixa fora do mapa) — o chamador segue imediatamente.
func time_to_next_beat() -> float:
	if not BEAT_SYNC_ENABLED or _music_active == null or not _music_active.playing:
		return 0.0
	var bpm := _bpm_for_track(_current_music)
	if bpm <= 0.0:
		return 0.0
	var beat := 60.0 / bpm
	return beat - fmod(_music_active.get_playback_position(), beat)

func _bpm_for_track(path: String) -> float:
	for track_name: String in TRACK_BPM:
		if path.contains(track_name):
			return TRACK_BPM[track_name]
	return 0.0

func _kill_silence_tween() -> void:
	if _silence_tween != null and _silence_tween.is_valid():
		_silence_tween.kill()

# ─── A mata respira (S7) ───────────────────────────
## Liga o scheduler só nas telas de exploração; qualquer outra tela o para.
func _update_mata_scheduler(screen: int) -> void:
	match screen:
		SignalBus.Screen.EXPLORATION, SignalBus.Screen.EXPLORATION_PHASE2, \
		SignalBus.Screen.EXPLORATION_PHASE3, SignalBus.Screen.EXPLORATION_PHASE4, \
		SignalBus.Screen.EXPLORATION_PHASE5:
			_mata_timer.start(randf_range(MATA_EVENT_MIN_SECS, MATA_EVENT_MAX_SECS))
		_:
			_mata_timer.stop()

## Evento raro: variante por convenção (_2/_3), volume baixo, bus Ambience.
## Rearma mesmo sem asset (graceful — o catálogo pode chegar depois).
func _on_mata_event_timeout() -> void:
	var options: Array[String] = []
	for suffix: String in ["", "_2", "_3"]:
		var path := SFX_DIR + "mata_event%s.wav" % suffix
		if ResourceLoader.exists(path):
			options.append(path)
	if not options.is_empty():
		_play_oneshot_sfx(options.pick_random(), MATA_EVENT_VOLUME_DB, BUS_AMBIENCE)
	_mata_timer.start(randf_range(MATA_EVENT_MIN_SECS, MATA_EVENT_MAX_SECS))

func _on_chama() -> void:
	if _audio_unlocked:
		_play_stinger(STING_CHAMA)

## Cicatriz sonora do chefe: stinger próprio acima da música, com duck no mix.
## O som seco de morte comum (death_sound, no SfxSystem da arena) segue tocando —
## se o asset boss_death_* faltar, ele É o fallback (_play_stinger no-opa).
func _on_boss_died(phase: int) -> void:
	if not _audio_unlocked:
		return
	duck()
	_play_stinger("boss_death_" + _boss_name(phase))

## Cue de leitura do especial do Jesuíta: sibilo de água benta no wind-up.
func _on_boss_special_telegraph(boss_type: String) -> void:
	if _audio_unlocked and boss_type == "jesuita":
		_play_stinger(STING_AGUA_BENTA)

## Cicatriz sonora em paz (Santuário dos Encantados): a MESMA assinatura musical da
## morte do chefe, mais baixa — memória, não ameaça. Toca no rito de chegada do
## espírito ao acampamento.
const SPIRIT_RITE_VOLUME_DB: float = -8.0

func play_spirit_rite(phase: int) -> void:
	if not _audio_unlocked:
		return
	_play_stinger("boss_death_" + _boss_name(phase), SPIRIT_RITE_VOLUME_DB)

# ─── Bolsa de fragmentos (corpse run) ──────────────
func _on_fragment_bag_dropped(_amount: float) -> void:
	if _audio_unlocked:
		_play_oneshot_sfx(STING_DIR + STING_BAG_DROP + ".wav")

func _on_fragment_bag_recovered(_amount: float) -> void:
	if _audio_unlocked:
		_play_oneshot_sfx(STING_DIR + STING_BAG_RECOVER + ".wav")

# ─── Micro-feedback de UI (hover/foco) ─────────────
## Tick de hover compartilhado entre menus. Cooldown central: focus_entered e
## mouse_entered do mesmo controle (e travessias de slider) não viram spam.
func play_ui_hover() -> void:
	if not _audio_unlocked:
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < UI_HOVER_COOLDOWN_MSEC:
		return
	_last_hover_msec = now
	_play_oneshot_sfx(SFX_DIR + "ui_hover.wav", UI_HOVER_VOLUME_DB)

## Tick percussivo do toque nas setas do D-pad de combate (ControlsHud). Vive aqui
## (e não no SfxSystem da arena) porque o HUD de controles é persistente entre telas.
func play_dpad_tap() -> void:
	if not _audio_unlocked:
		return
	var now := Time.get_ticks_msec()
	if now - _last_dpad_tap_msec < DPAD_TAP_COOLDOWN_MSEC:
		return
	_last_dpad_tap_msec = now
	_dpad_tap_variant = (_dpad_tap_variant + 1) % DPAD_TAP_VARIANTS
	var suffix := "" if _dpad_tap_variant == 0 else "_%d" % (_dpad_tap_variant + 1)
	var path := SFX_DIR + "dpad_tap" + suffix + ".wav"
	if not ResourceLoader.exists(path):
		path = SFX_DIR + "dpad_tap.wav"
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = BUS_SFX
	player.volume_db = DPAD_TAP_VOLUME_DB
	player.pitch_scale = 1.0 + randf_range(-DPAD_TAP_PITCH_JITTER, DPAD_TAP_PITCH_JITTER)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

## Beat percussivo por sílaba no loader de combate (Pe → Pele → Pelejar).
## Pitch escala 0.8 → 1.0 → 1.3 para tensão crescente. Reutiliza dpad_tap.wav.
func play_syllable_beat(index: int) -> void:
	if not _audio_unlocked:
		return
	const PITCHES: Array[float] = [0.8, 1.0, 1.3]
	var pitch := PITCHES[clampi(index, 0, PITCHES.size() - 1)]
	var path := SFX_DIR + "dpad_tap.wav"
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = BUS_SFX
	player.volume_db = 3.0
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## Fanfarra de vitória de combate: toca sting_victory com duck no mix.
## Chamada da arena em _run_victory_outro — não aguarda WIN screen.
func play_combat_victory() -> void:
	if not _audio_unlocked:
		return
	duck()
	_play_stinger(STING_VICTORY)


# ─── Cortejo dos Encantados ────────────────────────
## Direção de áudio do conceito §7: charge loop que sobe de pitch, trinco no armado,
## stinger por espírito (assinatura sônica do chefe), perdido morto, acento de
## maracatu no full-chain, STEM_TOP aceso na corrente + ducking. Tudo DORMENTE até os
## .wav dedicados existirem, com fallback aos sons canônicos para não ficar mudo hoje.

## Loop de carga do elo (sopro grave). Dormente até cortejo_charge.wav.
func play_cortejo_charge() -> void:
	if not _audio_unlocked:
		return
	var path := SFX_DIR + "cortejo_charge.wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	_force_loop(stream)
	_cortejo_charge_player.stream = stream
	_cortejo_charge_player.pitch_scale = 0.85
	_cortejo_charge_player.volume_db = -4.0
	_cortejo_charge_player.play()

## Pitch do loop sobe com o progresso (0..1). No-op se não estiver tocando.
func set_cortejo_charge_progress(progress: float) -> void:
	if _cortejo_charge_player != null and _cortejo_charge_player.playing:
		_cortejo_charge_player.pitch_scale = 0.85 + clampf(progress, 0.0, 1.0) * 0.6

func stop_cortejo_charge() -> void:
	if _cortejo_charge_player != null and _cortejo_charge_player.playing:
		_cortejo_charge_player.stop()

## Trinco curto no topo do anel (armado). Reusa o tap do D-pad até cortejo_armed.wav.
func play_cortejo_armed() -> void:
	if not _audio_unlocked:
		return
	var path := SFX_DIR + "cortejo_armed.wav"
	if ResourceLoader.exists(path):
		_play_oneshot_sfx(path, -2.0)
	else:
		play_dpad_tap()

## Resultado do elo: landado toca o stinger do espírito; perdido dissolve sem brilho.
## Fallback do landado = morte canônica do chefe (mais baixa) — mesma identidade sônica.
func play_cortejo_link(phase: int, landed: bool) -> void:
	if not _audio_unlocked:
		return
	if landed:
		duck(PERFECT_DUCK_DB, PERFECT_DUCK_SECS)
		var spirit := "cortejo_" + _boss_name(phase)
		if ResourceLoader.exists(STING_DIR + spirit + ".wav"):
			_play_stinger(spirit)
		else:
			_play_stinger("boss_death_" + _boss_name(phase), -6.0)
	else:
		var miss := SFX_DIR + "cortejo_miss.wav"
		_play_oneshot_sfx(miss if ResourceLoader.exists(miss) else SFX_DIR + "combat_miss.wav", -4.0)

## Acento de maracatu quando a corrente fecha com TODOS os elos acertados.
func play_cortejo_full_chain() -> void:
	if not _audio_unlocked:
		return
	var accent := "cortejo_full"
	_play_stinger(accent if ResourceLoader.exists(STING_DIR + accent + ".wav") else STING_CHAMA)

## Acende o STEM_TOP do combate durante a corrente; fade de volta ao fim.
func set_cortejo_active(active: bool) -> void:
	if _cortejo_active == active:
		return
	_cortejo_active = active
	if _stems_active:
		_apply_stem_intensity(MUSIC_FADE)


## Player transiente (default bus SFX — audível mesmo com música desligada;
## eventos da mata usam o bus Ambience). Asset ausente é no-op (graceful).
func _play_oneshot_sfx(path: String, volume_db: float = 0.0, bus: String = BUS_SFX) -> void:
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = bus
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func _on_caipora_health_changed(new_health: float, max_health: float) -> void:
	if max_health <= 0.0:
		_set_heart_mode(false)
		return
	_set_heart_mode(new_health > 0.0 and (new_health / max_health) < CRITICAL_HP_RATIO)

func _set_heart_mode(enabled: bool) -> void:
	if _heart_mode == enabled:
		return
	_heart_mode = enabled
	if _stems_active:
		_apply_stem_intensity(MUSIC_FADE)
	_sync_heart_mode_audio()

func _sync_heart_mode_audio() -> void:
	if _heart_mode and _audio_unlocked and ResourceLoader.exists(AMB_HEARTBEAT):
		if not _heartbeat_player.playing:
			var stream: AudioStream = load(AMB_HEARTBEAT)
			_force_loop(stream)
			_heartbeat_player.stream = stream
			_heartbeat_player.volume_db = STEM_SILENCE_DB
			_heartbeat_player.play()
		_fade_player(_heartbeat_player, HEARTBEAT_VOLUME_DB, false, MUSIC_FADE)
	elif _heartbeat_player.playing:
		_fade_player(_heartbeat_player, STEM_SILENCE_DB, true, MUSIC_FADE)

# ─── Espaço acústico (bus Reverb) ──────────────────
## Resolve o perfil de espaço da tela. Fase 5 inteira (explore+arena) é a igreja
## de pedra; as demais arenas são a clareira; todo o resto é mata fechada.
func _space_for_screen(screen: int) -> StringName:
	match screen:
		SignalBus.Screen.EXPLORATION_PHASE5, SignalBus.Screen.ARENA_PHASE5, \
		SignalBus.Screen.FINAL_CHOICE:
			return &"igreja"
		SignalBus.Screen.ARENA, SignalBus.Screen.ARENA_PHASE2, \
		SignalBus.Screen.ARENA_PHASE3, SignalBus.Screen.ARENA_PHASE4:
			return &"arena"
		_:
			return &"mata"

func _apply_space_profile(screen: int) -> void:
	var idx := AudioServer.get_bus_index(BUS_REVERB)
	if idx < 0:
		return
	var fx := AudioServer.get_bus_effect(idx, 0) as AudioEffectReverb
	if fx == null:
		return
	var profile: Dictionary = SPACE_PROFILES[_space_for_screen(screen)]
	fx.room_size = profile["room_size"]
	fx.wet = profile["wet"]
	fx.damping = profile["damping"]
	fx.predelay_msec = profile["predelay_msec"]

# ─── Ambiência ─────────────────────────────────────
func _refresh_ambience(screen: int) -> void:
	var path := ""
	match screen:
		SignalBus.Screen.EXPLORATION, SignalBus.Screen.HUB:
			path = AMB_FOREST  # mata noturna
		SignalBus.Screen.EXPLORATION_PHASE2:
			path = AMB_FIRE    # floresta em chamas
		SignalBus.Screen.EXPLORATION_PHASE3:
			path = AMB_FOG     # névoa
		SignalBus.Screen.EXPLORATION_PHASE4:
			path = AMB_DREAD   # ruína fria
		# A arena da Fase 5 é o altar DENTRO da mesma igreja: a cama sonora não
		# troca na porta (mesma continuidade espacial do boss-intro→arena). A
		# escolha final acontece no MESMO altar, sobre o corpo do Jesuíta.
		SignalBus.Screen.EXPLORATION_PHASE5, SignalBus.Screen.ARENA_PHASE5, \
		SignalBus.Screen.FINAL_CHOICE:
			path = AMB_CHURCH  # igreja fria e úmida
		SignalBus.Screen.ARENA, SignalBus.Screen.ARENA_PHASE2, \
		SignalBus.Screen.ARENA_PHASE3, SignalBus.Screen.ARENA_PHASE4:
			path = AMB_DREAD
		_:
			path = ""
	_play_ambience(path)

func _play_ambience(path: String) -> void:
	if path == _current_ambience:
		return
	_current_ambience = path
	if path == "" or not ResourceLoader.exists(path):
		# Sem asset (ainda) ou tela sem ambiência: fade-out e para.
		if _ambience_player.playing:
			_fade_player(_ambience_player, -40.0, true)
		return
	var stream: AudioStream = load(path)
	_force_loop(stream)
	_ambience_player.stream = stream
	_ambience_player.volume_db = -40.0
	_ambience_player.play()
	# Player em 0 dB (cheio); o volume do usuário vive no bus Ambience.
	_fade_player(_ambience_player, 0.0, false)

# ─── Música por contexto ───────────────────────────
## Resolve a faixa (caminho .wav) da tela/fase atual. "" = sem música (WIN/GAME_OVER).
func _music_for_screen(screen: int) -> String:
	match screen:
		SignalBus.Screen.MAIN_MENU:
			return _mus("mus_menu")
		SignalBus.Screen.HUB:
			return _mus("mus_hub")
		SignalBus.Screen.ENDING:
			return _mus("mus_ending")
		SignalBus.Screen.EXPLORATION, SignalBus.Screen.EXPLORATION_PHASE2, \
		SignalBus.Screen.EXPLORATION_PHASE3, SignalBus.Screen.EXPLORATION_PHASE4, \
		SignalBus.Screen.EXPLORATION_PHASE5:
			return _mus("mus_explore_p%d" % _phase_from_screen(screen))
		SignalBus.Screen.ARENA, SignalBus.Screen.ARENA_PHASE2, \
		SignalBus.Screen.ARENA_PHASE3, SignalBus.Screen.ARENA_PHASE4, \
		SignalBus.Screen.ARENA_PHASE5:
			var phase := _phase_from_screen(screen)
			if GameState.active_combat_is_boss:
				return _mus(_boss_track(phase))
			return _mus("mus_arena_p%d" % phase)
		_:
			return ""

## Caminho completo da faixa de música por nome.
func _mus(track: String) -> String:
	return MUSIC_DIR + track + ".wav"

## Nome do tema do boss por fase (1=Mula, 2=Boitatá, 3=Curupira, 4=Saci).
func _boss_track(phase: int) -> String:
	return "mus_boss_" + _boss_name(phase)

## Nome canônico do chefe pela fase — fonte única para tema (mus_boss_*) e
## cicatriz de morte (boss_death_*).
func _boss_name(phase: int) -> String:
	match phase:
		2: return "boitata"
		3: return "curupira"
		4: return "saci"
		5: return "jesuita"
		_: return "mula"

## Fase 1..4 a partir do enum da tela (explore/arena codificam a fase no nome).
func _phase_from_screen(screen: int) -> int:
	match screen:
		SignalBus.Screen.EXPLORATION_PHASE2, SignalBus.Screen.ARENA_PHASE2:
			return 2
		SignalBus.Screen.EXPLORATION_PHASE3, SignalBus.Screen.ARENA_PHASE3:
			return 3
		SignalBus.Screen.EXPLORATION_PHASE4, SignalBus.Screen.ARENA_PHASE4:
			return 4
		SignalBus.Screen.EXPLORATION_PHASE5, SignalBus.Screen.ARENA_PHASE5:
			return 5
		_:
			return 1

## Crossfade para uma nova faixa. No-op se já tocando a mesma (transição sem corte
## boss-intro→arena). path "" ou ausente: faz fade-out e para.
func _play_music(path: String) -> void:
	if path == _current_music:
		return
	_current_music = path
	var outgoing := _music_active
	if _has_stems(path):
		_play_stems(path)
		if outgoing != null and outgoing != _music_stem_base and outgoing.playing:
			_fade_player(outgoing, STEM_SILENCE_DB, true, MUSIC_FADE)
		return
	_stop_stems(MUSIC_FADE)
	var stream_path := _music_stream_path(path)
	if stream_path == "":
		if outgoing != null and outgoing.playing:
			_fade_player(outgoing, STEM_SILENCE_DB, true, MUSIC_FADE)
		_music_active = null
		return
	var incoming: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var s := _load_music_stream(stream_path)
	if s == null:
		if outgoing != null and outgoing.playing:
			_fade_player(outgoing, STEM_SILENCE_DB, true, MUSIC_FADE)
		_music_active = null
		return
	_force_loop(s)
	incoming.stop()
	incoming.stream = s
	incoming.volume_db = STEM_SILENCE_DB
	incoming.play()
	_fade_player(incoming, 0.0, false, MUSIC_FADE)
	if outgoing != null and outgoing.playing:
		_fade_player(outgoing, STEM_SILENCE_DB, true, MUSIC_FADE)
	_music_active = incoming

func _music_stream_path(path: String) -> String:
	if path == "":
		return ""
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		return path
	var base_stem_path := "%s_base.%s" % [path.get_basename(), path.get_extension()]
	if ResourceLoader.exists(base_stem_path) or FileAccess.file_exists(base_stem_path):
		return base_stem_path
	return ""

func _load_music_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	if path.get_extension().to_lower() == "wav" and FileAccess.file_exists(path):
		return AudioStreamWAV.load_from_file(path)
	return null

func _new_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS_MUSIC
	player.volume_db = STEM_SILENCE_DB
	add_child(player)
	return player

func _stem_path(path: String, layer: String) -> String:
	if path == "":
		return ""
	return "%s_%s.%s" % [path.get_basename(), layer, path.get_extension()]

func _has_stems(path: String) -> bool:
	if path == "":
		return false
	for layer in STEM_LAYERS:
		var stem := _stem_path(path, layer)
		if not (ResourceLoader.exists(stem) or FileAccess.file_exists(stem)):
			return false
	return true

func _stem_player(layer: String) -> AudioStreamPlayer:
	match layer:
		STEM_MID:
			return _music_stem_mid
		STEM_TOP:
			return _music_stem_top
		_:
			return _music_stem_base

func _play_stems(path: String) -> void:
	if _music_a.playing:
		_fade_player(_music_a, STEM_SILENCE_DB, true, MUSIC_FADE)
	if _music_b.playing:
		_fade_player(_music_b, STEM_SILENCE_DB, true, MUSIC_FADE)
	for layer in STEM_LAYERS:
		var player := _stem_player(layer)
		var stream := _load_music_stream(_stem_path(path, layer))
		if stream == null:
			_stop_stems(0.0)
			return
		_force_loop(stream)
		player.stop()
		player.stream = stream
		player.volume_db = STEM_SILENCE_DB
	_stems_active = true
	_music_active = _music_stem_base
	for layer in STEM_LAYERS:
		_stem_player(layer).play()
	_apply_stem_intensity(MUSIC_FADE)

func _stop_stems(fade: float) -> void:
	if not _stems_active:
		return
	for layer in STEM_LAYERS:
		var player := _stem_player(layer)
		if player.playing:
			_fade_player(player, STEM_SILENCE_DB, true, fade)
	_stems_active = false
	if _music_active == _music_stem_base:
		_music_active = null

func _apply_stem_intensity(fade: float) -> void:
	for layer in STEM_LAYERS:
		_fade_player(_stem_player(layer), _stem_target_db(layer), false, fade)

func _stem_target_db(layer: String) -> float:
	if _heart_mode:
		return HEART_STEM_BASE_DB if layer == STEM_BASE else STEM_SILENCE_DB
	match layer:
		STEM_MID:
			return 0.0 if _music_intensity >= 1 else STEM_SILENCE_DB
		STEM_TOP:
			# O Cortejo acende a camada percussiva mais aguda por cima do loop base.
			if _cortejo_active:
				return 0.0
			return 0.0 if _music_intensity >= 2 else STEM_SILENCE_DB
		_:
			return 0.0

# ─── Stingers ──────────────────────────────────────
func _play_stinger(name: String, volume_db: float = 0.0) -> void:
	var path := STING_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		return
	_stinger_player.stream = load(path)
	_stinger_player.volume_db = volume_db
	_stinger_player.play()

## Garante loop contínuo no asset. O .import é gitignored (regenera sem loop), então
## forçamos LOOP_FORWARD em runtime no AudioStreamWAV (mono 16-bit = 2 bytes/frame).
func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# loop_end é em FRAMES: 1 byte por frame em 8-bit, 2 em 16-bit (mono).
		var bytes_per_frame := 1 if wav.format == AudioStreamWAV.FORMAT_8_BITS else 2
		wav.loop_end = wav.data.size() / bytes_per_frame

func _fade_player(player: AudioStreamPlayer, to_db: float, stop_after: bool, dur: float = AMBIENCE_FADE) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", to_db, dur)
	if stop_after:
		tween.tween_callback(player.stop)

# ─── Volume helpers ────────────────────────────────
func _apply_all_volumes() -> void:
	for bus_name in VOLUME_BUSES:
		_apply_volume(bus_name)

func _apply_volume(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if (bus_name == BUS_MUSIC or bus_name == BUS_AMBIENCE) and not _music_enabled:
		AudioServer.set_bus_volume_db(idx, -80.0)
		return
	var db := _linear_to_db(_bus_volume[bus_name])
	if bus_name == BUS_MASTER:
		db += MASTER_TRIM_DB
	AudioServer.set_bus_volume_db(idx, db)

func _linear_to_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0  # mute prático (evita -inf)
	return linear_to_db(linear)

# ─── Persistência ──────────────────────────────────
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus_name in VOLUME_BUSES:
		if cfg.has_section_key(SETTINGS_SECTION, bus_name):
			_bus_volume[bus_name] = clampf(cfg.get_value(SETTINGS_SECTION, bus_name), 0.0, 1.0)
	if cfg.has_section_key(SETTINGS_SECTION, "music_enabled"):
		_music_enabled = cfg.get_value(SETTINGS_SECTION, "music_enabled")

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # preserva outras seções, se houver
	for bus_name in VOLUME_BUSES:
		cfg.set_value(SETTINGS_SECTION, bus_name, _bus_volume[bus_name])
	cfg.set_value(SETTINGS_SECTION, "music_enabled", _music_enabled)
	cfg.save(SETTINGS_PATH)
