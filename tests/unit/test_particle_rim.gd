extends GutTest

# ParticleRim (modo HD): extração de silhueta, gate por Quality, idempotência,
# material compartilhado (batching) e evolução da protagonista por tier de Fúria.

const PLAYER_IDLE := preload("res://assets/sprites/player_idle.png")

var _sprite: AnimatedSprite2D
var _saved_upgrades: Dictionary
var _saved_chama: bool

func before_each() -> void:
	Quality._set_for_test(true)
	_saved_upgrades = MetaProgression.upgrades.duplicate()
	_saved_chama = MetaProgression.has_chama
	_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", PLAYER_IDLE)
	_sprite.sprite_frames = frames
	add_child_autofree(_sprite)

func after_each() -> void:
	Quality._reset_for_test()
	MetaProgression.upgrades = _saved_upgrades
	MetaProgression.has_chama = _saved_chama

# ── Silhueta: pontos na borda, dentro do rect centrado, normais unitárias ──
func test_edge_extraction() -> void:
	var data := ParticleRim._edge_data(PLAYER_IDLE)
	var points: PackedVector2Array = data["points"]
	var normals: PackedVector2Array = data["normals"]
	assert_gt(points.size(), 0, "silhueta da Caipora tem pontos de borda")
	assert_eq(points.size(), normals.size(), "uma normal por ponto")
	assert_lte(points.size(), ParticleRim.MAX_POINTS, "teto de pontos respeitado")
	var half := Vector2(PLAYER_IDLE.get_size()) * 0.5
	var all_inside := true
	var all_unit := true
	for i in range(points.size()):
		if absf(points[i].x) > half.x or absf(points[i].y) > half.y:
			all_inside = false
		if absf(normals[i].length() - 1.0) > 0.01:
			all_unit = false
	assert_true(all_inside, "todos os pontos dentro do rect centrado da textura")
	assert_true(all_unit, "normais unitárias")

func test_edge_cache_reuses_data() -> void:
	var a := ParticleRim._edge_data(PLAYER_IDLE)
	var b := ParticleRim._edge_data(PLAYER_IDLE)
	assert_true(is_same(a, b), "segunda consulta devolve o cache, não re-extrai")

# ── Gate: HD desligado = modo leve byte a byte ──
func test_hd_off_attaches_nothing() -> void:
	Quality._set_for_test(false)
	ParticleRim.attach_to(_sprite, Constants.COLOR_RIM_ENEMY)
	assert_null(_sprite.get_node_or_null("ParticleRim"), "modo leve não instancia o rim")

func test_hd_on_attaches_rim_with_shared_material() -> void:
	ParticleRim.attach_to(_sprite, Constants.COLOR_RIM_ENEMY)
	var rim := _sprite.get_node_or_null("ParticleRim")
	assert_not_null(rim, "rim anexado com HD ligado")
	var dust := rim.get_node_or_null("RimDust") as CPUParticles2D
	assert_not_null(dust, "emissor de contorno existe")
	assert_eq(dust.material, Constants.ADDITIVE_MATERIAL,
		"glow usa o recurso compartilhado (batching do Compatibility)")
	assert_gt(dust.amount, 0, "amount positivo")
	assert_eq(dust.emission_shape, CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS,
		"emite dos pontos da silhueta")
	assert_false(dust.local_coords, "global coords: descola no movimento (micro-rastro)")
	assert_null(rim.get_node_or_null("RimSparks"), "sem spark_color = sem faíscas")

func test_attach_is_idempotent() -> void:
	ParticleRim.attach_to(_sprite, Constants.COLOR_RIM_ENEMY)
	ParticleRim.attach_to(_sprite, Constants.COLOR_RIM_ENEMY)
	var count := 0
	for child in _sprite.get_children():
		if String(child.name).begins_with("ParticleRim"):
			count += 1
	assert_eq(count, 1, "re-attach substitui, não acumula")

# ── Protagonista: laranja domina, esquenta com o tier, faísca verde é rara ──
func test_caipora_rim_heats_with_furia_tier() -> void:
	for key in MetaProgression.FURIA_KEYS:
		MetaProgression.upgrades.erase(key)
	MetaProgression.has_chama = false
	ParticleRim.attach_caipora(_sprite)
	var dust := _sprite.get_node("ParticleRim/RimDust") as CPUParticles2D
	assert_eq(dust.color, ParticleRim._overbright(Constants.COLOR_JUBA),
		"tier 0: laranja da juba (overbright p/ glow)")
	assert_null(_sprite.get_node_or_null("ParticleRim/RimSparks"),
		"tier < 3: sem faísca verde (verde é acento raro)")

	for key in MetaProgression.FURIA_KEYS:
		MetaProgression.upgrades[key] = 1
	ParticleRim.attach_caipora(_sprite)
	dust = _sprite.get_node("ParticleRim/RimDust") as CPUParticles2D
	assert_eq(dust.color, ParticleRim._overbright(Constants.COLOR_CHAMA_HOT),
		"tier 6: brasa quente")
	var sparks := _sprite.get_node_or_null("ParticleRim/RimSparks") as CPUParticles2D
	assert_not_null(sparks, "tier >= 3 ganha a faísca do cristal")
	assert_lt(sparks.amount, dust.amount, "faísca verde nunca domina o laranja")

func test_caipora_rim_chama_overrides_ramp() -> void:
	MetaProgression.has_chama = true
	ParticleRim.attach_caipora(_sprite)
	var dust := _sprite.get_node("ParticleRim/RimDust") as CPUParticles2D
	assert_eq(dust.color,
		ParticleRim._overbright(Constants.COLOR_CHAMA_HOT.lerp(Constants.COLOR_CHAMA_CORE, 0.35)),
		"CHAMA clareia o rim para brasa viva")
