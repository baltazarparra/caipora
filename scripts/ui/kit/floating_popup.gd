class_name FloatingPopup
extends RefCounted

# Serviço único de popup flutuante (subir + fade). Funde hud.gd::_show_popup e
# hub_shop::_spawn_floating_cost numa só curva. Cria um Label transiente sob `parent`
# na posição `at` e se autolibera ao fim.

const RISE := 48.0
const DURATION := 1.5

static func spawn(parent: Node, text: String, color: Color, font_size: int, at: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", at.y - RISE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION)
	tween.chain().tween_callback(label.queue_free)
