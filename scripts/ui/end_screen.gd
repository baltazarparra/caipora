class_name EndScreen
extends CanvasLayer

## Tela de fim de combate (WIN / GAME_OVER). Registra o resultado da run e encerra.
## Cada entrada é uma instância nova (change_scene_to_file), então o _ready dispara
## end_run exatamente uma vez por entrada.
##
## Roteamento de saída (a run JÁ acabou — end_run desativou run_active): a derrota volta
## ao MENU PRINCIPAL, não ao acampamento. O hub só entra ENTRE fases (advance_phase_via_hub);
## morrer não é avanço de fase. A vitória terminal mantém o acampamento.

@export var won: bool = false

@onready var _vbox: VBoxContainer = $Center/VBox
@onready var _title: Label = $Center/VBox/Title
@onready var _hint: Label = $Center/VBox/Hint

# Guard contra dupla ativação: com emulate_mouse_from_touch, um toque gera touch +
# mouse emulado no mesmo frame; só a primeira troca de tela deve valer.
var _handled: bool = false

func _ready() -> void:
	GameState.end_run(won)
	_title.text = Lang.t(&"win.title") if won else Lang.t(&"gameover.title")
	_hint.text = _hint_text()
	_fit_portrait()
	get_viewport().size_changed.connect(_fit_portrait)

## Em retrato a tela é estreita: sem quebra de linha o título (frase longa, fonte grande) fica
## mais largo que o viewport e vaza pelos dois lados. Liga o autowrap e fixa a largura útil
## (capada) — os labels quebram e centralizam dentro dela, e o CenterContainer centraliza o bloco.
func _fit_portrait() -> void:
	var vp := get_viewport().get_visible_rect().size
	var maxw := clampf(vp.x - 64.0, 240.0, 640.0)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.custom_minimum_size.x = maxw
	_title.custom_minimum_size.x = maxw
	_hint.custom_minimum_size.x = maxw

## Tela-alvo ao dispensar (puro, sem efeitos colaterais — testável destacado da árvore).
## Derrota → MENU PRINCIPAL (a caçada acabou); vitória → INITIALS (entrada no PODIO).
func _dismiss_target() -> SignalBus.Screen:
	return SignalBus.Screen.INITIALS if won else SignalBus.Screen.MAIN_MENU

## Dica de saída coerente com o destino e a plataforma (web/toque não têm barra de espaço).
func _hint_text() -> String:
	var touch := OS.has_feature("web") or DisplayServer.is_touchscreen_available()
	if won:
		return Lang.t(&"end.hint.touch.won" if touch else &"end.hint.key.won")
	return Lang.t(&"end.hint.touch.lost" if touch else &"end.hint.key.lost")

# Usa _input (não _unhandled_input): o Background/CenterContainer cobrem a tela inteira com
# mouse_filter=STOP por padrão, engolindo o toque na fase de GUI. No mobile, sem barra de
# espaço, isso transformava a tela num dead-end. _input roda antes da GUI e captura o toque.
func _input(event: InputEvent) -> void:
	# Qualquer tecla (desktop) OU qualquer toque/clique (mobile) volta ao acampamento.
	if _handled:
		return
	if _is_dismiss_event(event):
		_handled = true
		get_viewport().set_input_as_handled()
		GameState.change_screen(_dismiss_target())

# No mobile/tablet não há barra de espaço, então qualquer tecla, toque ou clique encerra.
func _is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false
