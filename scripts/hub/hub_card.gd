class_name HubCard
extends Button

# Card clicável de UMA erva de aprimoramento no Hub — ficha compacta de uma linha:
#   [+N dano/HP                ícone Terra Rara  custo]
# Clicar/tocar pede a compra ao HubShop (que valida via MetaProgression.purchase_upgrade —
# fonte única). Estado visual ACESSÍVEL (borda âmbar viva, custo âmbar, respiro pulsante) vs.
# CARO (borda apagada, custo em sangue). É um Button: o conteúdo ignora o mouse para os
# cliques caírem no botão.
#
# Baixo e largo nas DUAS orientações: a pilha das trilhas mora na FAIXA SUPERIOR da tela,
# deixando o resto livre pro mundo/rastro/D-pad — em retrato empilhadas, em paisagem lado a
# lado. A largura vem do HubShop em relayout().

const CARD_HEIGHT := 48               # ficha baixa de uma linha, tocável sem virar parede
const COST_ICON_PX: int = 22
const TERRA_RARA_ICON: Texture2D = preload("res://assets/sprites/terra_rara_icon.png")

var key: String
var cost: int

var _content: HBoxContainer
var _effect_label: Label
var _cost_icon: TextureRect
var _cost_label: Label
var _pulse: Tween
var _affordable: bool = false

# StyleBoxes reaproveitados entre estados (acessível vs. caro).
var _style_afford: StyleBoxFlat
var _style_locked: StyleBoxFlat

func setup(erva_key: String) -> void:
	key = erva_key
	cost = MetaProgression.upgrade_cost(key)

	custom_minimum_size = Vector2(0, CARD_HEIGHT)
	# Clique/toque apenas: sem foco de teclado, pra não sequestrar as setas (ui_left/right/up/
	# down) que movem a Caipora pelo acampamento nem comprar por engano com Enter.
	focus_mode = Control.FOCUS_NONE
	clip_text = false
	_build_styles()

	# Conteúdo: uma linha. Tudo ignora o mouse para o clique cair no Button.
	_content = HBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("separation", 10)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	# Efeito curto derivado da matemática (fonte única — KI-006).
	_effect_label = Label.new()
	_effect_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_effect_label.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_effect_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_effect_label)

	var cost_box := HBoxContainer.new()
	cost_box.add_theme_constant_override("separation", 6)
	cost_box.alignment = BoxContainer.ALIGNMENT_END
	cost_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	cost_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(cost_box)

	_cost_icon = TextureRect.new()
	_cost_icon.texture = TERRA_RARA_ICON
	_cost_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_icon.custom_minimum_size = Vector2(COST_ICON_PX, COST_ICON_PX)
	_cost_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cost_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_box.add_child(_cost_icon)

	# Custo como número puro; o ícone carrega o significado de Terra Rara.
	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", Constants.FONT_MD)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_cost_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_box.add_child(_cost_label)

	refresh_text()

# Dois styleboxes de borda dura: âmbar quando dá pra pagar, apagado quando não.
# Larguras/margens/cores vêm dos tokens — o card é da mesma família do chrome.
func _build_styles() -> void:
	_style_afford = StyleBoxFlat.new()
	_style_afford.bg_color = Color(0.06, 0.05, 0.04, 0.92)
	_style_afford.border_color = Constants.COLOR_AMBER
	_style_afford.set_border_width_all(Constants.UI_BORDER_WIDTH)
	_style_afford.set_content_margin_all(Constants.UI_PADDING_V)

	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.05, 0.04, 0.045, 0.88)
	_style_locked.border_color = Constants.COLOR_BORDER_LOCKED
	_style_locked.set_border_width_all(Constants.UI_BORDER_WIDTH)
	_style_locked.set_content_margin_all(Constants.UI_PADDING_V)

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
		_cost_icon.modulate = Constants.COLOR_AMBER
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "modulate", Color(1.12, 1.12, 1.12, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
	else:
		_cost_label.add_theme_color_override("font_color", Constants.COLOR_BLOOD)
		_cost_icon.modulate = Constants.COLOR_BLOOD

func refresh_text() -> void:
	if is_instance_valid(_effect_label):
		_effect_label.text = MetaProgression.effect_short(key)
	if is_instance_valid(_cost_label):
		_cost_label.text = str(cost)

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
