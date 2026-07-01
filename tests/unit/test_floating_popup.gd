extends GutTest

# F2 — FloatingPopup: serviço único de popup (cria um Label transiente sob o pai).

func test_spawn_adds_label() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	FloatingPopup.spawn(parent, "+3", Constants.COLOR_AMBER, Constants.FONT_MD, Vector2.ZERO)
	var found := false
	for child: Node in parent.get_children():
		if child is Label and (child as Label).text == "+3":
			found = true
	assert_true(found, "popup deve criar um Label com o texto")

func test_spawn_null_parent_is_safe() -> void:
	FloatingPopup.spawn(null, "x", Constants.COLOR_AMBER, Constants.FONT_MD, Vector2.ZERO)
	assert_true(true, "não deve quebrar com parent nulo")
