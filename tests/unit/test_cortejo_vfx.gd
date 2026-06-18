extends GutTest

# Cobre os nós de VFX do Cortejo dos Encantados (ChargeBubble + CortejoApparition):
# contrato de API estável, mapeamento espírito↔fase completo e sprites canônicos
# presentes. Não exercita o turno inteiro (arena pesada) — isso é coberto pelo
# núcleo em test_hold_timing_system.gd.

const FREEABLE_PHASES: Array[int] = [1, 2, 3, 4]

# ─── ChargeBubble ──────────────────────────────────
func test_charge_bubble_visibility_lifecycle() -> void:
	var ring := ChargeBubble.new()
	add_child_autofree(ring)
	assert_false(ring.visible, "anel nasce invisível")
	ring.show_ring(Vector2(120, 80))
	assert_true(ring.visible, "show_ring exibe o anel")
	assert_eq(ring.position, Vector2(120, 80), "anel ancora na posição pedida")
	ring.hide_ring()
	assert_false(ring.visible, "hide_ring some com o anel")

func test_charge_bubble_progress_and_states_are_safe() -> void:
	var ring := ChargeBubble.new()
	add_child_autofree(ring)
	ring.show_ring(Vector2.ZERO)
	# Não deve estourar com progresso fora de faixa nem nos estados terminais.
	ring.set_progress(-0.5)
	ring.set_progress(0.5)
	ring.set_progress(2.0)
	ring.set_armed()
	ring.burst_landed()
	ring.set_frozen(true)
	ring.set_frozen(false)
	ring.burst_missed()
	pass_test("API do anel é robusta a entradas e estados")

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
	app.strike(1, Vector2(200, 120), true)
	assert_gt(app.get_child_count(), before, "elo landado instancia a aparição do espírito")
	app.finish()
	pass_test("begin/strike/finish não estouram")
