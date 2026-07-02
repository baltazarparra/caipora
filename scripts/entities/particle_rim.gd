class_name ParticleRim
extends Node2D

## Contorno de partículas neon dos atores (modo HD): brasas nascem NA silhueta
## do sprite e respiram PARA FORA — CPUParticles2D com DIRECTED_POINTS sobre os
## pontos de borda extraídos do alpha do frame de referência (idle), com normais
## apontando do centro para fora. `local_coords = false` faz as partículas
## descolarem em lunges/movimento: micro-rastro de graça.
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

## Anexa o rim ao sprite (AnimatedSprite2D da arena/exploração ou Sprite2D do
## mapa). Idempotente: free() do anterior permite refresh mid-run (ex.: CHAMA).
## `spark_color` transparente = sem o emissor de faíscas (inimigos usam só dust).
static func attach_to(sprite: Node2D, rim_color: Color, intensity: float = 1.0,
		spark_color: Color = Color.TRANSPARENT) -> void:
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
	rim.z_index = 2
	sprite.add_child(rim)

	var vp := sprite.get_viewport()
	var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) \
		if vp != null else 1.0
	rim.add_child(_build_dust(edge, rim_color, intensity, ps))
	if spark_color.a > 0.0:
		rim.add_child(_build_sparks(edge, spark_color, intensity, ps))

	# Respiro lento do contorno (par do pulso do FuriaVisual): vivo, não estático.
	var pulse := rim.create_tween().set_loops()
	pulse.tween_property(rim, "modulate:a", 0.75, 1.4)
	pulse.tween_property(rim, "modulate:a", 1.0, 1.4)

## Rim da protagonista: laranja da juba dominante, esquentando com o tier de
## Fúria; com CHAMA vira brasa clara. Faíscas verdes do cristal só como acento
## raro (tier >= 3, pouquíssimas) — o verde pertence ao cristal (lei da marca).
static func attach_caipora(sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var tier := FuriaVisual._max_furia_tier()
	var heat := float(tier) / 6.0
	var rim_color := Constants.COLOR_JUBA.lerp(Constants.COLOR_CHAMA_HOT, heat)
	if MetaProgression.has_chama:
		rim_color = Constants.COLOR_CHAMA_HOT.lerp(Constants.COLOR_CHAMA_CORE, 0.35)
	var spark := Constants.COLOR_CRYSTAL_GLOW if tier >= 3 else Color.TRANSPARENT
	attach_to(sprite, rim_color, 1.0 + heat, spark)

# ─── Emissores ───────────────────────────────────────────────────────────────

## Brasas do contorno: contínuas, lentas, morrendo para fora da silhueta.
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
	dust.initial_velocity_max = 16.0 + 6.0 * intensity
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 2.4
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
	sparks.initial_velocity_min = 10.0
	sparks.initial_velocity_max = 22.0
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.1
	sparks.color = col
	sparks.color_ramp = _fade_ramp(col)
	sparks.material = Constants.ADDITIVE_MATERIAL
	sparks.emitting = true
	return sparks

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

# ─── Silhueta ────────────────────────────────────────────────────────────────

## Frame de referência: idle frame 0 (as poses duram ~0.2-0.5s e o smear das
## partículas cobre a diferença — mesmo racional do FuriaVisual).
static func _reference_texture(sprite: Node2D) -> Texture2D:
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
