extends SceneTree

## Captura dev-only do rastro de fogo do Boitatá (modo HD): brasas contínuas
## do corpo + ghost frames no bote. Precisa de DISPLAY (receita Xvfb, AGENTS.md
## #1). A cena boitata.tscn é carregada em RUNTIME (frame 1) — a cadeia de
## scripts referencia autoloads por identificador e não compila em preload sob
## `-s` (gotcha #14). Duas capturas: meio do bote (_mid) e brasas assentadas.
## Uso: xvfb-run ... godot --resolution 960x540 --path . \
##     -s scripts/tools/preview_boitata_trail.gd -- --out=/tmp/boitata_trail.png

var _out: String = "/tmp/boitata_trail.png"
var _frames: int = 0
var _boitata: Node2D = null

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		Quality._set_for_test(true)
		_build_scene()
	# Deixa o EmberTrail encher (lifetime 0.9s) antes de disparar o bote.
	if _frames == 70:
		_boitata.call("_play_attack_lunge")
	if _frames == 74:
		_capture(_out.get_basename() + "_mid.png")
	if _frames >= 110:
		_capture(_out)
		print("[preview] saved ", _out)
		return true
	return false

func _capture(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	# Recorte 3x ao redor da serpente: o stretch expand encolhe o mundo na janela.
	var vp: Vector2 = Vector2(root.get_visible_rect().size)
	var factor: Vector2 = Vector2(img.get_width(), img.get_height()) / vp
	var rect := Rect2(_boitata.position - Vector2(220, 140), Vector2(360, 240))
	rect = Rect2(rect.position * factor, rect.size * factor).intersection(
		Rect2(0, 0, img.get_width(), img.get_height()))
	var crop := img.get_region(Rect2i(rect))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(path)

func _build_scene() -> void:
	var vp: Vector2 = Vector2(root.get_visible_rect().size)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.04)
	bg.size = vp
	root.add_child(bg)

	_boitata = (load("res://scenes/arena/boitata.tscn") as PackedScene).instantiate()
	_boitata.position = Vector2(vp.x * 0.62, vp.y * 0.55)
	root.add_child(_boitata)
