extends GutTest

# Cobre o nó de VFX do Golpe Perfeito (CortejoApparition): mapeamento espírito↔fase,
# sprites canônicos presentes e API estável. A lógica de barragem/dano é coberta por
# test_cortejo_barrage.gd; a janela por test_timing_system.gd. Não exercita a arena.

const FREEABLE_PHASES: Array[int] = [1, 2, 3, 4]

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
	app.strike(1, Vector2(200, 120), true)
	assert_gt(app.get_child_count(), before, "um espírito da barragem instancia a aparição")
	app.finish()
	pass_test("begin/strike/finish não estouram")
