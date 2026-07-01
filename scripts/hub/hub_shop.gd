class_name HubShop
extends CanvasLayer

# Interface de aprimoramentos do Hub: os cards clicáveis das ervas disponíveis numa faixa
# compacta no topo, agrupados por trilha (DANO e VIDA). O cabeçalho (Terra Rara + mudo) é do
# UiRoot/HudHeader (Mode.CAMP) — este script cuida SÓ da bandeja. purchase_upgrade continua
# a fonte única de custo/requires/persistência.
#
# Regra de pacing preservada da Etapa 2: o conjunto de cards é montado UMA vez na ENTRADA
# (available_keys). Comprar uma erva NÃO faz a próxima da cadeia aparecer nesta fogueira — ela
# nasce só na próxima visita. Os fundos ignoram o mouse para não engolir o D-pad de toque nem
# a caminhada até o rastro de saída.

# Sucesso/recusa de compra — o HubManager escuta para tocar o SFX (dono do SfxSystem).
signal purchased(key: String)
signal denied(key: String)

const COLUMN_SEP := 48         # separação entre as trilhas lado a lado (paisagem)
const PORTRAIT_TRACK_SEP := 16 # separação entre as trilhas empilhadas (retrato)
const CARD_WIDTH_MAX := 330    # teto da largura de coluna em paisagem
const CARD_WIDTH_MIN := 240    # piso tocável/legível da coluna (ambas orientações)
# Em paisagem cada coluna fica em ≤30% da largura: os cards saem do centro do mapa e moram
# numa faixa compacta no topo, junto do cabeçalho (o acampamento volta a ser o protagonista).
const LANDSCAPE_COLUMN_FRACTION := 0.30

# ─── State ─────────────────────────────────────────
var _root: Control
# Bandeja dos cards: ancorada no topo, abaixo do cabeçalho (ambas as orientações).
# VBoxContainer (não CenterContainer) para que a pilha cresça pra BAIXO — nunca pra cima
# invadindo o cabeçalho — quando uma trilha trouxer mais de um card.
var _band: VBoxContainer
# Container das trilhas: alterna entre lado a lado (paisagem) e empilhado (retrato) em _relayout.
var _tracks: BoxContainer
# Estilo da bandeja: o padding encolhe em paisagem (_relayout) pra faixa ficar baixa.
var _tray: BrandPanel
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

	_build_cards()

	_relayout()
	get_viewport().size_changed.connect(_relayout)
	Lang.language_changed.connect(_refresh_text)
	refresh()

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
	_tray = BrandPanel.new()
	_tray.framed = true
	_tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_tray)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_child(stack)

	_tracks = BoxContainer.new()
	_tracks.add_theme_constant_override("separation", COLUMN_SEP)
	_tracks.alignment = BoxContainer.ALIGNMENT_CENTER
	_tracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_tracks)

	_columns["furia"] = _build_column(_tracks, Lang.t(&"hub.track.furia"), MetaProgression.FURIA_KEYS)
	_columns["cura"] = _build_column(_tracks, Lang.t(&"hub.track.cura"), MetaProgression.CURA_KEYS)
	_furia_heading = _columns["furia"]["heading"]
	_cura_heading  = _columns["cura"]["heading"]

# Uma trilha: título + os cards disponíveis. Trilha sem card fica limpa.
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
	if not avail.is_empty():
		for key: String in avail:
			var card := HubCard.new()
			vbox.add_child(card)
			card.setup(key)
			card.pressed.connect(_on_card_pressed.bind(card))
			card.mouse_entered.connect(AudioDirector.play_ui_hover)
			card.focus_entered.connect(AudioDirector.play_ui_hover)
			column["cards"].append(card)
	# Predicado A: trilha sem card a oferecer (fase travada / maxada / pré-req) some INTEIRA,
	# recentralizando a trilha viva (o BoxContainer pai pula filhos ocultos).
	vbox.visible = not (column["cards"] as Array).is_empty()
	return column

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

# Tira o card da coluna; se a coluna esvaziou, ela fica limpa até a próxima visita.
func _remove_card(card: HubCard) -> void:
	var line: String = String(MetaProgression.UPGRADE_DEFS[card.key].get("line", ""))
	if not _columns.has(line):
		return
	var column: Dictionary = _columns[line]
	column["cards"].erase(card)

## Reescreve fragmentos/bônus e re-avalia o brilho de cada card (comprar pode ter esvaziado o
## bolso). Fonte de verdade: MetaProgression.
func refresh() -> void:
	for line: String in _columns:
		var col: Dictionary = _columns[line]
		col["vbox"].visible = not (col["cards"] as Array).is_empty()
		for card: HubCard in col["cards"]:
			card.set_affordable(MetaProgression.fragments >= card.cost)

func _refresh_text(_lang: StringName = Lang.current()) -> void:
	if is_instance_valid(_furia_heading):
		_furia_heading.text = Lang.t(&"hub.track.furia")
	if is_instance_valid(_cura_heading):
		_cura_heading.text = Lang.t(&"hub.track.cura")
	for line: String in _columns:
		for card: HubCard in _columns[line]["cards"]:
			card.refresh_text()
	refresh()

# Número flutuante "−custo" subindo do card (serviço único do kit).
func _spawn_floating_cost(card: HubCard) -> void:
	FloatingPopup.spawn(_root, "-%d" % card.cost, Constants.COLOR_AMBER,
		Constants.FONT_LG, card.global_position + Vector2(card.size.x * 0.5, 0.0))

# ─── Para os testes / inspeção ─────────────────────
## Keys das ervas com card vivo agora (não compradas nesta fogueira).
func available_card_keys() -> Array[String]:
	var out: Array[String] = []
	for line: String in _columns:
		for card: HubCard in _columns[line]["cards"]:
			out.append(card.key)
	return out

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
	var side: float = Constants.safe_insets(vp).x
	# Retrato: card ocupa quase a largura útil (capado pra não estourar em tablet retrato).
	# Paisagem: coluna em ≤30% da largura, duas trilhas lado a lado.
	_card_w = clampf(vp.x - side * 2.0, CARD_WIDTH_MIN, 520.0) if portrait \
		else clampf(vp.x * LANDSCAPE_COLUMN_FRACTION, CARD_WIDTH_MIN, CARD_WIDTH_MAX)
	if _tray != null:
		var pad: int = Constants.SPACE_MD if portrait else Constants.SPACE_SM
		_tray.add_theme_constant_override("margin_left", pad)
		_tray.add_theme_constant_override("margin_right", pad)
	for line: String in _columns:
		var col: Dictionary = _columns[line]
		col["vbox"].custom_minimum_size = Vector2(_card_w, 0)
		for card: HubCard in col["cards"]:
			card.relayout(_card_w)
	_position_band(vp)

## Posiciona a bandeja dos cards: ancorada ABAIXO do header do UiRoot (safe-area + linha 1
## + placas), pilha alinhada ao TOPO — nas DUAS orientações. Os cards moram na faixa de cima
## e o resto da tela fica livre pro acampamento, o rastro de saída e o D-pad.
func _position_band(vp: Vector2) -> void:
	if _band == null:
		return
	_band.set_anchors_preset(Control.PRESET_FULL_RECT)
	_band.offset_left = 0.0
	_band.offset_right = 0.0
	_band.offset_bottom = 0.0
	_band.offset_top = Constants.safe_insets(vp).y + HudHeader.top_row_height(vp) \
		+ HudHeader.plate_pady() * 2.0 + float(Constants.SPACE_SM)
	_band.alignment = BoxContainer.ALIGNMENT_BEGIN
