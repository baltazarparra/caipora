class_name FuriaVisual
extends Node2D

## Manifestação visual da Fúria da Caipora por tier (forca..forca_6), ancorada
## no CRISTAL do cajado (embutido no sprite 96×96 — ver gen_caipora.py).
## Cada tier mantém sua identidade de lore via partículas (fumaça, aura, breu,
## osso, carne) + um glow verde-cristal que escala. Sem sprite de arma separado:
## o cajado é parte do corpo da protagonista.
##
## Componente reutilizável: usado na exploração (Caipora) e na arena (ArenaManager).
## CPUParticles2D obrigatório (export web em GL Compatibility, sem GPUParticles).

const ForestLight := preload("res://scripts/exploration/forest_light.gd")

## Posição do cristal em idle no espaço local do AnimatedSprite2D (centrado):
## staff_tip (66.5, 23.5) do _rig em gen_caipora.py menos o centro (48, 48).
## O cajado se MOVE por pose (windup/strike); as poses duram ~0.2-0.5s e o
## smear das partículas cobre isso — não rastrear por frame.
const CRYSTAL_ANCHOR := Vector2(18.5, -24.5)

## Centro do corpo em coords locais do FuriaVisual: como visual.position =
## CRYSTAL_ANCHOR + sprite_offset e o centro da textura no espaço do pai é o
## sprite_offset, o offset cancela e o corpo fica exatamente em -CRYSTAL_ANCHOR.
## (Travado por test_anchor_follows_sprite_offset.)
const BODY_CENTER_LOCAL := Vector2(-18.5, 24.5)
## Queda da base da chama até os "pés" da Caipora (ajuste visual, 96px de altura).
const FIRE_FOOT_DROP := 26.0

var _base_x: float = 0.0

func _process(_delta: float) -> void:
	# flip_h do AnimatedSprite2D não espelha filhos: espelhar o anchor à mão
	# (exploração anda para a esquerda).
	var sprite := get_parent() as AnimatedSprite2D
	if sprite != null:
		position.x = -_base_x if sprite.flip_h else _base_x

## Retorna o tier máximo de Fúria desbloqueado (1–6), ou 0 se nenhum.
static func _max_furia_tier() -> int:
	var tier := 0
	for i in range(MetaProgression.FURIA_KEYS.size()):
		if MetaProgression.get_upgrade_level(MetaProgression.FURIA_KEYS[i]) >= 1:
			tier = i + 1
	return tier

## Anexa o visual da Fúria ao `parent` (AnimatedSprite2D), ancorado no cristal.
## Idempotente: remove um FuriaVisual anterior antes de recriar — permite
## refresh mid-run (ex.: CHAMA conquistada em pleno combate).
## No-op se nenhum tier de Fúria estiver desbloqueado.
static func attach_to(parent: Node2D) -> void:
	var previous := parent.get_node_or_null("FuriaVisual")
	if previous != null:
		# free() imediato: queue_free deixaria o nome ocupado neste frame e o
		# novo nó seria renomeado, quebrando lookups por "FuriaVisual".
		previous.free()

	var tier := _max_furia_tier()
	if tier < 1:
		return

	var visual := FuriaVisual.new()
	visual.name = "FuriaVisual"
	var sprite_offset := Vector2.ZERO
	if parent is AnimatedSprite2D:
		sprite_offset = (parent as AnimatedSprite2D).offset
	visual.position = CRYSTAL_ANCHOR + sprite_offset
	visual._base_x = visual.position.x
	visual.z_index = 1
	parent.add_child(visual)

	# Glow do cristal: presente em todo tier, escala com a Fúria.
	visual.add_child(_build_crystal_glow(tier))

	# Partículas de lore escalonadas por tier
	if tier >= 2:
		visual.add_child(_build_smoke(tier))
	if tier >= 3:
		visual.add_child(_build_gold_aura(tier))
	if tier >= 4:
		visual.add_child(_build_residue(tier))
	if tier >= 5:
		visual.add_child(_build_bone_fragments(tier))
	if tier >= 6:
		visual.add_child(_build_flesh_spines(tier))
		# Fúria máxima: aura de fogo envolvendo a silhueta (escala por device).
		var vp := parent.get_viewport()
		var ps: float = Constants.particle_amount_scale(vp.get_visible_rect().size) if vp != null else 1.0
		_build_max_fire(visual, ps)

	# CHAMA: chama viva somada às partículas do tier
	if MetaProgression.has_chama:
		visual.add_child(_build_flame(tier))

	# Respiro sutil: pulso lento esverdeado no modulate (filhos herdam)
	var pulse := visual.create_tween().set_loops()
	var peak := Color(0.96, 1.12, 1.02) if tier < 6 else Color(1.0, 1.18, 1.05)
	pulse.tween_property(visual, "modulate", peak, 1.6)
	pulse.tween_property(visual, "modulate", Color(1.0, 1.0, 1.0), 1.6)


# ─── Partículas escalonadas ──────────────────────────────────────────────────

## Glow do cristal (T1+): motas verdes subindo do cristal, intensidade por tier.
static func _build_crystal_glow(tier: int) -> CPUParticles2D:
	var glow_p := CPUParticles2D.new()
	glow_p.name = "CrystalGlow"
	glow_p.z_index = 1
	glow_p.amount = 6 + tier * 2          # T1=8, … T6=18
	glow_p.lifetime = 0.9 + tier * 0.05
	glow_p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glow_p.emission_sphere_radius = 4.0 + tier
	glow_p.direction = Vector2(0, -1)
	glow_p.spread = 180.0
	glow_p.gravity = Vector2(0, -6 - tier)
	glow_p.initial_velocity_min = 2.0
	glow_p.initial_velocity_max = 6.0 + tier
	glow_p.scale_amount_min = 1.0
	glow_p.scale_amount_max = 1.8 + tier * 0.2
	glow_p.color = Constants.COLOR_CRYSTAL
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Constants.COLOR_CRYSTAL_GLOW)
	ramp.add_point(0.5, Constants.COLOR_CRYSTAL)
	ramp.add_point(1.0, Color(Constants.COLOR_CRYSTAL.r, Constants.COLOR_CRYSTAL.g, Constants.COLOR_CRYSTAL.b, 0.0))
	glow_p.color_ramp = ramp
	glow_p.material = Constants.ADDITIVE_MATERIAL
	glow_p.emitting = true
	return glow_p


static func _build_smoke(tier: int) -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.position = Vector2(0, 2)
	smoke.z_index = -1
	smoke.amount = 4 + tier              # T2=6, T3=7, … T6=10
	smoke.lifetime = 1.4 + tier * 0.1
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(4 + tier * 0.5, 6 + tier)
	smoke.direction = Vector2(0, -1)
	smoke.spread = 20.0 + tier * 3.0
	smoke.gravity = Vector2(0, -14 - tier * 2)
	smoke.initial_velocity_min = 3.0
	smoke.initial_velocity_max = 8.0 + tier * 2.0
	smoke.scale_amount_min = 2.0
	smoke.scale_amount_max = 5.0 + tier * 0.8
	smoke.color = Constants.COLOR_SMOKE_DARK
	smoke.color_ramp = _smoke_ramp()
	smoke.emitting = true
	return smoke


static func _build_gold_aura(tier: int) -> CPUParticles2D:
	var aura := CPUParticles2D.new()
	aura.name = "GoldAura"
	aura.z_index = 1
	aura.amount = 8 + tier * 2           # T3=14, T4=16, … T6=20
	aura.lifetime = 1.2 + tier * 0.05
	aura.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	aura.emission_rect_extents = Vector2(5 + tier, 7 + tier)
	aura.direction = Vector2(0, -1)
	aura.spread = 30.0 + tier * 2.5
	aura.gravity = Vector2(0, -8 - tier)
	aura.initial_velocity_min = 5.0
	aura.initial_velocity_max = 12.0 + tier * 2.0
	aura.scale_amount_min = 1.2
	aura.scale_amount_max = 2.8 + tier * 0.5
	aura.color = Constants.COLOR_GOLD
	aura.color_ramp = _gold_ramp()
	aura.material = Constants.ADDITIVE_MATERIAL
	aura.emitting = true
	return aura


## Resíduos de breu/resina (T4+): pingam DO cristal (par das gotas embutidas
## no sprite), caindo lentamente.
static func _build_residue(tier: int) -> CPUParticles2D:
	var res := CPUParticles2D.new()
	res.name = "BreuResidue"
	res.position = Vector2(0, 4)
	res.z_index = -1
	res.amount = 6 + (tier - 3) * 3
	res.lifetime = 1.6
	res.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	res.emission_rect_extents = Vector2(5, 8)
	res.direction = Vector2(0, 1)
	res.spread = 45.0
	res.gravity = Vector2(0, 25)
	res.initial_velocity_min = 2.0
	res.initial_velocity_max = 8.0
	res.scale_amount_min = 1.5
	res.scale_amount_max = 3.5
	res.color = Color(0.18, 0.14, 0.08, 0.55)
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(0.18, 0.14, 0.08, 0.55))
	fade.add_point(1.0, Color(0.18, 0.14, 0.08, 0.0))
	res.color_ramp = fade
	res.emitting = true
	return res


## Fragmentos de osso/sangue seco (T5+): partículas pálidas/vermelhas.
static func _build_bone_fragments(tier: int) -> CPUParticles2D:
	var frag := CPUParticles2D.new()
	frag.name = "BoneFragments"
	frag.z_index = 1
	frag.amount = 8 + (tier - 4) * 4
	frag.lifetime = 1.0
	frag.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	frag.emission_rect_extents = Vector2(6, 9)
	frag.direction = Vector2(0, -1)
	frag.spread = 55.0
	frag.gravity = Vector2(0, -20)
	frag.initial_velocity_min = 6.0
	frag.initial_velocity_max = 18.0
	frag.scale_amount_min = 1.0
	frag.scale_amount_max = 2.5
	frag.color = Color(0.75, 0.55, 0.45, 0.7)
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(0.85, 0.65, 0.55, 0.75))
	ramp.add_point(0.5, Color(0.55, 0.25, 0.18, 0.5))
	ramp.add_point(1.0, Color(0.35, 0.12, 0.08, 0.0))
	frag.color_ramp = ramp
	frag.material = Constants.ADDITIVE_MATERIAL
	frag.emitting = true
	return frag


## Espinhos de carne viva (T6): partículas carmim escuras, pulsantes.
static func _build_flesh_spines(_tier: int) -> CPUParticles2D:
	var sp := CPUParticles2D.new()
	sp.name = "FleshSpines"
	sp.z_index = 2
	sp.amount = 10
	sp.lifetime = 0.9
	sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sp.emission_rect_extents = Vector2(7, 10)
	sp.direction = Vector2(0, -1)
	sp.spread = 25.0
	sp.gravity = Vector2(0, -35)
	sp.initial_velocity_min = 10.0
	sp.initial_velocity_max = 28.0
	sp.scale_amount_min = 1.5
	sp.scale_amount_max = 3.5
	sp.color = Color(0.72, 0.18, 0.18, 0.8)
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(0.92, 0.22, 0.22, 0.85))
	ramp.add_point(0.4, Color(0.68, 0.15, 0.15, 0.6))
	ramp.add_point(1.0, Color(0.25, 0.05, 0.05, 0.0))
	sp.color_ramp = ramp
	sp.material = Constants.ADDITIVE_MATERIAL
	sp.emitting = true
	return sp


## Chama viva da CHAMA (elemento fogo): sobe rápido, blend aditivo, gradiente quente.
## Escalona com o tier: quanto maior o tier, mais intensa a chama.
static func _build_flame(tier: int) -> CPUParticles2D:
	var flame := CPUParticles2D.new()
	flame.name = "ChamaFlame"
	flame.z_index = 1
	flame.amount = 10 + tier * 2       # T1=12, … T6=22
	flame.lifetime = 0.6 + tier * 0.03
	flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flame.emission_rect_extents = Vector2(4 + tier * 0.5, 6 + tier)
	flame.direction = Vector2(0, -1)
	flame.spread = 15.0 + tier * 2.0
	flame.gravity = Vector2(0, -40 - tier * 4)
	flame.initial_velocity_min = 12.0
	flame.initial_velocity_max = 28.0 + tier * 3.0
	flame.scale_amount_min = 1.8
	flame.scale_amount_max = 3.5 + tier * 0.4
	flame.color = Constants.COLOR_FIRE_HOT
	flame.color_ramp = _flame_ramp()
	flame.material = Constants.ADDITIVE_MATERIAL
	flame.emitting = true
	return flame


## Fúria máxima (T6): labareda quente envolvendo a silhueta (ATRÁS, z=-1, corpo
## legível por cima), brasas rápidas à frente e luz quente com flicker irregular.
## Reforça o read LARANJA da marca. Tudo CPUParticles2D + ADDITIVE_MATERIAL e
## escalado por device via `ps` (0.5 no celular). 1 luz por Caipora (custo baixo).
static func _build_max_fire(visual: Node2D, ps: float) -> void:
	# Labareda traseira: lambe a silhueta de baixo (pés) pra cima.
	var flame := CPUParticles2D.new()
	flame.name = "MaxFireFlame"
	flame.position = BODY_CENTER_LOCAL + Vector2(0, FIRE_FOOT_DROP)
	flame.z_index = -1
	flame.amount = maxi(1, int(16.0 * ps))
	flame.lifetime = 0.7
	flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flame.emission_rect_extents = Vector2(11, 12)
	flame.direction = Vector2(0, -1)
	flame.spread = 12.0
	flame.gravity = Vector2(0, -90)
	flame.initial_velocity_min = 16.0
	flame.initial_velocity_max = 38.0
	flame.scale_amount_min = 2.0
	flame.scale_amount_max = 4.5
	flame.color = Constants.COLOR_FIRE_HOT
	flame.color_ramp = _flame_ramp()
	flame.material = Constants.ADDITIVE_MATERIAL
	flame.emitting = true
	visual.add_child(flame)

	# Brasas: poucas, rápidas, subindo alto à frente do corpo.
	var embers := CPUParticles2D.new()
	embers.name = "MaxFireEmbers"
	embers.position = BODY_CENTER_LOCAL
	embers.z_index = 1
	embers.amount = maxi(1, int(7.0 * ps))
	embers.lifetime = 1.1
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(9, 12)
	embers.direction = Vector2(0, -1)
	embers.spread = 30.0
	embers.gravity = Vector2(0, -70)
	embers.initial_velocity_min = 22.0
	embers.initial_velocity_max = 52.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.2
	embers.color = Color(1.0, 0.6, 0.2, 0.9)
	embers.color_ramp = _max_ember_ramp()
	embers.material = Constants.ADDITIVE_MATERIAL
	embers.emitting = true
	visual.add_child(embers)

	# Luz quente pulsante (flicker irregular em 4 passos), centrada no corpo.
	var light := ForestLight.make(Constants.COLOR_FIRE_HOT, 0.9, 0.7)
	light.position = BODY_CENTER_LOCAL
	visual.add_child(light)
	var flicker := visual.create_tween().set_loops()
	flicker.tween_property(light, "energy", 1.05, 0.18).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(light, "energy", 0.72, 0.13).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(light, "energy", 0.95, 0.21).set_trans(Tween.TRANS_SINE)
	flicker.tween_property(light, "energy", 0.8, 0.16).set_trans(Tween.TRANS_SINE)


# ─── Ramps ───────────────────────────────────────────────────────────────────

static func _flame_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Constants.COLOR_FIRE_HOT)
	g.add_point(0.5, Constants.COLOR_FIRE_MID)
	g.add_point(1.0, Color(Constants.COLOR_FIRE_LOW.r, Constants.COLOR_FIRE_LOW.g, Constants.COLOR_FIRE_LOW.b, 0.0))
	return g


static func _max_ember_ramp() -> Gradient:
	var amber := Constants.COLOR_AMBER
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1.0, 0.6, 0.2, 0.9))
	g.add_point(1.0, Color(amber.r, amber.g, amber.b, 0.0))
	return g


static func _smoke_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(Constants.COLOR_SMOKE_DARK.r, Constants.COLOR_SMOKE_DARK.g, Constants.COLOR_SMOKE_DARK.b, 0.42))
	g.add_point(1.0, Color(Constants.COLOR_SMOKE_DARK.r, Constants.COLOR_SMOKE_DARK.g, Constants.COLOR_SMOKE_DARK.b, 0.0))
	return g


static func _gold_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Constants.COLOR_GOLD)
	g.add_point(0.55, Constants.COLOR_GOLD_DARK)
	g.add_point(1.0, Constants.COLOR_AURA_BUSTER_DARK)
	return g
