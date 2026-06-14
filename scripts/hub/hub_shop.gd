class_name HubShop
extends CanvasLayer

# Interface de aprimoramentos do Hub: cabeçalho com FRAGMENTOS + resumo de bônus + Opções, e
# os cards clicáveis das ervas disponíveis numa faixa compacta no topo, agrupados por trilha
# (FÚRIA · dano e CURA · vida). Substitui as ervas pequenas no chão da Fase 9 por algo claro
# de ler/clicar/entender. purchase_upgrade continua a fonte única de custo/requires/persistência.
#
# Regra de pacing preservada da Etapa 2: o conjunto de cards é montado UMA vez na ENTRADA
# (available_keys). Comprar uma erva NÃO faz a próxima da cadeia aparecer nesta fogueira — ela
# "nasce na próxima fogueira" (a coluna mostra esse status). Os fundos ignoram o mouse para
# não engolir o D-pad de toque nem a caminhada até o rastro de saída.

# Sucesso/recusa de compra — o HubManager escuta para tocar o SFX (dono do SfxSystem).
signal purchased(key: String)
signal denied(key: String)

const HINT_COLOR := Color(0.55, 0.55, 0.58, 1.0)
const COLUMN_SEP := 48         # separação entre as trilhas lado a lado (paisagem)
const PORTRAIT_TRACK_SEP := 16 # separação entre as trilhas empilhadas (retrato)
const CARD_WIDTH_MAX := 330    # teto da largura de coluna em paisagem
const CARD_WIDTH_MIN := 240    # piso tocável/legível da coluna (ambas orientações)
# Em paisagem cada coluna fica em ≤30% da largura: os cards saem do centro do mapa e moram
# numa faixa compacta no topo, junto do cabeçalho (o acampamento volta a ser o protagonista).
const LANDSCAPE_COLUMN_FRACTION := 0.30
const HEADER_BAND_OFFSET := 44.0  # altura da linha de fragmentos do cabeçalho

# ─── State ─────────────────────────────────────────
var _root: Control
var _frag_label: Label
var _options: OptionsPanel
var _options_button: Button
var _margin: MarginContainer
# Bandeja dos cards: ancorada no topo, abaixo do cabeçalho (ambas as orientações).
# VBoxContainer (não CenterContainer) para que a pilha cresça pra BAIXO — nunca pra cima
# invadindo o cabeçalho — quando uma trilha trouxer mais de um card.
var _band: VBoxContainer
# Container das trilhas: alterna entre lado a lado (paisagem) e empilhado (retrato) em _relayout.
var _tracks: BoxContainer
# Estilo da bandeja: o padding encolhe em paisagem (_relayout) pra faixa ficar baixa.
var _tray_box: StyleBoxFlat
# Largura corrente dos cards/colunas (recalculada por orientação em _relayout).
var _card_w: float = float(CARD_WIDTH_MAX)

# Colunas por trilha: { "furia"/"cura": { "vbox": VBox, "heading": Label, "cards": Array[HubCard] } }.
var _columns: Dictionary = {}
var _furia_heading: Label
var _cura_heading: Label

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = 10
	_build()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_header()
	_build_cards()

	_options = OptionsPanel.new()
	add_child(_options)
	_options_button.pressed.connect(_options.open)
	_options_button.mouse_entered.connect(AudioDirector.play_ui_hover)
	_options_button.focus_entered.connect(AudioDirector.play_ui_hover)

	_apply_safe_margins()
	_relayout()
	get_viewport().size_changed.connect(_apply_safe_margins)
	get_viewport().size_changed.connect(_relayout)
	Lang.language_changed.connect(_refresh_text)
	refresh()

# Cabeçalho: [ fragmentos + bônus à esquerda ] ··· [ Opções à direita ].
func _build_header() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(row)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(vbox)

	_frag_label = Label.new()
	_frag_label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_frag_label.add_theme_font_size_override("font_size", Constants.FONT_LG)
	vbox.add_child(_frag_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_options_button = Button.new()
	_options_button.text = Lang.t(&"hub.options.btn")
	_options_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_options_button)

# Corpo: as duas trilhas sobre uma bandeja escura (legibilidade contra a mata viva), na faixa
# superior da tela. Lado a lado em paisagem, empilhadas em retrato — a orientação é definida em
# _relayout. Deixa o centro pro acampamento e o rodapé livre pro D-pad e o rastro.
func _build_cards() -> void:
	_band = VBoxContainer.new()
	_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_band)

	# Bandeja: painel escuro de borda dura que segura os cards acima do acampamento animado.
	# Encolhe pra largura do conteúdo e centraliza na horizontal (o _band só comanda a vertical).
	var tray := PanelContainer.new()
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray_box = _tray_style()
	tray.add_theme_stylebox_override("panel", _tray_box)
	_band.add_child(tray)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(stack)

	_tracks = BoxContainer.new()
	_tracks.add_theme_constant_override("separation", COLUMN_SEP)
	_tracks.alignment = BoxContainer.ALIGNMENT_CENTER
	_tracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_tracks)

	_columns["furia"] = _build_column(_tracks, Lang.t(&"hub.track.furia"), MetaProgression.FURIA_KEYS)
	_columns["cura"] = _build_column(_tracks, Lang.t(&"hub.track.cura"), MetaProgression.CURA_KEYS)
	_furia_heading = _columns["furia"]["heading"]
	_cura_heading  = _columns["cura"]["heading"]

# Uma trilha: título + os cards disponíveis (ou um status do que vem a seguir).
func _build_column(parent: BoxContainer, title: String, keys: Array) -> Dictionary:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(_card_w, 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vbox)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	heading.add_theme_font_size_override("font_size", Constants.FONT_MD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(heading)

	var column := { "vbox": vbox, "heading": heading, "cards": [] as Array }
	var avail := MetaProgression.available_keys(keys)
	if avail.is_empty():
		_add_status(column, keys)
	else:
		for key: String in avail:
			var card := HubCard.new()
			vbox.add_child(card)
			card.setup(key)
			card.pressed.connect(_on_card_pressed.bind(card))
			card.mouse_entered.connect(AudioDirector.play_ui_hover)
			card.focus_entered.connect(AudioDirector.play_ui_hover)
			column["cards"].append(card)
	return column

# Status da trilha sem card disponível: o que vem a seguir (ou trilha completa).
func _add_status(column: Dictionary, keys: Array) -> void:
	var status := Label.new()
	status.text = _trilha_status_text(keys)
	status.add_theme_color_override("font_color", HINT_COLOR)
	status.add_theme_font_size_override("font_size", Constants.FONT_SM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(_card_w, 0)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column["vbox"].add_child(status)
	column["status"] = status

## Explica o próximo passo de uma trilha sem erva disponível: erva pendente travada por fase,
## travada pela regra desta-fogueira (requisito já cumprido) ou trilha completa.
func _trilha_status_text(keys: Array) -> String:
	var pending := MetaProgression.next_pending_key(keys)
	if pending == "":
		return Lang.t(&"hub.track.complete")
	var def: Dictionary = MetaProgression.UPGRADE_DEFS[pending]
	var nm: String = String(def.get("name", pending))
	if MetaProgression.phase_reached < int(def.get("phase", 1)):
		return Lang.tf(&"hub.next.phase", [nm, int(def.get("phase", 1))])
	return Lang.tf(&"hub.next.fire", [nm])

# ─── Compra ────────────────────────────────────────
func _on_card_pressed(card: HubCard) -> void:
	attempt_buy(card.key)

## Tenta comprar a erva `key` (mesmo caminho do clique). purchase_upgrade valida tudo e
## persiste. Em sucesso: card some, debita, atualiza HUD e demais cards; em falha (fragmento
## insuficiente): pisca o custo. Retorna true se comprou. Exposto para os testes.
func attempt_buy(key: String) -> bool:
	var card := _card_for(key)
	if card == null:
		return false
	if MetaProgression.purchase_upgrade(key):
		_spawn_floating_cost(card)
		_remove_card(card)
		card.consume()
		refresh()
		purchased.emit(key)
		return true
	card.deny()
	denied.emit(key)
	return false

func _card_for(key: String) -> HubCard:
	for line: String in _columns:
		for card: HubCard in _columns[line]["cards"]:
			if card.key == key:
				return card
	return null

# Tira o card da coluna; se a coluna esvaziou, mostra o status do que vem a seguir.
func _remove_card(card: HubCard) -> void:
	var line: String = String(MetaProgression.UPGRADE_DEFS[card.key].get("line", ""))
	if not _columns.has(line):
		return
	var column: Dictionary = _columns[line]
	column["cards"].erase(card)
	if column["cards"].is_empty():
		var keys: Array = MetaProgression.FURIA_KEYS if line == "furia" else MetaProgression.CURA_KEYS
		_add_status(column, keys)

## Reescreve fragmentos/bônus e re-avalia o brilho de cada card (comprar pode ter esvaziado o
## bolso). Fonte de verdade: MetaProgression.
func refresh() -> void:
	_frag_label.text = Lang.tf(&"hub.fragments", [int(MetaProgression.fragments)])
	for line: String in _columns:
		for card: HubCard in _columns[line]["cards"]:
			card.set_affordable(MetaProgression.fragments >= card.cost)

func _refresh_text(_lang: StringName = Lang.current()) -> void:
	_options_button.text = Lang.t(&"hub.options.btn")
	if is_instance_valid(_furia_heading):
		_furia_heading.text = Lang.t(&"hub.track.furia")
	if is_instance_valid(_cura_heading):
		_cura_heading.text = Lang.t(&"hub.track.cura")
	refresh()

# Número flutuante "−custo" subindo do card (screen-space, sobre o _root).
func _spawn_floating_cost(card: HubCard) -> void:
	var label := Label.new()
	label.text = "-%d" % card.cost
	label.add_theme_font_size_override("font_size", Constants.FONT_LG)
	label.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	label.position = card.global_position + Vector2(card.size.x * 0.5, 0.0)
	label.z_index = 5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 48.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(label.queue_free)

# ─── Para os testes / inspeção ─────────────────────
## Keys das ervas com card vivo agora (não compradas nesta fogueira).
func available_card_keys() -> Array[String]:
	var out: Array[String] = []
	for line: String in _columns:
		for card: HubCard in _columns[line]["cards"]:
			out.append(card.key)
	return out

# ─── Margens seguras (notch/safe-area; espelha o HUD antigo) ───
func _apply_safe_margins() -> void:
	var vp := get_viewport().get_visible_rect().size
	var top: int = int(clampf(minf(vp.x, vp.y) * 0.05, 28.0, 64.0))
	var side: int = int(clampf(minf(vp.x, vp.y) * 0.055, 40.0, 80.0))
	var fs: int = int(clampf(minf(vp.x, vp.y) * 0.024, 10.0, 18.0))
	_margin.add_theme_constant_override("margin_top", top)
	_margin.add_theme_constant_override("margin_left", side)
	_margin.add_theme_constant_override("margin_right", side)
	_options_button.add_theme_font_size_override("font_size", fs)

# ─── Layout responsivo (orientação + largura dos cards) ───
## Alterna as trilhas entre lado a lado (paisagem) e empilhadas (retrato), e dimensiona cards/
## colunas à largura útil corrente. Em retrato dois cards de 330px nunca caberiam lado a lado na
## tela estreita — empilhar + alargar cada card é o que torna a tela legível e tocável. Em
## paisagem cada coluna fica em ≤30% da largura e a bandeja encolhe o padding: faixa compacta.
func _relayout() -> void:
	if _tracks == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var portrait := Constants.is_portrait(vp)
	_tracks.vertical = portrait
	_tracks.add_theme_constant_override(
		"separation", PORTRAIT_TRACK_SEP if portrait else COLUMN_SEP
	)
	var side: float = clampf(minf(vp.x, vp.y) * 0.055, 40.0, 80.0)
	# Retrato: card ocupa quase a largura útil (capado pra não estourar em tablet retrato).
	# Paisagem: coluna em ≤30% da largura, duas trilhas lado a lado.
	_card_w = clampf(vp.x - side * 2.0, CARD_WIDTH_MIN, 520.0) if portrait \
		else clampf(vp.x * LANDSCAPE_COLUMN_FRACTION, CARD_WIDTH_MIN, CARD_WIDTH_MAX)
	if _tray_box != null:
		_tray_box.set_content_margin_all(Constants.SPACE_MD if portrait else Constants.SPACE_SM)
	for line: String in _columns:
		var col: Dictionary = _columns[line]
		col["vbox"].custom_minimum_size = Vector2(_card_w, 0)
		if col.has("status") and is_instance_valid(col["status"]):
			col["status"].custom_minimum_size = Vector2(_card_w, 0)
		for card: HubCard in col["cards"]:
			card.relayout(_card_w)
	_position_band(vp)

## Posiciona a bandeja dos cards: ancorada ABAIXO do cabeçalho (margem superior segura + a
## linha de fragmentos), pilha alinhada ao TOPO — nas DUAS orientações. Os cards
## moram na faixa de cima e o resto da tela fica livre pro acampamento, o rastro de saída e o
## D-pad (em paisagem, centralizar na vertical cobria o mapa).
func _position_band(vp: Vector2) -> void:
	if _band == null:
		return
	_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	_band.offset_left = 0.0
	_band.offset_right = 0.0
	_band.offset_bottom = 0.0
	_band.offset_top = clampf(minf(vp.x, vp.y) * 0.05, 28.0, 64.0) + HEADER_BAND_OFFSET
	_band.alignment = BoxContainer.ALIGNMENT_BEGIN

## Bandeja escura de borda dura atrás dos cards (sem cantos arredondados — guia de UI). Translúcida
## para deixar a fogueira e a vida ambiente respirarem por trás, mas firme o bastante pra leitura.
func _tray_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.02, 0.02, 0.82)
	s.border_color = Color(Constants.COLOR_AMBER.r, Constants.COLOR_AMBER.g, Constants.COLOR_AMBER.b, 0.22)
	s.set_border_width_all(Constants.UI_BORDER_WIDTH)
	s.set_content_margin_all(Constants.SPACE_MD)
	return s
