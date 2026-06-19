class_name EndScreen
extends CanvasLayer

## Tela de fim de combate (WIN / GAME_OVER). Registra o resultado da run e encerra.
## Cada entrada é uma instância nova (change_scene_to_file), então o _ready dispara
## end_run exatamente uma vez por entrada.
##
## Roteamento de saída (a run JÁ acabou — end_run desativou run_active): vitória e derrota
## voltam ao MENU PRINCIPAL. O hub só entra ENTRE fases (advance_phase_via_hub); fim de run
## (morte ou vitória terminal) não é avanço de fase.

@export var won: bool = false

@onready var _vbox: VBoxContainer = $Center/VBox
@onready var _title: Label = $Center/VBox/Title
@onready var _hint: Label = $Center/VBox/Hint

# Guard contra dupla ativação: com emulate_mouse_from_touch, um toque gera touch +
# mouse emulado no mesmo frame; só a primeira troca de tela deve valer.
var _handled: bool = false
# Aviso souls-like da Terra Rara derrubada na morte (só na derrota, criado por código).
var _terra_label: Label = null

func _ready() -> void:
	GameState.end_run(won)
	_title.text = Lang.t(&"win.title") if won else Lang.t(&"gameover.title")
	_hint.text = _hint_text()
	_maybe_show_dropped_terra()
	_fit_portrait()
	get_viewport().size_changed.connect(_fit_portrait)

## Na derrota, se a Caipora derrubou Terra Rara, avisa quanto ficou caído e que dá pra recuperar
## voltando ao local da queda numa run futura (souls-like). Label adicionado por código entre o
## título e a dica — editar o .tscn à mão é proibido (gotcha 7).
func _maybe_show_dropped_terra() -> void:
	if won or not MetaProgression.frag_bag_active or MetaProgression.frag_bag_amount <= 0.0:
		return
	_terra_label = Label.new()
	_terra_label.text = Lang.tf(&"gameover.terra_lost", [int(MetaProgression.frag_bag_amount)])
	_terra_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_terra_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_terra_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_terra_label)
	_vbox.move_child(_terra_label, _hint.get_index())

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
	if _terra_label != null:
		_terra_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_terra_label.custom_minimum_size.x = maxw

## Tela-alvo ao dispensar (puro, sem efeitos colaterais — testável destacado da árvore).
## Vitória e derrota → MENU PRINCIPAL (a caçada acabou nos dois casos).
func _dismiss_target() -> SignalBus.Screen:
	return SignalBus.Screen.MAIN_MENU

## Dica de saída coerente com o destino e a plataforma (web/toque não têm barra de espaço).
## Ambos os desfechos voltam ao menu, então a dica não depende de vitória/derrota.
func _hint_text() -> String:
	var touch := OS.has_feature("web") or DisplayServer.is_touchscreen_available()
	return Lang.t(&"end.hint.touch" if touch else &"end.hint.key")

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
