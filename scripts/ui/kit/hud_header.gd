class_name HudHeader
extends Control

# Header unificado da UI — um só componente para TODAS as telas. Substitui
# hud.gd::_layout_exploration / _layout_combat_header e hub_shop::_build_header.
# É uma VIEW: recebe valores por API; o UiRoot faz a fiação com o SignalBus.
# Safe-area e escala tátil vêm de fonte única (Constants.safe_insets / hud_touch_scale).
#
#   CAMP        →  linha 1: Terra Rara (esq.) | mudo (dir.)  [sem HP: o acampamento cura]
#   EXPLORATION →  linha 1 idêntica ao CAMP; linha 2: HP do jogador (esq.)
#   COMBAT      →  MESMO header da exploração + HP do inimigo espelhado (dir. da linha 2,
#                  com NOME REAL) — um só header no jogo inteiro (decisão do dono)
#   MENU        →  vazio (o menu tem rodapé próprio)

enum Mode { MENU, CAMP, EXPLORATION, COMBAT }

const HEADER_CENTER_GAP := 48.0
## Crista reduzida nas placas baixas do HUD (menos ruído que nos painéis-herói).
const HUD_CREST_SCALE := 0.6

signal mute_toggled

var _mode: Mode = Mode.EXPLORATION
var _player_bar: HealthBar
var _enemy_bar: HealthBar
var _frag: FragmentCounter
var _mute: SpeakerButton
var _enemy_max: float = -1.0
var _enemy_is_boss: bool = false
var _enemy_name: String = ""
var _plates: Array[Rect2] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_player_bar = HealthBar.new()
	add_child(_player_bar)
	_player_bar.setup(
		GameState.caipora_max_hp,
		Constants.COLOR_BLOOD,
		Constants.COLOR_ARENA_BG,
		Constants.COLOR_BLOOD.lightened(0.2),
		Lang.t(&"hud.player")
	)
	_player_bar.set_value(GameState.caipora_current_hp)

	_enemy_bar = HealthBar.new()
	_enemy_bar.set_mirrored(true)
	add_child(_enemy_bar)

	_frag = FragmentCounter.new()
	add_child(_frag)

	_mute = SpeakerButton.new()
	_mute.icon_color = Constants.COLOR_AMBER
	_mute.pressed.connect(func() -> void: mute_toggled.emit())
	add_child(_mute)

	_apply_mode()
	if get_viewport() != null:
		get_viewport().size_changed.connect(relayout)
	relayout()

# ─── API (o UiRoot chama) ──────────────────────────
func set_mode(mode: Mode) -> void:
	_mode = mode
	_apply_mode()
	relayout()

func set_player_health(current: float, max_health: float) -> void:
	_player_bar.set_max(max_health)
	_player_bar.set_value(current)

## Define escala/identidade da barra do inimigo (com o NOME REAL da criatura/boss).
func setup_enemy(max_health: float, is_boss: bool, enemy_name: String) -> void:
	_enemy_max = max_health
	_enemy_is_boss = is_boss
	_enemy_name = enemy_name
	_enemy_bar.setup(
		max_health,
		Constants.COLOR_AMBER,
		Constants.COLOR_ARENA_BG,
		Constants.COLOR_AMBER.darkened(0.15),
		enemy_name,
		is_boss
	)
	relayout()

func set_enemy_health(current: float, max_health: float) -> void:
	if not is_equal_approx(max_health, _enemy_max):
		_enemy_max = max_health
		_enemy_bar.set_max(max_health)
	_enemy_bar.set_value(current)

func set_currency(amount: int) -> void:
	_frag.set_count(amount)
	# A largura do contador muda com a contagem — as placas precisam re-abraçar.
	relayout()

func set_muted(muted: bool) -> void:
	_mute.set_muted(muted)

# ─── Acessores de estado (view/testes) ─────────────
func player_visible() -> bool: return _player_bar != null and _player_bar.visible
func enemy_visible() -> bool: return _enemy_bar != null and _enemy_bar.visible
func currency_visible() -> bool: return _frag != null and _frag.visible
func mute_visible() -> bool: return _mute != null and _mute.visible
func enemy_name() -> String: return _enemy_name

# ─── Interno ───────────────────────────────────────
func _apply_mode() -> void:
	if _player_bar == null:
		return
	var combat := _mode == Mode.COMBAT
	var exploration := _mode == Mode.EXPLORATION
	_player_bar.visible = combat or exploration
	_enemy_bar.visible = combat
	# Linha 1 (moeda|mudo) vive em TODA tela de jogo — inclusive combate.
	_frag.visible = _mode != Mode.MENU
	_mute.visible = _mode != Mode.MENU

func _font_size(vp: Vector2) -> int:
	return int(clampf(minf(vp.x, vp.y) * 0.026, 14.0, 24.0))

func _viewport_size() -> Vector2:
	if get_viewport() != null:
		return get_viewport().get_visible_rect().size
	return size

func relayout() -> void:
	if _player_bar == null:
		return
	var vp := _viewport_size()
	var insets := Constants.safe_insets(vp)
	var side := insets.x
	var top := insets.y
	var fs := _font_size(vp)
	# Linha 2 (barras de HP) senta abaixo das placas da linha 1 — mesma âncora em toda tela.
	var bar_y := top + top_row_height(vp) + plate_pady() * 2.0 + float(Constants.SPACE_XS)
	match _mode:
		Mode.COMBAT:
			_layout_top_row(vp, side, top, fs)
			_layout_combat(vp, side, bar_y, fs)
		Mode.EXPLORATION:
			_layout_top_row(vp, side, top, fs)
			_layout_player(vp, side, bar_y, fs)
		Mode.CAMP:
			_layout_top_row(vp, side, top, fs)
		_:
			pass  # MENU: header vazio
	_rebuild_plates()
	queue_redraw()

func _layout_player(vp: Vector2, side: float, top: float, fs: int) -> void:
	var pw := clampf(vp.x * 0.24, 220.0, 420.0)
	_player_bar.configure_size(pw, fs)
	_player_bar.position = Vector2(side, top)

## Altura canônica da linha 1 (moeda|mudo) — o mudo é o item mais alto da linha.
## Consumida também por quem se ancora abaixo do header (ex.: bandeja do acampamento).
static func top_row_height(vp: Vector2) -> float:
	return (SpeakerButton.SIZE + SpeakerButton.HITBOX_PAD * 2.0) * Constants.hud_touch_scale(vp)

## Linha 1 do HUD: Terra Rara à ESQUERDA, mudo à DIREITA (padrão do acampamento em
## toda tela); 2x em telefone-retrato (política tátil única). Cada um na sua placa —
## cantos opostos, nunca disputam espaço (nem com o pop do contador).
func _layout_top_row(vp: Vector2, side: float, top: float, fs: int) -> void:
	var scale := Constants.hud_touch_scale(vp)
	var row_h := top_row_height(vp)
	_frag.configure_size(fs, scale)
	_frag.size = _frag.get_combined_minimum_size()
	_mute.configure_size(SpeakerButton.SIZE * scale)
	_mute.size = _mute.get_combined_minimum_size()
	_frag.position = Vector2(side, top + (row_h - _frag.size.y) * 0.5)
	_mute.position = Vector2(vp.x - side - _mute.size.x, top + (row_h - _mute.size.y) * 0.5)

## Barras de luta (linha 2): jogador (esq.) × inimigo (dir. espelhado), larguras simétricas.
func _layout_combat(vp: Vector2, side: float, top: float, fs: int) -> void:
	var hw := (clampf(vp.x * 0.40, 300.0, 620.0) if _enemy_is_boss
		else clampf(vp.x * 0.34, 240.0, 460.0))
	var max_hw := (vp.x - side * 2.0 - HEADER_CENTER_GAP) * 0.5
	hw = minf(hw, maxf(max_hw, 1.0))
	_player_bar.configure_size(hw, fs)
	_player_bar.position = Vector2(side, top)
	_enemy_bar.configure_size(hw, fs)
	_enemy_bar.position = Vector2(vp.x - side - hw, top)

# ─── Placas serrilhadas por grupo (chrome "casca flutuante") ───
## Folga vertical das placas (respiro + crista). Estático: quem se ancora abaixo do
## header (ex.: bandeja do acampamento) soma isto ao top_row_height.
static func plate_pady() -> float:
	return float(Constants.SPACE_XS) + BrandFrame.crest_clearance(HUD_CREST_SCALE)

func _rebuild_plates() -> void:
	_plates.clear()
	var padx := float(Constants.SPACE_SM)
	var pady := plate_pady()
	match _mode:
		Mode.COMBAT:
			_append_plate([_frag], padx, pady)
			_append_plate([_mute], padx, pady)
			_append_plate([_player_bar], padx, pady)
			if _enemy_max > 0.0:
				_append_plate([_enemy_bar], padx, pady)
		Mode.EXPLORATION:
			_append_plate([_frag], padx, pady)
			_append_plate([_mute], padx, pady)
			_append_plate([_player_bar], padx, pady)
		Mode.CAMP:
			_append_plate([_frag], padx, pady)
			_append_plate([_mute], padx, pady)
		_:
			pass

func _append_plate(nodes: Array, padx: float, pady: float) -> void:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for node: Control in nodes:
		if node == null or not node.visible:
			continue
		min_p = min_p.min(node.position)
		max_p = max_p.max(node.position + node.size)
	if min_p.x == INF:
		return
	_plates.append(Rect2(min_p - Vector2(padx, pady), (max_p - min_p) + Vector2(padx * 2.0, pady * 2.0)))

func _draw() -> void:
	var bg := Constants.COLOR_NIGHT
	bg.a = 0.8
	for plate: Rect2 in _plates:
		if plate.size.x <= 1.0 or plate.size.y <= 1.0:
			continue
		BrandFrame.draw_plate(self, plate, bg, Constants.COLOR_JUBA_DARK,
			float(Constants.UI_BORDER_WIDTH), HUD_CREST_SCALE)
