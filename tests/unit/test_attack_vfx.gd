extends GutTest

# VFX por golpe (moves nomeados, Fase 4). Construído EM CÓDIGO (sem .tscn/PNG), então
# testável headless: trava o elo dado↔registro e a construção da partícula.

var _fb: FeedbackSystem

func before_each() -> void:
	_fb = FeedbackSystem.new()
	add_child_autofree(_fb)  # entra na árvore -> get_viewport() válido

func test_every_pattern_vfx_id_is_registered() -> void:
	var dir := DirAccess.open("res://resources/attack_patterns")
	assert_not_null(dir, "pasta de attack_patterns deve existir")
	var checked := 0
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var p := load("res://resources/attack_patterns/%s" % file) as AttackPattern
		if p == null or p.vfx_id.is_empty():
			continue
		assert_true(FeedbackSystem._VFX_BY_ID.has(StringName(p.vfx_id)),
			"%s tem vfx_id '%s' sem registro em _VFX_BY_ID" % [file, p.vfx_id])
		checked += 1
	assert_gt(checked, 0, "deve ter checado ao menos um vfx_id")

func test_every_registry_archetype_exists() -> void:
	# Toda entrada do registro aponta para um arquétipo conhecido.
	for vfx_id: StringName in FeedbackSystem._VFX_BY_ID:
		var arch: StringName = FeedbackSystem._VFX_BY_ID[vfx_id][0]
		assert_true(FeedbackSystem._VFX_ARCH.has(arch),
			"vfx_id %s usa arquétipo inexistente %s" % [vfx_id, arch])

func test_make_attack_burst_builds_particle() -> void:
	var pa := _fb._make_attack_burst(FeedbackSystem._VFX_ARCH[&"fire"], Color(1.0, 0.5, 0.0))
	assert_true(pa is CPUParticles2D, "deve construir um CPUParticles2D")
	assert_gt(pa.amount, 0, "deve emitir partículas")
	assert_true(pa.emitting, "deve estar emitindo (one-shot)")
	pa.queue_free()

func test_unknown_or_empty_vfx_id_is_safe_noop() -> void:
	_fb.spawn_attack_vfx("nao_existe", Vector2.ZERO)
	_fb.spawn_attack_vfx("", Vector2.ZERO)
	assert_true(true, "id desconhecido/vazio não deve quebrar")
