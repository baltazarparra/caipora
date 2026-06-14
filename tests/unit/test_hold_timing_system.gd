extends GutTest

# Cobre o núcleo de carga do Cortejo (HoldTimingSystem) via _apply(delta, pressed),
# sem depender de input real — frame a frame, determinístico.

var _hold: HoldTimingSystem

# [emitiu?, landed]
var _result: Array = [false, false]
var _armed_count: int = 0

func before_each() -> void:
	_hold = HoldTimingSystem.new()
	add_child_autofree(_hold)
	# Desliga o _process para o input real nunca interferir nos testes determinísticos.
	_hold.set_process(false)
	_result = [false, false]
	_armed_count = 0
	_hold.link_finished.connect(func(landed: bool) -> void:
		_result[0] = true
		_result[1] = landed)
	_hold.link_armed.connect(func() -> void: _armed_count += 1)

func test_charge_reaches_armed_at_full() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_HOLD_SEC, true)  # enche num frame
	assert_eq(_armed_count, 1, "deve armar ao cruzar o cheio")
	assert_false(_result[0], "armar não finaliza o elo")
	assert_true(_hold.is_open(), "elo segue aberto enquanto segura")

func test_release_when_full_lands() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_HOLD_SEC, true)   # arma
	_hold._apply(0.016, false)                       # solta no cheio
	assert_true(_result[0], "deve finalizar")
	assert_true(_result[1], "soltar no cheio = landed")
	assert_false(_hold.is_open())

func test_release_too_early_misses() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_HOLD_SEC * 0.5, true)  # meio caminho
	_hold._apply(0.016, false)                            # solta cedo
	assert_true(_result[0])
	assert_false(_result[1], "soltar antes do cheio = elo perdido")

func test_overcharge_misses() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_HOLD_SEC, true)                       # arma
	_hold._apply(Constants.CORTEJO_RELEASE_GRACE + 0.05, true)           # segura demais
	assert_true(_result[0])
	assert_false(_result[1], "overcharge = o espírito escapa (perdido)")

func test_timeout_without_input_misses() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_LINK_TIMEOUT + 0.1, false)  # nunca prensa
	assert_true(_result[0])
	assert_false(_result[1], "timeout = elo perdido")

func test_close_link_unblocks_with_miss() -> void:
	_hold.open_link()
	_hold._apply(0.2, true)  # carregando
	_hold.close_link()       # teardown externo
	assert_true(_result[0], "close_link com elo aberto emite o terminal")
	assert_false(_result[1], "fechado de fora = perdido")
	assert_false(_hold.is_open())

func test_finish_is_idempotent() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_HOLD_SEC, true)
	_hold._apply(0.016, false)  # landed
	var landed_after: bool = _result[1]
	_hold.close_link()          # não deve re-emitir nem mudar o resultado
	assert_eq(_result[1], landed_after, "close após finalizar não re-emite")

func test_open_link_resets_state() -> void:
	_hold.open_link()
	_hold._apply(Constants.CORTEJO_HOLD_SEC, true)
	_hold._apply(0.016, false)  # finaliza um elo
	_result = [false, false]
	_hold.open_link()           # novo elo
	assert_true(_hold.is_open())
	_hold._apply(Constants.CORTEJO_HOLD_SEC * 0.5, true)
	_hold._apply(0.016, false)
	assert_false(_result[1], "estado zerado: meio caminho = perdido")
