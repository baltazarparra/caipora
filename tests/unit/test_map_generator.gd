extends GutTest

# Invariantes da geração procedural de mapas (Etapa 0 — fundação testável).
# Cada invariante roda sobre as 4 fases × vários seeds. É o que separa
# "procedural elegante" de "procedural quebrado".

const PHASES := [1, 2, 3, 4]
const SEEDS := [1, 2, 3, 7, 42, 99, 128, 256, 1001, 31337]

func _gen(phase: int, seed_val: int) -> GeneratedMap:
	var cfg := MapConfig.for_phase(phase)
	var gen := MapGenerator.new()
	return gen.generate(cfg, seed_val)

func _enemy_sig(m: GeneratedMap) -> String:
	var parts: Array = []
	for e: Dictionary in m.enemies:
		parts.append("%s:%d,%d,%s" % [e["id"], e["x"], e["y"], str(e["boss"])])
	return ",".join(parts)

# ── Determinismo: mesmo seed → mapa idêntico (contrato do loop run→arena→volta) ──
func test_determinism_identical_for_same_seed() -> void:
	for phase: int in PHASES:
		var a := _gen(phase, 42)
		var b := _gen(phase, 42)
		assert_eq(a.rows(), b.rows(), "grid idêntico p/ mesmo seed (fase %d)" % phase)
		assert_eq(a.exit_pos, b.exit_pos, "saída idêntica (fase %d)" % phase)
		assert_eq(a.player_start, b.player_start, "spawn idêntico (fase %d)" % phase)
		assert_eq(_enemy_sig(a), _enemy_sig(b), "inimigos idênticos (fase %d)" % phase)
		assert_eq(a.chest_pos, b.chest_pos, "baú idêntico (fase %d)" % phase)
		assert_eq(a.key_pos, b.key_pos, "chave idêntica (fase %d)" % phase)

# ── Dimensões corretas e bordas sempre parede (sem vazamento off-grid) ──
func test_dimensions_and_border_walls() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			assert_eq(m.tiles.size(), Constants.GRID_HEIGHT, "altura do grid")
			assert_eq(m.tiles[0].size(), Constants.GRID_WIDTH, "largura do grid")
			for x: int in Constants.GRID_WIDTH:
				assert_eq(m.char_at(Vector2i(x, 0)), "W", "borda topo parede")
				assert_eq(m.char_at(Vector2i(x, Constants.GRID_HEIGHT - 1)), "W", "borda base parede")
			for y: int in Constants.GRID_HEIGHT:
				assert_eq(m.char_at(Vector2i(0, y)), "W", "borda esquerda parede")
				assert_eq(m.char_at(Vector2i(Constants.GRID_WIDTH - 1, y)), "W", "borda direita parede")

# ── Conectividade: saída (quando existe) e boss SEMPRE alcançáveis do spawn ──
func test_exit_and_boss_reachable_from_start() -> void:
	for phase: int in PHASES:
		var cfg := MapConfig.for_phase(phase)
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var dist := m.reachable_from(m.player_start)
			var b := m.boss()
			assert_true(dist.has(Vector2i(b["x"], b["y"])),
				"boss alcançável (fase %d seed %d)" % [phase, s])
			if cfg.has_exit:
				assert_true(dist.has(m.exit_pos),
					"saída alcançável (fase %d seed %d)" % [phase, s])
			else:
				assert_eq(m.exit_pos, Vector2i(-1, -1),
					"fase sem saída não expõe exit_pos (fase %d)" % phase)

func test_player_start_walkable_and_not_exit() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			assert_true(m.is_walkable(m.player_start), "spawn caminhável")
			assert_ne(m.player_start, m.exit_pos, "spawn != saída")

# ── Paridade de conteúdo: contagem de inimigos casa com a referência ──
func test_enemy_count_matches_config() -> void:
	for phase: int in PHASES:
		var expected := MapConfig.for_phase(phase).enemy_count
		for s: int in SEEDS:
			var m := _gen(phase, s)
			assert_eq(m.enemies.size(), expected,
				"contagem de inimigos (fase %d seed %d)" % [phase, s])

func test_exactly_one_boss() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var bosses := 0
			for e: Dictionary in m.enemies:
				if e["boss"]:
					bosses += 1
			assert_eq(bosses, 1, "exatamente 1 boss (fase %d seed %d)" % [phase, s])

# ── Sanidade de placement: inimigos em chão alcançável, únicos, fora do spawn ──
func test_enemies_walkable_reachable_unique_offspawn() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var dist := m.reachable_from(m.player_start)
			var seen := {}
			for e: Dictionary in m.enemies:
				var p := Vector2i(e["x"], e["y"])
				assert_true(m.is_walkable(p), "inimigo em tile caminhável")
				assert_true(dist.has(p), "inimigo alcançável do spawn")
				assert_ne(p, m.player_start, "inimigo não nasce no spawn")
				assert_false(seen.has(p), "sem inimigos sobrepostos")
				seen[p] = true

# ── Hazards: zero quando a fase não tem; densidade limitada quando tem ──
func test_hazard_density_within_bounds() -> void:
	for phase: int in PHASES:
		var cfg := MapConfig.for_phase(phase)
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var hazards := 0
			var floors := 0
			for y: int in m.tiles.size():
				var row: Array = m.tiles[y]
				for x: int in row.size():
					var ch: String = row[x]
					if ch == "R" or ch == "S":
						hazards += 1
					if ch != "W":
						floors += 1
			if cfg.hazard_chars.is_empty():
				assert_eq(hazards, 0, "fase sem hazard não gera hazard (fase %d)" % phase)
			else:
				var frac := float(hazards) / float(maxi(1, floors))
				assert_lt(frac, cfg.hazard_density + 0.08,
					"densidade de hazard sob controle (fase %d seed %d)" % [phase, s])

# ── Variação: seeds diferentes produzem mapas diferentes ──
func test_seed_variation() -> void:
	for phase: int in PHASES:
		var a := _gen(phase, 1)
		var b := _gen(phase, 2)
		assert_ne(a.rows(), b.rows(),
			"seeds diferentes → mapas diferentes (fase %d)" % phase)

# ── Baú/chave só existem quando a config pede ──
func test_chest_key_only_when_configured() -> void:
	var m1 := _gen(1, 5)  # Fase 1 tem baú + chave
	assert_ne(m1.chest_pos, Vector2i(-1, -1), "fase 1 tem baú")
	assert_ne(m1.key_pos, Vector2i(-1, -1), "fase 1 tem chave")
	for phase: int in [2, 3, 4]:
		var m := _gen(phase, 5)
		assert_eq(m.chest_pos, Vector2i(-1, -1), "fase %d sem baú" % phase)
		assert_eq(m.key_pos, Vector2i(-1, -1), "fase %d sem chave" % phase)

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

# ── Contagem padrão por fase: 7 monstros em todas (6 comuns + boss) ──
func test_phase_enemy_counts_are_all_seven() -> void:
	for phase: int in PHASES:
		assert_eq(MapConfig.for_phase(phase).enemy_count, 7,
			"fase %d = 7 monstros (6 comuns + boss)" % phase)

# ── Composição dos comuns: fase 1 só caçador; demais 4/2 por paridade ──
func test_common_enemy_mix_by_parity() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var counts := {"cacador": 0, "bruxo": 0}
			for e: Dictionary in m.enemies:
				if e["boss"]:
					continue
				var t: String = e.get("enemy_type", "")
				assert_true(counts.has(t),
					"comum tem tipo válido (fase %d seed %d): %s" % [phase, s, t])
				counts[t] += 1
			if phase == 1:
				assert_eq(counts["cacador"], 6, "fase 1: 6 caçadores, sem bruxo")
				assert_eq(counts["bruxo"], 0, "fase 1: nenhum bruxo")
				continue
			var major := "bruxo" if phase % 2 == 1 else "cacador"
			var minor := "cacador" if phase % 2 == 1 else "bruxo"
			assert_eq(counts[major], 4, "fase %d: 4 do tipo majoritário (%s)" % [phase, major])
			assert_eq(counts[minor], 2, "fase %d: 2 do tipo minoritário (%s)" % [phase, minor])

# ── Boss sempre distante do jogador (na metade mais longe do mapa) ──
func test_boss_far_from_player() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var dist := m.reachable_from(m.player_start)
			var max_d := 0
			for d: int in dist.values():
				max_d = maxi(max_d, d)
			var b := m.boss()
			var bd: int = int(dist.get(Vector2i(b["x"], b["y"]), 0))
			assert_gte(bd, int(max_d * 0.5),
				"boss na metade mais distante (fase %d seed %d)" % [phase, s])

# ── Sempre 1+ monstro perto do boss (guardas) ──
func test_at_least_one_enemy_near_boss() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var b := m.boss()
			var bpos := Vector2i(b["x"], b["y"])
			var near := 0
			for e: Dictionary in m.enemies:
				if e["boss"]:
					continue
				if _manhattan(Vector2i(e["x"], e["y"]), bpos) <= MapGenerator.BOSS_GUARD_RADIUS:
					near += 1
			assert_gte(near, 1, "ao menos 1 guarda perto do boss (fase %d seed %d)" % [phase, s])

# ── Baú e chave: longe do jogador e longe um do outro ──
func test_chest_key_distant() -> void:
	for s: int in SEEDS:
		var m := _gen(1, s)  # só a fase 1 tem baú/chave
		var dist := m.reachable_from(m.player_start)
		assert_gte(int(dist.get(m.chest_pos, 0)), MapGenerator.CHEST_KEY_MIN_PLAYER_DIST,
			"baú longe do spawn (seed %d)" % s)
		assert_gte(int(dist.get(m.key_pos, 0)), MapGenerator.CHEST_KEY_MIN_PLAYER_DIST,
			"chave longe do spawn (seed %d)" % s)
		assert_gte(_manhattan(m.chest_pos, m.key_pos), MapGenerator.CHEST_KEY_MIN_SEPARATION,
			"baú e chave separados (seed %d)" % s)

# ── Decorações: quantidade certa, em chão livre, sem sobrepor entidades ──
func test_decorations_valid() -> void:
	for phase: int in PHASES:
		var expected := MapConfig.for_phase(phase).decoration_count
		for s: int in SEEDS:
			var m := _gen(phase, s)
			assert_eq(m.decorations.size(), expected,
				"contagem de decorações (fase %d seed %d)" % [phase, s])
			var occupied := {m.player_start: true, m.exit_pos: true,
				m.chest_pos: true, m.key_pos: true}
			for e: Dictionary in m.enemies:
				occupied[Vector2i(e["x"], e["y"])] = true
			var seen := {}
			for d: Vector2i in m.decorations:
				assert_true(m.is_walkable(d), "decoração em chão caminhável")
				assert_ne(m.char_at(d), "E", "decoração não na saída")
				assert_false(occupied.has(d), "decoração não sobrepõe entidade")
				assert_false(seen.has(d), "decorações sem sobreposição entre si")
				seen[d] = true

# ── Boss carrega o boss_type da config (sprite/aura corretos no mapa) ──
func test_boss_carries_boss_type() -> void:
	for phase: int in PHASES:
		var expected := MapConfig.for_phase(phase).boss_type
		for s: int in SEEDS:
			var m := _gen(phase, s)
			assert_eq(m.boss().get("boss_type", ""), expected,
				"boss_type da fase %d" % phase)

# ── has_exit: fases 1–4 têm exatamente um tile 'E' (só a fase 5 não tem) ──
func test_exit_tile_matches_has_exit() -> void:
	for phase: int in PHASES:
		var cfg := MapConfig.for_phase(phase)
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var exits := 0
			for y: int in m.tiles.size():
				var row: Array = m.tiles[y]
				for x: int in row.size():
					if row[x] == "E":
						exits += 1
			if cfg.has_exit:
				assert_eq(exits, 1, "uma saída (fase %d seed %d)" % [phase, s])
			else:
				assert_eq(exits, 0, "sem tile de saída (fase %d seed %d)" % [phase, s])

# ── A saída fica numa clareira 5×5 caminhável e SEM dano (a área útil da saída) ──
func test_exit_clearing_walkable_and_safe() -> void:
	var r: int = MapGenerator.EXIT_CLEARING_RADIUS
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			for dy: int in range(-r, r + 1):
				for dx: int in range(-r, r + 1):
					var p: Vector2i = m.exit_pos + Vector2i(dx, dy)
					var ch := m.char_at(p)
					assert_ne(ch, "W",
						"clareira da saída caminhável em %s (fase %d seed %d)" % [str(p), phase, s])
					assert_false(ch == "R" or ch == "S",
						"clareira da saída sem fogo/espinho em %s (fase %d seed %d)" % [str(p), phase, s])

# ── O boss guarda a ÚNICA aproximação à clareira (sem como contornar o boss) ──
func test_boss_guards_single_approach() -> void:
	var r: int = MapGenerator.EXIT_CLEARING_RADIUS
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var rect := Rect2i(m.exit_pos.x - r, m.exit_pos.y - r, 2 * r + 1, 2 * r + 1)
			var openings := {}
			for y: int in range(rect.position.y, rect.end.y):
				for x: int in range(rect.position.x, rect.end.x):
					for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var o: Vector2i = Vector2i(x, y) + d
						if rect.has_point(o):
							continue
						if m.char_at(o) != "W":
							openings[o] = true
			assert_eq(openings.size(), 1,
				"clareira da saída com uma única abertura (fase %d seed %d)" % [phase, s])
			var b := m.boss()
			assert_true(openings.has(Vector2i(b["x"], b["y"])),
				"o boss posta na abertura da clareira (fase %d seed %d)" % [phase, s])

# ── Garantia: sempre existe rota até o boss SEM pisar em fogo ──
func test_clean_path_to_boss_exists() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen(phase, s)
			var b := m.boss()
			var goal := Vector2i(b["x"], b["y"])
			assert_true(_reachable_avoiding_hazards(m, m.player_start, goal),
				"rota até o boss sem fogo (fase %d seed %d)" % [phase, s])

# ══ Fase 5 (A Igreja na Mata) — fora do loop PHASES por ter conteúdo próprio ══
# 5 inimigos (4 chefes-monstro + Jesuíta), sem caçador/bruxo, sem saída.

func test_phase5_enemy_count_is_five() -> void:
	assert_eq(MapConfig.for_phase(5).enemy_count, 5,
		"fase 5 = 5 inimigos (4 chefes-monstro + Jesuíta)")

func test_phase5_commons_are_the_four_bosses() -> void:
	# Cada um dos 4 chefes anteriores aparece exatamente uma vez como "comum".
	for s: int in SEEDS:
		var m := _gen(5, s)
		var counts := {"mula": 0, "boitata": 0, "curupira": 0, "saci": 0}
		var bosses := 0
		for e: Dictionary in m.enemies:
			if e["boss"]:
				bosses += 1
				assert_eq(e.get("boss_type", ""), "jesuita",
					"boss da fase 5 é o Jesuíta (seed %d)" % s)
				continue
			var t: String = e.get("enemy_type", "")
			assert_true(counts.has(t),
				"comum da fase 5 é um chefe válido (seed %d): %s" % [s, t])
			counts[t] += 1
		assert_eq(bosses, 1, "exatamente 1 boss na fase 5 (seed %d)" % s)
		for boss_name: String in counts:
			assert_eq(counts[boss_name], 1,
				"fase 5: exatamente um %s (seed %d)" % [boss_name, s])

func test_phase5_invariants() -> void:
	# Universais que devem valer também na fase final: sem saída, boss alcançável,
	# rota até o boss sem fogo, determinismo.
	var cfg := MapConfig.for_phase(5)
	assert_false(cfg.has_exit, "fase 5 não tem saída (progride ao matar o Jesuíta)")
	for s: int in SEEDS:
		var m := _gen(5, s)
		assert_eq(m.exit_pos, Vector2i(-1, -1), "fase 5 não expõe exit_pos (seed %d)" % s)
		var dist := m.reachable_from(m.player_start)
		var b := m.boss()
		var goal := Vector2i(b["x"], b["y"])
		assert_true(dist.has(goal), "Jesuíta alcançável do spawn (seed %d)" % s)
		assert_true(_reachable_avoiding_hazards(m, m.player_start, goal),
			"rota até o Jesuíta sem fogo (seed %d)" % s)
	assert_eq(_enemy_sig(_gen(5, 42)), _enemy_sig(_gen(5, 42)),
		"fase 5 determinística p/ mesmo seed")

# ══ Santuário dos Encantados — fase sem guardião (boss_freed) ══
# Guardião libertado sai do mapa, a cela dele vira marca de paz e o RESTO da geração
# permanece BYTE-IDÊNTICO ao mapa com boss: a volta do combate regenera o mapa e nada
# pode mudar de lugar (mesma classe de bug do KI-007).

func _gen_freed(phase: int, seed_val: int) -> GeneratedMap:
	var cfg := MapConfig.for_phase(phase)
	cfg.boss_freed = true
	return MapGenerator.new().generate(cfg, seed_val)

func test_freed_phase_has_no_boss() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen_freed(phase, s)
			assert_eq(m.boss(), {}, "sem boss no mapa (fase %d seed %d)" % [phase, s])
			assert_eq(m.enemies.size(), MapConfig.for_phase(phase).enemy_count - 1,
				"só os comuns (fase %d seed %d)" % [phase, s])

func test_freed_map_identical_except_boss() -> void:
	for phase: int in PHASES:
		for s: int in [1, 42, 31337]:
			var a := _gen(phase, s)
			var b := _gen_freed(phase, s)
			assert_eq(a.rows(), b.rows(), "grid idêntico (fase %d seed %d)" % [phase, s])
			assert_eq(a.exit_pos, b.exit_pos, "saída idêntica (fase %d seed %d)" % [phase, s])
			assert_eq(a.player_start, b.player_start, "spawn idêntico (fase %d)" % phase)
			assert_eq(a.chest_pos, b.chest_pos, "baú idêntico (fase %d)" % phase)
			assert_eq(a.key_pos, b.key_pos, "chave idêntica (fase %d)" % phase)
			assert_eq(a.decorations, b.decorations, "decorações idênticas (fase %d)" % phase)
			assert_eq(_common_sig(a), _common_sig(b),
				"comuns idênticos com/sem guardião (fase %d seed %d)" % [phase, s])
		assert_eq(_enemy_sig(_gen_freed(phase, 42)), _enemy_sig(_gen_freed(phase, 42)),
			"fase libertada determinística (fase %d)" % phase)

func test_freed_peace_mark_at_boss_cell() -> void:
	for phase: int in PHASES:
		for s: int in SEEDS:
			var a := _gen(phase, s)
			var m := _gen_freed(phase, s)
			var b := a.boss()
			assert_eq(m.peace_pos, Vector2i(b["x"], b["y"]),
				"marca de paz na cela do guardião (fase %d seed %d)" % [phase, s])
			assert_true(m.is_walkable(m.peace_pos), "marca de paz em chão caminhável")
			assert_eq(a.peace_pos, Vector2i(-1, -1),
				"mapa com boss não tem marca de paz (fase %d)" % phase)

func test_freed_exit_reachable_and_passage_guarded() -> void:
	# Sem o guardião a saída segue alcançável (sem softlock), com rota limpa de fogo
	# até a cela dele (a mesma garantia que protegia a rota ao boss) e com ao menos
	# 1 guarda postado na passagem.
	for phase: int in PHASES:
		for s: int in SEEDS:
			var m := _gen_freed(phase, s)
			var dist := m.reachable_from(m.player_start)
			assert_true(dist.has(m.exit_pos),
				"saída alcançável sem o guardião (fase %d seed %d)" % [phase, s])
			assert_true(_reachable_avoiding_hazards(m, m.player_start, m.peace_pos),
				"rota limpa até a passagem (fase %d seed %d)" % [phase, s])
			var near := 0
			for e: Dictionary in m.enemies:
				if _manhattan(Vector2i(e["x"], e["y"]), m.peace_pos) <= MapGenerator.BOSS_GUARD_RADIUS:
					near += 1
			assert_gte(near, 1,
				"ao menos 1 guarda na passagem (fase %d seed %d)" % [phase, s])

func _common_sig(m: GeneratedMap) -> String:
	var parts: Array = []
	for e: Dictionary in m.enemies:
		if e["boss"]:
			continue
		parts.append("%s:%d,%d,%s" % [e["id"], e["x"], e["y"], e.get("enemy_type", "")])
	return ",".join(parts)

func _reachable_avoiding_hazards(m: GeneratedMap, start: Vector2i, goal: Vector2i) -> bool:
	# BFS sobre células caminháveis que NÃO são hazard (R/S).
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	var nb_dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == goal:
			return true
		for d: Vector2i in nb_dirs:
			var nb: Vector2i = cur + d
			if seen.has(nb):
				continue
			var ch := m.char_at(nb)
			if ch == "W" or ch == "R" or ch == "S":
				continue
			seen[nb] = true
			frontier.append(nb)
	return false
