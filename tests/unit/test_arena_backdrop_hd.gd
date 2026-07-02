extends GutTest

# Arena viva (modo HD): brasas ambientes em toda fase, palco aceso durante o
# combate; modo leve byte a byte (embers só P4, cull no combate).

var _saved_phase: int

func before_each() -> void:
	_saved_phase = GameState.active_phase

func after_each() -> void:
	GameState.active_phase = _saved_phase
	Quality._reset_for_test()

func _make_backdrop(phase: int) -> ArenaBackdrop:
	GameState.active_phase = phase
	var backdrop := ArenaBackdrop.new()
	add_child_autofree(backdrop)
	return backdrop

func test_hd_spawns_ambient_motes_in_every_phase() -> void:
	Quality._set_for_test(true)
	var backdrop := _make_backdrop(1)
	assert_not_null(backdrop._embers, "P1 ganha motas ambientes em HD")
	assert_true(backdrop._embers.emitting, "motas emitindo")

func test_lite_keeps_embers_only_in_p4() -> void:
	Quality._set_for_test(false)
	var p1 := _make_backdrop(1)
	assert_null(p1._embers, "P1 leve não tem brasas (comportamento atual)")
	var p4 := _make_backdrop(4)
	assert_not_null(p4._embers, "P4 leve mantém as brasas de sempre")

func test_combat_mode_keeps_stage_alive_in_hd() -> void:
	Quality._set_for_test(true)
	var backdrop := _make_backdrop(1)
	backdrop.set_combat_mode(true)
	assert_true(backdrop._mist.emitting, "HD: névoa segue viva no combate")
	assert_true(backdrop._embers.emitting, "HD: brasas seguem vivas no combate")
	assert_true(backdrop._far_line.visible, "HD: treelines visíveis no combate")

func test_combat_mode_culls_stage_in_lite() -> void:
	Quality._set_for_test(false)
	var backdrop := _make_backdrop(1)
	backdrop.set_combat_mode(true)
	assert_false(backdrop._mist.emitting, "leve: névoa pausada no combate (atual)")
	assert_false(backdrop._far_line.visible, "leve: treelines somem no combate (atual)")