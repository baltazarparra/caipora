extends SceneTree

## Captura dev-only da aura de Fúria MÁXIMA (tier 6) ao redor da Caipora. Precisa de
## DISPLAY (Xvfb ou WSLg :0). Reproduz o sprite de combate (AnimatedSprite2D idle,
## offset (0,-30), scale 1.2) sobre fundo escuro para ler o glow aditivo, força os 6
## tiers de Fúria via MetaProgression no frame 1 e salva o frame inteiro em --out.
## FuriaVisual é carregado em runtime (load), não preload: senão compila antes dos
## autoloads e quebra com "Identifier not found: MetaProgression" (gotcha #16).
## Uso: DISPLAY=:0 godot --path . --resolution 393x852 \
##     -s scripts/tools/preview_furia_max.gd -- --out=/tmp/furia_max.png

var _out: String = "/tmp/furia_max.png"
var _frames: int = 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Frame 1: autoloads já rodaram _ready(); setar a Fúria máxima (gotcha #16).
		var meta: Node = root.get_node("MetaProgression")
		for key in meta.FURIA_KEYS:
			meta.upgrades[key] = 1
		_build_scene()
	# Deixa as partículas preencherem o quadro antes de capturar.
	if _frames >= 40:
		var img: Image = root.get_texture().get_image()
		img.save_png(_out)
		# Recorte 3x centrado no corpo (196,460) para inspecionar a aura de perto.
		var vp: Vector2 = Vector2(root.get_visible_rect().size)
		var factor: Vector2 = Vector2(img.get_width(), img.get_height()) / vp
		var rect := Rect2(Vector2(196, 460) - Vector2(70, 90), Vector2(140, 180))
		rect = Rect2(rect.position * factor, rect.size * factor).intersection(
			Rect2(0, 0, img.get_width(), img.get_height()))
		var crop := img.get_region(Rect2i(rect))
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.get_basename() + "_crop.png")
		print("[preview] saved ", _out)
		return true
	return false

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.05)
	bg.size = Vector2(393, 852)
	root.add_child(bg)

	var center := Node2D.new()
	center.position = Vector2(196, 460)
	root.add_child(center)

	var sprite := AnimatedSprite2D.new()
	sprite.offset = Vector2(0, -30)
	sprite.scale = Vector2(1.2, 1.2)
	var tex := load("res://assets/sprites/player_idle.png") as Texture2D
	if tex != null:
		var frames := SpriteFrames.new()
		frames.add_frame(&"default", tex)
		sprite.sprite_frames = frames
	center.add_child(sprite)

	var furia_visual: GDScript = load("res://scripts/entities/furia_visual.gd")
	furia_visual.attach_to(sprite)
