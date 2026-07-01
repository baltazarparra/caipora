extends SceneTree

## Captura dev-only do HUD (precisa de DISPLAY; Xvfb serve). Renderiza o HUD em modo
## exploração (2x tátil no retrato: mudo + Terra Rara) ou em modo combate (header
## espelhado jogador × adversário). Salva o frame inteiro em --out.
## Uso: xvfb-run -a godot --path . --resolution 393x852 \
##     -s scripts/tools/preview_hud.gd -- --mode=combat --out=/tmp/hud.png
##   --mode: explore | combat | combat_boss

const HUD_SCENE := "res://scenes/ui/hud.tscn"

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
	_frames += 1
	if _frames == 1:
		var gs: Node = root.get_node("GameState")
		gs.caipora_max_hp = 10.0
		gs.caipora_current_hp = 7.0
		var combat: bool = _mode == "combat" or _mode == "combat_boss"
		gs.active_combat_is_boss = _mode == "combat_boss"
		var hud: Node = (load(HUD_SCENE) as PackedScene).instantiate()
		hud.show_enemy_hp = combat
		root.add_child(hud)
		var bus: Node = root.get_node("SignalBus")
		bus.caipora_health_changed.emit(7.0, 10.0)
		if combat:
			var emax: float = 36.0 if _mode == "combat_boss" else 8.0
			bus.enemy_health_changed.emit(emax * 0.55, emax)
		else:
			bus.fragment_gained.emit(12.0, 12.0)
	if _frames >= 14:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
