class_name GeneratedMap
extends RefCounted

# Resultado puro de uma geração procedural. Espelha exatamente a IR dos mapas
# estáticos (char-grid W/F/E/R/S) para plugar nos managers sem fricção, mas
# carrega como metadados separados o que os estáticos guardavam em constantes
# (spawn, saída, inimigos, erva). Sem dependência de SceneTree — testável
# headless. Ver scripts/exploration/map_generator.gd.

# ─── Tile Chars (mesma IR do MAP_LAYOUT estático) ──
const WALL := "W"
const FLOOR := "F"
const EXIT := "E"

# ─── State ─────────────────────────────────────────
var map_seed: int = 0
var width: int = 0
var height: int = 0
var tiles: Array = []                       # tiles[y][x] = String (1 char)
var player_start: Vector2i = Vector2i.ZERO
var exit_pos: Vector2i = Vector2i(-1, -1)
var enemies: Array = []                      # [{id, x, y, boss}]
var herb_pos: Vector2i = Vector2i(-1, -1)    # Erva da Vida: pickup que dá HP máx. (+fase)
var decorations: Array[Vector2i] = []        # ambientação visual (não afeta walkability)
# Santuário dos Encantados: cela onde o guardião libertado postaria (vira marca de paz).
# (-1,-1) = boss presente no mapa (boss_freed=false).
var peace_pos: Vector2i = Vector2i(-1, -1)

# ─── Public API ────────────────────────────────────
func char_at(pos: Vector2i) -> String:
	if pos.y < 0 or pos.y >= tiles.size():
		return WALL
	var row: Array = tiles[pos.y]
	if pos.x < 0 or pos.x >= row.size():
		return WALL
	return row[pos.x]

func is_walkable(pos: Vector2i) -> bool:
	# Qualquer coisa que não seja parede é caminhável (hazards R/S incluídos).
	return char_at(pos) != WALL

func rows() -> PackedStringArray:
	# Forma MAP_LAYOUT-compatível (array de strings), p/ pintura e comparação.
	var out := PackedStringArray()
	for y: int in tiles.size():
		out.append("".join(tiles[y]))
	return out

func reachable_from(start: Vector2i) -> Dictionary:
	# Flood-fill 4-direções sobre tiles caminháveis. Retorna {Vector2i: dist}.
	# Ordem de vizinhos fixa → determinístico.
	var dist := {}
	if not is_walkable(start):
		return dist
	var frontier: Array[Vector2i] = [start]
	dist[start] = 0
	const NB := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		for d: Vector2i in NB:
			var nb: Vector2i = cur + d
			if dist.has(nb):
				continue
			if not is_walkable(nb):
				continue
			dist[nb] = int(dist[cur]) + 1
			frontier.append(nb)
	return dist

func boss() -> Dictionary:
	for e: Dictionary in enemies:
		if e["boss"]:
			return e
	return {}
