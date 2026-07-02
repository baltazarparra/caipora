class_name ParticleRim
extends Node2D

## Contorno de partículas neon (modo HD): brasas nascem NA silhueta do sprite e
## respiram PARA FORA (EMISSION_SHAPE_DIRECTED_POINTS com pontos da borda alpha).
## v2 "Impressionante" soma três camadas opcionais:
##   - RimHalo: bloom fake — quads da textura radial do ForestLight, alpha baixo,
##     aditivo, em global coords (descola no movimento = esteira volumétrica);
##   - RimLight: PointLight2D pulsante na cor do rim — fura o CanvasModulate;
##   - Momentos: flare() no PERFEITO/crítico (pico de luz + RimBurst da silhueta
##     + anel de choque) e FootEmbers na passada da Caipora.
## Densidade ambiente escala por Constants.ambient_amount_scale (2x em HD).
##
## Espelho estrutural do FuriaVisual: componente Node2D filho do sprite, montado
## em código (GL Compatibility, sem GPUParticles), idempotente via attach_to.
## NO-OP quando Quality.hd_enabled() é falso — o modo leve nem instancia isto,
## então os call sites não precisam de guarda.

const NODE_NAME := "ParticleRim"
const EDGE_ALPHA := 0.5    # limiar de silhueta no alpha
const EDGE_STEP := 2       # amostra a cada N px (a borda é densa demais em 1px)
const MAX_POINTS := 256    # teto por textura (subamostra uniforme se estourar)

## Cache de silhueta por textura: 1 passe de Image por processo.
## chave -> {"points": PackedVector2Array, "normals": PackedVector2Array}
static var _edge_cache: Dictionary = {}

var _base_x: float = 0.0
var _color: Color = Color.WHITE
var _light: PointLight2D = null
var _burst: CPUParticles2D = null
var _ring: Sprite2D = null
var _foot: CPUParticles2D = null
var _pulse_tween: Tween = null
var _flare_tween: Tween = null
var _ring_tween: Tween = null

func _process(_delta: float) -> void:
	# flip_h do sprite não espelha filhos: espelhar posição + scale à mão
	# (padrão FuriaVisual._process). O scale espelha os pontos de emissão.
	var parent := get_parent()
	var flipped := false
	if parent is AnimatedSprite2D:
		flipped = (parent as AnimatedSprite2D).flip_h
	elif parent is Sprite2D:
		flipped = (parent as Sprite2D).flip_h
	position.x = -_base_x if flipped else _base_x
	scale.x = -1.0 if flipped else 1.0
	# Brasas de passada: emitem só enquanto o ator anda (duck-typing no avô —
	# a Caipora de exploração/HUB tem _is_moving; na arena ninguém anda).
	if _foot != null and parent != null:
		var actor := parent.get_parent()
		var moving: Variant = actor.get("_is_moving") if actor != null else null
		_foot.emitting = moving is bool and bool(moving)

## Anexa o rim ao sprite (AnimatedSprite2D da arena/exploração ou Sprite2D do
## mapa). Idempotente: free() do anterior permite refresh mid-run (ex.: CHAMA).
## `spark_color` transparente = sem faíscas. `with_light`/`with_halo` seguem o
## orçamento do plano HD (luz: Caipora, ator de arena, boss/miniboss do mapa;
## halo: Caipora, bosses, espíritos). `light_scale` 0 = RIM_LIGHT_SCALE padrão
## (o mapa usa RIM_LIGHT_SCALE_MAP — tile de 32px alaga com o raio da arena).
static func attach_to(sprite: Node2D, rim_color: Color, intensity: float = 1.0,
		spark_color: Color = Color.TRANSPARENT, with_light: bool = false,
		with_halo: bool = false, light_scale: float = 0.0) -> void:
	if sprite == null:
		return
	var previous := sprite.get_node_or_null(NODE_NAME)
	if previous != null:
		# free() imediato: queue_free deixaria o nome ocupado neste frame
		# (mesma razão do FuriaVisual.attach_to).
		previous.free()
	if not Quality.hd_enabled():
		return
	var tex := _reference_texture(sprite)
	if tex == null:
		return
	var edge := _edge_data(tex)
	var points := edge["points"] as PackedVector2Array
	if points.is_empty():
		return

	var rim := ParticleRim.new()
	rim.name = NODE_NAME
	rim.position = _sprite_offset(sprite)
	rim._base_x = rim.position.x
	rim._color = rim_color
	rim.z_index = 2
	sprite.add_child(rim)

	var ps := _ambient_scale(sprite)
	rim.add_child(_build_dust(edge, rim_color, intensity, ps))
	if spark_color.a > 0.0:
		rim.add_child(_build_sparks(edge, spark_color, intensity, ps))
	if with_halo:
		rim.add_child(_build_halo(edge, rim_color, ps))
	if with_light:
		rim._light = _build_light(rim_color, light_scale)
		rim.add_child(rim._light)
		rim._start_light_pulse()

	# Respiro lento do contorno (par do pulso do FuriaVisual): vivo, não estático.
	var pulse := rim.create_tween().set_loops()
	pulse.tween_property(rim, "modulate:a", 0.75, 1.4)
	pulse.tween_property(rim, "modulate:a", 1.0, 1.4)

## Rim da protagonista: laranja da juba dominante, esquentando com o tier de
## Fúria; com CHAMA vira brasa clara. Faíscas verdes do cristal só como acento
## raro (tier >= 3, pouquíssimas) — o verde pertence ao cristal (lei da marca).
## Camadas completas: halo + luz + flare de combate + brasas de passada.
static func attach_caipora(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var tier := FuriaVisual._max_furia_tier()
	var heat := float(tier) / 6.0
	var rim_color := Constants.COLOR_JUBA.lerp(Constants.COLOR_CHAMA_HOT, heat)
	if MetaProgression.has_chama:
		rim_color = Constants.COLOR_CHAMA_HOT.lerp(Constants.COLOR_CHAMA_CORE, 0.35)
	var spark := Constants.COLOR_CRYSTAL_GLOW if tier >= 3 else Color.TRANSPARENT
	attach_to(sprite, rim_color, 1.0 + heat, spark, true, true)
	var rim := sprite.get_node_or_null(NODE_NAME) as ParticleRim
	if rim != null:
		rim._enable_combat_flare()
		rim._add_foot_embers()

## Coroa de brasas ORBITANDO um set piece (chefes do mapa, espíritos do
## santuário). local_coords = TRUE — com coords globais o centro da órbita
## congela no transform do spawn e a coroa fica para trás quando o dono se
## move/teleporta. Fade no fim da volta = cauda de cometa. No-op sem HD.
static func attach_crown(parent: Node2D, color: Color, radius: float,
		offset: Vector2 = Vector2.ZERO) -> void:
	if parent == null or not Quality.hd_enabled():
		return
	var crown := CPUParticles2D.new()
	crown.name = "AuraRing"
	crown.amount = 14
	crown.lifetime = 1.8
	crown.local_coords = true
	crown.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	crown.emission_sphere_radius = radius
	crown.orbit_velocity_min = 0.3
	crown.orbit_velocity_max = 0.5
	crown.gravity = Vector2.ZERO
	crown.initial_velocity_min = 0.0
	crown.initial_velocity_max = 0.0
	crown.scale_amount_min = 1.0
	crown.scale_amount_max = 1.8
	var glow := _overbright(color)
	crown.color = glow
	crown.color_ramp = _fade_ramp(glow)
	crown.material = Constants.ADDITIVE_MATERIAL
	crown.z_index = 1
	crown.position = offset
	parent.add_child(crown)

# ─── Momentos (flare / passada) ──────────────────────────────────────────────

## Liga o pico de PERFEITO/crítico: monta o RimBurst + anel de choque e conecta
## os desfechos do combate. Fora da arena os sinais nunca disparam (inofensivo);
## a desconexão é automática quando o rim é liberado (re-attach/troca de tela).
func _enable_combat_flare() -> void:
	var tex := _reference_texture(get_parent())
	if tex == null:
		return
	_burst = _build_burst(_edge_data(tex), _color, _ambient_scale(get_parent()))
	add_child(_burst)
	_ring = _build_ring(_color)
	add_child(_ring)
	SignalBus.attack_result_perfect.connect(flare)
	SignalBus.defense_result_perfect.connect(flare)

## Pico dramático de momento: a luz estoura e decai, brasas explodem da
## silhueta, um anel de choque expande. AAA lê nos picos, não no estado.
func flare() -> void:
	if _light != null:
		if _pulse_tween != null and _pulse_tween.is_valid():
			_pulse_tween.kill()
		if _flare_tween != null and _flare_tween.is_valid():
			_flare_tween.kill()
		_light.energy = Constants.RIM_LIGHT_ENERGY * 2.5
		_flare_tween = create_tween()
		_flare_tween.tween_property(_light, "energy", Constants.RIM_LIGHT_ENERGY, 0.4)
		_flare_tween.tween_callback(_start_light_pulse)
	if _burst != null:
		_burst.restart()
	if _ring != null:
		if _ring_tween != null and _ring_tween.is_valid():
			_ring_tween.kill()
		_ring.scale = Vector2.ONE * Constants.RIM_RING_SCALE_START
		_ring.modulate = Color(_color.r, _color.g, _color.b, Constants.RIM_RING_ALPHA)
		_ring_tween = create_tween().set_parallel()
		_ring_tween.tween_property(_ring, "scale",
			Vector2.ONE * Constants.RIM_RING_SCALE_END, 0.3)
		_ring_tween.tween_property(_ring, "modulate:a", 0.0, 0.3)

## Brasas de passada da Caipora: emissor nos pés, ligado pelo _process enquanto
## o ator anda (exploração/HUB). Global coords: as brasas ficam no chão andado.
func _add_foot_embers() -> void:
	var tex := _reference_texture(get_parent())
	if tex == null:
		return
	var foot_y := tex.get_size().y * 0.5 - 6.0
	_foot = CPUParticles2D.new()
	_foot.name = "FootEmbers"
	_foot.amount = maxi(1, int(8.0 * _ambient_scale(get_parent())))
	_foot.lifetime = 0.6
	_foot.local_coords = false
	_foot.emitting = false
	_foot.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_foot.emission_rect_extents = Vector2(6.0, 2.0)
	_foot.position = Vector2(0.0, foot_y)
	_foot.gravity = Vector2(0, -20)
	_foot.initial_velocity_min = 2.0
	_foot.initial_velocity_max = 8.0
	_foot.scale_amount_min = 1.0
	_foot.scale_amount_max = 2.0
	_foot.color = _overbright(_color)
	_foot.color_ramp = _fade_ramp(_overbright(_color))
	_foot.material = Constants.ADDITIVE_MATERIAL
	add_child(_foot)

func _start_light_pulse() -> void:
	if _light == null:
		return
	# Pulso dessincronizado (padrão dos fátuos do santuário).
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_light, "energy",
		Constants.RIM_LIGHT_ENERGY * 1.35, 1.1).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_light, "energy",
		Constants.RIM_LIGHT_ENERGY * 0.7, 1.1).set_trans(Tween.TRANS_SINE)

# ─── Emissores ───────────────────────────────────────────────────────────────

## Brasas do contorno: contínuas, morrendo para fora da silhueta.
static func _build_dust(edge: Dictionary, col: Color, intensity: float,
		ps: float) -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.name = "RimDust"
	dust.amount = maxi(1, int((Constants.RIM_DUST_BASE_AMOUNT + 8.0 * intensity) * ps))
	dust.lifetime = 0.8
	dust.local_coords = false
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	dust.emission_points = edge["points"]
	dust.emission_normals = edge["normals"]
	dust.spread = Constants.RIM_SPREAD_DEG
	dust.gravity = Vector2.ZERO
	# Rápido o bastante para ESCAPAR da silhueta: brasa que morre em cima da
	# juba laranja é invisível — o contorno vive no breu ao redor.
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 22.0 + 8.0 * intensity
	dust.scale_amount_min = 1.4
	dust.scale_amount_max = 3.0
	dust.color = _overbright(col)
	dust.color_ramp = _fade_ramp(_overbright(col))
	dust.material = Constants.ADDITIVE_MATERIAL
	dust.emitting = true
	return dust

## Faíscas raras subindo da silhueta (acento, só na protagonista tier >= 3).
static func _build_sparks(edge: Dictionary, col: Color, intensity: float,
		ps: float) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.name = "RimSparks"
	sparks.amount = maxi(1, int((2.0 + 2.0 * intensity) * ps))
	sparks.lifetime = 0.5
	sparks.local_coords = false
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	sparks.emission_points = edge["points"]
	sparks.emission_normals = edge["normals"]
	sparks.spread = 12.0
	sparks.gravity = Vector2(0, -30)
	sparks.initial_velocity_min = 14.0
	sparks.initial_velocity_max = 30.0
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.1
	sparks.color = col
	sparks.color_ramp = _fade_ramp(col)
	sparks.material = Constants.ADDITIVE_MATERIAL
	sparks.emitting = true
	return sparks

## Halo volumétrico: bloom fake — quads da textura radial do ForestLight (256px;
## scale_amount 0.08–0.18 = blobs de ~20–45px) nascendo na silhueta, alpha baixo.
## Global coords: no movimento o hálito de luz fica para trás (esteira).
static func _build_halo(edge: Dictionary, col: Color, ps: float) -> CPUParticles2D:
	var halo := CPUParticles2D.new()
	halo.name = "RimHalo"
	halo.texture = ForestLight.LIGHT_TEXTURE
	halo.amount = maxi(1, int(Constants.RIM_HALO_AMOUNT * ps))
	halo.lifetime = 1.6
	halo.local_coords = false
	halo.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	halo.emission_points = edge["points"]
	halo.emission_normals = edge["normals"]
	halo.spread = 180.0
	halo.gravity = Vector2.ZERO
	halo.initial_velocity_min = 2.0
	halo.initial_velocity_max = 6.0
	halo.scale_amount_min = 0.08
	halo.scale_amount_max = 0.18
	var glow := _overbright(col)
	glow.a = Constants.RIM_HALO_ALPHA
	halo.color = glow
	halo.color_ramp = _fade_ramp(glow)
	halo.material = Constants.ADDITIVE_MATERIAL
	halo.emitting = true
	return halo

## Luz do ator: poça pulsante na cor do rim — o "neon" que fura a noite.
static func _build_light(col: Color, light_scale: float) -> PointLight2D:
	var lscale := light_scale if light_scale > 0.0 else Constants.RIM_LIGHT_SCALE
	var light := ForestLight.make(col.lerp(Color.WHITE, Constants.RIM_LIGHT_WHITEN),
		Constants.RIM_LIGHT_ENERGY, lscale)
	light.name = "RimLight"
	return light

## Explosão one-shot de brasas da silhueta (flare do PERFEITO/crítico).
static func _build_burst(edge: Dictionary, col: Color, ps: float) -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.name = "RimBurst"
	burst.amount = maxi(1, int(24.0 * ps))
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.emitting = false
	burst.local_coords = false
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS
	burst.emission_points = edge["points"]
	burst.emission_normals = edge["normals"]
	burst.spread = 20.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 110.0
	burst.scale_amount_min = 1.4
	burst.scale_amount_max = 2.8
	burst.color = _overbright(col)
	burst.color_ramp = _fade_ramp(_overbright(col))
	burst.material = Constants.ADDITIVE_MATERIAL
	return burst

## Anel de choque do flare: 1 Sprite2D aditivo com tween de escala+fade (1 draw
## call) — nasce invisível e só aparece no flare().
static func _build_ring(col: Color) -> Sprite2D:
	var ring := Sprite2D.new()
	ring.name = "ShockRing"
	ring.texture = ForestLight.LIGHT_TEXTURE
	ring.material = Constants.ADDITIVE_MATERIAL
	ring.modulate = Color(col.r, col.g, col.b, 0.0)
	ring.scale = Vector2.ONE * Constants.RIM_RING_SCALE_START
	ring.z_index = 1
	return ring

## Neon: empurra o RGB acima de 1.0 para o blend aditivo estourar no escuro.
static func _overbright(col: Color) -> Color:
	return Color(col.r * Constants.RIM_GLOW_BOOST, col.g * Constants.RIM_GLOW_BOOST,
		col.b * Constants.RIM_GLOW_BOOST, col.a)

static func _fade_ramp(col: Color) -> Gradient:
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, col)
	ramp.add_point(1.0, Color(col.r, col.g, col.b, 0.0))
	return ramp

## Escala ambiente do device (2x em HD via Quality.heavy).
static func _ambient_scale(node: Node) -> float:
	var vp := node.get_viewport() if node != null else null
	if vp == null:
		return Quality.heavy()
	return Constants.ambient_amount_scale(vp.get_visible_rect().size)

# ─── Silhueta ────────────────────────────────────────────────────────────────

## Frame de referência: idle frame 0 (as poses duram ~0.2-0.5s e o smear das
## partículas cobre a diferença — mesmo racional do FuriaVisual).
static func _reference_texture(sprite: Node) -> Texture2D:
	if sprite is AnimatedSprite2D:
		var frames := (sprite as AnimatedSprite2D).sprite_frames
		if frames == null:
			return null
		var anim: StringName = &"idle"
		if not frames.has_animation(anim):
			var names := frames.get_animation_names()
			if names.is_empty():
				return null
			anim = names[0]
		if frames.get_frame_count(anim) < 1:
			return null
		return frames.get_frame_texture(anim, 0)
	if sprite is Sprite2D:
		return (sprite as Sprite2D).texture
	return null

static func _sprite_offset(sprite: Node2D) -> Vector2:
	if sprite is AnimatedSprite2D:
		return (sprite as AnimatedSprite2D).offset
	if sprite is Sprite2D:
		return (sprite as Sprite2D).offset
	return Vector2.ZERO

## Extrai a borda da silhueta em coords locais CENTRADAS na textura + normal
## (ponto − centro) normalizada. Cacheado por resource_path (fallback RID).
static func _edge_data(tex: Texture2D) -> Dictionary:
	var key := tex.resource_path
	if key.is_empty():
		key = str(tex.get_rid().get_id())
	if _edge_cache.has(key):
		return _edge_cache[key]
	var points := PackedVector2Array()
	var normals := PackedVector2Array()
	var img := _texture_image(tex)
	if img != null:
		var size := img.get_size()
		var center := Vector2(size) * 0.5
		for y in range(0, size.y, EDGE_STEP):
			for x in range(0, size.x, EDGE_STEP):
				if img.get_pixel(x, y).a <= EDGE_ALPHA:
					continue
				if not _has_transparent_neighbor(img, x, y, size):
					continue
				var p := Vector2(x + 0.5, y + 0.5) - center
				points.append(p)
				normals.append(p.normalized() if p.length() > 0.01 else Vector2.UP)
		if points.size() > MAX_POINTS:
			# Subamostra uniforme: um break simples deixaria a base do sprite nua.
			var pruned_points := PackedVector2Array()
			var pruned_normals := PackedVector2Array()
			var stride := float(points.size()) / float(MAX_POINTS)
			for i in range(MAX_POINTS):
				var idx := int(i * stride)
				pruned_points.append(points[idx])
				pruned_normals.append(normals[idx])
			points = pruned_points
			normals = pruned_normals
	var data := {"points": points, "normals": normals}
	_edge_cache[key] = data
	return data

static func _texture_image(tex: Texture2D) -> Image:
	# AtlasTexture: get_image() devolveria o atlas INTEIRO — recortar a region.
	# (Defensivo: os SpriteFrames atuais usam PNGs individuais.)
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		if at.atlas == null:
			return null
		var full := at.atlas.get_image()
		if full == null:
			return null
		if full.is_compressed():
			full.decompress()
		return full.get_region(Rect2i(at.region))
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	return img

static func _has_transparent_neighbor(img: Image, x: int, y: int, size: Vector2i) -> bool:
	# A borda da textura conta como transparente (silhueta encostada no limite).
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx := x + off.x
		var ny := y + off.y
		if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y:
			return true
		if img.get_pixel(nx, ny).a <= EDGE_ALPHA:
			return true
	return false
