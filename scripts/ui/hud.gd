class_name Hud
extends CanvasLayer

# HUD de combate/exploração. Layout coerente e sempre visível, independente da magnitude
# de HP ou de Terra Rara (antes os ícones de HP transbordavam com muito HP e a economia
# era "+".repeat(n), estourando a tela):
#
#   ┌ topo-esq: barra da CAIPORA            topo-dir: ◈ Terra Rara   🔊 ┐
#   │                                                                   │
#   └              centro (combate): barra do inimigo / boss           ┘
#
# A LÓGICA de dano/vida é a mesma — esta camada só consome os sinais existentes.

# ─── Constants ─────────────────────────────────────
# Header de combate nítido acima da vinheta do Atmosphere (CanvasLayer 50) e abaixo do
# ControlsHud (55) — só o combate sobe; o HUD de exploração fica no layer 0 (inalterado).
const COMBAT_HUD_LAYER: int = 52
# 2x no HUD tátil de exploração (telefone retrato): botão de mudo + contador de Terra Rara.
const HUD_TOUCH_SCALE: float = 2.0
# Respiro central entre as duas barras do header de combate (leitura "eu × ele").
const HEADER_CENTER_GAP: float = 48.0

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
	# Estrangulamento: se o UiRoot é dono do header desta tela (ex.: exploração migrada),
	# o Hud embutido se recolhe — o header vem do UiRoot. Ver scripts/ui/ui_root.gd.
	if UiRoot.owns(GameState.current_screen):
		return
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
		Lang.t(&"hud.player")
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
		# Modo combate (arena): header espelhado jogador × adversário, no topo, nítido acima
		# da vinheta. Terra Rara e mudo não têm função na briga — ficam ocultos (o estado de
		# áudio persiste; o botão reaparece na exploração).
		layer = COMBAT_HUD_LAYER
		_frag_counter.visible = false
		_music_btn.visible = false
		_enemy_bar = HealthBar.new()
		_root.add_child(_enemy_bar)
		_enemy_bar.set_mirrored(true)
		# Setup inicial; o spawn do inimigo reemite o max real (5/8/boss) e reajusta.
		_setup_enemy_bar(float(EnemyStats.COMMON_HP_EARLY), false)

	_layout()
	get_viewport().size_changed.connect(_layout)

	SignalBus.caipora_health_changed.connect(_on_caipora_health_changed)
	SignalBus.enemy_health_changed.connect(_on_enemy_health_changed)
	SignalBus.fragment_gained.connect(_on_fragment_gained)
	SignalBus.chama_gained.connect(_on_chama_gained)
	SignalBus.herb_collected.connect(_on_herb_collected)

# ─── Layout responsivo ─────────────────────────────
func _font_size() -> int:
	var vp := get_viewport().get_visible_rect().size
	return int(clampf(minf(vp.x, vp.y) * 0.026, 14.0, 24.0))

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var side: float = clampf(minf(vp.x, vp.y) * 0.055, 32.0, 72.0)
	var top: float = clampf(minf(vp.x, vp.y) * 0.05, 24.0, 56.0)
	var fs: int = _font_size()
	if show_enemy_hp:
		_layout_combat_header(vp, side, top, fs)
	else:
		_layout_exploration(vp, side, top, fs)

## Exploração: barra do jogador à esquerda; Terra Rara + mudo à direita. No telefone
## retrato, esses dois dobram de tamanho (alvo tátil e leitura de "moeda").
func _layout_exploration(vp: Vector2, side: float, top: float, fs: int) -> void:
	var pw: float = clampf(vp.x * 0.24, 220.0, 420.0)
	_player_bar.configure_size(pw, fs)
	_player_bar.position = Vector2(side, top)

	# Em retrato a arte contém-na-largura (canvas ~750px reduzido para a largura física do
	# telefone), então esses ícones ficam sempre proporcionalmente pequenos — dobra-os para
	# leitura e alvo tátil. `is_portrait` é ratio-invariante (correto sob canvas_items/expand);
	# o lado curto em px de canvas NÃO serve de gatilho aqui (é sempre ~750 em retrato).
	var scale: float = HUD_TOUCH_SCALE if Constants.is_portrait(vp) else 1.0
	_frag_counter.configure_size(fs, scale)
	_music_btn.configure_size(SpeakerButton.SIZE * scale)
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

## Combate: header estilo fighting game — jogador (esq.) e adversário (dir.) na mesma fileira
## do topo, larguras simétricas, fills espelhados encontrando-se no centro.
func _layout_combat_header(vp: Vector2, side: float, top: float, fs: int) -> void:
	var hw: float = (clampf(vp.x * 0.40, 300.0, 620.0) if _enemy_is_boss
		else clampf(vp.x * 0.34, 240.0, 460.0))
	# Nunca colidir no centro: cada barra ≤ metade do espaço útil menos o respiro central.
	var max_hw: float = (vp.x - side * 2.0 - HEADER_CENTER_GAP) * 0.5
	hw = minf(hw, maxf(max_hw, 1.0))

	_player_bar.configure_size(hw, fs)
	_player_bar.position = Vector2(side, top)
	if _enemy_bar != null:
		_enemy_bar.configure_size(hw, fs)
		_enemy_bar.position = Vector2(vp.x - side - hw, top)

func _setup_enemy_bar(max_health: float, is_boss: bool) -> void:
	_enemy_max = max_health
	_enemy_is_boss = is_boss
	_enemy_bar.setup(
		max_health,
		Constants.COLOR_AMBER,
		Constants.COLOR_ARENA_BG,
		Constants.COLOR_AMBER.darkened(0.15),
		Lang.t(&"hud.enemy"),
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
	_show_popup(Lang.t(&"hud.chama"), Constants.COLOR_FIRE_HOT)

func _on_herb_collected(bonus: int) -> void:
	_show_popup("+%d %s" % [bonus, Lang.t(&"hud.herb")], Constants.COLOR_HERB_GLOW)

func _on_music_toggle() -> void:
	AudioDirector.toggle_music_ambience()
	_music_btn.set_muted(not AudioDirector.is_music_enabled())

# ─── Popups ────────────────────────────────────────
func _show_fragment_popup(amount: float) -> void:
	var n: String = "%d" % int(amount) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	var key := &"hud.fragment.pl" if amount != 1.0 else &"hud.fragment.s"
	_show_popup(Lang.tf(key, [n]), Constants.COLOR_AMBER)

## Texto compacto do ganho em pt-BR (função pura, sem acesso a Lang — testável isolado).
## "Terra Rara" é incontável (minério), então não há plural. NÃO usar "%g": o format do
## Godot não suporta e vaza literal na tela. Só "%d", "%.1f", "%s".
static func format_fragment_popup(amount: float) -> String:
	var n: String = "%d" % int(amount) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	return "+%s Terra Rara" % n

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
