extends SceneTree

## Captura dev-only do ParticleRim (modo HD) na Caipora em 4 estágios de
## evolução: tier 0, tier 3 (com faísca do cristal), tier 6 e CHAMA. Precisa de
## DISPLAY (receita Xvfb do AGENTS.md #1). particle_rim.gd é carregado em
## RUNTIME (load) porque attach_caipora referencia MetaProgression — preload
## quebraria com "Identifier not found" (gotcha #14).
## O estado do MetaProgression é mutado ENTRE os attaches (o rim lê o tier no
## momento do attach), então um processo captura os 4 estágios lado a lado.
## Layout em frações do visible_rect: o stretch canvas_items/expand do projeto
## faz o mundo visível ser MAIOR que a janela — coords absolutas encolhem tudo.
## Uso: xvfb-run ... godot --resolution 640x300 --path . \
##     -s scripts/tools/preview_particle_rim.gd -- --out=/tmp/rim.png

var _out: String = "/tmp/particle_rim.png"
var _frames: int = 0
var _crop_center := Vector2.ZERO

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Frame 1: autoloads já rodaram _ready() (gotcha #14).
		Quality._set_for_test(true)
		_build_scene()
	# Rim tem lifetime 0.7s: deixar o contorno encher antes de capturar.
	if _frames >= 70:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		# Recorte 3x no estágio CHAMA para inspecionar a borda de perto.
		var vp: Vector2 = Vector2(root.get_visible_rect().size)
		var factor: Vector2 = Vector2(img.get_width(), img.get_height()) / vp
		var rect := Rect2(_crop_center - Vector2(110, 140), Vector2(220, 280))
		rect = Rect2(rect.position * factor, rect.size * factor).intersection(
			Rect2(0, 0, img.get_width(), img.get_height()))
		var crop := img.get_region(Rect2i(rect))
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.get_basename() + "_crop.png")
		print("[preview] saved ", _out)
		return true
	return false

func _build_scene() -> void:
	var vp: Vector2 = Vector2(root.get_visible_rect().size)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.05)
	bg.size = vp
	root.add_child(bg)

	var particle_rim: GDScript = load("res://scripts/entities/particle_rim.gd")
	var meta: Node = root.get_node("MetaProgression")
	var furia_keys: Array = meta.FURIA_KEYS

	# [rótulo, tier de Fúria, chama]
	var stages: Array = [
		["tier 0", 0, false],
		["tier 3", 3, false],
		["tier 6", 6, false],
		["CHAMA", 6, true],
	]
	for i in range(stages.size()):
		var stage: Array = stages[i]
		for k in range(furia_keys.size()):
			if k < int(stage[1]):
				meta.upgrades[furia_keys[k]] = 1
			else:
				meta.upgrades.erase(furia_keys[k])
		meta.has_chama = bool(stage[2])

		var center := Node2D.new()
		center.position = Vector2(vp.x * (0.14 + 0.24 * i), vp.y * 0.5)
		root.add_child(center)
		var sprite := AnimatedSprite2D.new()
		sprite.offset = Vector2(0, -30)
		sprite.scale = Vector2(2.0, 2.0)
		var tex := load("res://assets/sprites/player_idle.png") as Texture2D
		if tex != null:
			var frames := SpriteFrames.new()
			frames.add_frame(&"default", tex)
			sprite.sprite_frames = frames
		center.add_child(sprite)
		# O rim lê MetaProgression AGORA — por isso o attach fica dentro do loop.
		particle_rim.attach_caipora(sprite)

		var label := Label.new()
		label.text = String(stage[0])
		label.add_theme_font_size_override("font_size", 28)
		label.position = center.position + Vector2(-45, 130)
		root.add_child(label)
		if i == stages.size() - 1:
			_crop_center = center.position
