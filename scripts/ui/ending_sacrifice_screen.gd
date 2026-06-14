class_name EndingSacrificeScreen
extends CanvasLayer

## Final do SACRIFÍCIO (poupar o Jesuíta). A misericórdia foi paga com água
## benta: a Caipora morreu e a floresta virou cristã. Amanhecer frio e
## alvejado — o oposto exato do por do sol vivo do EndingScreen: sol pálido
## como hóstia, treelines PARADAS (sway zero: a mata não respira mais), um
## cemitério de cruzes onde havia mato, e o corpo da guardiã apagando ao pé
## de uma cruz. O sino da igreja dobra (AudioDirector); não há música.
##
## O horror aqui não é sangue: é silêncio. Mas o sangue também está — real,
## empoçado sob ela. Não suavizar.

const FADE_IN_DURATION: float = 1.8
const MESSAGE_1 := "a caipora não respira mais"
const MESSAGE_2 := "a floresta virou cristã"
const MESSAGE_1_DELAY: float = 2.2
const MESSAGE_FADE: float = 2.4
const MESSAGE_2_GAP: float = 1.4
const BODY_DIM_DURATION: float = 16.0

# Céu frio: noite de cinza no topo → osso no horizonte (bandas, como SunsetSky).
const SKY_BANDS: int = 60
const _SKY_STOPS: Array = [
	[0.00, Color(0.13, 0.16, 0.21)],
	[0.40, Color(0.36, 0.42, 0.48)],
	[0.72, Color(0.62, 0.65, 0.66)],
	[1.00, Color(0.82, 0.79, 0.71)],
]

const CAIPORA_DEAD_PATH := "res://assets/sprites/player_dead.png"
const GROUND_CREST_Y := 560.0
const CROSS_COUNT := 14

var _crest_y_px: float = 0.0
var _body: Sprite2D
var _body_pos: Vector2 = Vector2.ZERO
var _body_scale: float = 2.0

func _ready() -> void:
	if GameState.run_active:
		GameState.end_run(true)
	layer = 20
	_build_scene()

func _build_scene() -> void:
	var vp := get_viewport().get_visible_rect().size
	_crest_y_px = GROUND_CREST_Y / 720.0 * vp.y

	var sky := BackdropLayer.new()
	sky.z_index = -100
	sky.draw_callback = _draw_cold_sky
	add_child(sky)

	# Treelines mortas e PARADAS: sway_amount 0 — nem o vento sobrou.
	var far := TitleTreeline.new()
	far.scroll_speed = 0.0
	far.sway_amount = 0.0
	far.silhouette_color = Color(0.38, 0.42, 0.46)
	far.base_y = 560.0
	far.tree_count = 10
	far.tree_scale = 2.0
	far.layer_z = -80
	far.rng_seed = 1
	add_child(far)

	var mid := TitleTreeline.new()
	mid.scroll_speed = 0.0
	mid.sway_amount = 0.0
	mid.silhouette_color = Color(0.24, 0.27, 0.31)
	mid.base_y = 580.0
	mid.tree_count = 12
	mid.tree_scale = 2.8
	mid.layer_z = -70
	mid.rng_seed = 3
	add_child(mid)

	var ground := TitleGround.new()
	ground.ground_color = Color(0.14, 0.15, 0.17)
	add_child(ground)

	# Onde havia mato, fiadas de cruzes — a floresta virou cemitério batizado.
	var graveyard := BackdropLayer.new()
	graveyard.z_index = -45
	graveyard.draw_callback = _draw_graveyard
	add_child(graveyard)

	_build_body(vp)

	add_child(Atmosphere.new())

	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.18)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var msg1 := _make_sky_message(Lang.t(&"sacrifice.msg1"), 0.16, Constants.COLOR_TEXT)
	add_child(msg1)
	var msg2 := _make_sky_message(Lang.t(&"sacrifice.msg2"), 0.24, Constants.COLOR_BAPTISM_TINT)
	add_child(msg2)

	var menu_btn := _make_menu_button()
	menu_btn.modulate.a = 0.0
	add_child(menu_btn)

	var fade := ColorRect.new()
	# Nasce do BRANCO da água benta (handoff do _spare_beat), não do breu.
	fade.color = Color(0.92, 0.94, 0.98, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	var t := create_tween()
	t.tween_property(fade, "color:a", 0.0, FADE_IN_DURATION)
	t.parallel().tween_property(menu_btn, "modulate:a", 1.0, FADE_IN_DURATION)

	var msgs := create_tween()
	msgs.tween_interval(MESSAGE_1_DELAY)
	msgs.tween_property(msg1, "modulate:a", 1.0, MESSAGE_FADE)
	msgs.tween_interval(MESSAGE_2_GAP)
	msgs.tween_property(msg2, "modulate:a", 1.0, MESSAGE_FADE)

func _build_body(vp: Vector2) -> void:
	_body_scale = clampf(minf(vp.x, vp.y) / 160.0, 2.0, 4.2)
	# A pose deitada vive na metade baixa do canvas 96 (conteudo ~y49..92,
	# centro ~y71): subir 23px de canvas assenta o corpo NA crista.
	_body_pos = Vector2(vp.x * 0.42, _crest_y_px - 27.0 * _body_scale)

	# A poça sob o corpo — a água benta não lavou o sangue.
	var blood := BackdropLayer.new()
	blood.z_index = -42
	blood.draw_callback = _draw_blood
	add_child(blood)

	# O corpo da guardiã, tombado (pose "dead" do gen_caipora.py: sem olhos,
	# mortalha de juba, cajado caído). SEMPRE a variante base: a CHAMA morreu com ela.
	_body = Sprite2D.new()
	_body.texture = load(CAIPORA_DEAD_PATH)
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.position = _body_pos
	_body.scale = Vector2(_body_scale, _body_scale)
	_body.z_index = -40
	add_child(_body)

	# A vida saindo: a mancha laranja apaga devagar para a cinza da conversão.
	var dim := create_tween()
	dim.tween_property(_body, "modulate", Color(0.74, 0.66, 0.68), BODY_DIM_DURATION) \
		.set_trans(Tween.TRANS_SINE)

	# Cinza sobe do corpo — o que sobrou do fogo dela.
	var ash := CPUParticles2D.new()
	ash.position = _body_pos + Vector2(2.0 * _body_scale, 18.0 * _body_scale)
	ash.z_index = -39
	ash.amount = 16
	ash.lifetime = 6.0
	ash.preprocess = 6.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(24.0 * _body_scale, 5.0)
	ash.direction = Vector2(0, -1)
	ash.spread = 16.0
	ash.gravity = Vector2(0, -8.0)
	ash.initial_velocity_min = 6.0
	ash.initial_velocity_max = 18.0
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 2.2
	ash.color_ramp = _ash_ramp()
	ash.material = Constants.ADDITIVE_MATERIAL
	add_child(ash)

func _draw_cold_sky(canvas: Node2D) -> void:
	var vp := get_viewport().get_visible_rect().size
	var band_h: float = vp.y / float(SKY_BANDS) + 1.0
	for i: int in SKY_BANDS:
		var t: float = float(i) / float(SKY_BANDS - 1)
		canvas.draw_rect(Rect2(0.0, t * vp.y - band_h * 0.5, vp.x, band_h), _sky_color(t))
	# Sol pálido e redondo como hóstia — frio, sem calor nenhum.
	var s := Vector2(vp.x * 0.62, vp.y * 0.42)
	canvas.draw_circle(s, 54.0, Color(0.95, 0.95, 0.92, 0.16))
	canvas.draw_circle(s, 40.0, Color(0.97, 0.97, 0.94, 0.30))
	canvas.draw_circle(s, 30.0, Color(0.99, 0.99, 0.97))

func _sky_color(t: float) -> Color:
	for i: int in range(_SKY_STOPS.size() - 1):
		var t0: float = _SKY_STOPS[i][0]
		var t1: float = _SKY_STOPS[i + 1][0]
		if t <= t1:
			var f: float = (t - t0) / (t1 - t0)
			return (_SKY_STOPS[i][1] as Color).lerp(_SKY_STOPS[i + 1][1], f)
	return _SKY_STOPS[-1][1]

func _draw_graveyard(canvas: Node2D) -> void:
	var vp := get_viewport().get_visible_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Fiadas de cruzes pequenas cravadas na crista — uma por entidade enterrada.
	for i: int in CROSS_COUNT:
		var x := vp.x * (0.04 + 0.92 * float(i) / float(CROSS_COUNT - 1)) \
			+ rng.randf_range(-12.0, 12.0)
		# Vão central: o corpo e a cruz grande dela dominam o meio do quadro.
		if absf(x - vp.x * 0.42) < vp.x * 0.15:
			continue
		var s := rng.randf_range(0.7, 1.3) * _body_scale * 0.5
		var y := _crest_y_px + rng.randf_range(-6.0, 10.0)
		_draw_cross(canvas, Vector2(x, y), s, Constants.COLOR_WOOD_DARK)
	# A cruz GRANDE plantada sobre a guardiã — enterraram a floresta com ela.
	var big_cross := Vector2(_body_pos.x + 30.0 * _body_scale, _crest_y_px + 2.0)
	_draw_cross(canvas, big_cross, _body_scale * 1.6, Constants.COLOR_WOOD_DARK)
	canvas.draw_rect(Rect2(big_cross.x - 1.0 * _body_scale,
		big_cross.y - 44.0 * _body_scale * 1.6, 2.0 * _body_scale,
		44.0 * _body_scale * 1.6), Constants.COLOR_GOLD_DARK)

func _draw_cross(canvas: Node2D, base: Vector2, s: float, col: Color) -> void:
	var h := 44.0 * s
	var w := 6.0 * s
	canvas.draw_rect(Rect2(base.x - w * 0.5, base.y - h, w, h), col)
	canvas.draw_rect(Rect2(base.x - 11.0 * s, base.y - h + 9.0 * s, 22.0 * s, 5.0 * s), col)

func _draw_blood(canvas: Node2D) -> void:
	var p := _body_pos + Vector2(-26.0 * _body_scale, 26.0 * _body_scale)
	canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.30))
	canvas.draw_circle(Vector2.ZERO, 18.0 * _body_scale, Constants.COLOR_BLOOD_POOL_DARK)
	canvas.draw_circle(Vector2(3.0, 1.0), 11.0 * _body_scale, Constants.COLOR_BLOOD_POOL)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _ash_ramp() -> Gradient:
	var c := Color(0.80, 0.80, 0.82)
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(c.r, c.g, c.b, 0.0))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(c.r, c.g, c.b, 0.0))
	grad.add_point(0.4, Color(c.r, c.g, c.b, 0.30))
	return grad

func _make_sky_message(text: String, anchor_y: float, color: Color) -> Label:
	var msg := Label.new()
	msg.text = text
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", Constants.FONT_LG)
	msg.add_theme_color_override("font_color", color)
	msg.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	msg.add_theme_constant_override("shadow_offset_x", 2)
	msg.add_theme_constant_override("shadow_offset_y", 2)
	msg.anchor_left = 0.0
	msg.anchor_right = 1.0
	msg.anchor_top = anchor_y
	msg.anchor_bottom = anchor_y
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.modulate.a = 0.0
	return msg

func _make_menu_button() -> Button:
	var btn := Button.new()
	btn.text = Lang.t(&"sacrifice.menu_btn")
	btn.add_theme_font_size_override("font_size", Constants.FONT_MD)
	btn.anchor_left = 0.35
	btn.anchor_right = 0.65
	btn.anchor_top = 0.88
	btn.anchor_bottom = 0.95
	btn.pressed.connect(func() -> void: GameState.change_screen(SignalBus.Screen.MAIN_MENU))
	return btn
