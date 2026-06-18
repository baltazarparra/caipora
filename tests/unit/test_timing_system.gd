extends GutTest

var _timing: TimingSystem

func before_each():
    _timing = TimingSystem.new()
    add_child_autofree(_timing)

func test_perfect_timing_within_window():
    var result: Array = [TimingSystem.TimingResult.MISS]
    _timing.timing_result.connect(func(r): result[0] = r)
    _timing.open_window(1.0, 0.35, 0.65)
    _timing._window_progress = 0.5
    _timing._evaluate_timing()
    assert_eq(result[0], TimingSystem.TimingResult.PERFECT)

func test_miss_timing_outside_window():
    var result: Array = [TimingSystem.TimingResult.PERFECT]
    _timing.timing_result.connect(func(r): result[0] = r)
    _timing.open_window(1.0, 0.35, 0.65)
    _timing._window_progress = 0.1
    _timing._evaluate_timing()
    assert_eq(result[0], TimingSystem.TimingResult.MISS)

func test_miss_on_timeout():
    var result: Array = [TimingSystem.TimingResult.PERFECT]
    _timing.timing_result.connect(func(r): result[0] = r)
    _timing.open_window(0.1)
    await get_tree().create_timer(0.15).timeout
    assert_eq(result[0], TimingSystem.TimingResult.MISS)

func test_phase_timing_windows():
    assert_almost_eq(
        Constants.timing_window_for_phase(Constants.TIMING_WINDOW_ATTACK, 1),
        1.0,
        0.001
    )
    assert_almost_eq(
        Constants.timing_window_for_phase(Constants.TIMING_WINDOW_ATTACK, 4),
        0.7,
        0.001
    )

# cancel_window destrava quem dá `await timing_result` (ex.: o batuque do Cortejo no
# teardown): emite MISS uma vez quando a janela está aberta.
func test_cancel_window_emits_miss_when_open():
    var result: Array = [TimingSystem.TimingResult.PERFECT]
    var count: Array = [0]
    _timing.timing_result.connect(func(r):
        result[0] = r
        count[0] += 1)
    _timing.open_window(1.0)
    _timing.cancel_window()
    assert_eq(result[0], TimingSystem.TimingResult.MISS, "cancel emite MISS")
    assert_eq(count[0], 1, "emite exatamente uma vez")
    assert_false(_timing.is_open(), "janela fica fechada após cancel")

# Sem janela aberta, cancel_window é no-op (não emite, não estoura).
func test_cancel_window_is_noop_when_closed():
    var count: Array = [0]
    _timing.timing_result.connect(func(_r): count[0] += 1)
    _timing.cancel_window()
    assert_eq(count[0], 0, "cancel sem janela aberta não emite")

# ─── Modo SEGURAR (Golpe Carregado) ────────────────
func _action_event(action: String, pressed: bool) -> InputEventAction:
    var ev := InputEventAction.new()
    ev.action = action
    ev.pressed = pressed
    ev.strength = 1.0 if pressed else 0.0
    return ev

func _open_hold(start: float = 0.5, end: float = 0.92, dur: float = 1.0) -> void:
    _timing.open_window(dur, start, end, false, 0.0, 0.0, "ui_up", "ui_right", true)

# Segura e SOLTA dentro da zona confortável → PERFEITO (avaliação no soltar).
func test_hold_release_in_zone_is_perfect():
    var result: Array = [TimingSystem.TimingResult.MISS]
    _timing.timing_result.connect(func(r): result[0] = r)
    _open_hold()
    _timing._input(_action_event("ui_up", true))    # agarra
    _timing._window_progress = 0.7                   # carga na zona de soltar
    _timing._input(_action_event("ui_up", false))    # solta
    assert_eq(result[0], TimingSystem.TimingResult.PERFECT)

# Soltar antes da carga cheia (cedo demais) → MISS.
func test_hold_release_too_early_is_miss():
    var result: Array = [TimingSystem.TimingResult.PERFECT]
    _timing.timing_result.connect(func(r): result[0] = r)
    _open_hold()
    _timing._input(_action_event("ui_up", true))
    _timing._window_progress = 0.3                   # antes de CHARGE_FULL
    _timing._input(_action_event("ui_up", false))
    assert_eq(result[0], TimingSystem.TimingResult.MISS)

# Segurar até a janela expirar (overcharge) → MISS por timeout.
func test_hold_overcharge_times_out():
    var result: Array = [TimingSystem.TimingResult.PERFECT]
    _timing.timing_result.connect(func(r): result[0] = r)
    _open_hold(0.5, 0.92, 0.1)
    _timing._input(_action_event("ui_up", true))     # segura e não solta
    await get_tree().create_timer(0.15).timeout
    assert_eq(result[0], TimingSystem.TimingResult.MISS)

# charge_started dispara uma vez ao agarrar; press repetido enquanto carrega é ignorado.
func test_hold_charge_started_once():
    var count: Array = [0]
    _timing.charge_started.connect(func(): count[0] += 1)
    _open_hold()
    _timing._input(_action_event("ui_up", true))
    _timing._input(_action_event("ui_up", true))
    assert_eq(count[0], 1, "agarrar emite charge_started uma única vez")

# Soltar sem ter agarrado é no-op (janela segue aberta, sem resultado).
func test_hold_release_without_press_is_noop():
    var count: Array = [0]
    _timing.timing_result.connect(func(_r): count[0] += 1)
    _open_hold()
    _timing._input(_action_event("ui_up", false))
    assert_eq(count[0], 0, "soltar sem carga não avalia")
    assert_true(_timing.is_open(), "janela continua aberta")
