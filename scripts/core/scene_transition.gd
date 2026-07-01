extends CanvasLayer
# Autoload registrado como SceneTransition em project.godot.
# Sem class_name: conflita com o nome do autoload em Godot 4.
#
# Mascara toda troca de cena com fade preto curto. Avancos de fase exibem flavor
# tematico com a assinatura da marca — dois olhos brancos abrem no breu, piscam
# e fecham (o mesmo gesto do loader HTML e do "O" do wordmark). A entrada em
# arena fica com fade limpo, porque a chamada de luta pertence ao loader
# interno do ArenaManager.

const LAYER := 100
const FADE_OUT := 0.22
const FADE_IN := 0.28
const TEXT_FADE := 0.18
const TEXT_HOLD := 0.5
# Assinatura dos olhos: iguais, duros, sem halo (docs/CONCEITO-protagonista.md).
const EYE_SIZE := Vector2(12, 14)
const EYE_GAP := 18.0
const EYE_OFFSET_Y := -52.0
const EYE_BLINK := 0.07

var _fade: ColorRect
var _label: Label
var _eyes: Control
var _tween: Tween
var _last_exploration: int = -1


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_label.modulate.a = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.add_child(_label)

	_eyes = Control.new()
	_eyes.set_anchors_preset(Control.PRESET_CENTER)
	_eyes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_eyes.visible = false
	for side: float in [-1.0, 1.0]:
		var eye := ColorRect.new()
		eye.color = Color.WHITE
		eye.size = EYE_SIZE
		eye.position = Vector2(
			side * EYE_GAP / 2.0 - (EYE_SIZE.x if side < 0.0 else 0.0),
			EYE_OFFSET_Y - EYE_SIZE.y / 2.0)
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_eyes.add_child(eye)
	_fade.add_child(_eyes)


func transition_to(path: String, new_screen: int) -> void:
	if path.is_empty():
		return
	var flavor := _flavor_for(new_screen)
	if _is_exploration(new_screen):
		_last_exploration = new_screen
	_run(path, flavor)


func _is_exploration(s: int) -> bool:
	return s == SignalBus.Screen.EXPLORATION \
		or s == SignalBus.Screen.EXPLORATION_PHASE2 \
		or s == SignalBus.Screen.EXPLORATION_PHASE3 \
		or s == SignalBus.Screen.EXPLORATION_PHASE4 \
		or s == SignalBus.Screen.EXPLORATION_PHASE5


func _flavor_for(new_screen: int) -> String:
	if _is_exploration(new_screen) and new_screen != _last_exploration:
		return Lang.t(&"transition.themed")
	if new_screen == SignalBus.Screen.HUB:
		return Lang.t(&"transition.camp")
	return ""


func _is_themed(new_screen: int) -> bool:
	return not _flavor_for(new_screen).is_empty()


func _run(path: String, flavor: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_fade.color.a = 0.0
	_label.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var themed := not flavor.is_empty()
	if themed:
		_label.text = flavor
	_eyes.modulate.a = 0.0
	_eyes.visible = themed

	_tween = create_tween()
	_tween.tween_property(_fade, "color:a", 1.0, FADE_OUT)
	_tween.tween_callback(func() -> void: get_tree().change_scene_to_file(path))
	if themed:
		# Olhos abrem no breu, piscam uma vez e se fecham antes da luz voltar.
		_tween.tween_callback(func() -> void: _eyes.modulate.a = 1.0)
		_tween.tween_property(_label, "modulate:a", 1.0, TEXT_FADE)
		_tween.tween_interval(TEXT_HOLD * 0.45)
		_tween.tween_callback(func() -> void: _eyes.modulate.a = 0.0)
		_tween.tween_interval(EYE_BLINK)
		_tween.tween_callback(func() -> void: _eyes.modulate.a = 1.0)
		_tween.tween_interval(TEXT_HOLD * 0.55)
		_tween.tween_callback(func() -> void: _eyes.modulate.a = 0.0)
		_tween.tween_property(_label, "modulate:a", 0.0, TEXT_FADE)
	_tween.tween_property(_fade, "color:a", 0.0, FADE_IN)
	_tween.tween_callback(func() -> void:
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_eyes.visible = false)
