extends GutTest

const BOITATA_LINES: Array[Dictionary] = [
	{"speaker": "CAIPORA", "text": "Você nos traiu..."},
	{"speaker": "BOITATÁ", "text": "Vocês me abandonaram!"},
]

var _screen: DialogueScreen

func before_each() -> void:
	_screen = preload("res://scenes/ui/dialogue_screen.tscn").instantiate()
	add_child_autofree(_screen)

func test_start_shows_boss_name() -> void:
	_screen.start("BOITATÁ", BOITATA_LINES)
	assert_eq(_screen._boss_name_label.text, "BOITATÁ")

func test_start_shows_first_line() -> void:
	_screen.start("BOITATÁ", BOITATA_LINES)
	# Primeira linha: CAIPORA (falante esquerdo)
	assert_eq(_screen._left_speaker_label.text, "CAIPORA")
	assert_eq(_screen._left_text_label.text, "Você nos traiu...")

func test_advance_shows_second_line() -> void:
	_screen.start("BOITATÁ", BOITATA_LINES)
	_screen.advance()
	# Segunda linha: BOITATÁ (falante direito)
	assert_eq(_screen._right_speaker_label.text, "BOITATÁ")
	assert_eq(_screen._right_text_label.text, "Vocês me abandonaram!")

func test_advance_last_line_emits_dialogue_finished() -> void:
	watch_signals(SignalBus)
	_screen.start("BOITATÁ", BOITATA_LINES)
	_screen.advance()  # → linha 2
	_screen.advance()  # → fim
	assert_signal_emitted(SignalBus, "dialogue_finished")

func test_advance_ignored_when_not_ready() -> void:
	_screen.start("BOITATÁ", BOITATA_LINES)
	_screen._ready_for_input = false
	_screen.advance()
	assert_eq(_screen._left_speaker_label.text, "CAIPORA", "linha não deve avançar")

# ─── Retrato: caixas de largura total; nomes longos não estouram o container ───

func test_portrait_boxes_span_full_width() -> void:
	# No retrato cada caixa de fala ocupa a largura toda — metade de um phone
	# estreito espreme a fala para fora do viewport. O headless de teste não tem
	# viewport retrato, então o ramo é forçado pelo seam puro.
	_screen.start("JESUÍTA BANDEIRANTE CATEQUIZADOR", BOITATA_LINES)
	_screen._apply_box_anchors(true)
	assert_eq(_screen._left_box.anchor_right, 1.0, "caixa da Caipora em largura total no retrato")
	assert_eq(_screen._right_box.anchor_left, 0.0, "caixa do chefe em largura total no retrato")
	_screen._apply_box_anchors(false)
	assert_almost_eq(_screen._left_box.anchor_right, 0.48, 0.001,
		"paisagem volta ao lado a lado")
	assert_almost_eq(_screen._right_box.anchor_left, 0.52, 0.001,
		"paisagem volta ao lado a lado")

func test_speaker_labels_wrap_by_word() -> void:
	# Sem quebra, um nome longo no rótulo do falante infla a largura mínima do VBox
	# além da caixa e arrasta a fala inteira para fora do viewport (bug do Jesuíta).
	_screen.start("JESUÍTA BANDEIRANTE CATEQUIZADOR", BOITATA_LINES)
	assert_eq(_screen._left_speaker_label.autowrap_mode, TextServer.AUTOWRAP_WORD)
	assert_eq(_screen._right_speaker_label.autowrap_mode, TextServer.AUTOWRAP_WORD)

# ─── Input: qualquer tecla / toque / clique avança (mobile sem barra de espaço) ───

func test_touch_advances() -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	assert_true(_screen._is_advance_event(ev), "toque deve avançar a fala")

func test_touch_release_does_not_advance() -> void:
	var ev := InputEventScreenTouch.new()
	ev.pressed = false
	assert_false(_screen._is_advance_event(ev), "soltar o toque não deve avançar")

func test_any_key_advances() -> void:
	# No mobile/tablet não há barra de espaço: qualquer tecla precisa avançar.
	var ev := InputEventKey.new()
	ev.keycode = KEY_X
	ev.pressed = true
	assert_true(_screen._is_advance_event(ev), "qualquer tecla deve avançar a fala")

func test_key_echo_does_not_advance() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	ev.echo = true
	assert_false(_screen._is_advance_event(ev), "auto-repeat (echo) não deve avançar")

func test_mouse_click_advances() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	assert_true(_screen._is_advance_event(ev), "clique deve avançar a fala")
