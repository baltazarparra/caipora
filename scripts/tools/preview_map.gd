extends SceneTree

## Ferramenta de preview procedural (dev only, headless). Imprime o ASCII de cada
## fase × seeds e um resumo de densidades (chão, fogo, abertura). Sem render — roda
## em headless/CI para tunar MapConfig sem display, contornando a falta de tela.
##
## Uso:
##   godot --headless --path . -s scripts/tools/preview_map.gd -- \
##       [--phases=1,2,3,4] [--seeds=1,42,1001]
##
## Glifos: '#'=parede  '.'=chão  '*'=fogo(R)  '%'=espinho(S)
##         '@'=spawn  '>'=saída  'B'=boss  'e'=inimigo  'C'=baú  'k'=chave

func _initialize() -> void:
	var phases: Array = [1, 2, 3, 4]
	var seeds: Array = [1, 42, 1001]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phases="):
			phases = _ints(arg.substr("--phases=".length()))
		elif arg.begins_with("--seeds="):
			seeds = _ints(arg.substr("--seeds=".length()))

	for phase: int in phases:
		var cfg := MapConfig.for_phase(phase)
		for s: int in seeds:
			_dump(cfg, phase, s)
	quit()

func _ints(csv: String) -> Array:
	var out: Array = []
	for part: String in csv.split(",", false):
		out.append(int(part.strip_edges()))
	return out

func _dump(cfg: MapConfig, phase: int, s: int) -> void:
	var gen := MapGenerator.new()
	var m := gen.generate(cfg, s)

	# Conta densidades sobre o grid bruto (W/F/E/R/S).
	var wall_n := 0
	var floor_n := 0   # chão caminhável (inclui hazards, exclui parede)
	var fire_n := 0
	for y: int in m.tiles.size():
		var row: Array = m.tiles[y]
		for x: int in row.size():
			match String(row[x]):
				"W": wall_n += 1
				"R", "S": fire_n += 1; floor_n += 1
				_: floor_n += 1
	var interior := (m.width - 2) * (m.height - 2)
	var floor_pct := 100.0 * float(floor_n) / float(maxi(1, interior))
	var fire_pct := 100.0 * float(fire_n) / float(maxi(1, floor_n))

	# Overlay de entidades sobre uma cópia do char-grid.
	var glyphs: Array = []
	for y: int in m.tiles.size():
		var line := ""
		var row: Array = m.tiles[y]
		for x: int in row.size():
			line += _glyph(String(row[x]))
		glyphs.append(line)
	_stamp(glyphs, m.player_start, "@")
	if m.exit_pos != Vector2i(-1, -1):
		_stamp(glyphs, m.exit_pos, ">")
	if m.herb_pos != Vector2i(-1, -1):
		_stamp(glyphs, m.herb_pos, "H")
	for e: Dictionary in m.enemies:
		_stamp(glyphs, Vector2i(e["x"], e["y"]), "B" if e["boss"] else "e")

	print("══ Fase %d · seed %d · %s · chão %.0f%% · fogo %.0f%% do chão ══"
		% [phase, s, _topo(cfg), floor_pct, fire_pct])
	for line: String in glyphs:
		print(line)
	print("")

func _glyph(ch: String) -> String:
	match ch:
		"W": return "#"
		"R": return "*"
		"S": return "%"
		"E": return ">"
		_: return "."

func _stamp(glyphs: Array, p: Vector2i, g: String) -> void:
	if p.y < 0 or p.y >= glyphs.size():
		return
	var line: String = glyphs[p.y]
	if p.x < 0 or p.x >= line.length():
		return
	glyphs[p.y] = line.substr(0, p.x) + g + line.substr(p.x + 1)

func _topo(cfg: MapConfig) -> String:
	return "CORRIDOR" if cfg.topology_mode == MapConfig.TopologyMode.CORRIDOR else "OPEN"
