class_name InitialsScreen
extends CanvasLayer

## Tela de entrada de iniciais pós-vitória (PODIO arcade).
## Lê GameState.run_elapsed_seconds (já calculado por end_run), deixa o jogador
## escolher 3 letras A–Z e envia via Supabase. Nunca bloqueia — se a rede falhar,
## exibe erro e redireciona ao HUB assim mesmo.

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var _press_start: Font

var _letters: Array[String] = ["A", "A", "A"]
var _active_slot: int = 0
var _confirmed: bool = false

var _slot_labels: Array[Label] = []
var _slot_panels: Array[PanelContainer] = []
var _status_label: Label
var _http: HTTPRequest


func _ready() -> void:
	layer = 20
	_press_start = load("res://assets/fonts/PressStart2P.ttf")
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.02, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	vbox.custom_minimum_size = Vector2(300, 0)
	center.add_child(vbox)

	# Título
	var title := Label.new()
	title.text = Lang.t(&"initials.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _press_start)
	title.add_theme_color_override("font_color", Color(0.91, 0.45, 0.12))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Tempo da run
	var time_label := Label.new()
	time_label.text = _fmt(GameState.run_elapsed_seconds)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_override("font", _press_start)
	time_label.add_theme_color_override("font_color", Color(0.85, 0.81, 0.79))
	time_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(time_label)

	# Instrução
	var sub := Label.new()
	sub.text = Lang.t(&"initials.sub")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.49, 0.45, 0.44))
	sub.add_theme_font_size_override("font_size", 10)
	vbox.add_child(sub)

	# Slots
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox)

	for i in range(3):
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		hbox.add_child(col)

		var up := _make_arrow_btn("▲", i, 1)
		col.add_child(up)

		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(64, 72)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_slot_style(panel, i == _active_slot)
		panel.gui_input.connect(_on_slot_input.bind(i))
		col.add_child(panel)
		_slot_panels.append(panel)

		var lbl := Label.new()
		lbl.text = _letters[i]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", _press_start)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.81, 0.79))
		lbl.add_theme_font_size_override("font_size", 28)
		panel.add_child(lbl)
		_slot_labels.append(lbl)

		var dn := _make_arrow_btn("▼", i, -1)
		col.add_child(dn)

	# Status
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.706, 0.094, 0.094))
	_status_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_status_label)

	# Botões
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 14)
	vbox.add_child(brow)

	var confirm_btn := Button.new()
	confirm_btn.text = Lang.t(&"initials.confirm")
	confirm_btn.custom_minimum_size = Vector2(150, 44)
	_style_btn_primary(confirm_btn)
	confirm_btn.pressed.connect(_submit)
	brow.add_child(confirm_btn)

	var skip_btn := Button.new()
	skip_btn.text = Lang.t(&"initials.skip")
	skip_btn.custom_minimum_size = Vector2(90, 44)
	_style_btn_ghost(skip_btn)
	skip_btn.pressed.connect(_go_to_hub)
	brow.add_child(skip_btn)

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func _make_arrow_btn(glyph: String, slot: int, direction: int) -> Button:
	var btn := Button.new()
	btn.text = glyph
	btn.flat = true
	btn.custom_minimum_size = Vector2(64, 30)
	btn.add_theme_color_override("font_color", Color(0.49, 0.45, 0.44))
	btn.add_theme_color_override("font_hover_color", Color(0.91, 0.45, 0.12))
	btn.pressed.connect(_cycle.bind(slot, direction))
	return btn


func _apply_slot_style(panel: PanelContainer, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.055, 0.051, 0.051)
	s.set_border_width_all(1)
	s.border_color = Color(0.91, 0.45, 0.12) if active else Color(0.165, 0.078, 0.078)
	panel.add_theme_stylebox_override("panel", s)


func _style_btn_primary(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.706, 0.094, 0.094)
	btn.add_theme_stylebox_override("normal", s)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.91, 0.45, 0.12)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_override("font", _press_start)
	btn.add_theme_font_size_override("font_size", 9)


func _style_btn_ghost(btn: Button) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.set_border_width_all(1)
	s.border_color = Color(0.165, 0.078, 0.078)
	btn.add_theme_stylebox_override("normal", s)
	var h := s.duplicate() as StyleBoxFlat
	h.border_color = Color(0.91, 0.45, 0.12)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", Color(0.49, 0.45, 0.44))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.81, 0.79))
	btn.add_theme_font_override("font", _press_start)
	btn.add_theme_font_size_override("font_size", 9)


func _cycle(slot: int, dir: int) -> void:
	var idx: int = LETTERS.find(_letters[slot])
	idx = (idx + dir + 26) % 26
	_letters[slot] = LETTERS[idx]
	_slot_labels[slot].text = _letters[slot]


func _select_slot(slot: int) -> void:
	_active_slot = slot
	for i in range(3):
		_apply_slot_style(_slot_panels[i], i == _active_slot)


func _on_slot_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_select_slot(slot)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_select_slot(slot)


func _input(event: InputEvent) -> void:
	if _confirmed:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_LEFT:
			_select_slot((_active_slot - 1 + 3) % 3)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_select_slot((_active_slot + 1) % 3)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_cycle(_active_slot, 1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_cycle(_active_slot, -1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_submit()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_go_to_hub()
			get_viewport().set_input_as_handled()


func _submit() -> void:
	if _confirmed:
		return
	_confirmed = true
	_status_label.text = Lang.t(&"initials.sending")
	_status_label.add_theme_color_override("font_color", Color(0.49, 0.45, 0.44))
	var initials := _letters[0] + _letters[1] + _letters[2]
	var body := JSON.stringify({
		"action": "submit_podio",
		"initials": initials,
		"time_secs": GameState.run_elapsed_seconds,
	})
	var err := _http.request(
		SupabaseConfig.endpoint(),
		SupabaseConfig.headers(),
		HTTPClient.METHOD_POST,
		body,
	)
	if err != OK:
		_go_to_hub()


func _on_request_completed(_result: int, code: int, _headers: PackedStringArray, _raw: PackedByteArray) -> void:
	if code != 200:
		_status_label.text = Lang.t(&"initials.error")
		_status_label.add_theme_color_override("font_color", Color(0.706, 0.094, 0.094))
		_confirmed = false
		return
	_status_label.text = Lang.t(&"initials.saved")
	_status_label.add_theme_color_override("font_color", Color(0.31, 0.68, 0.33))
	get_tree().create_timer(0.8).timeout.connect(_go_to_hub)


func _go_to_hub() -> void:
	GameState.change_screen(SignalBus.Screen.HUB)


func _fmt(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 60, seconds % 60]
