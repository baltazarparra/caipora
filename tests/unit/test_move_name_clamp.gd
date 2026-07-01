extends GutTest

# C8 — spawn_move_name: nomes de golpe 100% dentro do rect (o inimigo mora a ~85% da
# largura do palco; nomes longos como "Procissão das Almas" vazavam do viewport).

const FeedbackSystemScript := preload("res://scripts/systems/feedback_system.gd")
const LONG_NAME := "Procissão das Almas"

var _fb: FeedbackSystem
var _scene_stub: Node2D
var _prev_scene: Node

func before_each() -> void:
	# _attach_to_scene pendura labels na current_scene; headless o GUT roda
	# sem uma — apontamos para um stub e restauramos depois (padrão do feedback_pool).
	_scene_stub = Node2D.new()
	get_tree().root.add_child(_scene_stub)
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = _scene_stub
	_fb = FeedbackSystemScript.new()
	add_child_autofree(_fb)

func after_each() -> void:
	get_tree().current_scene = _prev_scene
	_scene_stub.queue_free()

func _spawned_label() -> Label:
	for child in _scene_stub.get_children():
		if child is Label:
			return child
	return null

func _measured_width(text: String) -> float:
	var font: Font = load(FeedbackSystemScript.MOVE_NAME_FONT)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		FeedbackSystemScript.MOVE_NAME_SIZE).x

func test_long_name_stays_fully_inside_rect() -> void:
	var rect := Rect2(40.0, 55.0, 360.0, 340.0)  # ~retrato: ação de 360px de largura
	# Ancorado no inimigo à direita (x=430): sem clamp, metade do nome vazaria.
	_fb.spawn_move_name(LONG_NAME, Vector2(430.0, 80.0), rect)
	var label := _spawned_label()
	assert_not_null(label, "label do nome nasceu")
	var w := _measured_width(LONG_NAME)
	assert_gte(label.position.x, rect.position.x, "borda esquerda dentro do rect")
	assert_lte(label.position.x + w, rect.end.x + 0.01, "borda direita dentro do rect")
	assert_gte(label.position.y, rect.position.y, "topo dentro do rect (com folga do drift)")

func test_without_rect_keeps_legacy_centered_position() -> void:
	var at := Vector2(430.0, 80.0)
	_fb.spawn_move_name(LONG_NAME, at)
	var label := _spawned_label()
	assert_not_null(label)
	var w := _measured_width(LONG_NAME)
	assert_almost_eq(label.position.x, at.x - w * 0.5, 0.01,
		"sem rect: centralização legada intacta")

func test_rect_narrower_than_name_pins_to_left_edge() -> void:
	var rect := Rect2(100.0, 50.0, 80.0, 200.0)  # rect mais estreito que o nome
	_fb.spawn_move_name(LONG_NAME, Vector2(500.0, 60.0), rect)
	var label := _spawned_label()
	assert_not_null(label)
	assert_almost_eq(label.position.x, rect.position.x, 0.01,
		"nome maior que o rect: encosta na borda esquerda (nunca à direita do rect)")
