class_name OptionsPanel
extends CanvasLayer

## Overlay de Opcoes enxuto: Volume global + apagar progresso.

# ─── Constants ─────────────────────────────────────
const OVERLAY_LAYER: int = 60
const DIM_BG := Color(0, 0, 0, 0.6)
const RESET_CONFIRM_WINDOW: float = 3.0
const RESTART_FADE: float = 0.22
const BUS_VOLUME := "Master"

# ─── State ─────────────────────────────────────────
var _close_button: Button
var _volume_label: Label
var _volume_slider: HSlider
var _last_focus: Control
var _title_label: Label
var _reset_button: Button
var _reset_armed: bool = false
var _restart_fade: ColorRect

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = OVERLAY_LAYER
	visible = false
	_build()
	Lang.language_changed.connect(_refresh_text)

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM_BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := BrandPanel.new()
	panel.framed = true
	panel.scrim_alpha = 0.96  # modal quase opaco (leitura sobre o gameplay)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", Constants.SPACE_MD)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = Lang.t(&"options.title")
	_title_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_title_label.add_theme_font_size_override("font_size", Constants.FONT_LG)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_add_volume_row(vbox)
	_add_reset_row(vbox)

	_close_button = Button.new()
	_close_button.text = Lang.t(&"options.close")
	_close_button.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_close_button.pressed.connect(close)
	vbox.add_child(_close_button)
	for control: Control in [_volume_slider, _reset_button, _close_button]:
		_hook_hover(control)

	_restart_fade = ColorRect.new()
	_restart_fade.color = Color(0, 0, 0, 0)
	_restart_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_restart_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restart_fade.visible = false
	add_child(_restart_fade)

func _add_volume_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Constants.SPACE_SM)

	_volume_label = Label.new()
	_volume_label.text = Lang.t(&"options.volume")
	_volume_label.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	_volume_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_volume_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(_volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = AudioDirector.get_bus_volume(BUS_VOLUME)
	_volume_slider.custom_minimum_size = Vector2(240, 0)
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	row.add_child(_volume_slider)
	parent.add_child(row)

func _add_reset_row(parent: VBoxContainer) -> void:
	_reset_button = Button.new()
	_reset_button.text = Lang.t(&"options.reset")
	_reset_button.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_reset_button.add_theme_color_override("font_color", Constants.COLOR_BLOOD)
	_reset_button.pressed.connect(_on_reset_pressed)
	parent.add_child(_reset_button)

func _refresh_text(_lang: StringName = Lang.current()) -> void:
	if _title_label != null:
		_title_label.text = Lang.t(&"options.title")
	if _volume_label != null:
		_volume_label.text = Lang.t(&"options.volume")
	if _close_button != null:
		_close_button.text = Lang.t(&"options.close")
	if _reset_button != null and not _reset_armed:
		_reset_button.text = Lang.t(&"options.reset")

func _hook_hover(control: Control) -> void:
	control.focus_entered.connect(AudioDirector.play_ui_hover)
	control.mouse_entered.connect(AudioDirector.play_ui_hover)

func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = Lang.t(&"options.reset.confirm")
		await get_tree().create_timer(RESET_CONFIRM_WINDOW).timeout
		if _reset_armed:
			_disarm_reset()
		return
	_reset_armed = false
	MetaProgression.reset_save()
	_reset_button.text = Lang.t(&"options.reset.done")
	_restart_clean_session()

func _disarm_reset() -> void:
	_reset_armed = false
	if is_instance_valid(_reset_button):
		_reset_button.text = Lang.t(&"options.reset")

func _restart_clean_session() -> void:
	_restart_fade.visible = true
	_restart_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_restart_fade, "color:a", 1.0, RESTART_FADE)
	tween.tween_callback(func() -> void:
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.location.reload()", true)
		else:
			GameState.change_screen(SignalBus.Screen.MAIN_MENU))

# ─── Public API ────────────────────────────────────
func open() -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	_disarm_reset()
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(AudioDirector.get_bus_volume(BUS_VOLUME))
	visible = true
	if _volume_slider != null:
		_volume_slider.grab_focus()

func close() -> void:
	visible = false
	if is_instance_valid(_last_focus):
		_last_focus.grab_focus()

# ─── Private ───────────────────────────────────────
func _on_volume_changed(value: float) -> void:
	AudioDirector.set_bus_volume(BUS_VOLUME, value)
