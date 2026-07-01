extends SceneTree

## Captura dev-only do HUD unificado (HudHeader). Precisa de DISPLAY (Xvfb serve).
## Renderiza o header em um dos modos, com as placas serrilhadas flutuantes.
## Uso: xvfb-run -a godot --path . --resolution 393x852 \
##     -s scripts/tools/preview_hud.gd -- --mode=explore --out=/tmp/hud.png
##   --mode: explore | combat | combat_boss | camp

var _out: String = "/tmp/hud.png"
var _mode: String = "explore"
var _frames: int = 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--mode="):
			_mode = arg.substr("--mode=".length())

func _process(_delta: float) -> bool:
	# Frame 1: autoloads já rodaram _ready (gotcha #14) — seguro configurar o estado aqui.
	_frames += 1
	if _frames == 1:
		var gs: Node = root.get_node("GameState")
		gs.caipora_max_hp = 10.0
		gs.caipora_current_hp = 7.0
		var header := HudHeader.new()
		root.add_child(header)
		match _mode:
			"combat", "combat_boss":
				header.set_mode(HudHeader.Mode.COMBAT)
				var boss: bool = _mode == "combat_boss"
				var emax: float = 36.0 if boss else 8.0
				header.setup_enemy(emax, boss, "Curupira" if boss else "Caçador")
				header.set_enemy_health(emax * 0.55, emax)
			"camp":
				header.set_mode(HudHeader.Mode.CAMP)
				header.set_currency(12)
			_:
				header.set_mode(HudHeader.Mode.EXPLORATION)
				header.set_currency(12)
		header.set_player_health(7.0, 10.0)
	if _frames >= 14:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
