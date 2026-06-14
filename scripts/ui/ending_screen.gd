class_name EndingScreen
extends CanvasLayer

## Cena final (NÃO poupar o Jesuíta) — por do sol sobre a floresta. Mesma
## composição visual do menu principal, mas com SunsetSky no lugar do DoomFire.
## A mensagem no céu fecha a escolha: a guardiã matou — e a floresta segue viva.

const FADE_IN_DURATION: float = 1.2
const SKY_MESSAGE := "a floresta segue respirando"
const SKY_MESSAGE_DELAY: float = 1.6
const SKY_MESSAGE_FADE: float = 2.6

func _ready() -> void:
	if GameState.run_active:
		GameState.end_run(true)
	layer = 20
	_build_scene()

func _build_scene() -> void:
	var sky := SunsetSky.new()
	add_child(sky)

	var far := TitleTreeline.new()
	far.scroll_speed = 5.0
	far.base_y = 560.0
	far.tree_count = 10
	far.tree_scale = 2.0
	far.layer_z = -80
	far.rng_seed = 1
	add_child(far)

	var mid := TitleTreeline.new()
	mid.scroll_speed = 14.0
	mid.base_y = 580.0
	mid.tree_count = 12
	mid.tree_scale = 2.8
	mid.layer_z = -70
	mid.rng_seed = 3
	add_child(mid)

	var embers := TitleEmbers.new()
	add_child(embers)

	var ground := TitleGround.new()
	add_child(ground)

	var walker := TitleWalker.new()
	add_child(walker)

	var atmo := Atmosphere.new()
	add_child(atmo)

	var scrim := ColorRect.new()
	scrim.color = Color(0.0, 0.0, 0.0, 0.25)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var menu_btn := _make_menu_button()
	menu_btn.modulate.a = 0.0
	add_child(menu_btn)

	var sky_msg := _make_sky_message()
	add_child(sky_msg)
	var msg_tween := create_tween()
	msg_tween.tween_interval(SKY_MESSAGE_DELAY)
	msg_tween.tween_property(sky_msg, "modulate:a", 1.0, SKY_MESSAGE_FADE)

	var fade := ColorRect.new()
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

	var t := create_tween()
	t.tween_property(fade, "color:a", 0.0, FADE_IN_DURATION)
	t.parallel().tween_property(menu_btn, "modulate:a", 1.0, FADE_IN_DURATION)

## A mensagem escrita no céu do por do sol, acima da treeline.
func _make_sky_message() -> Label:
	var msg := Label.new()
	msg.text = Lang.t(&"ending.sky")
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", Constants.FONT_LG)
	msg.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	msg.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	msg.add_theme_constant_override("shadow_offset_x", 2)
	msg.add_theme_constant_override("shadow_offset_y", 2)
	msg.anchor_left = 0.0
	msg.anchor_right = 1.0
	msg.anchor_top = 0.18
	msg.anchor_bottom = 0.18
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.modulate.a = 0.0
	return msg

func _make_menu_button() -> Button:
	var btn := Button.new()
	btn.text = Lang.t(&"ending.menu_btn")
	btn.add_theme_font_size_override("font_size", Constants.FONT_MD)
	btn.anchor_left = 0.35
	btn.anchor_right = 0.65
	btn.anchor_top = 0.88
	btn.anchor_bottom = 0.95
	btn.pressed.connect(func() -> void: GameState.change_screen(SignalBus.Screen.MAIN_MENU))
	return btn
