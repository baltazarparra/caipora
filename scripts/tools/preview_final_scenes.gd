extends SceneTree

## Captura dev-only das cenas finais (escolha "Poupar ele?" e os dois endings).
## Instancia a cena pedida fora do fluxo de telas e salva um frame após --frames
## (deixa fade-in/typewriter/letterbox assentarem). Precisa de DISPLAY (Xvfb).
## Com --choose=sim|nao na cena da escolha, aciona a resposta no frame 80 e a
## captura tardia mostra o ENDING/ENDING_SACRIFICE real pós-transição (e2e).
## Uso: xvfb-run -a godot --path . --resolution 852x393 \
##     -s scripts/tools/preview_final_scenes.gd -- \
##     --scene=res://scenes/ui/final_choice_screen.tscn --out=/tmp/cena.png \
##     [--frames=340] [--choose=sim|nao]

const CHOOSE_FRAME: int = 80

var _out: String = "/tmp/final_scene.png"
var _scene: String = "res://scenes/ui/final_choice_screen.tscn"
var _wait: int = 340
var _choose: String = ""
## Ganho de exposição (igual capture_clips.gd): a cena roda na web e o jogo é muito
## escuro (Atmosphere/vinheta). 1.0 = sem ganho (mantém o frame cru do jogo).
var _gain: float = 1.0
var _frames: int = 0
var _inst: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--scene="):
			_scene = arg.substr("--scene=".length())
		elif arg.begins_with("--frames="):
			_wait = int(arg.substr("--frames=".length()))
		elif arg.begins_with("--choose="):
			_choose = arg.substr("--choose=".length())
		elif arg.begins_with("--gain="):
			_gain = maxf(1.0, arg.substr("--gain=".length()).to_float())
	var packed: PackedScene = load(_scene)
	_inst = packed.instantiate()
	root.add_child(_inst)
	if _choose != "":
		# A troca real de cena entra como current_scene; a instância manual sai
		# de cena no mesmo frame para não sobrepor o ending capturado.
		var bus: Node = root.get_node("SignalBus")
		bus.screen_changed.connect(func(_s: int) -> void: _inst.queue_free())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == CHOOSE_FRAME and _choose != "" and is_instance_valid(_inst):
		_inst._enable_buttons()
		_inst._choose(_choose == "sim")
	if _frames >= _wait:
		var img: Image = root.get_texture().get_image()
		if _gain != 1.0:
			_apply_gain(img)
		img.save_png(_out)
		print("[preview] saved ", _out)
		return true
	return false

## Multiplica RGB pelo ganho (preto continua preto; o que está iluminado sobe).
func _apply_gain(img: Image) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			c.r = minf(c.r * _gain, 1.0)
			c.g = minf(c.g * _gain, 1.0)
			c.b = minf(c.b * _gain, 1.0)
			img.set_pixel(x, y, c)
