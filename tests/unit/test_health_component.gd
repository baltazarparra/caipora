extends GutTest

var _health: HealthComponent

func before_each():
    _health = HealthComponent.new()
    _health.max_health = 100
    add_child_autofree(_health)
    _health._ready()

func test_take_damage_reduces_health():
    _health.take_damage(30)
    assert_eq(_health.current_health, 70.0)

func test_died_signal_at_zero():
    var died: Array = [false]
    _health.died.connect(func(): died[0] = true)
    _health.take_damage(100)
    assert_true(died[0])
    assert_eq(_health.current_health, 0.0)

func test_heal_caps_at_max():
    _health.take_damage(50)
    _health.heal(100)
    assert_eq(_health.current_health, 100.0)

func test_is_alive_returns_false_when_dead():
    _health.take_damage(100)
    assert_false(_health.is_alive())

func test_full_heal_restores_to_max():
    var changed: Array = [false]
    _health.health_changed.connect(func(_n, _m): changed[0] = true)
    _health.take_damage(70)
    _health.full_heal()
    assert_eq(_health.current_health, float(_health.max_health))
    assert_true(changed[0])
