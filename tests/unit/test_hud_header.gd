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

func test_exploration_builds_two_plates() -> void:
	# Redesign "placas flutuantes": HP numa placa, Terra Rara+mudo noutra.
	_h.set_mode(HudHeader.Mode.EXPLORATION)
	assert_eq(_h._plates.size(), 2, "exploração: placa do HP + placa de moeda/mudo")

func test_camp_builds_one_plate() -> void:
	_h.set_mode(HudHeader.Mode.CAMP)
	assert_eq(_h._plates.size(), 1, "acampamento: só a placa de moeda/mudo")
