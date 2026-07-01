extends GutTest

# Exercita o contrato do AudioDirector (autoload) de forma headless:
#   - os buses do layout existem
#   - volume por bus seta/lê e respeita o clamp
#   - duck() roda sem erro
#   - cada tela resolve a faixa de música correta e a arena começa a tocar
#   - o tema do boss começa na revelação e atravessa para a arena sem corte
# Não valida áudio audível (isso é manual). Restaura o estado global ao fim.

func after_each():
	# Para toda reprodução iniciada pelos testes (evita 'resources in use at exit').
	AudioDirector._music_a.stop()
	AudioDirector._music_b.stop()
	AudioDirector._music_stem_base.stop()
	AudioDirector._music_stem_mid.stop()
	AudioDirector._music_stem_top.stop()
	AudioDirector._stems_active = false
	AudioDirector._music_intensity = 0
	AudioDirector._heart_mode = false
	AudioDirector._music_active = null
	AudioDirector._current_music = ""
	AudioDirector._stinger_player.stop()
	AudioDirector._ambience_player.stop()
	AudioDirector._heartbeat_player.stop()
	AudioDirector._current_ambience = ""
	AudioDirector.set_bus_volume("Music", 0.8)
	AudioDirector.set_master_muted(false)
	# Remove players one-shot (hover/bolsa) na hora — queue_free só age no idle e
	# vazaria contagem para o teste seguinte.
	var fixed := [AudioDirector._music_a, AudioDirector._music_b,
		AudioDirector._music_stem_base, AudioDirector._music_stem_mid,
		AudioDirector._music_stem_top, AudioDirector._stinger_player,
		AudioDirector._ambience_player, AudioDirector._heartbeat_player]
	for child in AudioDirector.get_children():
		if child is AudioStreamPlayer and not fixed.has(child):
			child.free()
	AudioDirector._last_hover_msec = -AudioDirector.UI_HOVER_COOLDOWN_MSEC
	AudioDirector._mata_timer.stop()
	AudioDirector._kill_silence_tween()

func test_layout_buses_exist():
	for bus_name in ["Master", "SFX", "Music", "Ambience"]:
		assert_true(AudioServer.get_bus_index(bus_name) >= 0, "bus %s deve existir" % bus_name)

func test_set_get_bus_volume_clamps():
	AudioDirector.set_bus_volume("SFX", 0.5)
	assert_almost_eq(AudioDirector.get_bus_volume("SFX"), 0.5, 0.001)
	AudioDirector.set_bus_volume("SFX", 2.0)
	assert_almost_eq(AudioDirector.get_bus_volume("SFX"), 1.0, 0.001)
	AudioDirector.set_bus_volume("SFX", 1.0)  # restaura

func test_master_mute_toggles_master_bus():
	var idx := AudioServer.get_bus_index("Master")
	AudioDirector.set_master_muted(false)
	assert_false(AudioDirector.is_master_muted(), "Master começa audível")
	assert_false(AudioServer.is_bus_mute(idx), "bus Master começa audível")
	AudioDirector.toggle_master_mute()
	assert_true(AudioDirector.is_master_muted(), "toggle muta o Master")
	assert_true(AudioServer.is_bus_mute(idx), "AudioServer reflete o mute")
	AudioDirector.toggle_master_mute()
	assert_false(AudioDirector.is_master_muted(), "segundo toggle desmuta")
	assert_false(AudioServer.is_bus_mute(idx), "AudioServer reflete o unmute")

func test_duck_runs_without_error():
	AudioDirector.duck()
	assert_true(true, "duck() não deve quebrar")

func test_music_resolves_per_screen():
	# Cada fase de exploração e arena mapeia para a sua própria faixa.
	GameState.active_combat_is_boss = false
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.MAIN_MENU),
		"res://assets/audio/music/mus_menu.wav")
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.EXPLORATION_PHASE3),
		"res://assets/audio/music/mus_explore_p3.wav")
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.ARENA_PHASE2),
		"res://assets/audio/music/mus_arena_p2.wav")
	# Fase FINAL (A Igreja): faixa própria de exploração e de arena.
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.EXPLORATION_PHASE5),
		"res://assets/audio/music/mus_explore_p5.wav")
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.ARENA_PHASE5),
		"res://assets/audio/music/mus_arena_p5.wav")
	# WIN/GAME_OVER não têm loop de música.
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.WIN), "")

func test_boss_screen_picks_boss_theme():
	GameState.active_combat_is_boss = true
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.ARENA_PHASE4),
		"res://assets/audio/music/mus_boss_saci.wav")
	# Boss FINAL: o Jesuíta tem seu próprio tema.
	assert_eq(AudioDirector._music_for_screen(SignalBus.Screen.ARENA_PHASE5),
		"res://assets/audio/music/mus_boss_jesuita.wav")
	GameState.active_combat_is_boss = false

func test_ambience_resolves_church_for_phase5():
	# A igreja tem cama sonora própria — na exploração E na arena (mesmo espaço).
	AudioDirector._refresh_ambience(SignalBus.Screen.EXPLORATION_PHASE5)
	assert_eq(AudioDirector._current_ambience, AudioDirector.AMB_CHURCH,
		"exploração da Fase 5 usa a ambiência de igreja")
	AudioDirector._refresh_ambience(SignalBus.Screen.ARENA_PHASE5)
	assert_eq(AudioDirector._current_ambience, AudioDirector.AMB_CHURCH,
		"a arena da Fase 5 é o altar da mesma igreja")
	AudioDirector._refresh_ambience(SignalBus.Screen.ARENA_PHASE4)
	assert_eq(AudioDirector._current_ambience, AudioDirector.AMB_DREAD,
		"arenas 1–4 continuam no dread")

func _stinger_path() -> String:
	return AudioDirector._stinger_player.stream.resource_path

func test_boss_intro_stinger_is_church_bell_on_final_phase():
	# S7: o stinger nasce do silêncio — espera o vazio curto antes de afirmar.
	AudioDirector.unlock_audio()
	var phase_before := GameState.active_phase
	GameState.active_phase = 5
	GameState.active_combat_is_boss = true
	AudioDirector._on_boss_intro()
	await get_tree().create_timer(AudioDirector.SILENCE_BEFORE_STING + 0.1).timeout
	assert_true(_stinger_path().ends_with("sting_sino_igreja.wav"),
		"revelação do Jesuíta toca o sino da torre")
	GameState.active_phase = 1
	AudioDirector._on_boss_intro()
	await get_tree().create_timer(AudioDirector.SILENCE_BEFORE_STING + 0.1).timeout
	assert_true(_stinger_path().ends_with("sting_boss_intro.wav"),
		"fases 1–4 mantêm o stinger genérico de revelação")
	GameState.active_phase = phase_before
	GameState.active_combat_is_boss = false

func test_boss_intro_defers_stinger_into_the_silence():
	# A mata cala primeiro: nada toca no frame da revelação; o stinger vem depois.
	AudioDirector.unlock_audio()
	GameState.active_phase = 1
	GameState.active_combat_is_boss = true
	AudioDirector._stinger_player.stop()
	AudioDirector._stinger_player.stream = null
	AudioDirector._on_boss_intro()
	assert_false(AudioDirector._stinger_player.playing,
		"no frame da revelação o mundo está calando, não tocando")
	await get_tree().create_timer(AudioDirector.SILENCE_BEFORE_STING + 0.1).timeout
	assert_true(AudioDirector._stinger_player.playing, "o stinger nasce do vazio")
	GameState.active_combat_is_boss = false

func test_final_choice_plays_organ_death_rattle():
	AudioDirector.unlock_audio()
	AudioDirector._apply_screen_audio(SignalBus.Screen.FINAL_CHOICE)
	assert_true(_stinger_path().ends_with("sting_orgao_estertor.wav"),
		"o Jesuíta caído no altar = estertor de órgão sob a pergunta final")

func test_sacrifice_ending_tolls_church_bell():
	AudioDirector.unlock_audio()
	AudioDirector._apply_screen_audio(SignalBus.Screen.ENDING_SACRIFICE)
	assert_true(_stinger_path().ends_with("sting_sino_igreja.wav"),
		"a floresta convertida dobra o sino da igreja")

func test_final_choice_keeps_church_ambience_and_space():
	# A escolha acontece no MESMO altar: cama sonora e reverb de igreja seguem.
	AudioDirector._refresh_ambience(SignalBus.Screen.FINAL_CHOICE)
	assert_eq(AudioDirector._current_ambience, AudioDirector.AMB_CHURCH,
		"a pergunta final é feita dentro da igreja")
	AudioDirector._apply_space_profile(SignalBus.Screen.FINAL_CHOICE)
	assert_almost_eq(_reverb_fx().room_size, 0.9, 0.01,
		"o reverb da nave não troca na hora da escolha")

func test_jesuita_special_telegraph_plays_agua_benta():
	AudioDirector.unlock_audio()
	SignalBus.boss_special_telegraph.emit("jesuita")
	assert_true(_stinger_path().ends_with("sting_agua_benta.wav"),
		"wind-up do especial do Jesuíta sibila água benta")
	SignalBus.boss_special_telegraph.emit("saci")
	assert_true(_stinger_path().ends_with("sting_agua_benta.wav"),
		"outros chefes não trocam o stinger")

func test_arena_starts_music():
	AudioDirector.unlock_audio()
	GameState.active_combat_is_boss = false
	AudioDirector._apply_screen_audio(SignalBus.Screen.ARENA)
	assert_not_null(AudioDirector._music_active, "deve haver player de música ativo na arena")
	assert_true(AudioDirector._music_active.playing, "a música da arena deve estar tocando")

func test_arena_uses_stems_at_intensity_one():
	AudioDirector.unlock_audio()
	GameState.active_combat_is_boss = false
	AudioDirector._apply_screen_audio(SignalBus.Screen.ARENA_PHASE2)
	assert_true(AudioDirector._stems_active, "arena comum deve usar stems verticais")
	assert_eq(AudioDirector._music_active, AudioDirector._music_stem_base,
		"o stem base preserva o contrato de player ativo")
	assert_true(AudioDirector._music_stem_base.playing, "stem base deve tocar")
	assert_true(AudioDirector._music_stem_mid.playing, "stem mid deve tocar sincronizado")
	assert_true(AudioDirector._music_stem_top.playing, "stem top deve tocar sincronizado")
	assert_eq(AudioDirector._music_intensity, 1, "arena comum entra em intensidade 1")

func test_boss_uses_stems_at_intensity_two():
	AudioDirector.unlock_audio()
	GameState.active_combat_is_boss = true
	AudioDirector._apply_screen_audio(SignalBus.Screen.ARENA_PHASE4)
	assert_true(AudioDirector._stems_active, "boss deve usar stems verticais")
	assert_eq(AudioDirector._music_intensity, 2, "boss entra em intensidade 2")
	assert_true(AudioDirector._music_stem_base.stream.resource_path.ends_with("mus_boss_saci_base.wav"))
	GameState.active_combat_is_boss = false

func test_heart_mode_activates_on_critical_hp():
	AudioDirector.unlock_audio()
	GameState.active_combat_is_boss = false
	AudioDirector._apply_screen_audio(SignalBus.Screen.ARENA_PHASE2)
	SignalBus.caipora_health_changed.emit(2.0, 10.0)
	assert_true(AudioDirector._heart_mode, "HP abaixo de 30% ativa modo coração")
	assert_true(AudioDirector._heartbeat_player.playing, "heartbeat deve tocar após unlock")
	assert_almost_eq(AudioDirector._stem_target_db(AudioDirector.STEM_BASE),
		AudioDirector.HEART_STEM_BASE_DB, 0.01)
	assert_almost_eq(AudioDirector._stem_target_db(AudioDirector.STEM_MID),
		AudioDirector.STEM_SILENCE_DB, 0.01)
	assert_almost_eq(AudioDirector._stem_target_db(AudioDirector.STEM_TOP),
		AudioDirector.STEM_SILENCE_DB, 0.01)

func test_heart_mode_waits_for_audio_unlock():
	AudioDirector._audio_unlocked = false
	SignalBus.caipora_health_changed.emit(1.0, 10.0)
	assert_true(AudioDirector._heart_mode, "estado crítico deve ser guardado")
	assert_false(AudioDirector._heartbeat_player.playing,
		"heartbeat não deve tocar antes do gesto que libera áudio")

func test_heart_mode_restores_previous_intensity_after_recovery():
	AudioDirector.unlock_audio()
	GameState.active_combat_is_boss = false
	AudioDirector._apply_screen_audio(SignalBus.Screen.ARENA_PHASE2)
	SignalBus.caipora_health_changed.emit(2.0, 10.0)
	SignalBus.caipora_health_changed.emit(5.0, 10.0)
	assert_false(AudioDirector._heart_mode, "HP recuperado acima do limiar sai do modo coração")
	assert_almost_eq(AudioDirector._stem_target_db(AudioDirector.STEM_BASE), 0.0, 0.01)
	assert_almost_eq(AudioDirector._stem_target_db(AudioDirector.STEM_MID), 0.0, 0.01)
	assert_almost_eq(AudioDirector._stem_target_db(AudioDirector.STEM_TOP),
		AudioDirector.STEM_SILENCE_DB, 0.01)

func test_heart_mode_ignores_death_zero_hp():
	AudioDirector.unlock_audio()
	SignalBus.caipora_health_changed.emit(0.0, 10.0)
	assert_false(AudioDirector._heart_mode, "HP zero é morte, não estado crítico")

func test_same_track_does_not_restart():
	# Boss-intro inicia o tema (após o silêncio dramático); a arena pede a MESMA
	# faixa → não reinicia (sem corte).
	AudioDirector.unlock_audio()
	GameState.active_phase = 1
	GameState.active_combat_is_boss = true
	AudioDirector._on_boss_intro()
	await get_tree().create_timer(AudioDirector.SILENCE_BEFORE_STING + 0.1).timeout
	var active_before := AudioDirector._music_active
	AudioDirector._apply_screen_audio(SignalBus.Screen.ARENA)
	assert_eq(AudioDirector._music_active, active_before,
		"a faixa de boss não deve trocar de player ao entrar na arena")
	GameState.active_combat_is_boss = false

func test_missing_single_loop_falls_back_to_base_stem():
	var path := "res://assets/audio/music/mus_arena_p1.wav"
	assert_false(ResourceLoader.exists(path), "arena p1 não tem loop único materializado")
	assert_true(ResourceLoader.exists("res://assets/audio/music/mus_arena_p1_base.wav"),
		"o fallback base existe")
	assert_eq(AudioDirector._music_stream_path(path),
		"res://assets/audio/music/mus_arena_p1_base.wav")

func _count_transient_players() -> int:
	# Players one-shot criados por _play_oneshot_sfx (filhos diretos além dos fixos).
	var fixed := [AudioDirector._music_a, AudioDirector._music_b,
		AudioDirector._music_stem_base, AudioDirector._music_stem_mid,
		AudioDirector._music_stem_top, AudioDirector._stinger_player,
		AudioDirector._ambience_player, AudioDirector._heartbeat_player]
	var extras := 0
	for child in AudioDirector.get_children():
		if child is AudioStreamPlayer and not fixed.has(child):
			extras += 1
	return extras

func test_ui_hover_respects_unlock_and_cooldown():
	AudioDirector._audio_unlocked = false
	AudioDirector._last_hover_msec = -AudioDirector.UI_HOVER_COOLDOWN_MSEC
	AudioDirector.play_ui_hover()
	assert_eq(_count_transient_players(), 0, "hover não toca antes do unlock de áudio")
	AudioDirector.unlock_audio()
	AudioDirector.play_ui_hover()
	AudioDirector.play_ui_hover()  # foco+mouse do mesmo controle: colapsa num tick só
	assert_eq(_count_transient_players(), 1, "cooldown colapsa hover duplo num único player")

func test_oneshot_sfx_missing_asset_is_noop():
	AudioDirector.unlock_audio()
	AudioDirector._play_oneshot_sfx("res://assets/audio/sfx/nao_existe.wav")
	assert_eq(_count_transient_players(), 0, "asset ausente não cria player nem quebra")

func test_bag_signals_play_oneshots_when_assets_exist():
	AudioDirector.unlock_audio()
	SignalBus.fragment_bag_dropped.emit(5.0)
	SignalBus.fragment_bag_recovered.emit(5.0)
	var expected := 0
	if ResourceLoader.exists(AudioDirector.STING_DIR + AudioDirector.STING_BAG_DROP + ".wav"):
		expected += 1
	if ResourceLoader.exists(AudioDirector.STING_DIR + AudioDirector.STING_BAG_RECOVER + ".wav"):
		expected += 1
	assert_eq(_count_transient_players(), expected,
		"cada sinal da bolsa toca um one-shot (graceful se o asset faltar)")

func test_boss_name_resolves_each_phase():
	# Fonte única: tema (mus_boss_*) e cicatriz (boss_death_*) usam o mesmo nome.
	var names := {1: "mula", 2: "boitata", 3: "curupira", 4: "saci", 5: "jesuita"}
	for phase: int in names:
		assert_eq(AudioDirector._boss_name(phase), names[phase])
		assert_eq(AudioDirector._boss_track(phase), "mus_boss_" + names[phase])

func test_boss_died_plays_death_scar_stinger():
	AudioDirector.unlock_audio()
	for phase: int in [1, 2, 3, 4, 5]:
		SignalBus.boss_died.emit(phase)
		var expected := "boss_death_" + AudioDirector._boss_name(phase) + ".wav"
		assert_true(_stinger_path().ends_with(expected),
			"chefe da fase %d morre com %s" % [phase, expected])

func test_boss_died_missing_asset_does_not_crash():
	AudioDirector.unlock_audio()
	AudioDirector._play_stinger("boss_death_inexistente")
	assert_true(true, "stinger ausente é no-op (o death_sound comum é o fallback)")

func test_mata_scheduler_runs_only_in_exploration():
	AudioDirector.unlock_audio()
	for screen: int in [SignalBus.Screen.EXPLORATION, SignalBus.Screen.EXPLORATION_PHASE3,
			SignalBus.Screen.EXPLORATION_PHASE5]:
		AudioDirector._apply_screen_audio(screen)
		assert_false(AudioDirector._mata_timer.is_stopped(),
			"a mata respira na exploração (tela %d)" % screen)
		var wait := AudioDirector._mata_timer.time_left
		assert_between(wait, AudioDirector.MATA_EVENT_MIN_SECS - 0.01,
			AudioDirector.MATA_EVENT_MAX_SECS + 0.01, "intervalo dentro de 8-20s")
	for screen: int in [SignalBus.Screen.ARENA, SignalBus.Screen.HUB,
			SignalBus.Screen.MAIN_MENU, SignalBus.Screen.GAME_OVER]:
		AudioDirector._apply_screen_audio(screen)
		assert_true(AudioDirector._mata_timer.is_stopped(),
			"nenhum timer da mata sobrevive fora da exploração (tela %d)" % screen)

func test_mata_event_rearms_after_firing():
	AudioDirector.unlock_audio()
	AudioDirector._apply_screen_audio(SignalBus.Screen.EXPLORATION)
	AudioDirector._on_mata_event_timeout()
	assert_false(AudioDirector._mata_timer.is_stopped(),
		"o evento rearma o scheduler (mesmo sem asset)")

func test_game_over_empties_world_before_stinger():
	AudioDirector.unlock_audio()
	AudioDirector._stinger_player.stop()
	AudioDirector._stinger_player.stream = null
	AudioDirector._apply_screen_audio(SignalBus.Screen.GAME_OVER)
	assert_false(AudioDirector._stinger_player.playing,
		"a morte esvazia o mundo primeiro — o stinger não toca no mesmo frame")
	await get_tree().create_timer(AudioDirector.GAME_OVER_SILENCE + 0.1).timeout
	assert_true(_stinger_path().ends_with("sting_game_over.wav"),
		"o stinger de game over nasce do vazio")

func test_screen_change_kills_pending_silence():
	# Troca de tela no meio do vazio: o stinger pendente NÃO pode tocar atrasado.
	AudioDirector.unlock_audio()
	GameState.active_phase = 1
	GameState.active_combat_is_boss = true
	AudioDirector._stinger_player.stop()
	AudioDirector._stinger_player.stream = null
	AudioDirector._on_boss_intro()
	AudioDirector._apply_screen_audio(SignalBus.Screen.MAIN_MENU)
	await get_tree().create_timer(AudioDirector.SILENCE_BEFORE_STING + 0.1).timeout
	assert_false(AudioDirector._stinger_player.playing,
		"o tween de silêncio morre na troca de tela — sem callback órfão")
	GameState.active_combat_is_boss = false

func test_beat_sync_ships_disabled_and_waits_zero():
	# S9: kill switch — a flag NUNCA deve ir para true sem playtest deliberado.
	assert_false(AudioDirector.BEAT_SYNC_ENABLED, "beat-sync é experimento: ships OFF")
	assert_eq(AudioDirector.time_to_next_beat(), 0.0,
		"com a flag desligada o wind-up nunca espera")

func test_bpm_map_covers_arena_tracks_only():
	assert_eq(AudioDirector._bpm_for_track("res://assets/audio/music/mus_arena_p1_base.wav"), 100.0)
	assert_eq(AudioDirector._bpm_for_track("res://assets/audio/music/mus_arena_p5.wav"), 120.0)
	assert_eq(AudioDirector._bpm_for_track("res://assets/audio/music/mus_boss_saci.wav"), 0.0,
		"bosses ficam fora do beat-sync v1")
	assert_eq(AudioDirector._bpm_for_track("res://assets/audio/music/mus_menu.wav"), 0.0)

func test_force_loop_handles_8_and_16_bit():
	# A música é gravada em PCM 8-bit (1 byte por frame mono); SFX seguem 16-bit.
	var wav8 := AudioStreamWAV.new()
	wav8.format = AudioStreamWAV.FORMAT_8_BITS
	wav8.data = PackedByteArray([128, 200, 60, 128])
	AudioDirector._force_loop(wav8)
	assert_eq(wav8.loop_end, 4, "8-bit: loop_end = bytes (1 byte por frame)")
	var wav16 := AudioStreamWAV.new()
	wav16.format = AudioStreamWAV.FORMAT_16_BITS
	wav16.data = PackedByteArray([0, 0, 0, 0])
	AudioDirector._force_loop(wav16)
	assert_eq(wav16.loop_end, 2, "16-bit: loop_end = bytes / 2")

func test_reverb_bus_exists_and_routes():
	var idx_reverb := AudioServer.get_bus_index("Reverb")
	assert_true(idx_reverb >= 0, "bus Reverb deve existir")
	assert_true(AudioServer.get_bus_effect(idx_reverb, 0) is AudioEffectReverb,
		"bus Reverb carrega um AudioEffectReverb")
	var idx_sfx := AudioServer.get_bus_index("SFX")
	var idx_amb := AudioServer.get_bus_index("Ambience")
	assert_eq(AudioServer.get_bus_send(idx_sfx), &"Reverb", "SFX atravessa o espaço")
	assert_eq(AudioServer.get_bus_send(idx_amb), &"Reverb", "Ambience atravessa o espaço")
	var idx_music := AudioServer.get_bus_index("Music")
	assert_eq(AudioServer.get_bus_send(idx_music), &"Master",
		"Music fica fora do reverb (espaço da música é a cauda impressa)")

func _reverb_fx() -> AudioEffectReverb:
	return AudioServer.get_bus_effect(AudioServer.get_bus_index("Reverb"), 0) as AudioEffectReverb

func test_space_profile_per_screen():
	# Igreja (Fase 5 inteira) = sala grande; arenas 1–4 = clareira; resto = mata seca.
	AudioDirector._apply_space_profile(SignalBus.Screen.EXPLORATION_PHASE5)
	assert_almost_eq(_reverb_fx().room_size, 0.9, 0.01, "igreja de pedra responde")
	AudioDirector._apply_space_profile(SignalBus.Screen.ARENA_PHASE5)
	assert_almost_eq(_reverb_fx().room_size, 0.9, 0.01, "o altar é a mesma igreja")
	AudioDirector._apply_space_profile(SignalBus.Screen.ARENA_PHASE2)
	assert_almost_eq(_reverb_fx().room_size, 0.55, 0.01, "arena = clareira média")
	AudioDirector._apply_space_profile(SignalBus.Screen.EXPLORATION)
	assert_almost_eq(_reverb_fx().room_size, 0.25, 0.01, "a folhagem absorve")
	assert_almost_eq(_reverb_fx().wet, 0.05, 0.001, "mata quase seca")

func test_music_bus_has_eq():
	var fx := AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
	assert_true(fx is AudioEffectEQ6, "bus Music carrega EQ de 6 bandas")
	var eq := fx as AudioEffectEQ6
	assert_almost_eq(eq.get_band_gain_db(4), -3.0, 0.01,
		"a música cede a banda de presença aos SFX de timing")
