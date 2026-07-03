extends SceneTree

## Captura dev-only das telas de TEXTO de chefe: apresentação (BossIntroScreen)
## e diálogo (DialogueScreen), em qualquer resolução — valida nome/fala longos
## (ex. "JESUÍTA BANDEIRANTE CATEQUIZADOR") em phone retrato e paisagem.
##
## Uso (receita KI-020 para WSLg):
##   XDG_DATA_HOME=/tmp/caipora-godot-data LIBGL_ALWAYS_SOFTWARE=1 WAYLAND_DISPLAY= \
##   xvfb-run -a godot --display-driver x11 --rendering-driver opengl3 \
##       --rendering-method gl_compatibility --resolution 393x852 --path . \
##       -s scripts/tools/preview_boss_text.gd -- \
##       --mode=intro|dialogue --boss=jesuita|mula --out=/tmp/x.png [--line=0]
##
## Padrão de -s (gotcha #14): nada de identificador de autoload/classe global no
## corpo — tudo via load() e root.get_node(); montagem no frame 1 do _process.

const BOSS_DATA := {
	"jesuita": {
		"name_key": "boss.jesuita.name",
		"line_keys": ["dlg.jesuita.intro.1", "dlg.jesuita.intro.2"],
		"frames": "res://assets/sprites/jesuita_sprite_frames.tres",
		"aura": Color(0.42, 0.34, 0.10, 0.75),
		"color": Color(0.92, 0.82, 0.45, 1.0),
	},
	"mula": {
		"name_key": "boss.mula.name",
		"line_keys": ["dlg.mula.1", "dlg.mula.2"],
		"frames": "res://assets/sprites/mula_sprite_frames.tres",
		"aura": Color(0.55, 0.12, 0.02, 0.72),
		"color": Color(1.0, 0.50, 0.10, 1.0),
	},
}
const COLOR_CAIPORA := Color(0.55, 0.90, 0.60, 1.0)

var _out: String = "/tmp/boss_text.png"
var _mode: String = "intro"
var _boss: String = "jesuita"
var _line: int = 0
var _frames: int = 0
var _target: int = -1  # -1 = automático: intro ~pós-reveal, diálogo curto

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--mode="):
			_mode = arg.substr("--mode=".length())
		elif arg.begins_with("--boss="):
			_boss = arg.substr("--boss=".length())
		elif arg.begins_with("--line="):
			_line = int(arg.substr("--line=".length()))
		elif arg.begins_with("--frames="):
			_target = int(arg.substr("--frames=".length()))

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()
	if _frames >= _target:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		print("[preview] saved ", _out)
		return true
	return false

func _build() -> void:
	var data: Dictionary = BOSS_DATA[_boss]
	var lang: Node = root.get_node("Lang")
	var boss_name: String = lang.t(StringName(data["name_key"]))
	if _mode == "intro":
		if _target < 0:
			_target = 170  # pop (0.5s) + barras (0.28s) + reveal (~1.9s) já concluídos
		var intro: CanvasLayer = (load("res://scenes/ui/boss_intro_screen.tscn") \
			as PackedScene).instantiate()
		root.add_child(intro)
		intro.start(boss_name, load(data["frames"]) as SpriteFrames,
			data["aura"], data["color"])
		return
	if _target < 0:
		_target = 30  # diálogo é estático: captura curta
	var line_key: String = data["line_keys"][clampi(_line, 0, data["line_keys"].size() - 1)]
	var speaker: String = boss_name if _line == 0 else lang.t(&"dialogue.caipora")
	var lines: Array[Dictionary] = [
		{"speaker": speaker, "text": lang.t(StringName(line_key))},
	]
	var dlg: CanvasLayer = (load("res://scenes/ui/dialogue_screen.tscn") \
		as PackedScene).instantiate()
	root.add_child(dlg)
	dlg.start(boss_name, lines, lang.t(&"dialogue.caipora"), COLOR_CAIPORA, data["color"])
