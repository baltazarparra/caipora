class_name EnemyStateMachine
extends Node

## Controla autonomamente o ciclo de combate de um inimigo a partir de um
## AttackPattern. O ArenaManager apenas escuta sinais — nunca dirige estados.
##
## Ciclo de um pattern (não auto-reinicia; cede o turno ao final):
##   IDLE → WIND_UP → ATTACK → COOLDOWN → (pattern_finished)
## Com strike_count > 1, após ATTACK volta a WIND_UP até esgotar os golpes.

enum State { IDLE, WIND_UP, ATTACK, COOLDOWN }

signal state_changed(new_state: State)
signal attack_started
signal attack_finished
signal pattern_finished

var _current_state: State = State.IDLE
var _attack_pattern: AttackPattern
var _state_timer: Timer
var _strikes_remaining: int = 0

func _ready() -> void:
	_state_timer = Timer.new()
	_state_timer.one_shot = true
	_state_timer.timeout.connect(_on_state_timer_timeout)
	add_child(_state_timer)

## Inicia um pattern do zero. Chamado pelo ArenaManager no turno do inimigo.
func start_pattern(pattern: AttackPattern) -> void:
	_attack_pattern = pattern
	_strikes_remaining = maxi(1, pattern.strike_count)
	_transition_to(State.IDLE)

## Interrompe o pattern imediatamente (ex: inimigo morre durante a sequência).
func stop() -> void:
	_state_timer.stop()
	_current_state = State.IDLE

func get_current_state() -> State:
	return _current_state

func _transition_to(new_state: State) -> void:
	_current_state = new_state
	state_changed.emit(new_state)
	match new_state:
		State.IDLE:
			_start_timer(_attack_pattern.idle_duration)
		State.WIND_UP:
			# Golpe 1 usa o wind-up; follow-ups usam o intervalo INDEPENDENTE do hit
			# (strike_intervals[i]), com fallback no strike_delay único.
			var total := maxi(1, _attack_pattern.strike_count)
			var is_first := _strikes_remaining == total
			var windup: float = _attack_pattern.wind_up_duration if is_first else _strike_interval_at(total - 1 - _strikes_remaining)
			_start_timer(windup)
		State.ATTACK:
			attack_started.emit()
			_start_timer(_attack_pattern.attack_duration)
		State.COOLDOWN:
			_start_timer(_next_turn_delay())

## Intervalo entre o golpe (idx+1) e o (idx+2). Cai no strike_delay quando o
## array por-hit não cobre esse índice (compat com .tres antigos).
func _strike_interval_at(idx: int) -> float:
	var intervals: Array[float] = _attack_pattern.strike_intervals
	if idx >= 0 and idx < intervals.size():
		return intervals[idx]
	return _attack_pattern.strike_delay

## Intervalo último-golpe → próximo turno. Sentinela < 0 cai no cooldown_duration.
func _next_turn_delay() -> float:
	if _attack_pattern.next_turn_delay >= 0.0:
		return _attack_pattern.next_turn_delay
	return _attack_pattern.cooldown_duration

func _start_timer(duration: float) -> void:
	_state_timer.wait_time = maxf(0.01, duration)
	_state_timer.start()

func _on_state_timer_timeout() -> void:
	match _current_state:
		State.IDLE:
			_transition_to(State.WIND_UP)
		State.WIND_UP:
			_transition_to(State.ATTACK)
		State.ATTACK:
			attack_finished.emit()
			_strikes_remaining -= 1
			if _strikes_remaining > 0:
				_transition_to(State.WIND_UP)
			else:
				_transition_to(State.COOLDOWN)
		State.COOLDOWN:
			# Pattern concluído. Não auto-reinicia: cede o turno ao ArenaManager.
			_current_state = State.IDLE
			pattern_finished.emit()
