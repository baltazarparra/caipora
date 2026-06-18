class_name MapObject
extends Node2D

const ForestLight := preload("res://scripts/exploration/forest_light.gd")
const FireEffect := preload("res://scripts/exploration/fire_effect.gd")
# Sprite premium da TERRA RARA caída (souls-like): minério cristalino numa poça de sangue.
const TERRA_RARA_NODE_TEX: Texture2D = preload("res://assets/sprites/terra_rara_node.png")

enum Type { FIRE, SPIKE, DEAD_TREE, BONES, MOSS, BLOOD_POOL, ROCK, FERN, VINE,
	MUSHROOM, STUMP, TOTEM, ROOTS, PUDDLE, BAG, CROSS, MIRROR, FONT, CANDLE, PEW, BURROW,
	EXIT_PASSAGE }

const T: int = Constants.TILE_SIZE  # 32

# Decorações puramente visuais (não-bloqueantes), renderizadas atrás das entidades.
const DECO_TYPES := [Type.DEAD_TREE, Type.BONES, Type.MOSS, Type.BLOOD_POOL, Type.ROCK, Type.FERN, Type.VINE,
	Type.MUSHROOM, Type.STUMP, Type.TOTEM, Type.ROOTS, Type.PUDDLE]

# Props de igreja (Fase 5): também ambientação (z atrás das entidades), mas FORA de
# DECO_TYPES (que dobra como paleta da Fase 1 — não devem vazar pra floresta).
const CHURCH_PROPS := [Type.CROSS, Type.MIRROR, Type.FONT, Type.CANDLE, Type.PEW]

var _type: Type
# Saída SELADA (gate do boss): o guardião da fase ainda vive, então o portal está trancado
# — leitura fria/barrada, sem o halo âmbar de portal ativo. Destravada ao libertar o boss.
var _sealed: bool = false

# ─── Public API ────────────────────────────────────
## `enhanced` liga luz + partículas na fogueira (chama/brasas/fumaça). Fases 1 e 2 usam.
## `sealed` (só EXIT_PASSAGE) desenha o portal trancado enquanto o boss da fase não cai.
func setup(type: Type, grid_pos: Vector2i, enhanced: bool = false, sealed: bool = false) -> void:
	_type = type
	_sealed = sealed
	position = Vector2(grid_pos) * T
	if type in DECO_TYPES or type in CHURCH_PROPS:
		z_index = -1  # ambientação fica embaixo de jogador/inimigos/baú
	if type == Type.BAG:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # sprite pixel-art crocante
	if type == Type.FIRE and enhanced:
		FireEffect.attach(self, Vector2(T / 2.0, T / 2.0), 0.8)
	queue_redraw()

# ─── Drawing ───────────────────────────────────────
func _draw() -> void:
	var cx: float = T / 2.0
	var cy: float = T / 2.0
	match _type:
		Type.FIRE:       _draw_fire(cx, cy)
		Type.SPIKE:      _draw_spike(cx, cy)
		Type.DEAD_TREE:  _draw_dead_tree(cx, cy)
		Type.BONES:      _draw_bones(cx, cy)
		Type.MOSS:       _draw_moss(cx, cy)
		Type.BLOOD_POOL: _draw_blood_pool(cx, cy)
		Type.ROCK:       _draw_rock(cx, cy)
		Type.FERN:       _draw_fern(cx, cy)
		Type.VINE:       _draw_vine(cx, cy)
		Type.MUSHROOM:   _draw_mushroom(cx, cy)
		Type.STUMP:      _draw_stump(cx, cy)
		Type.TOTEM:      _draw_totem(cx, cy)
		Type.ROOTS:      _draw_roots(cx, cy)
		Type.PUDDLE:     _draw_puddle(cx, cy)
		Type.BAG:        _draw_bag(cx, cy)
		Type.CROSS:      _draw_cross(cx, cy)
		Type.MIRROR:     _draw_mirror(cx, cy)
		Type.FONT:       _draw_font(cx, cy)
		Type.CANDLE:     _draw_candle(cx, cy)
		Type.PEW:        _draw_pew(cx, cy)
		Type.BURROW:     _draw_burrow(cx, cy)
		Type.EXIT_PASSAGE: _draw_exit_passage(cx, cy)

func _draw_fire(cx: float, cy: float) -> void:
	# CHAMA da mata: base preta, silhueta triangular e miolo quente chapado.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 12, cy + 10), Vector2(cx - 8, cy + 4), Vector2(cx - 2, cy + 8),
		Vector2(cx + 5, cy + 3), Vector2(cx + 12, cy + 10),
	]), Constants.COLOR_NIGHT)
	draw_circle(Vector2(cx, cy + 2), 12.0, Constants.COLOR_FIRE_GLOW)
	var flames: Array = [
		[Vector2(cx - 9, cy + 8), Vector2(cx - 3, cy - 11), Vector2(cx + 2, cy + 8)],
		[Vector2(cx - 3, cy + 8), Vector2(cx + 1, cy - 7), Vector2(cx + 5, cy + 8)],
		[Vector2(cx + 3, cy + 8), Vector2(cx + 8, cy - 9), Vector2(cx + 11, cy + 8)],
	]
	var fire_colors: Array = [
		Constants.COLOR_FIRE_MID,
		Constants.COLOR_FIRE_HOT,
		Constants.COLOR_FIRE_LOW,
	]
	for i: int in 3:
		draw_colored_polygon(PackedVector2Array(flames[i]), fire_colors[i])
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 2, cy + 7), Vector2(cx + 1, cy - 5), Vector2(cx + 4, cy + 7),
	]), Constants.COLOR_FIRE_HOT)

func _draw_spike(cx: float, cy: float) -> void:
	# Dentes de raiz/osso saindo do chao, nao cones limpos.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 13, cy + 8), Vector2(cx - 6, cy + 4), Vector2(cx + 3, cy + 7),
		Vector2(cx + 12, cy + 4), Vector2(cx + 13, cy + 10), Vector2(cx - 13, cy + 11),
	]), Constants.COLOR_NIGHT)
	var spike_color := Constants.COLOR_BONE
	for i: int in 4:
		var bx: float = cx - 9.0 + i * 6.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 4, cy + 9),
			Vector2(bx + float(i % 2) - 1.0, cy - 10),
			Vector2(bx + 4, cy + 9),
		]), Constants.COLOR_NIGHT)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 3, cy + 8),
			Vector2(bx + float(i % 2) - 1.0, cy - 9),
			Vector2(bx + 3, cy + 8),
		]), spike_color)
		draw_line(Vector2(bx - 1, cy + 7), Vector2(bx, cy - 5), Constants.COLOR_BONE_HOLLOW, 1.0)

# ─── Decorações (ambientação folk-horror, não-bloqueantes) ──
func _draw_dead_tree(cx: float, cy: float) -> void:
	var bark      := Constants.COLOR_BARK
	var bark_dark := Constants.COLOR_BARK_DARK
	# tronco como garra preta, com lascas laranja de madeira viva.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 4, cy + 12), Vector2(cx - 3, cy - 5), Vector2(cx + 1, cy - 8),
		Vector2(cx + 4, cy - 3), Vector2(cx + 3, cy + 12),
	]), bark_dark)
	draw_line(Vector2(cx - 1, cy - 4), Vector2(cx - 1, cy + 11), bark, 1.5)
	draw_line(Vector2(cx + 1, cy - 2), Vector2(cx + 1, cy + 8), Constants.COLOR_AMBER, 1.0)
	# galhos secos retorcidos, denteados.
	var branches: Array = [
		[Vector2(cx, cy - 2),  Vector2(cx - 9, cy - 9)],
		[Vector2(cx, cy - 4),  Vector2(cx + 8, cy - 11)],
		[Vector2(cx, cy - 1),  Vector2(cx + 6, cy - 3)],
		[Vector2(cx, cy - 6),  Vector2(cx - 5, cy - 13)],
	]
	for b: Array in branches:
		draw_line(b[0], b[1], bark_dark, 3.0)
		draw_line(b[0], b[1], bark, 1.0)

func _draw_bones(cx: float, cy: float) -> void:
	var bone := Constants.COLOR_BONE
	var hollow := Constants.COLOR_BONE_HOLLOW
	# crânio
	draw_circle(Vector2(cx - 3, cy - 1), 5.0, bone)
	draw_circle(Vector2(cx - 5, cy - 2), 1.3, hollow)
	draw_circle(Vector2(cx - 1, cy - 2), 1.3, hollow)
	draw_rect(Rect2(cx - 4, cy + 2, 3, 2), bone)
	# ossos cruzados
	draw_line(Vector2(cx + 1, cy + 5), Vector2(cx + 10, cy - 2), bone, 2.0)
	draw_line(Vector2(cx + 1, cy - 2), Vector2(cx + 10, cy + 5), bone, 2.0)

func _draw_moss(cx: float, cy: float) -> void:
	var moss      := Constants.COLOR_MOSS_DECO
	var moss_dark := Constants.COLOR_MOSS_DECO_DARK
	var blobs: Array = [
		[Vector2(cx - 6, cy + 4), 6.0], [Vector2(cx + 5, cy + 6), 5.0],
		[Vector2(cx + 7, cy - 4), 4.0], [Vector2(cx - 4, cy - 5), 4.5],
		[Vector2(cx + 1, cy + 1), 5.5],
	]
	for b: Array in blobs:
		draw_circle(b[0], b[1], moss)
	draw_circle(Vector2(cx - 5, cy + 5), 2.5, moss_dark)
	draw_circle(Vector2(cx + 6, cy - 3), 2.0, moss_dark)

func _draw_blood_pool(cx: float, cy: float) -> void:
	var blood      := Constants.COLOR_BLOOD_POOL
	var blood_dark := Constants.COLOR_BLOOD_POOL_DARK
	var pool: PackedVector2Array = [
		Vector2(cx - 9, cy + 1), Vector2(cx - 5, cy - 5), Vector2(cx + 2, cy - 6),
		Vector2(cx + 8, cy - 2), Vector2(cx + 9, cy + 4), Vector2(cx + 3, cy + 8),
		Vector2(cx - 4, cy + 7), Vector2(cx - 10, cy + 5),
	]
	draw_colored_polygon(pool, blood)
	draw_circle(Vector2(cx + 1, cy + 1), 3.5, blood_dark)
	# respingos
	draw_circle(Vector2(cx + 11, cy - 6), 1.5, blood)
	draw_circle(Vector2(cx - 12, cy - 3), 1.2, blood)

func _draw_rock(cx: float, cy: float) -> void:
	var stone      := Constants.COLOR_STONE
	var stone_dark := Constants.COLOR_STONE_DARK
	var rock: PackedVector2Array = [
		Vector2(cx - 8, cy + 6), Vector2(cx - 6, cy - 3), Vector2(cx, cy - 7),
		Vector2(cx + 7, cy - 2), Vector2(cx + 8, cy + 6),
	]
	draw_colored_polygon(rock, stone)
	var shade: PackedVector2Array = [
		Vector2(cx, cy - 7), Vector2(cx + 7, cy - 2), Vector2(cx + 8, cy + 6), Vector2(cx + 2, cy + 2),
	]
	draw_colored_polygon(shade, stone_dark)

func _draw_fern(cx: float, cy: float) -> void:
	# Samambaia amazônica: leque de frondes saindo da base.
	var frond := Constants.COLOR_MOSS_DECO
	var frond_dark := Constants.COLOR_MOSS_DECO_DARK
	var base := Vector2(cx, cy + 9)
	var angles: Array = [-1.15, -0.7, -0.25, 0.25, 0.7, 1.15]
	for a: float in angles:
		var tip := base + Vector2(sin(a), -cos(a)) * 13.0
		draw_line(base, tip, frond_dark, 2.0)
		# folíolos ao longo da fronde
		var dir := (tip - base).normalized()
		var perp := Vector2(-dir.y, dir.x)
		for s: float in [0.4, 0.65, 0.9]:
			var p := base.lerp(tip, s)
			draw_line(p, p + perp * 2.5, frond, 1.0)
			draw_line(p, p - perp * 2.5, frond, 1.0)

func _draw_vine(cx: float, cy: float) -> void:
	# Cipó pendente: trança que desce do topo do tile com folhas esparsas.
	var vine := Constants.COLOR_MOSS_DECO_DARK
	var leaf := Constants.COLOR_MOSS_DECO
	var prev := Vector2(cx - 6, cy - 14)
	for i: int in range(1, 9):
		var t := i / 8.0
		var nxt := Vector2(cx - 6 + sin(t * 6.0) * 4.0, cy - 14 + t * 26.0)
		draw_line(prev, nxt, vine, 2.0)
		if i % 2 == 0:
			draw_circle(nxt + Vector2(3, 0), 2.2, leaf)
		prev = nxt

func _draw_mushroom(cx: float, cy: float) -> void:
	# Trio de cogumelos pálidos com leve bioluminescência (encantado/doentio).
	var cap := Constants.COLOR_MUSHROOM
	var glow := Constants.COLOR_MUSHROOM_GLOW
	var stalk := Constants.COLOR_BONE_HOLLOW
	var caps: Array = [
		[Vector2(cx - 5, cy + 3), 4.5], [Vector2(cx + 4, cy + 5), 3.5], [Vector2(cx, cy - 2), 5.5],
	]
	for c: Array in caps:
		var p: Vector2 = c[0]
		var r: float = c[1]
		# pé
		draw_rect(Rect2(p.x - 1, p.y, 2, r * 0.9), stalk)
		# chapéu
		draw_circle(p, r, cap)
		# pintas brilhantes
		draw_circle(p + Vector2(-1.5, -1.0), 0.9, glow)
		draw_circle(p + Vector2(1.6, 0.2), 0.7, glow)

func _draw_stump(cx: float, cy: float) -> void:
	# Toco cortado: anéis de crescimento concêntricos.
	var wood := Constants.COLOR_WOOD
	var wood_dark := Constants.COLOR_WOOD_DARK
	var bark := Constants.COLOR_BARK
	draw_circle(Vector2(cx, cy + 2), 9.0, bark)
	draw_circle(Vector2(cx, cy + 2), 8.0, wood)
	draw_arc(Vector2(cx, cy + 2), 6.0, 0, TAU, 16, wood_dark, 1.0)
	draw_arc(Vector2(cx, cy + 2), 3.5, 0, TAU, 12, wood_dark, 1.0)
	draw_circle(Vector2(cx, cy + 2), 1.2, wood_dark)

func _draw_totem(cx: float, cy: float) -> void:
	# Totem entalhado folk-horror: poste com rosto e marcas de sangue.
	var wood := Constants.COLOR_WOOD
	var wood_dark := Constants.COLOR_WOOD_DARK
	var blood := Constants.COLOR_BLOOD
	draw_rect(Rect2(cx - 5, cy - 12, 10, 26), wood_dark)
	draw_rect(Rect2(cx - 4, cy - 11, 8, 24), wood)
	# olhos ocos
	draw_circle(Vector2(cx - 2, cy - 6), 1.6, wood_dark)
	draw_circle(Vector2(cx + 2, cy - 6), 1.6, wood_dark)
	# boca rasgada
	draw_rect(Rect2(cx - 3, cy - 1, 6, 2), wood_dark)
	# marcas rituais de sangue
	draw_line(Vector2(cx - 3, cy + 4), Vector2(cx + 3, cy + 6), blood, 1.0)
	draw_line(Vector2(cx + 3, cy + 4), Vector2(cx - 3, cy + 6), blood, 1.0)

func _draw_roots(cx: float, cy: float) -> void:
	# Raízes rastejantes pelo chão: silhueta preta que morde a trilha.
	var bark := Constants.COLOR_BARK
	var bark_dark := Constants.COLOR_BARK_DARK
	var roots: Array = [
		[Vector2(cx - 12, cy - 6), Vector2(cx, cy)], [Vector2(cx, cy), Vector2(cx + 11, cy + 5)],
		[Vector2(cx, cy), Vector2(cx + 9, cy - 7)], [Vector2(cx, cy), Vector2(cx - 8, cy + 8)],
	]
	for r: Array in roots:
		draw_line(r[0], r[1], Constants.COLOR_NIGHT, 4.0)
		draw_line(r[0], r[1], bark_dark, 2.0)
		draw_line(r[0], r[1], bark, 1.0)

func _draw_puddle(cx: float, cy: float) -> void:
	# Poça d'água escura refletindo a noite (leve brilho da superfície).
	var water := Constants.COLOR_WATER
	var water_light := Constants.COLOR_WATER_LIGHT
	var pool: PackedVector2Array = [
		Vector2(cx - 10, cy + 2), Vector2(cx - 5, cy - 4), Vector2(cx + 3, cy - 5),
		Vector2(cx + 10, cy - 1), Vector2(cx + 8, cy + 5), Vector2(cx, cy + 7), Vector2(cx - 7, cy + 6),
	]
	draw_colored_polygon(pool, water)
	# reflexos na superfície
	draw_line(Vector2(cx - 4, cy + 1), Vector2(cx + 2, cy), water_light, 1.0)
	draw_line(Vector2(cx + 1, cy + 3), Vector2(cx + 6, cy + 2), water_light, 1.0)

func _draw_bag(_cx: float, _cy: float) -> void:
	# TERRA RARA derrubada na morte (souls-like): sprite premium do minério cristalino caído
	# numa poça de sangue — atrai o olhar pra "voltar lá". O brilho âmbar pulsante é erguido
	# pelo ExplorationManager (ForestLight) sobre este tile.
	draw_texture(TERRA_RARA_NODE_TEX, Vector2.ZERO)

func _draw_burrow(cx: float, cy: float) -> void:
	# Boca de toca descendo pra escuridão da mata, com terra revolvida e folhas secas
	# amontoadas na beirada — o rastro por onde a Caipora mergulha de volta na caçada.
	var night := Constants.COLOR_NIGHT
	var earth := Constants.COLOR_EARTH
	var bark_dark := Constants.COLOR_BARK_DARK
	var leaf := Constants.COLOR_MOSS_DECO
	var leaf_dark := Constants.COLOR_MOSS_DECO_DARK
	var twig := Constants.COLOR_BARK
	# halo âmbar de portal ativo: brilho que marca a saída contra o chão escuro
	var amber_glow := Constants.COLOR_AMBER
	amber_glow.a = 0.45
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 2), 16.0, 12.0), amber_glow)
	# aro de terra revolvida em volta da boca (maior para ler melhor)
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 2), 15.0, 11.0), earth)
	# parede interna em sombra (dá profundidade ao mergulho)
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 2.5), 10.5, 7.5), bark_dark)
	# o buraco em si: escuridão total
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3), 8.5, 6.0), night)
	# galhos secos atravessados na borda
	draw_line(Vector2(cx - 12, cy - 4), Vector2(cx - 3, cy - 8), twig, 1.5)
	draw_line(Vector2(cx + 4, cy - 9), Vector2(cx + 12, cy - 3), twig, 1.5)
	# folhas amontoadas na beirada de cima (monte mais denso atrás da boca)
	# folhas claras predominam para contraste contra o chão
	var pile: Array = [
		[Vector2(cx - 8, cy - 6), 3.5, leaf], [Vector2(cx - 2, cy - 8), 4.0, leaf],
		[Vector2(cx + 5, cy - 7), 3.5, leaf], [Vector2(cx + 10, cy - 4), 2.8, leaf],
		[Vector2(cx - 12, cy - 2), 2.6, leaf], [Vector2(cx + 1, cy - 5), 3.0, leaf],
	]
	for p: Array in pile:
		draw_circle(p[0], p[1], p[2])
	# folhas soltas escorregando pra dentro e caídas na frente
	draw_circle(Vector2(cx - 5, cy + 9), 2.0, leaf_dark)
	draw_circle(Vector2(cx + 7, cy + 8), 1.8, leaf)
	draw_circle(Vector2(cx + 2, cy + 1), 1.6, leaf_dark)

func _draw_exit_passage(cx: float, cy: float) -> void:
	if _sealed:
		_draw_exit_passage_sealed(cx, cy)
		return
	# Passagem ritual: portal de pedra-osso aberto na terra escura, por onde a Caipora
	# mergulha de volta na caçada. Halo âmbar (a marca laranja), boca acesa, vazio preto
	# total, ladeado por dois menires de osso com marca ritual de sangue e brasas âmbar
	# subindo do breu — leitura distinta da toca (folhas) e mais "portão" de saída.
	var night := Constants.COLOR_NIGHT
	var earth := Constants.COLOR_EARTH
	var bark_dark := Constants.COLOR_BARK_DARK
	var bone := Constants.COLOR_BONE
	var bone_dark := Constants.COLOR_BONE_HOLLOW
	var blood := Constants.COLOR_BLOOD
	var amber := Constants.COLOR_AMBER
	var ember := Constants.COLOR_FIRE_HOT
	# halo âmbar de portal ativo: brilho que marca a saída contra o chão escuro
	var glow := amber
	glow.a = 0.40
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3), 16.0, 12.0), glow)
	# aro de terra revolvida em volta da boca
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3), 14.0, 10.0), earth)
	# anel âmbar fino: a boca acesa do portal
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3), 11.5, 8.0), amber)
	# parede interna em sombra (profundidade do mergulho)
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3.5), 10.0, 6.8), bark_dark)
	# o vão: escuridão total (mais fundo, pra o laranja virar só o aro aceso)
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3.5), 9.5, 6.3), night)
	# menires de osso ladeando a passagem (gatepostes rituais): mais baixos e em pedra
	# aquecida (osso puxado pra terra) pra emoldurar o portal sem roubar o laranja dominante.
	var stone := bone.lerp(earth, 0.4)
	for sx: float in [cx - 10.0, cx + 10.0]:
		# outline/sombra do menir
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 3, cy + 8), Vector2(sx - 3, cy - 7),
			Vector2(sx, cy - 10), Vector2(sx + 3, cy - 7), Vector2(sx + 3, cy + 8),
		]), night)
		# corpo do menir (pedra aquecida)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 2, cy + 7), Vector2(sx - 2, cy - 6),
			Vector2(sx, cy - 9), Vector2(sx + 2, cy - 6), Vector2(sx + 2, cy + 7),
		]), stone)
		# face direita em sombra (volume chapado, 2 tons)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, cy - 9), Vector2(sx + 2, cy - 6), Vector2(sx + 2, cy + 7), Vector2(sx, cy + 7),
		]), bone_dark)
		# fio claro de osso na face esquerda (acento, 1px)
		draw_line(Vector2(sx - 2, cy - 5), Vector2(sx - 2, cy + 6), bone, 1.0)
		# marca ritual de sangue gravada na pedra
		draw_line(Vector2(sx - 1, cy - 4), Vector2(sx + 1, cy), blood, 1.0)
	# brasas âmbar subindo do breu (o portal está vivo)
	for e: Array in [[Vector2(cx - 3, cy - 1), 1.8, ember], [Vector2(cx + 2, cy - 4), 1.4, amber],
			[Vector2(cx, cy + 2), 1.5, ember]]:
		var p: Vector2 = e[0]
		var r: float = e[1]
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -r), p + Vector2(r * 0.7, 0), p + Vector2(0, r), p + Vector2(-r * 0.7, 0),
		]), e[2])

func _draw_exit_passage_sealed(cx: float, cy: float) -> void:
	# Saída TRANCADA: o guardião da fase ainda vive, então o portal está selado. Mesmo
	# enquadramento de menires da passagem aberta, mas a boca é barrada por ossos cruzados e
	# um selo de sangue — frio, sem o halo âmbar (a marca laranja só volta ao libertar o boss).
	var night := Constants.COLOR_NIGHT
	var earth := Constants.COLOR_EARTH
	var bark_dark := Constants.COLOR_BARK_DARK
	var bone := Constants.COLOR_BONE
	var bone_dark := Constants.COLOR_BONE_HOLLOW
	var blood := Constants.COLOR_BLOOD
	# aro de terra revolvida (sem halo âmbar — apagado)
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3), 14.0, 10.0), earth)
	# parede interna em sombra + vão escuro
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3.5), 11.0, 7.5), bark_dark)
	draw_colored_polygon(_ellipse(Vector2(cx, cy + 3.5), 9.5, 6.3), night)
	# ossos cruzados barrando a boca (o portal está trancado)
	draw_line(Vector2(cx - 9, cy - 2), Vector2(cx + 9, cy + 8), bone, 2.5)
	draw_line(Vector2(cx + 9, cy - 2), Vector2(cx - 9, cy + 8), bone, 2.5)
	draw_line(Vector2(cx - 9, cy - 2), Vector2(cx + 9, cy + 8), bone_dark, 1.0)
	draw_line(Vector2(cx + 9, cy - 2), Vector2(cx - 9, cy + 8), bone_dark, 1.0)
	# selo de sangue ritual no centro (marca que ninguém passa)
	draw_circle(Vector2(cx, cy + 3), 3.0, blood)
	draw_line(Vector2(cx - 2, cy + 1), Vector2(cx + 2, cy + 5), blood, 1.0)
	draw_line(Vector2(cx + 2, cy + 1), Vector2(cx - 2, cy + 5), blood, 1.0)
	# menires de osso ladeando a passagem (gatepostes rituais, frios)
	var stone := bone.lerp(earth, 0.4)
	for sx: float in [cx - 10.0, cx + 10.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 3, cy + 8), Vector2(sx - 3, cy - 7),
			Vector2(sx, cy - 10), Vector2(sx + 3, cy - 7), Vector2(sx + 3, cy + 8),
		]), night)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 2, cy + 7), Vector2(sx - 2, cy - 6),
			Vector2(sx, cy - 9), Vector2(sx + 2, cy - 6), Vector2(sx + 2, cy + 7),
		]), stone)
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, cy - 9), Vector2(sx + 2, cy - 6), Vector2(sx + 2, cy + 7), Vector2(sx, cy + 7),
		]), bone_dark)

# Elipse achatada (leitura top-down) como polígono — base de buracos e bocas de toca.
func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i: int in 20:
		var a: float = TAU * i / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# ─── Props de igreja (Fase 5, ambientação não-bloqueante) ──
func _draw_cross(cx: float, cy: float) -> void:
	# Cruz torta: madeira preta, fio litúrgico gasto e sangue escorrido.
	var wood := Constants.COLOR_WOOD_DARK
	var gold := Constants.COLOR_GOLD_DARK
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 2, cy - 13), Vector2(cx + 3, cy - 12), Vector2(cx + 2, cy + 13), Vector2(cx - 3, cy + 12),
	]), wood)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 8, cy - 7), Vector2(cx + 8, cy - 6), Vector2(cx + 7, cy - 2), Vector2(cx - 7, cy - 3),
	]), wood)
	draw_line(Vector2(cx, cy - 12), Vector2(cx, cy + 12), gold, 1.0)
	draw_line(Vector2(cx - 7, cy - 5), Vector2(cx + 7, cy - 4), gold, 1.0)
	draw_line(Vector2(cx - 1, cy - 2), Vector2(cx - 2, cy + 11), Constants.COLOR_BLOOD, 1.0)

func _draw_mirror(cx: float, cy: float) -> void:
	# Espelho rachado de moldura dourada (a isca de conversão do Jesuíta).
	var frame := Constants.COLOR_GOLD_DARK
	var glass := Constants.COLOR_WATER_LIGHT
	var glint := Constants.COLOR_PARTICLE_DODGE
	draw_rect(Rect2(cx - 6, cy - 11, 12, 22), frame)  # moldura
	draw_rect(Rect2(cx - 4, cy - 9, 8, 18), glass)    # vidro
	draw_line(Vector2(cx - 3, cy + 6), Vector2(cx + 3, cy - 7), glint, 1.5)  # glint
	draw_line(Vector2(cx + 2, cy - 8), Vector2(cx - 2, cy + 4), frame, 1.0)  # rachadura
	draw_rect(Rect2(cx - 1, cy + 11, 2, 4), frame)    # cabo

func _draw_font(cx: float, cy: float) -> void:
	# Pia de água benta em pedra, a água estagnada virando lodo.
	var stone := Constants.COLOR_STONE
	var stone_dark := Constants.COLOR_STONE_DARK
	var water := Constants.COLOR_WATER
	var water_light := Constants.COLOR_WATER_LIGHT
	draw_rect(Rect2(cx - 3, cy - 2, 6, 12), stone_dark)  # pedestal
	draw_rect(Rect2(cx - 2, cy - 2, 3, 12), stone)
	draw_rect(Rect2(cx - 6, cy + 9, 12, 3), stone_dark)  # base
	var bowl := PackedVector2Array([
		Vector2(cx - 9, cy - 6), Vector2(cx + 9, cy - 6),
		Vector2(cx + 6, cy - 1), Vector2(cx - 6, cy - 1),
	])
	draw_colored_polygon(bowl, stone)                    # bacia
	draw_rect(Rect2(cx - 7, cy - 6, 14, 2), water)       # água benta
	draw_line(Vector2(cx - 4, cy - 5), Vector2(cx + 3, cy - 5), water_light, 1.0)

func _draw_candle(cx: float, cy: float) -> void:
	# Círio votivo aceso: pequena CHAMA em vez de luz macia.
	var wax := Constants.COLOR_BONE
	var wax_dark := Constants.COLOR_BONE_HOLLOW
	var glow := Constants.COLOR_FIRE_GLOW
	var flame := Constants.COLOR_FIRE_HOT
	var flame_mid := Constants.COLOR_FIRE_MID
	draw_circle(Vector2(cx, cy - 8), 6.0, glow)
	draw_rect(Rect2(cx - 3, cy - 4, 6, 16), wax_dark)    # cera
	draw_rect(Rect2(cx - 2, cy - 4, 3, 16), wax)
	draw_rect(Rect2(cx - 1, cy - 7, 2, 3), wax_dark)     # pavio
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 3, cy - 6), Vector2(cx, cy - 13), Vector2(cx + 3, cy - 6),
	]), flame_mid)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 1, cy - 6), Vector2(cx, cy - 10), Vector2(cx + 1, cy - 6),
	]), flame)

func _draw_pew(cx: float, cy: float) -> void:
	# Banco de igreja quebrado.
	var wood := Constants.COLOR_WOOD
	var wood_dark := Constants.COLOR_WOOD_DARK
	draw_rect(Rect2(cx - 12, cy + 2, 24, 4), wood_dark)  # assento
	draw_rect(Rect2(cx - 12, cy + 2, 24, 2), wood)
	draw_rect(Rect2(cx - 12, cy - 6, 24, 3), wood_dark)  # encosto
	draw_rect(Rect2(cx - 12, cy - 6, 24, 1), wood)
	draw_rect(Rect2(cx - 11, cy + 5, 3, 7), wood_dark)   # pernas
	draw_rect(Rect2(cx + 8, cy + 5, 3, 7), wood_dark)
	draw_rect(Rect2(cx - 11, cy - 6, 2, 8), wood_dark)   # suportes do encosto
	draw_rect(Rect2(cx + 9, cy - 6, 2, 8), wood_dark)
