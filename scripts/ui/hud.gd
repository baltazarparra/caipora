class_name Hud
extends CanvasLayer

# HUD de combate/exploração. Layout coerente e sempre visível, independente da magnitude
# de HP ou de fragmentos (antes os ícones de HP transbordavam com muito HP e os fragmentos
# eram "+".repeat(n), estourando a tela):
#
#   ┌ topo-esq: barra da CAIPORA            topo-dir: ◈ fragmentos   🔊 ┐
#   │                                                                   │
#   └              centro (combate): barra do inimigo / boss           ┘
#
# A LÓGICA de dano/vida é a mesma — esta camada só consome os sinais existentes.

# ─── Exports ───────────────────────────────────────
@export var show_enemy_hp: bool = true

# ─── State ─────────────────────────────────────────
var _root: Control
var _player_bar: HealthBar
var _enemy_bar: HealthBar
var _frag_counter: FragmentCounter
var _music_btn: SpeakerButton

var _enemy_max: float = -1.0
var _enemy_is_boss: bool = false

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_player_bar = HealthBar.new()
	_root.add_child(_player_bar)
	_player_bar.setup(
		GameState.caipora_max_hp,
		Constants.COLOR_BLOOD,
		Constants.COLOR_ARENA_BG,
		Constants.COLOR_BLOOD.lightened(0.2),
		"CAIPORA"
	)
	_player_bar.set_value(GameState.caipora_current_hp)

	_frag_counter = FragmentCounter.new()
	_root.add_child(_frag_counter)
	_frag_counter.set_count(int(MetaProgression.fragments))

	_music_btn = SpeakerButton.new()
	_music_btn.icon_color = Constants.COLOR_AMBER
	_music_btn.muted = not AudioDirector.is_music_enabled()
	_music_btn.pressed.connect(_on_music_toggle)
	_root.add_child(_music_btn)

	if show_enemy_hp:
		_enemy_bar = HealthBar.new()
		_root.add_child(_enemy_bar)
		# Setup inicial; o spawn do inimigo reemite o max real (5/8/boss) e reajusta.
		_setup_enemy_bar(float(EnemyStats.COMMON_HP_EARLY), false)

	_layout()
	get_viewport().size_changed.connect(_layout)

	SignalBus.caipora_health_changed.connect(_on_caipora_health_changed)
	SignalBus.enemy_health_changed.connect(_on_enemy_health_changed)
	SignalBus.fragment_gained.connect(_on_fragment_gained)
	SignalBus.chama_gained.connect(_on_chama_gained)
	SignalBus.chest_opened.connect(_on_chest_opened)

# ─── Layout responsivo ─────────────────────────────
func _font_size() -> int:
	var vp := get_viewport().get_visible_rect().size
	return int(clampf(minf(vp.x, vp.y) * 0.026, 14.0, 24.0))

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var side: float = clampf(minf(vp.x, vp.y) * 0.055, 32.0, 72.0)
	var top: float = clampf(minf(vp.x, vp.y) * 0.05, 24.0, 56.0)
	var fs: int = _font_size()

	# Barra do jogador — topo-esquerda.
	var pw: float = clampf(vp.x * 0.24, 220.0, 420.0)
	_player_bar.configure_size(pw, fs)
	_player_bar.position = Vector2(side, top)

	# Grupo topo-direita: fragmentos + botão de áudio.
	_frag_counter.configure_size(fs)
	_music_btn.size = _music_btn.get_combined_minimum_size()
	var music_w: float = _music_btn.size.x
	var music_h: float = _music_btn.size.y
	var frag_h: float = _frag_counter.size.y
	var group_h: float = maxf(music_h, frag_h)
	var mx: float = vp.x - side - music_w
	_music_btn.position = Vector2(mx, top + (group_h - music_h) * 0.5)
	_frag_counter.position = Vector2(
		mx - float(Constants.SPACE_MD) - _frag_counter.size.x,
		top + (group_h - frag_h) * 0.5
	)

	# Barra do inimigo — centralizada, numa fileira abaixo dos cantos do topo
	# (garante que nunca colida com jogador/fragmentos por mais largo que seja o boss).
	if _enemy_bar != null:
		var ew: float = (clampf(vp.x * 0.46, 360.0, 760.0) if _enemy_is_boss
			else clampf(vp.x * 0.30, 260.0, 520.0))
		_enemy_bar.configure_size(ew, fs)
		var row_y: float = top + maxf(_player_bar.total_height(), group_h) + float(Constants.SPACE_MD)
		_enemy_bar.position = Vector2((vp.x - ew) * 0.5, row_y)

func _setup_enemy_bar(max_health: float, is_boss: bool) -> void:
	_enemy_max = max_health
	_enemy_is_boss = is_boss
	_enemy_bar.setup(
		max_health,
		Constants.COLOR_AMBER,
		Constants.COLOR_ARENA_BG,
		Constants.COLOR_AMBER.darkened(0.15),
		"CRIATURA",
		is_boss
	)

# ─── Signal handlers ───────────────────────────────
func _on_caipora_health_changed(new_health: float, max_health: float) -> void:
	_player_bar.set_max(max_health)
	_player_bar.set_value(new_health)

func _on_enemy_health_changed(new_health: float, max_health: float) -> void:
	if not show_enemy_hp or _enemy_bar == null:
		return
	var is_boss: bool = GameState.active_combat_is_boss
	if not is_equal_approx(max_health, _enemy_max) or is_boss != _enemy_is_boss:
		_setup_enemy_bar(max_health, is_boss)
		_layout()
	_enemy_bar.set_value(new_health)

func _on_fragment_gained(total: float, amount: float) -> void:
	_frag_counter.set_count(int(total))
	_show_fragment_popup(amount)

func _on_chama_gained() -> void:
	# A CHAMA substitui o fragmento daquela morte; este popup é o feedback da conquista.
	_show_popup("CHAMA!", Constants.COLOR_FIRE_HOT)

func _on_chest_opened() -> void:
	_show_popup("+1 HP", Constants.COLOR_BLOOD)

func _on_music_toggle() -> void:
	AudioDirector.toggle_music_ambience()
	_music_btn.set_muted(not AudioDirector.is_music_enabled())

# ─── Popups ────────────────────────────────────────
func _show_fragment_popup(amount: float) -> void:
	_show_popup(format_fragment_popup(amount), Constants.COLOR_AMBER)

## Texto compacto do ganho: inteiro sem casas ("+3 fragmentos"), fracionário com uma casa
## ("+1.5 fragmento" — drops de 1.5/kill na Fase 2 somam múltiplos de 0.5). NÃO usar "%g": o
## format do Godot não suporta esse especificador e o devolvia LITERAL na tela ("+%.4g
## fragmento%s"), além de empurrar erro. Só "%d", "%.1f" e "%s" (todos válidos) aqui.
static func format_fragment_popup(amount: float) -> String:
	var n: String = "%d" % int(amount) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	var plural: String = "s" if amount != 1.0 else ""
	return "+%s fragmento%s" % [n, plural]

func _show_popup(text: String, color: Color) -> void:
	var popup := Label.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", _font_size() + 4)
	popup.add_theme_color_override("font_color", color)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.position = Vector2(-80.0, 40.0)
	_root.add_child(popup)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 48.0, 1.5)
	tween.tween_property(popup, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(popup.queue_free)
