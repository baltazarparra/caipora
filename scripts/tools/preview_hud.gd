extends SceneTree

## Preview dev-only do HudHeader unificado (placas serrilhadas flutuantes). Precisa de um
## display + GL por software. Comando que funciona no WSL (evita wayland/d3d12):
##   env -u WAYLAND_DISPLAY LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe \
##     xvfb-run -a -s "-screen 0 1280x1400x24" ~/.local/bin/godot --path . \
##     --display-driver x11 --rendering-driver opengl3 --resolution 393x852 \
##     -s scripts/tools/preview_hud.gd -- --mode=explore --out=/tmp/hud.png
##   --mode: explore | combat | combat_boss | camp
##
## Gotcha #14: este é o script de ENTRADA (-s) — NÃO referenciar autoloads nem class_name
## em compile-time (só existem no frame 1). HudHeader é carregado via load(); modo é int.

const HEADER_SCRIPT := "res://scripts/ui/kit/hud_header.gd"
# Espelha HudHeader.Mode (sem referência de enum no compile do script de entrada).
const MODE_CAMP := 1
const MODE_EXPLORATION := 2
const MODE_COMBAT := 3

var _out: String = "/tmp/hud.png"
var _mode: String = "explore"
var _frames: int = 0
var _target_frames: int = 14

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--mode="):
			_mode = arg.substr("--mode=".length())
		elif arg.begins_with("--frames="):
			_target_frames = maxi(int(arg.substr("--frames=".length())), 2)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var gs = root.get_node("GameState")
		gs.caipora_max_hp = 10.0
		gs.caipora_current_hp = 7.0
		var header = (load(HEADER_SCRIPT) as GDScript).new()
		root.add_child(header)
		match _mode:
			"combat", "combat_boss":
				var boss: bool = _mode == "combat_boss"
				var emax: float = 36.0 if boss else 8.0
				header.set_mode(MODE_COMBAT)
				header.setup_enemy(emax, boss, "Curupira" if boss else "Caçador")
				header.set_enemy_health(emax * 0.55, emax)
			"camp":
				header.set_mode(MODE_CAMP)
				header.set_currency(12)
			_:
				header.set_mode(MODE_EXPLORATION)
				header.set_currency(12)
		header.set_player_health(7.0, 10.0)
	if _frames >= _target_frames:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
