extends SceneTree

## Ferramenta de captura visual (dev only). Renderiza uma cena com janela real
## (precisa de DISPLAY, ex. WSLg :0) por N frames e salva um PNG. Reutilizada para
## validar mudanças visuais (UI, mapa, atmosfera, personagens).
##
## Uso:
##   DISPLAY=:0 godot --path . -s scripts/tools/screenshot.gd -- \
##       --scene=res://scenes/ui/main_menu.tscn --out=/tmp/shot.png [--frames=30] [--phase=N] [--screen=HUB]
##
## --phase=N seta GameState.active_phase antes de instanciar — cenas de arena e
## exploração derivam estilo/dificuldade da fase ativa, não do arquivo .tscn.
## --screen=NOME (chave de SignalBus.Screen, ex. HUB) seta GameState.current_screen para
## o UiRoot compor o header da tela — instanciar direto não passa por change_screen.

var _out: String = "/tmp/caipora_shot.png"
var _target_frames: int = 30
var _frames: int = 0

func _initialize() -> void:
	var scene_path: String = "res://scenes/ui/main_menu.tscn"
	var phase: int = 0
	var screen_key: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.substr("--scene=".length())
		elif arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--frames="):
			_target_frames = int(arg.substr("--frames=".length()))
		elif arg.begins_with("--phase="):
			phase = int(arg.substr("--phase=".length()))
		elif arg.begins_with("--screen="):
			screen_key = arg.substr("--screen=".length())
	if phase > 0:
		root.get_node("GameState").active_phase = phase
	if not screen_key.is_empty():
		# Sem referência compile-time a autoloads (gotcha #14): enum lido do script do bus.
		# Setar antes do _ready dos autoloads: o UiRoot lê current_screen em _apply_screen.
		var bus := root.get_node("SignalBus")
		var screens: Dictionary = bus.get_script().get_script_constant_map().get("Screen", {})
		if screens.has(screen_key):
			root.get_node("GameState").current_screen = screens[screen_key]
	var packed: PackedScene = load(scene_path)
	root.add_child(packed.instantiate())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= _target_frames:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("[screenshot] saved ", _out)
		return true  # quit
	return false
