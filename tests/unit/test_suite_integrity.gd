extends GutTest
## Guarda contra o gotcha #12: o GUT PULA em silêncio arquivos de teste que falham
## ao compilar (ex.: um `class_name` novo sem `godot --headless --import`, que
## derruba o parse de todo arquivo que referencia a classe) e ainda assim reporta
## "All tests passed". Aqui carregamos cada `test_*.gd` irmão e exigimos que compile:
## um arquivo silenciosamente pulado vira uma FALHA dura neste teste, no gate.

const TESTS_DIR := "res://tests/unit"

func test_every_test_file_compiles() -> void:
	var dir := DirAccess.open(TESTS_DIR)
	assert_not_null(dir, "tests/unit deve existir")
	if dir == null:
		return
	var checked := 0
	for file_name in dir.get_files():
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		if file_name == "test_suite_integrity.gd":
			continue
		var path := "%s/%s" % [TESTS_DIR, file_name]
		var res := load(path)
		assert_not_null(res, "%s nao compilou (parse error -> GUT pularia em silencio; gotcha #12)" % file_name)
		assert_true(res is GDScript, "%s nao e um GDScript valido" % file_name)
		checked += 1
	assert_gt(checked, 0, "esperava arquivos test_*.gd para verificar")
