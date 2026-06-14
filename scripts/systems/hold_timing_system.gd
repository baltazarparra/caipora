class_name HoldTimingSystem
extends Node

## Sistema de CARGA (hold) do Cortejo dos Encantados — irmão do TimingSystem (que só
## lê taps). Cada "elo" da corrente é uma carga: o jogador segura ↑; um anel enche em
## Constants.CORTEJO_HOLD_SEC; soltar no cheio = golpe (link_finished(true)); soltar
## cedo, segurar demais (overcharge) ou não concluir a tempo = elo perdido
## (link_finished(false)). A corrente NUNCA trava — todo caminho é terminal.
## Ver docs/CONCEITO-corrente-encantados.md.
##
## Núcleo puro e testável: toda a lógica vive em _apply(delta, pressed); _process só
## injeta o estado real do input. O polling cobre teclado nativo E o touch (o D-pad de
## combate mantém a ação pressionada via Input.action_press — ControlsHud._on_pressed).

# ─── Signals ───────────────────────────────────────
## Progresso da carga (0..1) a cada frame pressionado — alimenta o anel/feedback.
signal link_charging(progress: float)
## A carga chegou ao cheio: armado, pronto para soltar.
signal link_armed
## Único sinal TERMINAL do elo (landed = soltou no cheio). Permite `await` limpo no
## ArenaManager. Disparado uma única vez por elo (idempotente).
signal link_finished(landed: bool)

# ─── State ─────────────────────────────────────────
var _open: bool = false
var _progress: float = 0.0
var _armed: bool = false
var _was_pressed: bool = false
var _link_elapsed: float = 0.0
var _overcharge_elapsed: float = 0.0
var _action: String = "ui_up"

# ─── Public API ────────────────────────────────────
func open_link(action: String = "ui_up") -> void:
	_action = action
	_progress = 0.0
	_armed = false
	_was_pressed = false
	_link_elapsed = 0.0
	_overcharge_elapsed = 0.0
	_open = true

## Fecha o elo de fora (teardown). Se havia elo aberto, emite link_finished(false)
## para desbloquear qualquer await pendente — sem corrotina pendurada.
func close_link() -> void:
	_finish(false)

func is_open() -> bool:
	return _open

# ─── Lifecycle ─────────────────────────────────────
func _process(delta: float) -> void:
	if not _open:
		return
	_apply(delta, Input.is_action_pressed(_action))

# ─── Núcleo puro (testável sem Input real) ─────────
func _apply(delta: float, pressed: bool) -> void:
	if not _open:
		return
	_link_elapsed += delta

	# Transição soltar (estava segurando, largou): avalia o elo.
	if _was_pressed and not pressed:
		_was_pressed = false
		_finish(_armed)
		return

	if pressed:
		_was_pressed = true
		if not _armed:
			_progress = minf(_progress + delta / Constants.CORTEJO_HOLD_SEC, 1.0)
			link_charging.emit(_progress)
			if _progress >= 1.0:
				_armed = true
				link_armed.emit()
		else:
			# Overcharge: segurar além da graça = o espírito escapa (elo perdido).
			_overcharge_elapsed += delta
			if _overcharge_elapsed > Constants.CORTEJO_RELEASE_GRACE:
				_finish(false)
	else:
		# Nunca começou a carga a tempo: elo perdido por timeout.
		if _link_elapsed >= Constants.CORTEJO_LINK_TIMEOUT:
			_finish(false)

# ─── Private helpers ───────────────────────────────
func _finish(landed: bool) -> void:
	if not _open:
		return
	_open = false
	link_finished.emit(landed)
