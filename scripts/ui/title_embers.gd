class_name TitleEmbers
extends Node2D

## Brasas/cinzas ascendentes da abertura. Reusa o padrão de AmbientLife: CPUParticles2D
## (NUNCA GPUParticles2D — export web é gl_compatibility) com CanvasItemMaterial aditivo
## e color_ramp âmbar que acende/apaga ao longo da vida. Sobem da base do viewport.

# ─── Exports ───────────────────────────────────────
@export var layer_z: int = -60
## Contagem em tela grande; telas de telefone pagam metade via
## Constants.particle_amount_scale (web/Android fraco seguem leves).
@export var ember_count: int = 80

# ─── State ─────────────────────────────────────────
var _vp_w: float = 1280.0
var _vp_h: float = 720.0

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_vp_w = vp.x
	_vp_h = vp.y
	z_index = layer_z
	_spawn_embers()

# ─── Private helpers ───────────────────────────────
func _spawn_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.amount = maxi(1, int(ember_count * Constants.particle_amount_scale(Vector2(_vp_w, _vp_h))))
	embers.lifetime = 5.0
	embers.preprocess = 5.0  # já espalhadas ao iniciar
	embers.position = Vector2(_vp_w * 0.5, _vp_h)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(_vp_w * 0.5, 24.0)
	embers.direction = Vector2(0, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(0, -10.0)  # sobem (leve)
	embers.initial_velocity_min = 22.0
	embers.initial_velocity_max = 60.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.5
	embers.color_ramp = _ember_ramp()
	# Blend aditivo: a brasa realmente brilha sobre o fogo.
	embers.material = Constants.ADDITIVE_MATERIAL
	add_child(embers)

## Acende (âmbar quente) e apaga ao longo da vida.
func _ember_ramp() -> Gradient:
	var amber := Constants.COLOR_AMBER
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(amber.r, amber.g, amber.b, 0.0))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(amber.r, amber.g, amber.b, 0.0))
	grad.add_point(0.2, Color(1.0, 0.5, 0.1, 0.9))
	grad.add_point(0.5, Color(amber.r, amber.g, amber.b, 0.65))
	return grad
