class_name HubCard
extends Button

# Card clicável de UMA erva de aprimoramento no Hub — ficha compacta de duas linhas:
#   [ícone  NOME]
#   [+N dano/HP                custo]
# Clicar/tocar pede a compra ao HubShop (que valida via MetaProgression.purchase_upgrade —
# fonte única). Estado visual ACESSÍVEL (borda âmbar viva, custo âmbar, respiro pulsante) vs.
# CARO (borda apagada, custo em sangue). É um Button: o conteúdo ignora o mouse para os
# cliques caírem no botão.
#
# Baixo e largo nas DUAS orientações: a pilha das trilhas mora na FAIXA SUPERIOR da tela,
# deixando o resto livre pro mundo/rastro/D-pad — em retrato empilhadas, em paisagem lado a
# lado. A largura vem do HubShop em relayout().

const ICON_PX: int = 38               # ícone na primeira linha, à esquerda do nome
const CARD_HEIGHT := 68               # ficha baixa: duas linhas curtas, não parede de cards
const BORDER := 3                     # bordas duras (sem cantos arredondados — guia de UI)
# Fonte do nome entre MD(18) e LG(28): a fonte pixelada é larga, então 28 estoura a largura do
# card; 20 mantém os nomes curtos numa linha (os longos quebram no hífen, leitura natural).
const NAME_FONT: int = 20

var key: String
var cost: int

var _icon: TextureRect
var _content: VBoxContainer   # duas linhas: [ícone+nome] em cima, [efeito+custo] embaixo
var _name_label: Label
var _effect_label: Label
var _cost_label: Label
var _pulse: Tween
var _affordable: bool = false

# StyleBoxes reaproveitados entre estados (acessível vs. caro).
var _style_afford: StyleBoxFlat
var _style_locked: StyleBoxFlat

func setup(erva_key: String) -> void:
	key = erva_key
	var def: Dictionary = MetaProgression.UPGRADE_DEFS[key]
	cost = MetaProgression.upgrade_cost(key)

	custom_minimum_size = Vector2(0, CARD_HEIGHT)
	# Clique/toque apenas: sem foco de teclado, pra não sequestrar as setas (ui_left/right/up/
	# down) que movem a Caipora pelo acampamento nem comprar por engano com Enter.
	focus_mode = Control.FOCUS_NONE
	clip_text = false
	_build_styles()

	# Conteúdo: duas linhas empilhadas. Tudo ignora o mouse para o clique cair no Button.
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("separation", 4)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Linha de cima: ícone + nome.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(top)

	_icon = TextureRect.new()
	_icon.texture = load(String(def["icon"]))
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_icon)

	_name_label = Label.new()
	_name_label.text = String(def.get("name", key))
	_name_label.add_theme_font_size_override("font_size", NAME_FONT)
	_name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_name_label)

	# Linha de baixo: efeito curto à esquerda, custo à direita.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bottom)

	# Efeito curto derivado da matemática (fonte única — KI-006).
	_effect_label = Label.new()
	_effect_label.text = MetaProgression.effect_short(key)
	_effect_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_effect_label.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_effect_label)

	# Custo em fragmentos, alinhado à direita da segunda linha.
	_cost_label = Label.new()
	_cost_label.text = Lang.tf(&"card.cost.short", [cost])
	_cost_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cost_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_cost_label)

# Dois styleboxes de borda dura: âmbar quando dá pra pagar, apagado quando não.
func _build_styles() -> void:
	_style_afford = StyleBoxFlat.new()
	_style_afford.bg_color = Color(0.06, 0.05, 0.04, 0.92)
	_style_afford.border_color = Constants.COLOR_AMBER
	_style_afford.set_border_width_all(BORDER)
	_style_afford.set_content_margin_all(12)

	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.05, 0.04, 0.045, 0.88)
	_style_locked.border_color = Color(0.35, 0.18, 0.18, 0.9)
	_style_locked.set_border_width_all(BORDER)
	_style_locked.set_content_margin_all(12)

## Atualiza o estado visual conforme o jogador pode (ou não) pagar a erva. Acessível ganha
## borda âmbar, custo âmbar e respiro pulsante; cara fica apagada com custo em sangue.
func set_affordable(affordable: bool) -> void:
	_affordable = affordable
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
		_pulse = null
	modulate = Color.WHITE
	var style := _style_afford if affordable else _style_locked
	for slot: String in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(slot, style)
	if affordable:
		_cost_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "modulate", Color(1.12, 1.12, 1.12, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
	else:
		_cost_label.add_theme_color_override("font_color", Constants.COLOR_BLOOD)

## Reajusta o card à largura de coluna corrente (chamado pelo HubShop em size_changed).
## A largura é imposta como mínimo e o Button preenche a coluna.
func relayout(width: float) -> void:
	custom_minimum_size = Vector2(width, CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_FILL

## Comprada: encolhe e some (fumada no cachimbo) e se libera.
func consume() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
		_pulse = null
	disabled = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

## Sem fragmento suficiente: pisca o custo em sangue (não compra, card permanece).
func deny() -> void:
	_cost_label.add_theme_color_override("font_color", Constants.COLOR_BLOOD)
	var tween := create_tween()
	tween.tween_property(_cost_label, "modulate:a", 0.2, 0.12)
	tween.tween_property(_cost_label, "modulate:a", 1.0, 0.12)
