class_name MapEnemy
extends Node2D

const ForestLight := preload("res://scripts/exploration/forest_light.gd")

# ─── Constants ─────────────────────────────────────
const ENEMY_TEXTURE    = preload("res://assets/sprites/enemy_map.png")
const BRUXO_TEXTURE    = preload("res://assets/sprites/bruxo_map.png")
const BOSS_TEXTURE     = preload("res://assets/sprites/boss_idle.png")
const MULA_TEXTURE     = preload("res://assets/sprites/mula_map.png")
const BOITATA_TEXTURE  = preload("res://assets/sprites/boitata_map.png")
const CURUPIRA_TEXTURE = preload("res://assets/sprites/curupira_map.png")
const SACI_TEXTURE     = preload("res://assets/sprites/saci_idle.png")
const JESUITA_TEXTURE  = preload("res://assets/sprites/jesuita_map.png")
const CHASE_RANGE := 5          # comuns: alcance de aggro
const BOSS_CHASE_RANGE := 7     # boss: defende a porta com alcance maior
const DRIFT_IDLE_CHANCE := 0.4  # chance de ficar parado ao voltar pra origem

# Cue de pânico: quando o jogador o mata em um golpe, o inimigo foge tremendo.
const SHUDDER_PX := 1.5         # amplitude do tremor de pânico, em pixels
const SHUDDER_STEP := 0.05      # duração de cada meia-oscilação do tremor (s)

# Fase 5: tipos de comum que são chefes convertidos (espelha ExplorationManager).
const MINIBOSS_TYPES: Array[String] = ["mula", "boitata", "curupira", "saci"]

# Overlay de batismo dos convertidos: pingos de água benta caindo da cabeça
# (as auras sobem; a água benta CAI — contraste de leitura no mapa).
const BAPTISM_DRIP_AMOUNT := 6
const BAPTISM_DRIP_LIFETIME := 1.3
const BAPTISM_DRIP_RADIUS := 6.0
const BAPTISM_DRIP_HEAD_OFFSET := Vector2(0, -18)
const BAPTISM_DRIP_GRAVITY := Vector2(0, 26)

# ─── State ─────────────────────────────────────────
var enemy_id: String = ""
var grid_pos: Vector2i = Vector2i.ZERO
var is_boss: bool = false
var enemy_type: String = ""             # tipo do comum (cacador/bruxo); vazio p/ boss
var home_pos: Vector2i = Vector2i.ZERO  # origem; alvo do leash quando o jogador foge
var _boss_type: String = ""
var _sprite: Sprite2D = null            # sprite do inimigo; alvo do tremor de pânico
var _shudder_tween: Tween = null        # tween do tremor; morto/reiniciado a cada passo

# ─── Public API ────────────────────────────────────
## `pos` é a posição atual (pode ser a "andada" restaurada do combate); `home`
## é a origem do leash (spawn do mapa). Por padrão coincidem (entrada fresca).
func setup(id: String, pos: Vector2i, boss: bool = false, boss_type: String = "",
		home: Vector2i = Vector2i(-1, -1), p_enemy_type: String = "") -> void:
	enemy_id = id
	grid_pos = pos
	home_pos = home if home != Vector2i(-1, -1) else pos
	is_boss = boss
	_boss_type = boss_type
	enemy_type = p_enemy_type
	_update_visual_position()

	# Fase 5: os "monstros" são os 4 chefes convertidos (enemy_type = nome do chefe),
	# roteados como comuns mas exibidos com o sprite/aura de chefe no mapa.
	var miniboss := p_enemy_type in MINIBOSS_TYPES
	var sprite := Sprite2D.new()
	_sprite = sprite  # guardado para o tremor de pânico (_shudder)
	if boss:
		match boss_type:
			"mula":     sprite.texture = MULA_TEXTURE
			"boitata":  sprite.texture = BOITATA_TEXTURE
			"curupira": sprite.texture = CURUPIRA_TEXTURE
			"saci":     sprite.texture = SACI_TEXTURE
			# Antes o Jesuíta caía no `_` e o boss final aparecia no mapa da
			# Fase 5 com o sprite do caçador-de-machados (boss_idle.png).
			"jesuita":  sprite.texture = JESUITA_TEXTURE
			_:          sprite.texture = BOSS_TEXTURE
	else:
		match p_enemy_type:
			"mula":     sprite.texture = MULA_TEXTURE
			"boitata":  sprite.texture = BOITATA_TEXTURE
			"curupira": sprite.texture = CURUPIRA_TEXTURE
			"saci":     sprite.texture = SACI_TEXTURE
			"bruxo":    sprite.texture = BRUXO_TEXTURE
			_:          sprite.texture = ENEMY_TEXTURE
	# Invasores comuns usam a variante de mapa 56px (maiores que a Caipora, que
	# anda o mapa a ~51px); bosses/minibosses usam variantes de ~48px de altura
	# (Curupira, Jesuíta, Mula e Boitatá já re-renderizados do pipeline premium;
	# o Boitatá é 60×48 — serpente horizontal). Sempre transborda pra cima:
	# pés na base do tile.
	sprite.offset = Vector2(0, -13) if (not boss and not miniboss) else Vector2(0, -8)
	# Clamp interino (KI-016): bosses premium ainda SEM variante de mapa
	# (só resta o Saci 128) estourariam o tile de 32px —
	# reduz para ~48px visuais e mantém a base do desenho na linha do legado
	# (16px abaixo do nó). Sai quando cada um ganhar variante re-renderizada.
	if sprite.texture != null and sprite.texture.get_height() > 64:
		var clamp_scale := 48.0 / float(sprite.texture.get_height())
		sprite.scale = Vector2(clamp_scale, clamp_scale)
		sprite.offset.y = 16.0 / clamp_scale - sprite.texture.get_height() * 0.5
	add_child(sprite)
	ActorContrast.apply_outline(sprite)
	# Contorno de brasas HD (no-op sem HD): comuns em sangue frio, chefes e
	# convertidos na cor da própria aura. Luz + halo SÓ em set piece (boss/
	# miniboss) — 8 comuns com luz estourariam o orçamento do Compatibility;
	# o raio da luz é o de MAPA (tile 32px).
	var set_piece := boss or miniboss
	var rim_color := Constants.COLOR_RIM_ENEMY
	if boss:
		rim_color = _aura_color(boss_type)
	elif miniboss:
		rim_color = _aura_color(p_enemy_type)
	ParticleRim.attach_to(sprite, rim_color, 1.0, Color.TRANSPARENT,
		set_piece, set_piece, Constants.RIM_LIGHT_SCALE_MAP)
	if set_piece:
		_spawn_hd_crown(rim_color)

	# Sombra + luz frontal: ancora visual contra o chão escuro (mesmo sistema da arena).
	_spawn_shadow(not boss and not miniboss)
	_spawn_front_light(not boss and not miniboss)

	if boss:
		_spawn_aura(boss_type)
	elif miniboss:
		# Marca de batismo forçado: pele fria + água benta escorrendo. A aura de
		# chefe permanece — a conversão soma por cima, não apaga o que ele era.
		sprite.modulate = Constants.COLOR_BAPTISM_TINT
		_spawn_aura(p_enemy_type)
		_spawn_baptism_drip()
	# Boitatá deixa rastro de brasas no mapa (modo HD): o movimento por tile é
	# teleporte — em coords globais as brasas seguem queimando nos tiles
	# anteriores por ~0.9s, sem nenhum hook em take_turn.
	if boss_type == "boitata" or p_enemy_type == "boitata":
		_spawn_ember_trail()

## Chave deste inimigo no catálogo EnemyStats: boss → tipo do chefe; comum → seu
## tipo, caindo no caçador quando vazio (mesma regra de _regular_scene_for do
## ExplorationManager). Usada para consultar o HP total ao decidir a fuga.
func stats_id() -> StringName:
	if is_boss:
		return StringName(_boss_type)
	return StringName(enemy_type if enemy_type != "" else "cacador")

## Returns true if this enemy reaches the player and should trigger combat.
## `fearful` = o jogador o mata em um golpe base: em vez de perseguir, foge.
func take_turn(player_pos: Vector2i, walkable_fn: Callable, occupied_fn: Callable,
		fearful: bool = false) -> bool:
	var dist := _manhattan(grid_pos, player_pos)
	var aggro_range := BOSS_CHASE_RANGE if is_boss else CHASE_RANGE

	# Apavorado: foge do jogador em vez de persegui-lo e NUNCA inicia combate — o
	# jogador ainda pode encurralar e matar. Longe do jogador, apenas se esconde
	# parado (sem leash de volta pra casa, que o traria de volta rumo ao perigo).
	if fearful:
		if dist <= aggro_range:
			var away := _flee(player_pos, walkable_fn, occupied_fn)
			if away != grid_pos:
				grid_pos = away
				_update_visual_position()
			_shudder()  # treme de pânico enquanto o jogador está perto — mesmo encurralado
		return false

	if dist <= 1:
		return true

	var new_pos: Vector2i
	if dist <= aggro_range:
		# Dentro do alcance: persegue o jogador.
		new_pos = _chase(player_pos, walkable_fn, occupied_fn)
	elif grid_pos != home_pos:
		# Fora do alcance (jogador fugiu): faz leash de volta pra origem.
		new_pos = _drift_home(walkable_fn, occupied_fn)
	else:
		# Já em casa e jogador longe: fica de guarda.
		new_pos = grid_pos

	if new_pos != grid_pos:
		grid_pos = new_pos
		_update_visual_position()
		if grid_pos == player_pos:
			return true

	return false

# ─── Private ───────────────────────────────────────
func _spawn_shadow(is_common: bool) -> void:
	var scale := Vector2(1.12, 0.42) if is_common else Vector2(0.95, 0.34)
	ActorContrast.add_ground_shadow(self, scale, Vector2(0.0, 2.0))

func _spawn_front_light(is_common: bool) -> void:
	var pos := Vector2(-10, -10) if is_common else Vector2(-8, -8)
	ActorContrast.add_front_light(self, pos)

func _spawn_aura(aura_type: String) -> void:
	var aura := CPUParticles2D.new()
	aura.z_index = -1
	# ×heavy (não ambient_amount_scale): o amount era fixo — o modo leve fica
	# byte a byte idêntico e só o HD dobra.
	aura.amount = int(16.0 * Quality.heavy())
	aura.lifetime = 1.4
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 14.0
	aura.gravity = Vector2(0, -10)
	aura.initial_velocity_min = 2.0
	aura.initial_velocity_max = 8.0
	aura.scale_amount_min = 1.5
	aura.scale_amount_max = 3.5
	aura.color = _aura_color(aura_type)
	add_child(aura)

## Cor canônica da aura por tipo de chefe (compartilhada com o rim HD).
func _aura_color(aura_type: String) -> Color:
	match aura_type:
		"mula":     return Constants.COLOR_AURA_MULA
		"boitata":  return Constants.COLOR_AURA_BOITATA
		"curupira": return Constants.COLOR_AURA_CURUPIRA
		"saci":     return Constants.COLOR_AURA_SACI
		"jesuita":  return Constants.COLOR_AURA_JESUITA
		_:          return Constants.COLOR_AURA_BOSS

## Coroa de brasas ORBITANDO o chefe (modo HD): leitura de set piece à
## distância. local_coords = TRUE — com coords globais o centro da órbita
## congela no transform do spawn e a coroa fica para trás no teleporte por tile.
func _spawn_hd_crown(color: Color) -> void:
	if not Quality.hd_enabled():
		return
	var crown := CPUParticles2D.new()
	crown.name = "AuraRing"
	crown.amount = 14
	crown.lifetime = 1.8
	crown.local_coords = true
	crown.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	crown.emission_sphere_radius = 15.0
	crown.orbit_velocity_min = 0.3
	crown.orbit_velocity_max = 0.5
	crown.gravity = Vector2.ZERO
	crown.initial_velocity_min = 0.0
	crown.initial_velocity_max = 0.0
	crown.scale_amount_min = 1.0
	crown.scale_amount_max = 1.8
	var glow := ParticleRim._overbright(color)
	crown.color = glow
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, glow)
	ramp.add_point(1.0, Color(glow.r, glow.g, glow.b, 0.0))
	crown.color_ramp = ramp  # fade no fim da volta = cauda de cometa
	crown.material = Constants.ADDITIVE_MATERIAL
	crown.z_index = 1
	crown.position = Vector2(0.0, -8.0)  # centro do corpo (offset dos sprites de chefe)
	add_child(crown)

## Brasas do Boitatá em escala de mapa (tile 32px). Gated por HD.
func _spawn_ember_trail() -> void:
	if not Quality.hd_enabled():
		return
	var trail := CPUParticles2D.new()
	trail.name = "EmberTrail"
	trail.amount = int(10.0 * Quality.heavy())
	trail.lifetime = 0.9
	trail.local_coords = false
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	trail.emission_rect_extents = Vector2(12.0, 5.0)
	trail.position = Vector2(0.0, -8.0)
	trail.gravity = Vector2(0, 18)
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 5.0
	trail.scale_amount_min = 1.0
	trail.scale_amount_max = 2.0
	trail.color = Constants.COLOR_FIRE_HOT
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Constants.COLOR_FIRE_HOT)
	ramp.add_point(1.0, Color(Constants.COLOR_AURA_BOITATA.r,
		Constants.COLOR_AURA_BOITATA.g, Constants.COLOR_AURA_BOITATA.b, 0.0))
	trail.color_ramp = ramp
	trail.material = Constants.ADDITIVE_MATERIAL
	trail.z_index = 1
	add_child(trail)

func _spawn_baptism_drip() -> void:
	var drip := CPUParticles2D.new()
	drip.z_index = 1  # água escorre POR CIMA do sprite
	drip.amount = BAPTISM_DRIP_AMOUNT
	drip.lifetime = BAPTISM_DRIP_LIFETIME
	drip.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	drip.emission_sphere_radius = BAPTISM_DRIP_RADIUS
	drip.position = BAPTISM_DRIP_HEAD_OFFSET
	drip.gravity = BAPTISM_DRIP_GRAVITY
	drip.initial_velocity_min = 1.0
	drip.initial_velocity_max = 4.0
	drip.scale_amount_min = 1.0
	drip.scale_amount_max = 1.8
	drip.color = Constants.COLOR_BAPTISM_DROP
	add_child(drip)

func _update_visual_position() -> void:
	position = Vector2(grid_pos) * Constants.TILE_SIZE

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _chase(target: Vector2i, walkable_fn: Callable, occupied_fn: Callable) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	var best := grid_pos
	var best_dist := _manhattan(grid_pos, target)
	for d: Vector2i in dirs:
		var np: Vector2i = grid_pos + d
		if walkable_fn.call(np) and not occupied_fn.call(np):
			var dist := _manhattan(np, target)
			if dist < best_dist:
				best_dist = dist
				best = np
	return best

func _drift_home(walkable_fn: Callable, occupied_fn: Callable) -> Vector2i:
	if randf() < DRIFT_IDLE_CHANCE:
		return grid_pos
	return _chase(home_pos, walkable_fn, occupied_fn)

## Vizinho caminhável que mais AFASTA do alvo (oposto de _chase). Se nenhum
## afasta (encurralado), devolve a posição atual.
func _flee(target: Vector2i, walkable_fn: Callable, occupied_fn: Callable) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	var best := grid_pos
	var best_dist := _manhattan(grid_pos, target)
	for d: Vector2i in dirs:
		var np: Vector2i = grid_pos + d
		if walkable_fn.call(np) and not occupied_fn.call(np):
			var dist := _manhattan(np, target)
			if dist > best_dist:
				best_dist = dist
				best = np
	return best

## Tremor sutil de pânico: sacode o sprite em torno do repouso (Vector2.ZERO). Mata
## o tremor anterior antes de recomeçar, para turnos rápidos não deixarem o sprite
## escorrer para fora do lugar.
func _shudder() -> void:
	if _sprite == null:
		return
	if _shudder_tween != null and _shudder_tween.is_valid():
		_shudder_tween.kill()
	_sprite.position = Vector2.ZERO
	_shudder_tween = create_tween()
	_shudder_tween.tween_property(_sprite, "position", Vector2(SHUDDER_PX, 0.0), SHUDDER_STEP)
	_shudder_tween.tween_property(_sprite, "position", Vector2(-SHUDDER_PX, 0.0), SHUDDER_STEP)
	_shudder_tween.tween_property(_sprite, "position", Vector2.ZERO, SHUDDER_STEP)
