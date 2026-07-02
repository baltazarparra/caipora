extends SceneTree

## Captura dev-only da coroa orbital HD das miniaturas do mapa: boss (Boitatá),
## convertido (Saci) e comum (bruxo) lado a lado — o comum NÃO pode ter coroa
## nem luz. Receita Xvfb do AGENTS.md #1; estado no frame 1 e map_enemy.gd
## carregado em RUNTIME (a cadeia MapEnemy→ParticleRim referencia MetaProgression
## e não compila em preload sob -s — gotcha #14).
## Uso: xvfb-run ... godot --resolution 720x360 --path . \
##     -s scripts/tools/preview_boss_crown.gd -- --out=/tmp/crown.png

var _out: String = "/tmp/boss_crown.png"
var _frames: int = 0
var _center := Vector2.ZERO

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		Quality._set_for_test(true)
		_build_scene()
	# Coroa tem lifetime 1.8s: deixar a órbita dar pelo menos meia volta.
	if _frames >= 110:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		var vp: Vector2 = Vector2(root.get_visible_rect().size)
		var factor: Vector2 = Vector2(img.get_width(), img.get_height()) / vp
		var rect := Rect2(_center - Vector2(260, 110), Vector2(520, 220))
		rect = Rect2(rect.position * factor, rect.size * factor).intersection(
			Rect2(0, 0, img.get_width(), img.get_height()))
		var crop := img.get_region(Rect2i(rect))
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.get_basename() + "_crop.png")
		print("[preview] saved ", _out)
		return true
	return false

func _build_scene() -> void:
	var vp: Vector2 = Vector2(root.get_visible_rect().size)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.045, 0.04)
	bg.size = vp
	root.add_child(bg)
	# Penumbra do mapa: sem ela a RimLight não tem escuridão para devolver cor.
	var modulate := CanvasModulate.new()
	modulate.color = Color(0.55, 0.5, 0.45)
	root.add_child(modulate)

	_center = Vector2(vp.x * 0.5, vp.y * 0.52)
	# [rótulo, boss, boss_type, enemy_type]
	var specs: Array = [
		["boss boitatá", true, "boitata", ""],
		["convertido saci", false, "", "saci"],
		["comum bruxo", false, "", "bruxo"],
	]
	var map_enemy_script: GDScript = load("res://scripts/exploration/map_enemy.gd")
	for i in range(specs.size()):
		var spec: Array = specs[i]
		var holder := Node2D.new()
		holder.position = _center + Vector2((i - 1) * vp.x * 0.28, 0.0)
		root.add_child(holder)
		var enemy: Node2D = map_enemy_script.new()
		holder.add_child(enemy)
		enemy.setup("pv_%d" % i, Vector2i.ZERO, bool(spec[1]), String(spec[2]),
			Vector2i(-1, -1), String(spec[3]))
		enemy.position = Vector2.ZERO  # ignora o grid: fica no holder
		var label := Label.new()
		label.text = String(spec[0])
		label.add_theme_font_size_override("font_size", 22)
		label.position = holder.position + Vector2(-60, 70)
		root.add_child(label)
