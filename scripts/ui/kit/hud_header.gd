class_name HudHeader
extends Control

# Header unificado da UI — um só componente para TODAS as telas. Substitui
# hud.gd::_layout_exploration / _layout_combat_header e hub_shop::_build_header.
# É uma VIEW: recebe valores por API; o UiRoot faz a fiação com o SignalBus.
# Safe-area e escala tátil vêm de fonte única (Constants.safe_insets / hud_touch_scale).
#
#   CAMP        →  Terra Rara + mudo (dir.)                  [sem HP: o acampamento cura]
#   EXPLORATION →  HP jogador (esq.)  |  Terra Rara + mudo (dir.)
#   COMBAT      →  HP jogador (esq.)  |  HP inimigo espelhado + NOME REAL (dir.)
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
var _phase_badge: Label

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

	_phase_badge = Label.new()
	_phase_badge.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	_phase_badge.add_theme_font_size_override("font_size", Constants.FONT_SM)
	_phase_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_phase_badge)

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

func set_phase(phase: int) -> void:
	_phase_badge.text = Lang.tf(&"hud.phase", [phase])

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
	var camp := _mode == Mode.CAMP
	_player_bar.visible = combat or exploration
	_enemy_bar.visible = combat
	_frag.visible = exploration or camp
	_mute.visible = exploration or camp
	_phase_badge.visible = combat

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
	match _mode:
		Mode.COMBAT:
			_layout_combat(vp, side, top, fs)
		Mode.EXPLORATION:
			_layout_player(vp, side, top, fs)
			_layout_right_group(vp, side, top, fs)
		Mode.CAMP:
			_layout_right_group(vp, side, top, fs)
		_:
			pass  # MENU: header vazio
	_rebuild_plates()
	queue_redraw()

func _layout_player(vp: Vector2, side: float, top: float, fs: int) -> void:
	var pw := clampf(vp.x * 0.24, 220.0, 420.0)
	_player_bar.configure_size(pw, fs)
	_player_bar.position = Vector2(side, top)

## Terra Rara + mudo à direita; 2x em telefone-retrato (política tátil única).
func _layout_right_group(vp: Vector2, side: float, top: float, fs: int) -> void:
	var scale := Constants.hud_touch_scale(vp)
	_frag.configure_size(fs, scale)
	_mute.configure_size(SpeakerButton.SIZE * scale)
	_mute.size = _mute.get_combined_minimum_size()
	var mute_h := _mute.size.y
	var frag_h := _frag.size.y
	var group_h := maxf(mute_h, frag_h)
	var mx := vp.x - side - _mute.size.x
	_mute.position = Vector2(mx, top + (group_h - mute_h) * 0.5)
	_frag.position = Vector2(mx - float(Constants.SPACE_MD) - _frag.size.x, top + (group_h - frag_h) * 0.5)

## Header de luta: jogador (esq.) × inimigo (dir. espelhado), larguras simétricas.
func _layout_combat(vp: Vector2, side: float, top: float, fs: int) -> void:
	var hw := (clampf(vp.x * 0.40, 300.0, 620.0) if _enemy_is_boss
		else clampf(vp.x * 0.34, 240.0, 460.0))
	var max_hw := (vp.x - side * 2.0 - HEADER_CENTER_GAP) * 0.5
	hw = minf(hw, maxf(max_hw, 1.0))
	_player_bar.configure_size(hw, fs)
	_player_bar.position = Vector2(side, top)
	_enemy_bar.configure_size(hw, fs)
	_enemy_bar.position = Vector2(vp.x - side - hw, top)
	# Badge de fase centralizado no vão entre as duas placas.
	_phase_badge.size = Vector2(vp.x, float(fs))
	_phase_badge.position = Vector2(0.0, top + _player_bar.total_height() * 0.5 - float(fs) * 0.5)

# ─── Placas serrilhadas por grupo (chrome "casca flutuante") ───
func _rebuild_plates() -> void:
	_plates.clear()
	var padx := float(Constants.SPACE_SM)
	var pady := float(Constants.SPACE_XS) + BrandFrame.crest_clearance(HUD_CREST_SCALE)
	match _mode:
		Mode.COMBAT:
			_append_plate([_player_bar], padx, pady)
			if _enemy_max > 0.0:
				_append_plate([_enemy_bar], padx, pady)
		Mode.EXPLORATION:
			_append_plate([_player_bar], padx, pady)
			_append_plate([_frag, _mute], padx, pady)
		Mode.CAMP:
			_append_plate([_frag, _mute], padx, pady)
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
