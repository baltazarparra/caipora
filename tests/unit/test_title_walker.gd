extends GutTest

# O bando dos libertados na marcha do menu (TitleWalker + TitleCompanion).
# freed_bosses é forçado com array TIPADO (gotcha #14: duplicate()/ternário
# destipam Array[int]) e restaurado no after_each.

var _saved_freed: Array[int] = []

func before_each() -> void:
	_saved_freed.assign(MetaProgression.freed_bosses)

func after_each() -> void:
	var restore: Array[int] = []
	restore.assign(_saved_freed)
	MetaProgression.freed_bosses = restore

func _set_freed(phases: Array) -> void:
	var typed: Array[int] = []
	typed.assign(phases)
	MetaProgression.freed_bosses = typed

func _make_walker() -> TitleWalker:
	var walker := TitleWalker.new()
	add_child_autofree(walker)
	return walker

func _companions(walker: TitleWalker) -> Array:
	var found := []
	for child in walker.get_children():
		if child is TitleCompanion:
			found.append(child)
	return found

func test_no_freed_bosses_no_companions() -> void:
	_set_freed([])
	assert_eq(_companions(_make_walker()).size(), 0,
		"save novo: a Caipora atravessa sozinha, como sempre")

func test_one_companion_per_freed_boss() -> void:
	_set_freed([1, 2])
	assert_eq(_companions(_make_walker()).size(), 2)

func test_companions_alternate_sides_and_reuse_camp_defs() -> void:
	_set_freed([1, 2, 3, 4])
	var companions := _companions(_make_walker())
	assert_eq(companions.size(), 4)
	# Intercalados na frente e atrás: +GAP, -GAP, +2·GAP, -2·GAP.
	assert_almost_eq(companions[0].position.x, TitleWalker.COMPANION_GAP, 0.01)
	assert_almost_eq(companions[1].position.x, -TitleWalker.COMPANION_GAP, 0.01)
	assert_almost_eq(companions[2].position.x, TitleWalker.COMPANION_GAP * 2.0, 0.01)
	assert_almost_eq(companions[3].position.x, -TitleWalker.COMPANION_GAP * 2.0, 0.01)
	# Reusa o registro canônico do acampamento × escala da marcha, anim idle.
	var expected_scale: float = CampSpirit.DEFS[1]["scale"] * TitleWalker.WALK_SCALE
	assert_almost_eq(companions[0]._sprite.scale.x, expected_scale, 0.001)
	assert_eq(String(companions[0]._sprite.animation), "idle",
		"bosses não têm walk: o passo é o quique vertical")

func test_ending_opt_out_spawns_none() -> void:
	_set_freed([1, 2])
	var walker := TitleWalker.new()
	walker.companions_enabled = false
	add_child_autofree(walker)
	assert_eq(_companions(walker).size(), 0, "no ending a Caipora atravessa sozinha")
