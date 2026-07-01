extends SceneTree

## Preview dev-only do painel de Opções aberto (chrome + espaçamento). Uso:
##   env -u WAYLAND_DISPLAY LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##     xvfb-run -a -s "-screen 0 1280x1400x24" ~/.local/bin/godot --path . \
##     --display-driver x11 --rendering-driver opengl3 --resolution 393x852 \
##     -s scripts/tools/preview_options.gd -- --out=/tmp/options.png
##
## Gotcha #14: script de ENTRADA (-s) — nada de class_name/autoload em compile-time;
## tudo via load() no frame 1.

const PANEL_SCRIPT := "res://scripts/ui/options_panel.gd"

var _out: String = "/tmp/options.png"
var _frames: int = 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var panel = (load(PANEL_SCRIPT) as GDScript).new()
		root.add_child(panel)
		panel.open()
	if _frames >= 14:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
