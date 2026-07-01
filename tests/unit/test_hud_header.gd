extends GutTest

# F2 — HudHeader: composição por modo (visibilidade de slots), nome real do inimigo
# e as políticas únicas de safe-area/escala tátil (Constants).

var _h: HudHeader

func before_each() -> void:
	_h = HudHeader.new()
	add_child_autofree(_h)

func test_combat_shows_enemy_hides_currency() -> void:
	_h.set_mode(HudHeader.Mode.COMBAT)
	assert_true(_h.player_visible(), "combate mostra HP do jogador")
	assert_true(_h.enemy_visible(), "combate mostra HP do inimigo")
	assert_false(_h.currency_visible(), "combate esconde Terra Rara")
	assert_false(_h.mute_visible(), "combate esconde o mudo")

func test_exploration_shows_currency_hides_enemy() -> void:
	_h.set_mode(HudHeader.Mode.EXPLORATION)
	assert_true(_h.player_visible())
	assert_false(_h.enemy_visible())
	assert_true(_h.currency_visible())
	assert_true(_h.mute_visible())

func test_camp_hides_player_hp() -> void:
	_h.set_mode(HudHeader.Mode.CAMP)
	assert_false(_h.player_visible(), "acampamento não mostra HP (cura ao entrar)")
	assert_true(_h.currency_visible())

func test_enemy_real_name() -> void:
	_h.set_mode(HudHeader.Mode.COMBAT)
	_h.setup_enemy(8.0, false, "Caçador")
	assert_eq(_h.enemy_name(), "Caçador", "combate usa o nome real, não 'hud.enemy'")

func test_touch_scale_policy() -> void:
	assert_eq(Constants.hud_touch_scale(Vector2(400, 800)), Constants.HUD_TOUCH_SCALE, "retrato dobra")
	assert_eq(Constants.hud_touch_scale(Vector2(800, 400)), 1.0, "paisagem não dobra")

func test_safe_insets_clamped() -> void:
	var big := Constants.safe_insets(Vector2(4000, 4000))
	assert_eq(big.x, 80.0, "lateral clampa no máximo")
	assert_eq(big.y, 64.0, "topo clampa no máximo")

func test_exploration_builds_three_plates() -> void:
	# Placas flutuantes: moeda, mudo e HP — cada grupo na sua casca.
	_h.set_mode(HudHeader.Mode.EXPLORATION)
	assert_eq(_h._plates.size(), 3, "exploração: placas de moeda, mudo e HP")

func test_camp_builds_two_plates() -> void:
	_h.set_mode(HudHeader.Mode.CAMP)
	assert_eq(_h._plates.size(), 2, "acampamento: placas de moeda e mudo")

func test_top_row_currency_left_mute_right() -> void:
	# Padrão do acampamento em toda tela: Terra Rara à esquerda, mudo à direita.
	_h.set_mode(HudHeader.Mode.CAMP)
	assert_lt(_h._frag.position.x, _h._mute.position.x, "moeda à esquerda do mudo")

func test_exploration_hp_bar_below_top_row() -> void:
	_h.set_mode(HudHeader.Mode.EXPLORATION)
	var row_bottom := maxf(_h._frag.position.y + _h._frag.size.y,
		_h._mute.position.y + _h._mute.size.y)
	assert_gt(_h._player_bar.position.y, row_bottom, "HP vive na linha 2, abaixo da linha 1")

func test_phase_badge_only_in_combat() -> void:
	_h.set_mode(HudHeader.Mode.COMBAT)
	assert_true(_h._phase_badge.visible, "badge de fase aparece no combate")
	_h.set_mode(HudHeader.Mode.EXPLORATION)
	assert_false(_h._phase_badge.visible, "badge de fase some fora do combate")
