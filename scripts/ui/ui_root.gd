extends Node
# Autoload registrado como UiRoot em project.godot.
# Sem class_name: conflita com o nome do autoload em Godot 4 (mesmo motivo do PerfHud).
#
# Dono da composição de UI: hospeda os slots (CanvasLayer) nos layers canônicos e
# recompõe a UI a cada troca de tela (screen_changed). Estrangula a UI embutida nas
# cenas — telas migradas usam o header do UiRoot e o hud.gd embutido se recolhe (owns()).
# Precedente: ControlsHud (autoload que escuta screen_changed e reconstrói por modo).

# Telas já migradas ao UiRoot (cresce a cada fase do PRD). F3: exploração; C5: acampamento.
const MIGRATED_PREFIXES: PackedStringArray = ["EXPLORATION", "ARENA", "HUB"]
const POPUP_FONT_BONUS := 4

var _header_layer: CanvasLayer
var _header: HudHeader
var _active: bool = false
var _combat: bool = false
var _enemy_max: float = -1.0
var _enemy_is_boss: bool = false

func _ready() -> void:
	_header_layer = CanvasLayer.new()
	_header_layer.layer = Constants.LAYER_HUD
	add_child(_header_layer)
	_header = HudHeader.new()
	_header_layer.add_child(_header)
	_header.mute_toggled.connect(_on_mute_toggled)

	SignalBus.screen_changed.connect(_on_screen_changed)
	SignalBus.caipora_health_changed.connect(_on_caipora_health)
	SignalBus.fragment_gained.connect(_on_fragment_gained)
	SignalBus.enemy_health_changed.connect(_on_enemy_health)
	SignalBus.chama_gained.connect(_on_chama_gained)
	SignalBus.herb_collected.connect(_on_herb_collected)
	_apply_screen(GameState.current_screen)

## True quando o UiRoot é dono do header desta tela (o hud.gd embutido se recolhe).
func owns(screen: SignalBus.Screen) -> bool:
	var screen_name: String = SignalBus.Screen.keys()[screen]
	for prefix: String in MIGRATED_PREFIXES:
		if screen_name.begins_with(prefix):
			return true
	return false

func _on_screen_changed(screen: SignalBus.Screen) -> void:
	_apply_screen(screen)

func _is_arena(screen: SignalBus.Screen) -> bool:
	return SignalBus.Screen.keys()[screen].begins_with("ARENA")

func _apply_screen(screen: SignalBus.Screen) -> void:
	_active = owns(screen)
	_header_layer.visible = _active
	if not _active:
		return
	_combat = _is_arena(screen)
	_header.set_player_health(GameState.caipora_current_hp, GameState.caipora_max_hp)
	if _combat:
		# Força re-setup da barra do inimigo no próximo enemy_health_changed (spawn).
		_enemy_max = -1.0
		_enemy_is_boss = false
		_header.set_mode(HudHeader.Mode.COMBAT)
	else:
		# Linha 1 (moeda|mudo) idêntica no acampamento e na exploração.
		var camp := screen == SignalBus.Screen.HUB
		_header.set_mode(HudHeader.Mode.CAMP if camp else HudHeader.Mode.EXPLORATION)
		_header.set_currency(int(MetaProgression.fragments))
		_header.set_muted(not AudioDirector.is_music_enabled())

func _on_caipora_health(new_health: float, max_health: float) -> void:
	if _active:
		_header.set_player_health(new_health, max_health)

func _on_enemy_health(new_health: float, max_health: float) -> void:
	if not _active or not _combat:
		return
	var is_boss: bool = GameState.active_combat_is_boss
	if not is_equal_approx(max_health, _enemy_max) or is_boss != _enemy_is_boss:
		_enemy_max = max_health
		_enemy_is_boss = is_boss
		_header.setup_enemy(max_health, is_boss, GameState.active_combat_name)
	_header.set_enemy_health(new_health, max_health)

func _on_fragment_gained(total: float, amount: float) -> void:
	if not _active or _combat:
		return
	_header.set_currency(int(total))
	if amount <= 0.0:
		return  # compra no acampamento: o card já mostra o "−custo" flutuante
	var n: String = "%d" % int(amount) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	var key := &"hud.fragment.pl" if amount != 1.0 else &"hud.fragment.s"
	_spawn_popup(Lang.tf(key, [n]), Constants.COLOR_AMBER)

func _on_chama_gained() -> void:
	if _active and not _combat:
		_spawn_popup(Lang.t(&"hud.chama"), Constants.COLOR_FIRE_HOT)

func _on_herb_collected(bonus: int) -> void:
	if _active and not _combat:
		_spawn_popup("+%d %s" % [bonus, Lang.t(&"hud.herb")], Constants.COLOR_HERB_GLOW)

func _on_mute_toggled() -> void:
	AudioDirector.toggle_music_ambience()
	_header.set_muted(not AudioDirector.is_music_enabled())

func _spawn_popup(text: String, color: Color) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(750, 1334)
	var fs: int = int(clampf(minf(vp.x, vp.y) * 0.026, 14.0, 24.0)) + POPUP_FONT_BONUS
	var at := Vector2(vp.x * 0.5 - 60.0, vp.y * 0.12)
	FloatingPopup.spawn(_header, text, color, fs, at)
