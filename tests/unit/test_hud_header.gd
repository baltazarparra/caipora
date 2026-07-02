extends GutTest

# F2 — HudHeader: composição por modo (visibilidade de slots), nome real do inimigo
# e as políticas únicas de safe-area/escala tátil (Constants).

var _h: HudHeader

func before_each() -> void:
	_h = HudHeader.new()
	add_child_autofree(_h)

func test_combat_shows_enemy_and_standard_header() -> void:
	# Um só header no jogo inteiro: combate mantém a linha 1 (moeda|mudo) e
	# só ADICIONA o HP do inimigo à direita (decisão do dono, 2026-07-01).
	_h.set_mode(HudHeader.Mode.COMBAT)
	assert_true(_h.player_visible(), "combate mostra HP do jogador")
	assert_true(_h.enemy_visible(), "combate mostra HP do inimigo")
	assert_true(_h.currency_visible(), "combate mantém Terra Rara (header padrão)")
	assert_true(_h.mute_visible(), "combate mantém o mudo (header padrão)")

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

func test_combat_bars_on_second_row_enemy_right() -> void:
	_h.set_mode(HudHeader.Mode.COMBAT)
	_h.setup_enemy(8.0, false, "Caçador")
	var row_bottom := maxf(_h._frag.position.y + _h._frag.size.y,
		_h._mute.position.y + _h._mute.size.y)
	assert_gt(_h._player_bar.position.y, row_bottom, "barras na linha 2, abaixo da linha 1")
	assert_eq(_h._player_bar.position.y, _h._enemy_bar.position.y, "barras na mesma linha")
	assert_lt(_h._player_bar.position.x, _h._enemy_bar.position.x, "inimigo à direita")

func test_combat_builds_four_plates_with_enemy() -> void:
	_h.set_mode(HudHeader.Mode.COMBAT)
	_h.setup_enemy(8.0, false, "Caçador")
	assert_eq(_h._plates.size(), 4, "combate: placas de moeda, mudo, HP jogador e HP inimigo")

func test_bars_share_standard_size_even_for_boss() -> void:
	# Padrão de altura e largura: jogador e inimigo têm a MESMA barra, e boss
	# não ganha barra maior que a de um inimigo comum.
	_h.set_mode(HudHeader.Mode.COMBAT)
	_h.setup_enemy(8.0, false, "Caçador")
	var common_size: Vector2 = _h._enemy_bar.size
	assert_eq(_h._player_bar.size, common_size, "jogador e inimigo: mesmo tamanho de barra")
	_h.setup_enemy(36.0, true, "Mula sem Cabeça")
	assert_eq(_h._enemy_bar.size, common_size, "boss usa o mesmo tamanho padrão")
	assert_almost_eq(_h._enemy_bar.size.y, HealthBar.BAR_H, 0.01, "altura padrão única")

func test_player_bar_same_width_in_exploration_and_combat() -> void:
	_h.set_mode(HudHeader.Mode.EXPLORATION)
	var exploration_w: float = _h._player_bar.size.x
	_h.set_mode(HudHeader.Mode.COMBAT)
	_h.setup_enemy(8.0, false, "Caçador")
	assert_almost_eq(_h._player_bar.size.x, exploration_w, 0.01,
		"a barra do jogador não muda de largura entre exploração e combate")

func test_bars_have_no_text() -> void:
	# Decisão do dono: a barra de HP é só a barra — nenhum Label dentro dela.
	_h.set_mode(HudHeader.Mode.COMBAT)
	_h.setup_enemy(8.0, false, "Caçador")
	for bar: Control in [_h._player_bar, _h._enemy_bar]:
		for child in bar.get_children():
			assert_false(child is Label, "barra de HP sem texto")
	assert_eq(_h.enemy_name(), "Caçador", "o nome real segue guardado no header")

func test_top_row_plates_share_standard_height() -> void:
	# Padrão de altura da linha 1: as placas de moeda e mudo têm a mesma altura.
	_h.set_mode(HudHeader.Mode.CAMP)
	assert_eq(_h._plates.size(), 2)
	assert_almost_eq(_h._plates[0].size.y, _h._plates[1].size.y, 0.01,
		"placas de moeda e mudo com altura padrão igual")

