extends GutTest

# Cobre os nós de VFX do Batuque do Cortejo (CortejoApparition + CortejoBeatTrack):
# mapeamento espírito↔fase completo, sprites canônicos presentes e API estável. O
# turno/ritmo é coberto por test_cortejo_sequence.gd (sequência) e test_timing_system
# (janela/cancel). Não exercita a arena inteira (pesada).

const FREEABLE_PHASES: Array[int] = [1, 2, 3, 4]

# ─── CortejoApparition ─────────────────────────────
func test_apparition_covers_all_freeable_phases() -> void:
	for phase: int in FREEABLE_PHASES:
		assert_true(CortejoApparition.SPIRIT_FRAMES.has(phase),
			"espírito mapeado para a fase %d" % phase)
		assert_true(CortejoApparition.SPIRIT_AURA.has(phase),
			"aura mapeada para a fase %d" % phase)

func test_apparition_spirit_frames_resources_exist() -> void:
	for phase: int in FREEABLE_PHASES:
		var path: String = CortejoApparition.SPIRIT_FRAMES[phase]
		assert_true(ResourceLoader.exists(path),
			"sprite_frames do espírito da fase %d existe: %s" % [phase, path])
		var frames: SpriteFrames = load(path)
		assert_true(frames.has_animation(&"idle"),
			"espírito da fase %d tem animação idle" % phase)

func test_apparition_strike_spawns_ghost() -> void:
	var app := CortejoApparition.new()
	add_child_autofree(app)
	app.begin()
	var before: int = app.get_child_count()
	app.strike(1, Vector2(200, 120), "ui_up")
	assert_gt(app.get_child_count(), before, "chamado acertado instancia a aparição do espírito")
	app.finish()
	pass_test("begin/strike/finish não estouram")

# ─── CortejoBeatTrack ──────────────────────────────
func test_beat_track_lifecycle_is_safe() -> void:
	var track := CortejoBeatTrack.new()
	add_child_autofree(track)
	assert_false(track.visible, "faixa nasce invisível")
	track.setup(["ui_up", "ui_right", "ui_down"])
	assert_true(track.visible, "setup com chamados exibe a faixa")
	# Sequência de uso típica não deve estourar.
	track.set_current(0)
	track.mark(0, true)
	track.set_current(1)
	track.mark(1, false)
	track.pulse()
	track.finish()
	pass_test("API da faixa de batuque é robusta")

func test_beat_track_empty_stays_hidden() -> void:
	var track := CortejoBeatTrack.new()
	add_child_autofree(track)
	track.setup([])
	assert_false(track.visible, "sem chamados, a faixa não aparece")
