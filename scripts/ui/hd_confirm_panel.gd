class_name HdConfirmPanel
extends CanvasLayer

## Confirmação do toggle HD ("Ligar HD"/"Desligar HD"): ação drástica — o jogo
## RECARREGA (web) para bootar no modo escolhido. Molde do OptionsPanel, mas com
## Confirmar/Cancelar explícitos (não o arm-2-cliques do reset).
##
## No web o reload navega com `?hd=` mesclado na URL (não `reload()` puro): o
## syncfs do IndexedDB é assíncrono e o cfg recém-salvo pode não ter persistido —
## a URL é a autoridade do boot (ver Quality).

# ─── Constants ─────────────────────────────────────
const OVERLAY_LAYER: int = 60
const DIM_BG := Color(0, 0, 0, 0.6)
const RESTART_FADE: float = 0.22
const BODY_MIN_WIDTH := 240.0
const RELOAD_JS := "var u = new URL(window.location.href); " + \
	"u.searchParams.set('hd', '%s'); window.location.href = u.toString();"

# ─── State ─────────────────────────────────────────
var _turn_on: bool = false
var _title_label: Label
var _body_label: Label
var _confirm_button: Button
var _cancel_button: Button
var _restart_fade: ColorRect
var _last_focus: Control

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
	panel.scrim_alpha = 0.96
	panel.pad_extra = Vector2i(Constants.SPACE_XS, Constants.SPACE_SM)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", Constants.SPACE_LG)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_title_label.add_theme_font_size_override("font_size", Constants.FONT_LG)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	_body_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(BODY_MIN_WIDTH, 0)
	vbox.add_child(_body_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", Constants.SPACE_LG)
	vbox.add_child(row)

	_confirm_button = Button.new()
	_confirm_button.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_confirm_button.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_confirm_button.pressed.connect(_on_confirm)
	row.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_cancel_button.pressed.connect(close)
	row.add_child(_cancel_button)

	for control: Control in [_confirm_button, _cancel_button]:
		control.focus_entered.connect(AudioDirector.play_ui_hover)
		control.mouse_entered.connect(AudioDirector.play_ui_hover)

	_restart_fade = ColorRect.new()
	_restart_fade.color = Color(0, 0, 0, 0)
	_restart_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_restart_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restart_fade.visible = false
	add_child(_restart_fade)

func _refresh_text(_lang: StringName = Lang.current()) -> void:
	if _title_label == null:
		return
	_title_label.text = Lang.t(&"hd.confirm.title.on" if _turn_on else &"hd.confirm.title.off")
	_body_label.text = Lang.t(&"hd.confirm.body.on" if _turn_on else &"hd.confirm.body.off")
	_confirm_button.text = Lang.t(&"hd.confirm.ok")
	_cancel_button.text = Lang.t(&"hd.confirm.cancel")

# ─── Public API ────────────────────────────────────
func open(turn_on: bool) -> void:
	_turn_on = turn_on
	_refresh_text()
	_last_focus = get_viewport().gui_get_focus_owner()
	visible = true
	_cancel_button.grab_focus()

func close() -> void:
	visible = false
	if is_instance_valid(_last_focus):
		_last_focus.grab_focus()

## Persiste a escolha (separado do fade/reload para ser testável).
func apply_choice() -> void:
	Quality.set_hd_enabled(_turn_on)

# ─── Private ───────────────────────────────────────
func _on_confirm() -> void:
	AudioDirector.play_ui_hover()
	# Persistir ANTES do fade maximiza a janela do syncfs no web.
	apply_choice()
	_restart()

func _restart() -> void:
	_restart_fade.visible = true
	_restart_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_restart_fade, "color:a", 1.0, RESTART_FADE)
	tween.tween_callback(func() -> void:
		if OS.has_feature("web"):
			JavaScriptBridge.eval(RELOAD_JS % ("1" if _turn_on else "0"), true)
		else:
			GameState.change_screen(SignalBus.Screen.MAIN_MENU))
