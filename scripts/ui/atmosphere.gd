class_name Atmosphere
extends CanvasLayer

## Overlay de atmosfera (vinheta + grão de filme) por cima da cena. Espelha o
## padrão do DoomFire: um CanvasLayer com script que constrói tudo em código,
## sem material embutido em .tscn. Fica num layer alto para cobrir o jogo.
##
## Color grading (gradient map por fase, Constants.GRADING_*): vive numa
## CanvasLayer FILHA em layer 0 — captura só o mundo (acima do canvas implícito,
## abaixo do fog 10, da vinheta 50 e do HUD 52), então a UI não é graduada.
## O grade grosso por CanvasModulate continua sendo da cena; a LUT refina.
## A/B em device: ?grade=1/?grade=0 na URL sobrepõe GRADING_ON_WEB (só web) —
## afordância permanente de medição (PRD-performance-refactor-web, Frente B).

# ─── Constants ─────────────────────────────────────
const SHADER_PATH: String = "res://assets/shaders/atmosphere.gdshader"
const GRADE_SHADER_PATH: String = "res://shaders/gradient_map.gdshader"
const OVERLAY_LAYER: int = 50

# ─── State ─────────────────────────────────────────
var _rect: ColorRect

## Cache do override de URL (?grade=): -3 = ainda não lido; -1 = sem override;
## 0/1 = forçado. Estático porque Atmosphere é instanciado por tela e a URL
## não muda dentro do page load (evita JavaScriptBridge.eval repetido).
static var _url_grade_cache: int = -3

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = OVERLAY_LAYER

	if _grading_active():
		_setup_grading()

	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)

	_rect = ColorRect.new()
	_rect.material = mat
	_rect.color = Color(1, 1, 1, 1)  # cor base ignorada; o shader define a saída
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

# ─── Color grading ─────────────────────────────────
func _grading_active() -> bool:
	if not Constants.GRADING_ENABLED:
		return false
	# No web o SCREEN_TEXTURE custa caro em gl_compatibility: GRADING_ON_WEB é o
	# default e ?grade=1/?grade=0 na URL força para o A/B de medição em device.
	if OS.has_feature("web"):
		var override: int = _url_grade_override()
		if override != -1:
			return override == 1
		if not Constants.GRADING_ON_WEB:
			return false
	return true


static func _url_grade_override() -> int:
	if _url_grade_cache == -3:
		_url_grade_cache = -1
		if OS.has_feature("web"):
			var search: Variant = JavaScriptBridge.eval("location.search", true)
			if search is String:
				_url_grade_cache = _parse_grade_param(search as String)
	return _url_grade_cache


## Núcleo puro e testável (padrão do finado Quality._parse_hd_param):
## "grade=1" → 1, "grade=0" → 0, ausente → -1.
static func _parse_grade_param(search: String) -> int:
	for pair: String in search.trim_prefix("?").split("&"):
		if pair == "grade=1":
			return 1
		if pair == "grade=0":
			return 0
	return -1

func _setup_grading() -> void:
	var lut_path := "res://assets/sprites/grade_p%d.png" % clampi(GameState.active_phase, 1, 5)
	if not ResourceLoader.exists(lut_path):
		return
	var mat := ShaderMaterial.new()
	mat.shader = load(GRADE_SHADER_PATH)
	mat.set_shader_parameter("grade_lut", load(lut_path))
	mat.set_shader_parameter("mix_amount", Constants.GRADING_MIX)

	var grade_rect := ColorRect.new()
	grade_rect.material = mat
	grade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 0
	grade_layer.add_child(grade_rect)
	add_child(grade_layer)
