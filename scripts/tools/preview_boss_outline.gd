extends SceneTree

## Captura dev-only da legibilidade de contorno (risco de giz) dos chefes no mapa,
## lado a lado com a Caipora, sob o CanvasModulate de uma fase. Usa o caminho de
## código REAL (MapEnemy.setup + ActorContrast), não uma reconstrução.
## Uso: xvfb-run -a godot --path . --resolution 960x300 \
##     -s scripts/tools/preview_boss_outline.gd -- --out=/tmp/outline.png [--phase=2]

const BOSS_TYPES: Array[String] = ["mula", "boitata", "curupira", "saci", "jesuita"]
const PHASE_MODULATE := {
	1: Color(0.38, 0.42, 0.54),
	2: Color(0.72, 0.30, 0.10),
	3: Color(0.14, 0.26, 0.18),
}

var _out: String = "/tmp/outline.png"
var _phase: int = 2
var _frames: int = 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--phase="):
			_phase = int(arg.substr("--phase=".length()))

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_build()
	if _frames >= 30:
		var img: Image = root.get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(_out)
		print("[preview] saved ", _out)
		return true
	return false

func _build() -> void:
	var stage := Node2D.new()
	root.add_child(stage)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.06)
	bg.size = Vector2(2000, 2000)
	bg.position = Vector2(-1000, -1000)
	stage.add_child(bg)

	var mod := CanvasModulate.new()
	mod.color = PHASE_MODULATE.get(_phase, PHASE_MODULATE[2])
	stage.add_child(mod)

	# Caipora: mesma pilha visual de caipora.gd (skin + risco + luz frontal).
	var caipora := Node2D.new()
	caipora.position = Vector2(60, 90)
	stage.add_child(caipora)
	var anim := AnimatedSprite2D.new()
	# Frames default direto (sem CaiporaSkin: ele referencia MetaProgression por
	# identificador e não compila em contexto -s antes dos autoloads).
	anim.sprite_frames = load("res://assets/sprites/caipora_sprite_frames.tres")
	caipora.add_child(anim)
	anim.play("idle")
	ActorContrast.apply_outline(anim)
	ActorContrast.add_ground_shadow(caipora, Vector2(0.62, 0.22), Vector2(0.0, 2.0))
	ActorContrast.add_front_light(caipora, Vector2(0.0, -8.0), 0.7, 1.4)

	# Chefes: caminho real do mapa.
	var x := 140.0
	for boss_type in BOSS_TYPES:
		var enemy: MapEnemy = MapEnemy.new()
		stage.add_child(enemy)
		enemy.setup("preview_%s" % boss_type, Vector2i.ZERO, true, boss_type)
		enemy.position = Vector2(x, 90)
		x += 72.0

	var cam := Camera2D.new()
	cam.position = Vector2(260, 78)
	cam.zoom = Vector2(3.4, 3.4)
	stage.add_child(cam)
	cam.make_current()
