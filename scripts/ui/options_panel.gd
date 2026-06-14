class_name OptionsPanel
extends CanvasLayer

## Overlay de Opções reutilizável, construído em código (espelha o padrão do
## Atmosphere). Instanciado por main_menu e hub; mostra/esconde sobre a tela atual
## sem tocar na máquina de telas. Sliders ligados ao AudioDirector (que persiste em
## user://settings.cfg).

# ─── Constants ─────────────────────────────────────
const OVERLAY_LAYER: int = 60
const PANEL_BG := Color(0.051, 0.067, 0.09, 0.96)
const DIM_BG := Color(0, 0, 0, 0.6)
const ACCENT := Color(0.545, 0, 0, 1)
const TEXT := Color(0.788, 0.82, 0.851, 1)

# Bus names batem com default_bus_layout.tres / AudioDirector — não traduzir.
const ROWS: Array = [
	[&"options.audio.master",  "Master"],
	[&"options.audio.sfx",     "SFX"],
	[&"options.audio.music",   "Music"],
	[&"options.audio.ambience","Ambience"],
]

# Janela para o 2º clique confirmar o reset antes de desarmar sozinho.
const RESET_CONFIRM_WINDOW: float = 3.0
const DANGER := Color(0.78, 0.1, 0.1, 1)

# ─── State ─────────────────────────────────────────
var _close_button: Button
var _first_slider: HSlider
var _last_focus: Control
var _title_label: Label
var _touch_label: Label
var _lang_option: OptionButton

var _touch_option: OptionButton
var _reset_button: Button
var _reset_armed: bool = false

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
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # bloqueia cliques na tela de baixo
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = ACCENT
	style.set_border_width_all(2)  # bordas duras, sem cantos arredondados
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = Lang.t(&"options.title")
	_title_label.add_theme_color_override("font_color", ACCENT)
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	for row in ROWS:
		_add_slider_row(vbox, row[0], row[1])

	_add_language_row(vbox)
	_add_touch_controls_row(vbox)
	_add_reset_row(vbox)

	_close_button = Button.new()
	_close_button.text = Lang.t(&"options.close")
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.pressed.connect(close)
	vbox.add_child(_close_button)
	for control: Control in [_touch_option, _reset_button, _close_button]:
		_hook_hover(control)

## Atualiza todos os textos ao vivo quando o idioma muda.
func _refresh_text(_lang: StringName = Lang.current()) -> void:
	if _title_label != null:
		_title_label.text = Lang.t(&"options.title")
	if _touch_label != null:
		_touch_label.text = Lang.t(&"options.touch")
	if _close_button != null:
		_close_button.text = Lang.t(&"options.close")
	if _reset_button != null and not _reset_armed:
		_reset_button.text = Lang.t(&"options.reset")
	# Sliders não têm label refs guardados — recreate seria pesado; apenas title/close/touch.

## Tick de hover/foco central no AudioDirector (cooldown lá colapsa foco+mouse).
func _hook_hover(control: Control) -> void:
	control.focus_entered.connect(AudioDirector.play_ui_hover)
	control.mouse_entered.connect(AudioDirector.play_ui_hover)

func _add_language_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = Lang.t(&"options.language")
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 14)
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)

	_lang_option = OptionButton.new()
	# Nomes de idioma sempre no idioma deles próprios (convenção UX universal).
	_lang_option.add_item("Português", 0)
	_lang_option.add_item("English", 1)
	_lang_option.custom_minimum_size = Vector2(220, 0)
	_lang_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lang_option.select(0 if Lang.current() == Lang.LANG_PT else 1)
	_lang_option.item_selected.connect(_on_lang_changed)
	_hook_hover(_lang_option)
	row.add_child(_lang_option)
	parent.add_child(row)

func _add_touch_controls_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	_touch_label = Label.new()
	_touch_label.text = Lang.t(&"options.touch")
	_touch_label.add_theme_color_override("font_color", TEXT)
	_touch_label.add_theme_font_size_override("font_size", 14)
	_touch_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(_touch_label)

	var option := OptionButton.new()
	option.add_item(Lang.t(&"options.touch.auto"),   0)
	option.add_item(Lang.t(&"options.touch.always"), 1)
	option.add_item(Lang.t(&"options.touch.never"),  2)
	option.custom_minimum_size = Vector2(220, 0)
	option.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var mode := MetaProgression.get_touch_controls_mode()
	match mode:
		"auto":   option.select(0)
		"always": option.select(1)
		"never":  option.select(2)

	option.item_selected.connect(_on_touch_mode_changed)
	row.add_child(option)
	parent.add_child(row)
	_touch_option = option

## Botão de perigo para apagar o progresso. Confirmação em dois passos no próprio botão
## (sem ConfirmationDialog, que tem foco problemático no mobile/touch).
func _add_reset_row(parent: VBoxContainer) -> void:
	_reset_button = Button.new()
	_reset_button.text = Lang.t(&"options.reset")
	_reset_button.add_theme_font_size_override("font_size", 14)
	_reset_button.add_theme_color_override("font_color", DANGER)
	_reset_button.pressed.connect(_on_reset_pressed)
	parent.add_child(_reset_button)

func _on_reset_pressed() -> void:
	if not _reset_armed:
		# 1º clique: arma e dá uma janela para confirmar antes de desarmar sozinho.
		_reset_armed = true
		_reset_button.text = Lang.t(&"options.reset.confirm")
		await get_tree().create_timer(RESET_CONFIRM_WINDOW).timeout
		if _reset_armed:
			_disarm_reset()
		return
	# 2º clique dentro da janela: apaga de fato.
	_reset_armed = false
	MetaProgression.reset_save()
	_reset_button.text = Lang.t(&"options.reset.done")
	if _touch_option != null:
		_touch_option.select(0)  # reflete touch_controls_mode = "auto"

func _disarm_reset() -> void:
	_reset_armed = false
	if is_instance_valid(_reset_button):
		_reset_button.text = Lang.t(&"options.reset")

func _on_lang_changed(index: int) -> void:
	Lang.set_language(Lang.LANG_PT if index == 0 else Lang.LANG_EN)

func _on_touch_mode_changed(index: int) -> void:
	match index:
		0: MetaProgression.set_touch_controls_mode("auto")
		1: MetaProgression.set_touch_controls_mode("always")
		2: MetaProgression.set_touch_controls_mode("never")

func _add_slider_row(parent: VBoxContainer, label_key: StringName, bus_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = Lang.t(label_key)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 14)
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = AudioDirector.get_bus_volume(bus_name)
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(_on_slider_changed.bind(bus_name))
	_hook_hover(slider)
	row.add_child(slider)

	if _first_slider == null:
		_first_slider = slider

	parent.add_child(row)

# ─── Public API ────────────────────────────────────
func open() -> void:
	# Recarrega os valores correntes (caso tenham mudado em outra tela).
	_last_focus = get_viewport().gui_get_focus_owner()
	_disarm_reset()  # nunca reabrir com o reset armado/concluído pendente
	if _lang_option != null:
		_lang_option.select(0 if Lang.current() == Lang.LANG_PT else 1)
	visible = true
	if _first_slider != null:
		_first_slider.grab_focus()

func close() -> void:
	visible = false
	if is_instance_valid(_last_focus):
		_last_focus.grab_focus()

# ─── Private ───────────────────────────────────────
func _on_slider_changed(value: float, bus_name: String) -> void:
	AudioDirector.set_bus_volume(bus_name, value)
