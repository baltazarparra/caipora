extends GutTest

# Contrato do SpriteFrames do Boitatá (emitido POR CÓDIGO por gen_boitata.py).
# Art law: docs/CONCEITO-boitata.md §5 — os NOMES e a forma das animações são
# estáveis: boitata.tscn, camp_spirit e boss_intro dependem só deles.

const FRAMES_PATH := "res://assets/sprites/boitata_sprite_frames.tres"
const FRAME_SIZE := Vector2(160, 128)

# anim → [frame_count, loop, speed]
const CONTRACT: Dictionary = {
	&"idle": [5, true, 5.0],
	&"windup": [3, false, 15.0],
}

func _frames() -> SpriteFrames:
	var frames := load(FRAMES_PATH) as SpriteFrames
	assert_not_null(frames, "boitata_sprite_frames.tres carrega como SpriteFrames")
	return frames

func test_animations_match_contract() -> void:
	var frames := _frames()
	if frames == null:
		return
	for anim: StringName in CONTRACT:
		assert_true(frames.has_animation(anim), "tem animacao %s" % anim)
		if not frames.has_animation(anim):
			continue
		var expected: Array = CONTRACT[anim]
		assert_eq(frames.get_frame_count(anim), expected[0] as int,
			"%s tem %d frames" % [anim, expected[0]])
		assert_eq(frames.get_animation_loop(anim), expected[1] as bool,
			"%s loop=%s" % [anim, expected[1]])
		assert_eq(frames.get_animation_speed(anim), expected[2] as float,
			"%s speed=%s" % [anim, expected[2]])

func test_every_frame_is_160x128() -> void:
	var frames := _frames()
	if frames == null:
		return
	for anim: StringName in CONTRACT:
		for i: int in range(frames.get_frame_count(anim)):
			var tex := frames.get_frame_texture(anim, i)
			assert_not_null(tex, "%s frame %d tem textura" % [anim, i])
			if tex != null:
				assert_eq(tex.get_size(), FRAME_SIZE,
					"%s frame %d mantem 160x128" % [anim, i])

func test_anchor_frames_point_to_canonical_pngs() -> void:
	# Frame 0 do idle = boitata_idle.png (âncora byte-estável do gerador);
	# último frame do windup = boitata_windup.png (pose canônica do telegraph,
	# segurada pelo loop=false).
	var frames := _frames()
	if frames == null:
		return
	var idle0 := frames.get_frame_texture(&"idle", 0)
	assert_true(idle0.resource_path.ends_with("boitata_idle.png"),
		"idle frame 0 é boitata_idle.png (leu %s)" % idle0.resource_path)
	var last := frames.get_frame_count(&"windup") - 1
	var windup_held := frames.get_frame_texture(&"windup", last)
	assert_true(windup_held.resource_path.ends_with("boitata_windup.png"),
		"windup segura boitata_windup.png no último frame (leu %s)" % windup_held.resource_path)

func test_windup_cabe_no_windup_mais_curto() -> void:
	# O wind_up mais curto do kit dele (Brasa Rasteira) dura 0.2s: a animação
	# inteira precisa caber para o build-up completar o telegraph.
	var frames := _frames()
	if frames == null:
		return
	var duration := frames.get_frame_count(&"windup") / frames.get_animation_speed(&"windup")
	assert_true(duration <= 0.2 + 0.001,
		"windup completa em %.3fs (<= 0.2s da Brasa Rasteira)" % duration)
