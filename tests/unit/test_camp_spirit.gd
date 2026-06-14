extends GutTest

## Santuário dos Encantados (Etapa 2): a presença de um encantado libertado em repouso
## no acampamento. Contrato visual: idle mais lento que o combate, leitura abatida,
## respiração e aura calma na cor canônica — e NENHUM espírito para o Jesuíta (P5).

const ENCANTADO_PHASES := [1, 2, 3, 4]

func test_defs_cover_only_encantados() -> void:
	for phase: int in ENCANTADO_PHASES:
		assert_true(CampSpirit.DEFS.has(phase), "fase %d tem espírito" % phase)
	assert_false(CampSpirit.DEFS.has(5), "Jesuíta (P5) não é encantado — sem espírito")

func test_setup_builds_resting_presence() -> void:
	for phase: int in ENCANTADO_PHASES:
		var spirit := CampSpirit.new()
		add_child_autofree(spirit)
		assert_true(spirit.setup(phase), "setup da fase %d" % phase)
		assert_eq(spirit.phase, phase)
		var sprite := spirit._sprite
		assert_not_null(sprite.sprite_frames, "frames carregados (fase %d)" % phase)
		assert_true(sprite.sprite_frames.has_animation(&"idle"),
			"frames do boss têm idle (fase %d)" % phase)
		assert_eq(sprite.animation, &"idle", "espírito descansa em idle")
		assert_true(sprite.is_playing(), "idle animado (vivo, não estátua)")
		assert_lt(sprite.speed_scale, 1.0, "descanso mais lento que o combate")
		assert_lt(sprite.modulate.v, 1.0, "leitura abatida — a Caipora segue dona da tela")
		var has_aura := false
		for child: Node in spirit.get_children():
			if child is CPUParticles2D:
				has_aura = true
		assert_true(has_aura, "aura calma presente (fase %d)" % phase)

func test_setup_rejects_non_encantado_phases() -> void:
	for phase: int in [0, 5, 99]:
		var spirit := CampSpirit.new()
		add_child_autofree(spirit)
		assert_false(spirit.setup(phase), "fase %d não monta espírito" % phase)
		assert_eq(spirit.get_child_count(), 0, "setup rejeitado não cria nós")

func test_setup_alone_keeps_spirit_still() -> void:
	var spirit := CampSpirit.new()
	add_child_autofree(spirit)
	spirit.setup(1)
	spirit.position = Vector2(100, 100)
	await wait_frames(3)
	assert_eq(spirit.position, Vector2(100, 100),
		"sem enable_wander o espírito fica parado (contrato preservado)")

func test_enable_wander_moves_within_bounds() -> void:
	var spirit := CampSpirit.new()
	add_child_autofree(spirit)
	spirit.setup(1)
	var bounds := Rect2(0, 0, 400, 300)
	spirit.position = bounds.get_center()
	spirit.enable_wander(bounds)
	assert_true(spirit._wandering, "perambulação ligada")
	var start := spirit.position
	var moved := false
	for _i in range(120):
		await wait_frames(1)
		if spirit.position != start:
			moved = true
		assert_true(bounds.has_point(spirit.position),
			"posição permanece dentro da clareira")
	assert_true(moved, "o espírito se moveu ao perambular")
