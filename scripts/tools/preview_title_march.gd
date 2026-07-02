extends SceneTree

## Captura dev-only da marcha do menu: a Caipora atravessando a tela inicial com
## os encantados libertados (bando intercalado, TitleCompanion). Gate visual —
## flips corretos (todos encaram a DIREITA), escalas proporcionais ao camp,
## sombras no chão. Precisa de DISPLAY (Xvfb, receita KI-020).
## Uso: xvfb-run -a godot --path . --resolution 1280x720 \
##     -s scripts/tools/preview_title_march.gd -- --freed=4 --out=/tmp/march.png
##   --freed=N  liberta os encantados das fases 1..N (0 = Caipora sozinha)
##   --frames=M frames antes da captura (default 660 ≈ 11s — bando no centro)

var _out: String = "/tmp/title_march.png"
var _freed: int = 4
var _wait: int = 660
var _frames: int = 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--freed="):
			_freed = clampi(int(arg.substr("--freed=".length())), 0, 4)
		elif arg.begins_with("--frames="):
			_wait = int(arg.substr("--frames=".length()))

func _process(_delta: float) -> bool:
	_frames += 1
	# Frame 1, NÃO _initialize (gotcha #14): os autoloads só rodam _ready depois
	# do _initialize — o load_progress() do MetaProgression sobrescreveria o
	# estado do preview. Só em memória: o menu não persiste save.
	if _frames == 1:
		var meta: Node = root.get_node("MetaProgression")
		var freed: Array[int] = []
		for phase: int in range(1, _freed + 1):
			freed.append(phase)
		meta.freed_bosses = freed
		var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
	if _frames >= _wait:
		root.get_texture().get_image().save_png(_out)
		print("[preview] saved ", _out)
		return true
	return false
