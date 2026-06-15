class_name MapGenerator
extends RefCounted

# Gerador procedural PURO e determinístico. generate(config, seed) sempre devolve
# o MESMO GeneratedMap para o mesmo par (config, seed) — requisito do loop run→arena→
# exploração, onde o mapa não pode ser re-sorteado na volta do combate.
#
# Pipeline em camadas (best-practice de mercado: Spelunky/Brogue/Caves of Qud não
# usam UMA técnica, encadeiam várias):
#   1. TOPOLOGIA   — OPEN: região aberta;  CORRIDOR: drunkard's walk
#   2. SALA DO BOSS — (OPEN) alcova com a saída dentro e porta única
#   3. VALIDAÇÃO    — flood-fill: saída alcançável do spawn? senão regenera
#   4. HAZARDS      — R/S espalhados (são caminháveis → não afetam conectividade)
#   5. ENTIDADES    — inimigos por rejection sampling (espaçados, longe do spawn,
#                     boss guardando a saída/porta), baú e chave
#
# Sem dependência de SceneTree → roda nos testes GUT em headless.

const MAX_ATTEMPTS := 12
const PILLAR_MIN_SPACING := 2
const BOSS_ROOM_W := 7
const BOSS_ROOM_H := 4
const CORRIDOR_TURN_CHANCE := 0.28
const CORRIDOR_JUNCTION_CHANCE := 0.18
const CORRIDOR_MAX_STEPS := 4000
const CARDINALS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# Regras de placement (distâncias em manhattan/BFS sobre o grid 26×18).
const BOSS_GUARD_MIN := 1            # sempre 1 ou 2 monstros perto do boss
const BOSS_GUARD_MAX := 2
const BOSS_GUARD_RADIUS := 6         # raio que conta como "perto do boss"
const HERB_MIN_PLAYER_DIST := 10  # a Erva da Vida nasce sempre longe do spawn

# ─── Public API ────────────────────────────────────
func generate(config: MapConfig, p_seed: int) -> GeneratedMap:
	for attempt: int in MAX_ATTEMPTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = _mix(p_seed, attempt)
		# Última tentativa abre mão dos pilares — garante conectividade no OPEN.
		var drop_pillars := attempt == MAX_ATTEMPTS - 1
		var m := _attempt(config, rng, drop_pillars)
		if m != null:
			m.map_seed = p_seed
			return m
	# Inalcançável na prática (a última tentativa sem pilares sempre valida),
	# mas o contrato é nunca retornar null.
	return _attempt(config, RandomNumberGenerator.new(), true)

# ─── Geração (uma tentativa) ───────────────────────
func _attempt(config: MapConfig, rng: RandomNumberGenerator, drop_pillars: bool) -> GeneratedMap:
	var w := config.grid_width
	var h := config.grid_height
	var tiles := _blank(w, h, GeneratedMap.FLOOR)
	_frame_walls(tiles, w, h)

	var player_start := Vector2i(1, 1)
	var exit_pos := Vector2i(-1, -1)
	var boss_cell := Vector2i(-1, -1)
	var in_boss_room: Callable = func(_p: Vector2i) -> bool: return false

	if config.topology_mode == MapConfig.TopologyMode.OPEN:
		var room := _carve_boss_room(tiles, w, h)
		exit_pos = room["exit"]
		boss_cell = room["boss_cell"]
		var room_rect: Rect2i = room["rect"]
		in_boss_room = func(p: Vector2i) -> bool: return room_rect.has_point(p)
		if not drop_pillars:
			var door_cell: Vector2i = room["door"]
			var protect: Array[Vector2i] = [player_start, exit_pos, boss_cell, door_cell]
			_scatter_pillars(tiles, config, rng, protect, room_rect)
	else:
		_fill_interior(tiles, w, h, GeneratedMap.WALL)
		_drunkard_walk(tiles, config, rng, player_start, w, h)

	_set_tile(tiles, player_start, GeneratedMap.FLOOR)

	var m := GeneratedMap.new()
	m.width = w
	m.height = h
	m.tiles = tiles
	m.player_start = player_start

	var dist := m.reachable_from(player_start)

	# 'goal' é a célula profunda que precisa ser alcançável (saída no OPEN; ponta
	# mais distante no CORRIDOR). É também o alvo do boss quando não há saída.
	var goal := exit_pos
	if config.topology_mode == MapConfig.TopologyMode.CORRIDOR:
		# Com saída, a meta é o BECO mais fundo (um único vizinho de chão): o boss
		# posta na única aproximação e o combate é inevitável — paridade com a
		# porta única da sala do boss no OPEN.
		goal = _farthest_dead_end(tiles, dist) if config.has_exit else _farthest(dist)
		boss_cell = _near_exit_cell(dist, goal) if config.has_exit else goal

	# Validação: a célula-alvo precisa ser alcançável. Senão, esta tentativa falhou.
	if goal == Vector2i(-1, -1) or not dist.has(goal):
		return null

	# Fases sem saída (só a fase FINAL) progridem ao derrotar o boss — sem tile 'E'.
	if config.has_exit:
		_set_tile(tiles, goal, GeneratedMap.EXIT)
		m.exit_pos = goal

	# Pool de chão alcançável (exclui a saída, se houver).
	var pool: Array[Vector2i] = []
	for p: Vector2i in dist.keys():
		if not config.has_exit or p != goal:
			pool.append(p)

	var protected: Array[Vector2i] = [player_start, boss_cell, goal]
	var hset := _place_hazards(tiles, config, rng, pool, protected)

	# Garantia: sempre existe uma rota até o boss SEM pisar em fogo. Limpa os
	# hazards que caírem sobre uma rota (o resto do fogo segue hostil).
	_ensure_clean_path(tiles, hset, player_start, boss_cell)

	# Pool de posicionamento de entidades: chão alcançável sem spawn nem hazards.
	var place_pool: Array[Vector2i] = []
	for p: Vector2i in pool:
		if p == player_start or hset.has(p):
			continue
		place_pool.append(p)

	m.enemies = _place_enemies(config, rng, dist, place_pool, boss_cell, in_boss_room)

	# Santuário dos Encantados: guardião libertado não está no mapa — a cela dele vira
	# a marca de paz (a toca virou passagem).
	if config.boss_freed:
		m.peace_pos = _resolve_boss_cell(dist, boss_cell)

	var taken := {player_start: true, exit_pos: true}
	for e: Dictionary in m.enemies:
		taken[Vector2i(e["x"], e["y"])] = true
	# Santuário: a cela do guardião libertado segue reservada também para baú/chave/
	# decorações — sem isso o candidato extra desloca TODOS os sorteios seguintes e o
	# mapa deixa de ser idêntico ao gerado com boss (classe de bug do KI-007).
	if config.boss_freed:
		taken[m.peace_pos] = true
	# Erva da Vida: aleatória, mas sempre longe do jogador.
	var no_others: Array[Vector2i] = []
	if config.has_herb:
		m.herb_pos = _pick_free_distant(rng, place_pool, taken, dist,
			HERB_MIN_PLAYER_DIST, no_others, 0)

	m.decorations = _place_decorations(config, rng, place_pool, taken)

	return m

# ─── Topologia: OPEN ───────────────────────────────
func _carve_boss_room(tiles: Array, w: int, h: int) -> Dictionary:
	# Alcova retangular no canto inferior-direito, cercada por parede com porta
	# única no topo. Saída no canto interno; boss postado logo dentro da porta.
	var bw := mini(BOSS_ROOM_W, w - 4)
	var bh := mini(BOSS_ROOM_H, h - 4)
	var right := w - 2
	var bottom := h - 2
	var left := right - bw + 1
	var top := bottom - bh + 1
	# Parede em L que, com as bordas direita/inferior, fecha a sala.
	for x: int in range(left - 1, right + 1):
		tiles[top - 1][x] = GeneratedMap.WALL
	for y: int in range(top - 1, bottom + 1):
		tiles[y][left - 1] = GeneratedMap.WALL
	# Interior da sala em chão.
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			tiles[y][x] = GeneratedMap.FLOOR
	# Porta única na parede de cima.
	var door := Vector2i(left + int(bw / 2.0), top - 1)
	tiles[door.y][door.x] = GeneratedMap.FLOOR
	return {
		"exit": Vector2i(right, bottom),
		"boss_cell": Vector2i(door.x, top),  # dentro, guardando a porta
		"door": door,
		"rect": Rect2i(left, top, bw, bh),
	}

func _scatter_pillars(tiles: Array, config: MapConfig, rng: RandomNumberGenerator,
		protect: Array[Vector2i], room_rect: Rect2i) -> void:
	var w: int = tiles[0].size()
	var h: int = tiles.size()
	var cands: Array[Vector2i] = []
	for y: int in range(1, h - 1):
		for x: int in range(1, w - 1):
			var p := Vector2i(x, y)
			if tiles[y][x] != GeneratedMap.FLOOR:
				continue
			if room_rect.has_point(p):
				continue
			if _near_any(p, protect, 1):
				continue
			cands.append(p)
	_shuffle(cands, rng)
	var target := int(cands.size() * config.pillar_density)
	var placed: Array[Vector2i] = []
	for p: Vector2i in cands:
		if placed.size() >= target:
			break
		if _near_any(p, placed, PILLAR_MIN_SPACING - 1):
			continue
		tiles[p.y][p.x] = GeneratedMap.WALL
		placed.append(p)

# ─── Topologia: CORRIDOR ───────────────────────────
func _drunkard_walk(tiles: Array, config: MapConfig, rng: RandomNumberGenerator,
		start: Vector2i, w: int, h: int) -> void:
	# Caminhada aleatória que escava chão — conectividade garantida por construção.
	var width := maxi(1, config.corridor_width)
	var interior := (w - 2) * (h - 2)
	var target := int(interior * config.corridor_openness)
	var carved := {}
	var pos := start
	_carve_block(tiles, pos, width, w, h, carved)
	var dir: Vector2i = CARDINALS[rng.randi_range(0, 3)]
	var steps := 0
	while carved.size() < target and steps < CORRIDOR_MAX_STEPS:
		if rng.randf() < CORRIDOR_TURN_CHANCE:
			dir = CARDINALS[rng.randi_range(0, 3)]
			# Nas curvas, às vezes abre uma pequena junção (cruz) — cria salinhas e
			# rotas alternativas, o "feel" do Ventre da Mata e ajuda a evitar o fogo.
			if rng.randf() < CORRIDOR_JUNCTION_CHANCE:
				for d: Vector2i in CARDINALS:
					_carve_block(tiles, pos + d, width, w, h, carved)
		var np := pos + dir
		if np.x < 1 or np.x > w - 1 - width or np.y < 1 or np.y > h - 1 - width:
			dir = CARDINALS[rng.randi_range(0, 3)]
			steps += 1
			continue
		pos = np
		_carve_block(tiles, pos, width, w, h, carved)
		steps += 1

func _carve_block(tiles: Array, origin: Vector2i, width: int, w: int, h: int,
		carved: Dictionary) -> void:
	for dy: int in width:
		for dx: int in width:
			var c := origin + Vector2i(dx, dy)
			if c.x >= 1 and c.x <= w - 2 and c.y >= 1 and c.y <= h - 2:
				tiles[c.y][c.x] = GeneratedMap.FLOOR
				carved[c] = true

# ─── Hazards ───────────────────────────────────────
func _place_hazards(tiles: Array, config: MapConfig, rng: RandomNumberGenerator,
		pool: Array[Vector2i], protect: Array[Vector2i]) -> Dictionary:
	var hset := {}
	if config.hazard_chars.is_empty() or config.hazard_density <= 0.0:
		return hset
	var cands: Array[Vector2i] = []
	for p: Vector2i in pool:
		if p in protect:
			continue
		cands.append(p)
	_shuffle(cands, rng)
	var target := int(cands.size() * config.hazard_density)
	var i := 0
	for p: Vector2i in cands:
		if i >= target:
			break
		var ch: String = config.hazard_chars[rng.randi_range(0, config.hazard_chars.size() - 1)]
		tiles[p.y][p.x] = ch
		hset[p] = true
		i += 1
	return hset

# ─── Entidades ─────────────────────────────────────
func _place_enemies(config: MapConfig, rng: RandomNumberGenerator, dist: Dictionary,
		pool: Array[Vector2i], boss_cell: Vector2i, in_boss_room: Callable) -> Array:
	var count := config.enemy_count
	var result: Array = []
	var taken := {}

	# Boss: posição reservada — sempre distante do jogador (alcova no canto oposto
	# no OPEN, célula mais distante no CORRIDOR). Com o guardião libertado
	# (boss_freed) a cela CONTINUA reservada: guardas, baú, chave e decorações saem
	# idênticos com ou sem boss — a volta do combate regenera o mapa e nada pode
	# mudar de lugar (mesma classe de bug do KI-007).
	var bcell := _resolve_boss_cell(dist, boss_cell)
	taken[bcell] = true

	# Guardas: 1 ou 2 monstros sempre perto do boss. Sorteia entre as células mais
	# próximas do boss (flanqueando-o), com leve variação.
	var guard_target := mini(rng.randi_range(BOSS_GUARD_MIN, BOSS_GUARD_MAX), count - 1)
	var avail: Array[Vector2i] = []
	for p: Vector2i in pool:
		if not taken.has(p):
			avail.append(p)
	avail.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _dist_key(a, bcell) < _dist_key(b, bcell))
	var near_pool: Array[Vector2i] = avail.slice(0, mini(avail.size(), guard_target + 4))
	_shuffle(near_pool, rng)
	var guards: Array[Vector2i] = []
	for p: Vector2i in near_pool:
		if guards.size() >= guard_target:
			break
		guards.append(p)
		taken[p] = true

	# Espalhados: longe do spawn, fora da sala do boss, espaçados entre si.
	var want_scatter := (count - 1) - guards.size()
	var candidates: Array[Vector2i] = []
	for p: Vector2i in pool:
		if taken.has(p) or in_boss_room.call(p):
			continue
		if int(dist.get(p, 0)) < config.min_spawn_distance:
			continue
		candidates.append(p)
	_shuffle(candidates, rng)

	var scattered: Array[Vector2i] = []
	var spacing := config.min_enemy_spacing
	while scattered.size() < want_scatter and spacing >= 0:
		for p: Vector2i in candidates:
			if scattered.size() >= want_scatter:
				break
			if taken.has(p):
				continue
			if _near_any(p, scattered, spacing - 1):
				continue
			scattered.append(p)
			taken[p] = true
		spacing -= 1

	# Rede de segurança: completa a contagem com qualquer chão livre (mapas mínimos).
	var need := (count - 1) - guards.size() - scattered.size()
	if need > 0:
		for p: Vector2i in pool:
			if need <= 0:
				break
			if taken.has(p):
				continue
			scattered.append(p)
			taken[p] = true
			need -= 1

	# Tipos dos comuns (caçador/bruxo) embaralhados — determinístico por seed.
	var types: Array = []
	for t: String in config.common_types:
		types.append(t)
	_shuffle(types, rng)

	var idx := 0
	for p: Vector2i in (guards + scattered):
		var etype: String = types[idx] if idx < types.size() else "cacador"
		result.append({"id": "p%d_e%d" % [config.phase, idx], "x": p.x, "y": p.y,
			"boss": false, "enemy_type": etype})
		idx += 1
	# O boss carrega o boss_type → sprite/aura corretos no mapa (curupira/boitata/saci).
	# Guardião libertado (Santuário) não spawna — os guardas seguem postados na
	# aproximação, agora guardando a passagem.
	if not config.boss_freed:
		result.append({"id": "p%d_e%d" % [config.phase, idx], "x": bcell.x, "y": bcell.y,
			"boss": true, "boss_type": config.boss_type})
	return result

# Cela do boss com fallback determinístico (célula mais distante) quando a candidata
# original não é alcançável. Fonte única para o placement e para a marca de paz.
func _resolve_boss_cell(dist: Dictionary, boss_cell: Vector2i) -> Vector2i:
	if boss_cell == Vector2i(-1, -1) or not dist.has(boss_cell):
		return _farthest(dist)
	return boss_cell

func _place_decorations(config: MapConfig, rng: RandomNumberGenerator,
		pool: Array[Vector2i], taken: Dictionary) -> Array[Vector2i]:
	# Ambientação puramente visual: chão alcançável livre de entidades/hazards.
	var decs: Array[Vector2i] = []
	if config.decoration_count <= 0:
		return decs
	var cands: Array[Vector2i] = []
	for p: Vector2i in pool:
		if not taken.has(p):
			cands.append(p)
	_shuffle(cands, rng)
	for p: Vector2i in cands:
		if decs.size() >= config.decoration_count:
			break
		decs.append(p)
	return decs

func _pick_free(rng: RandomNumberGenerator, pool: Array[Vector2i], taken: Dictionary) -> Vector2i:
	var cands: Array[Vector2i] = []
	for p: Vector2i in pool:
		if not taken.has(p):
			cands.append(p)
	if cands.is_empty():
		return Vector2i(-1, -1)
	var c: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
	taken[c] = true
	return c

func _pick_free_distant(rng: RandomNumberGenerator, pool: Array[Vector2i], taken: Dictionary,
		dist: Dictionary, min_player_dist: int, others: Array[Vector2i], min_sep: int) -> Vector2i:
	# Sorteia uma célula livre longe do spawn e dos 'others'. Afrouxa as restrições
	# em etapas se não houver candidatos — nunca falha se houver chão livre.
	for relax: int in 3:
		var pd := min_player_dist if relax < 2 else 0
		var sep := min_sep if relax < 1 else 0
		var cands: Array[Vector2i] = []
		for p: Vector2i in pool:
			if taken.has(p):
				continue
			if int(dist.get(p, 0)) < pd:
				continue
			if sep > 0 and _near_any(p, others, sep - 1):
				continue
			cands.append(p)
		if not cands.is_empty():
			var c: Vector2i = cands[rng.randi_range(0, cands.size() - 1)]
			taken[c] = true
			return c
	return _pick_free(rng, pool, taken)

# ─── Helpers de grid ───────────────────────────────
func _blank(w: int, h: int, ch: String) -> Array:
	var g: Array = []
	for y: int in h:
		var row: Array = []
		for x: int in w:
			row.append(ch)
		g.append(row)
	return g

func _frame_walls(tiles: Array, w: int, h: int) -> void:
	for x: int in w:
		tiles[0][x] = GeneratedMap.WALL
		tiles[h - 1][x] = GeneratedMap.WALL
	for y: int in h:
		tiles[y][0] = GeneratedMap.WALL
		tiles[y][w - 1] = GeneratedMap.WALL

func _fill_interior(tiles: Array, w: int, h: int, ch: String) -> void:
	for y: int in range(1, h - 1):
		for x: int in range(1, w - 1):
			tiles[y][x] = ch

func _set_tile(tiles: Array, p: Vector2i, ch: String) -> void:
	tiles[p.y][p.x] = ch

# ─── Helpers de busca ──────────────────────────────
func _farthest(dist: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := -1
	for p: Vector2i in dist.keys():
		if int(dist[p]) > bd:
			bd = int(dist[p])
			best = p
	return best

func _farthest_dead_end(tiles: Array, dist: Dictionary) -> Vector2i:
	# Beco-sem-saída mais distante do spawn: célula alcançável com exatamente UM
	# vizinho de chão. Fallback: a célula mais distante (mapa sem becos).
	var best := Vector2i(-1, -1)
	var bd := -1
	for p: Vector2i in dist.keys():
		if _floor_neighbors(tiles, p) != 1:
			continue
		if int(dist[p]) > bd:
			bd = int(dist[p])
			best = p
	return best if best != Vector2i(-1, -1) else _farthest(dist)

func _floor_neighbors(tiles: Array, p: Vector2i) -> int:
	var n := 0
	for d: Vector2i in CARDINALS:
		if not _is_wall(tiles, p + d):
			n += 1
	return n

func _near_exit_cell(dist: Dictionary, exit_pos: Vector2i) -> Vector2i:
	for d: Vector2i in CARDINALS:
		var nb: Vector2i = exit_pos + d
		if dist.has(nb):
			return nb
	return exit_pos

# ─── Rota limpa de hazard ──────────────────────────
func _ensure_clean_path(tiles: Array, hset: Dictionary, start: Vector2i, goal: Vector2i) -> void:
	# Garante uma rota start→goal que não passa por hazard. Se a única rota cruza
	# fogo, limpa os hazards ao longo de UM caminho (o resto do fogo segue lá).
	if hset.is_empty() or _reachable_clean(tiles, hset, start, goal):
		return
	for p: Vector2i in _bfs_path(tiles, start, goal):
		if hset.has(p):
			tiles[p.y][p.x] = GeneratedMap.FLOOR
			hset.erase(p)

func _reachable_clean(tiles: Array, hset: Dictionary, start: Vector2i, goal: Vector2i) -> bool:
	# BFS sobre células caminháveis E sem hazard.
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == goal:
			return true
		for d: Vector2i in CARDINALS:
			var nb: Vector2i = cur + d
			if seen.has(nb) or hset.has(nb) or _is_wall(tiles, nb):
				continue
			seen[nb] = true
			frontier.append(nb)
	return false

func _bfs_path(tiles: Array, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# Caminho start→goal sobre células caminháveis (ignora hazard). Reconstrói via parents.
	var parent := {start: start}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == goal:
			break
		for d: Vector2i in CARDINALS:
			var nb: Vector2i = cur + d
			if parent.has(nb) or _is_wall(tiles, nb):
				continue
			parent[nb] = cur
			frontier.append(nb)
	var path: Array[Vector2i] = []
	if not parent.has(goal):
		return path
	var node := goal
	while node != start:
		path.append(node)
		node = parent[node]
	path.append(start)
	return path

func _is_wall(tiles: Array, p: Vector2i) -> bool:
	if p.y < 0 or p.y >= tiles.size():
		return true
	var row: Array = tiles[p.y]
	if p.x < 0 or p.x >= row.size():
		return true
	return row[p.x] == GeneratedMap.WALL

func _near_any(p: Vector2i, others: Array, radius: int) -> bool:
	# True se p está a <= radius (manhattan) de alguém em others.
	for q: Vector2i in others:
		if _manhattan(p, q) <= radius:
			return true
	return false

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _dist_key(p: Vector2i, anchor: Vector2i) -> int:
	# Chave de ordenação total e determinística: distância, depois y, depois x.
	return _manhattan(p, anchor) * 10000 + p.y * 100 + p.x

# ─── Determinismo ──────────────────────────────────
func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	# Fisher-Yates com o RNG semeado (Array.shuffle() usa o RNG global — não-determinístico).
	for i: int in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _mix(s: int, salt: int) -> int:
	# Deriva um sub-seed estável por tentativa, mantendo generate(config, S) determinístico.
	return (s * 1000003) ^ (salt * 2654435761 + 12345)
