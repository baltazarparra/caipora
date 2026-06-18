class_name TimingSystem
extends Node

enum TimingResult { PERFECT, MISS }

# ─── Signals ───────────────────────────────────────
signal timing_result(result: TimingResult)
signal timing_first_hit
## Emitido a cada input válido recebido durante uma janela aberta (perfeito OU
## não). Serve para feedback tátil imediato (micro-shake + clique) a cada ação.
signal input_registered

# ─── State ─────────────────────────────────────────
var _is_window_open: bool = false
var _window_progress: float = 0.0
var _window_duration: float = 1.5
var _perfect_start: float = 0.35
var _perfect_end: float = 0.65
var _perfect_start_2: float = 0.35
var _perfect_end_2: float = 0.65
var _double_mode: bool = false
var _first_hit_done: bool = false
var _expected_action: String = "ui_up"
var _expected_action_2: String = "ui_right"

# ─── Public API ────────────────────────────────────
func open_window(duration: float = 1.5, perfect_start: float = 0.35, perfect_end: float = 0.65, double: bool = false, perfect_start_2: float = 0.0, perfect_end_2: float = 0.0, action: String = "ui_up", action_2: String = "ui_right") -> void:
	_is_window_open = true
	_window_duration = duration
	_perfect_start = perfect_start
	_perfect_end = perfect_end
	_perfect_start_2 = perfect_start_2 if perfect_start_2 > 0.0 else perfect_start
	_perfect_end_2 = perfect_end_2 if perfect_end_2 > 0.0 else perfect_end
	_double_mode = double
	_first_hit_done = false
	_window_progress = 0.0
	_expected_action = action
	_expected_action_2 = action_2

func close_window() -> void:
	_is_window_open = false

## Cancela a janela aberta emitindo timing_result(MISS) uma única vez. Diferente de
## close_window (que fecha em silêncio), serve para desbloquear quem dá `await
## timing_result` — ex.: o batuque do Cortejo no teardown de combate. No-op se já
## fechada. Chame DEPOIS de desconectar os handlers normais para o emit não atingir
## ataque/defesa, só a corrotina pendurada.
func cancel_window() -> void:
	if not _is_window_open:
		return
	_is_window_open = false
	timing_result.emit(TimingResult.MISS)

func is_open() -> bool:
	return _is_window_open

# ─── Lifecycle ─────────────────────────────────────
func _process(delta: float) -> void:
	if not _is_window_open:
		return
	_window_progress += delta / _window_duration
	if _window_progress >= 1.0:
		_is_window_open = false
		timing_result.emit(TimingResult.MISS)

func _input(event: InputEvent) -> void:
	if not _is_window_open:
		return
	var action := _expected_action_2 if (_double_mode and _first_hit_done) else _expected_action
	if event.is_action_pressed(action):
		input_registered.emit()
		_evaluate_timing()

# ─── Private helpers ───────────────────────────────
func _in_perfect_zone() -> bool:
	if _double_mode and _first_hit_done:
		return _window_progress >= _perfect_start_2 and _window_progress <= _perfect_end_2
	return _window_progress >= _perfect_start and _window_progress <= _perfect_end

func _evaluate_timing() -> void:
	if not _double_mode:
		_is_window_open = false
		if _in_perfect_zone():
			timing_result.emit(TimingResult.PERFECT)
		else:
			timing_result.emit(TimingResult.MISS)
		return

	if not _first_hit_done:
		if _in_perfect_zone():
			_first_hit_done = true
			timing_first_hit.emit()
		else:
			_is_window_open = false
			timing_result.emit(TimingResult.MISS)
	else:
		_is_window_open = false
		if _in_perfect_zone():
			timing_result.emit(TimingResult.PERFECT)
		else:
			timing_result.emit(TimingResult.MISS)
