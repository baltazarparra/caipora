extends GutTest

# Exploração — fuga por medo: um inimigo comum que o jogador mata em um golpe base
# (ataque ≥ HP total) FOGE do jogador em vez de persegui-lo, e NUNCA inicia o
# combate (o jogador ainda pode encurralar e matar). O flag `fearful` vem do
# ExplorationManager; aqui exercitamos o contrato de MapEnemy.take_turn direto.
# Bosses e o comportamento normal (fearful=false) ficam intactos.

func _spawn(pos: Vector2i, boss: bool = false, enemy_type: String = "cacador") -> MapEnemy:
	var enemy: MapEnemy = MapEnemy.new()
	add_child_autofree(enemy)
	enemy.setup("e1", pos, boss, "mula" if boss else "", Vector2i(-1, -1), enemy_type)
	return enemy

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func test_fearful_common_flees_away_from_player() -> void:
	var player := Vector2i(0, 0)
	var enemy := _spawn(Vector2i(1, 0))  # adjacente ao jogador (dist 1)
	var walk := func(_p: Vector2i) -> bool: return true
	var occ := func(_p: Vector2i) -> bool: return false
	var hit := enemy.take_turn(player, walk, occ, true)
	assert_false(hit, "apavorado NUNCA inicia combate, mesmo adjacente")
	assert_eq(_manhattan(enemy.grid_pos, player), 2, "afastou-se do jogador (dist 1 → 2)")

func test_normal_adjacent_triggers_combat() -> void:
	# Regressão: sem medo, o comum adjacente ainda inicia o combate (dist<=1 → true).
	var enemy := _spawn(Vector2i(1, 0))
	var walk := func(_p: Vector2i) -> bool: return true
	var occ := func(_p: Vector2i) -> bool: return false
	assert_true(enemy.take_turn(Vector2i(0, 0), walk, occ),
		"comportamento normal intacto: adjacente inicia combate")

func test_cornered_fearful_stays_and_never_fights() -> void:
	# Sem tile de fuga (só a própria casa é caminhável): fica no lugar, sem crash,
	# e não inicia combate — o jogador precisa entrar nele para matá-lo.
	var enemy := _spawn(Vector2i(1, 0))
	var walk := func(p: Vector2i) -> bool: return p == Vector2i(1, 0)
	var occ := func(_p: Vector2i) -> bool: return false
	var hit := enemy.take_turn(Vector2i(0, 0), walk, occ, true)
	assert_false(hit, "encurralado não inicia combate")
	assert_eq(enemy.grid_pos, Vector2i(1, 0), "encurralado fica no lugar")

func test_stats_id_maps_enemy_to_catalog_key() -> void:
	assert_eq(_spawn(Vector2i.ZERO, false, "cacador").stats_id(), &"cacador",
		"comum usa o próprio tipo")
	assert_eq(_spawn(Vector2i.ZERO, false, "").stats_id(), &"cacador",
		"comum sem tipo cai no caçador")
	assert_eq(_spawn(Vector2i.ZERO, true).stats_id(), &"mula",
		"boss usa o tipo do chefe")
