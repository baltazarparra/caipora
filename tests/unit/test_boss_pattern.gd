extends GutTest

func test_attack_pattern_has_strike_fields():
    var p := AttackPattern.new()
    p.strike_count = 3
    p.strike_delay = 0.4
    assert_eq(p.strike_count, 3)
    assert_almost_eq(p.strike_delay, 0.4, 0.001)

func test_boss_is_a_criatura_with_boss_stats():
    var boss = preload("res://scenes/arena/boss.tscn").instantiate()
    add_child_autofree(boss)
    assert_true(boss is Criatura, "Boss herda de Criatura")
    assert_eq(EnemyStats.max_hp_for(&"mula", 1), 12, "HP do boss base (P1)")
    assert_eq(boss.base_attack_damage, 1)
    assert_eq(boss.attack_pattern.strike_count, 3)

func test_boss_pattern_runs_three_strikes():
    var sm := EnemyStateMachine.new()
    var pattern := AttackPattern.new()
    pattern.idle_duration = 0.05
    pattern.wind_up_duration = 0.05
    pattern.attack_duration = 0.05
    pattern.cooldown_duration = 0.05
    pattern.strike_delay = 0.05
    pattern.strike_count = 3
    add_child_autofree(sm)
    var attacks: Array = [0]
    sm.attack_started.connect(func(): attacks[0] += 1)
    var finished: Array = [false]
    sm.pattern_finished.connect(func(): finished[0] = true)
    sm.start_pattern(pattern)
    await get_tree().create_timer(0.6).timeout
    assert_eq(attacks[0], 3, "3 golpes consecutivos")
    assert_true(finished[0], "pattern conclui após o último golpe")
