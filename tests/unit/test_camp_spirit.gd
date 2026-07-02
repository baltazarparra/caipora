extends GutTest

## Santuário dos Encantados (Etapa 2): a presença de um encantado libertado em repouso
## no acampamento. Contrato visual: idle mais lento que o combate, leitura abatida,
## aura calma na cor canônica e andar aterrado (sombra + quique de passo, não pairando)
## — e NENHUM espírito para o Jesuíta (P5).

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

# ─── Modo HD: o encantado vira set piece (rim + coroa), leve fica intocado ───
func test_hd_spirit_gets_rim_and_crown() -> void:
	Quality._set_for_test(true)
	var spirit := CampSpirit.new()
	add_child_autofree(spirit)
	spirit.setup(2)  # Boitatá
	var rim := spirit._sprite.get_node_or_null("ParticleRim")
	assert_not_null(rim, "espírito tem contorno de brasas em HD")
	assert_not_null(rim.get_node_or_null("RimHalo"), "espírito tem halo (set piece)")
	assert_null(rim.get_node_or_null("RimLight"),
		"SEM segunda luz: o glow próprio do espírito já ilumina")
	var crown := spirit.get_node_or_null("AuraRing") as CPUParticles2D
	assert_not_null(crown, "espírito tem coroa orbital")
	assert_gt(crown.orbit_velocity_max, 0.0, "a coroa orbita")
	Quality._reset_for_test()

func test_lite_spirit_has_no_hd_layers() -> void:
	Quality._set_for_test(false)
	var spirit := CampSpirit.new()
	add_child_autofree(spirit)
	spirit.setup(1)  # Mula
	assert_null(spirit._sprite.get_node_or_null("ParticleRim"), "leve: sem rim")
	assert_null(spirit.get_node_or_null("AuraRing"), "leve: sem coroa")
	Quality._reset_for_test()

func test_hd_calm_aura_doubles_density() -> void:
	Quality._set_for_test(false)
	var lite := CampSpirit.new()
	add_child_autofree(lite)
	lite.setup(3)
	Quality._set_for_test(true)
	var hd := CampSpirit.new()
	add_child_autofree(hd)
	hd.setup(3)
	var lite_aura := _find_calm_aura(lite)
	var hd_aura := _find_calm_aura(hd)
	assert_eq(hd_aura.amount, lite_aura.amount * int(Quality.HD_HEAVY_FACTOR),
		"HD dobra a densidade da aura calma")
	Quality._reset_for_test()

## A aura calma é o CPUParticles2D filho direto que não é a coroa.
func _find_calm_aura(spirit: CampSpirit) -> CPUParticles2D:
	for child: Node in spirit.get_children():
		if child is CPUParticles2D and String(child.name) != "AuraRing":
			return child as CPUParticles2D
	return null

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
