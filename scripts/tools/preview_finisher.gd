extends SceneTree

## Captura dev-only do GOLPE FINAL ("esmagar o coração") para a landing page.
## Encena o clímax FORA do combate ao vivo (que tem HUD e enquadra o corpo inteiro,
## com a garra minúscula): monta o palco REAL da arena (ArenaBackdrop por fase), o
## inimigo morrendo e o VFX REAL do finisher (assets/effects/finisher_vfx_sheet.png)
## AMPLIADO sobre o peito, sem HUD, com câmera fechada no coração. Passo de frame
## determinístico (1 célula por frame de render) estica os 5 quadros da garra em N
## células + brilho/tremor sutil → tira que o site anima em loop (mesmo contrato de
## capture_clips.gd / clips.json). Precisa de DISPLAY (WSLg :0).
##
## Uso:
##   DISPLAY=:0 ~/.local/bin/godot --path . --resolution 270x480 \
##     -s scripts/tools/preview_finisher.gd -- \
##     --out=site/assets/clips/finisher_strip.png [--frames=26] [--gain=1.8] [--phase=1]

const FINISHER_PATH := "res://assets/effects/finisher_vfx_sheet.png"
const ENEMY_PATH := "res://assets/sprites/enemy_idle.png"
const SHADOW_PATH := "res://assets/sprites/shadow_oval.png"
# Carregado em runtime (NÃO preload): arena_backdrop.gd referencia o autoload
# GameState, que só é identificador global depois que os autoloads sobem — em
# `-s` o preload compilaria cedo demais e quebraria (igual capture_clips.gd).
const ARENA_BACKDROP_PATH := "res://scripts/arena/arena_backdrop.gd"

const VFX_FRAMES := 5
const VFX_CELL := 64
# Centro do peito (coordenadas de mundo do palco da arena: STAGE em 320,225).
const CHEST := Vector2(320.0, 236.0)
const WARMUP := 24  # deixa backdrop/névoa/brasas assentarem antes de amostrar

var _out: String = "site/assets/clips/finisher_strip.png"
var _frames: int = 26
var _gain: float = 1.8
var _phase: int = 1

var _world: Node2D
var _cam: Camera2D
var _enemy: Sprite2D
var _vfx: Sprite2D
var _glow: Sprite2D
var _blood: CPUParticles2D

var _captured: Array[Image] = []
var _cell: Vector2i = Vector2i.ZERO
var _f: int = 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--frames="):
			_frames = maxi(2, int(arg.substr("--frames=".length())))
		elif arg.begins_with("--gain="):
			_gain = maxf(1.0, arg.substr("--gain=".length()).to_float())
		elif arg.begins_with("--phase="):
			_phase = clampi(int(arg.substr("--phase=".length())), 1, 5)


func _process(_delta: float) -> bool:
	_f += 1
	# Frame 1: monta tudo (autoloads só rodaram _ready agora — gotcha #14, setar
	# GameState.active_phase aqui, não em _initialize, ou o backdrop pega a fase errada).
	if _f == 1:
		_setup()
		_apply_moment(0)
		return false
	if _f <= WARMUP:
		_apply_moment(0)  # mantém a 1ª pose enquanto o palco assenta
		return false

	# Cada frame: captura a pose JÁ renderizada (setada no frame anterior), então
	# avança para a próxima célula. Determinístico, sem depender de timing de anim.
	_grab_frame()
	if _captured.size() >= _frames:
		_build_strip()
		print("[preview] finisher: %d frames -> %s" % [_captured.size(), _out])
		return true
	_apply_moment(_captured.size())
	return false


# ─── Setup ─────────────────────────────────────────
func _setup() -> void:
	var gs: Node = root.get_node("GameState")
	gs.active_phase = _phase

	_world = Node2D.new()
	root.add_child(_world)

	var backdrop: Node = (load(ARENA_BACKDROP_PATH) as GDScript).new()
	_world.add_child(backdrop)

	# Sombra e inimigo (o "caçador" comum) tombando sob a garra.
	var shadow := Sprite2D.new()
	shadow.texture = load(SHADOW_PATH)
	shadow.modulate = Constants.COLOR_ACTOR_SHADOW
	shadow.position = Vector2(320.0, 396.0)
	shadow.scale = Vector2(5.2, 4.0)
	_world.add_child(shadow)

	_enemy = Sprite2D.new()
	_enemy.texture = load(ENEMY_PATH)
	_enemy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy.position = Vector2(320.0, 300.0)
	_enemy.scale = Vector2(2.6, 2.6)
	_world.add_child(_enemy)

	# Clarão de sangue por trás da garra (aditivo) — pulsa no aperto.
	_glow = Sprite2D.new()
	_glow.texture = load(SHADOW_PATH)  # oval suave reaproveitada como halo
	_glow.material = Constants.ADDITIVE_MATERIAL
	_glow.position = CHEST
	_glow.modulate = Color(0.7, 0.05, 0.02, 0.0)
	_glow.scale = Vector2(7.0, 6.0)
	_world.add_child(_glow)

	# VFX REAL do finisher, AMPLIADO: a garra preta esmagando o coração.
	_vfx = Sprite2D.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(FINISHER_PATH)
	atlas.region = Rect2(0, 0, VFX_CELL, VFX_CELL)
	_vfx.texture = atlas
	_vfx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vfx.position = CHEST
	_vfx.scale = Vector2(3.6, 3.6)
	_world.add_child(_vfx)

	# Respingo de sangue contínuo (vida entre as células do loop).
	_blood = CPUParticles2D.new()
	_blood.position = CHEST + Vector2(0.0, 6.0)
	_blood.amount = 16
	_blood.lifetime = 0.9
	_blood.preprocess = 0.9
	_blood.direction = Vector2(0, 1)
	_blood.spread = 60.0
	_blood.gravity = Vector2(0, 420.0)
	_blood.initial_velocity_min = 40.0
	_blood.initial_velocity_max = 130.0
	_blood.scale_amount_min = 2.0
	_blood.scale_amount_max = 4.0
	_blood.color = Constants.COLOR_BLOOD
	_world.add_child(_blood)

	_cam = Camera2D.new()
	# Fechado no peito: a garra/coração domina o quadro, sobrando só uma faixa de
	# céu/lua no topo e o tronco do inimigo abaixo (sem chão vazio).
	_cam.position = CHEST + Vector2(0.0, 22.0)
	_cam.zoom = Vector2(2.05, 2.05)
	_world.add_child(_cam)
	_cam.make_current()


# ─── Momento (pose determinística da célula k) ─────
func _apply_moment(k: int) -> void:
	var t: float = float(k) / float(maxi(_frames - 1, 1))  # 0..1
	# Qual dos 5 quadros da garra: cravar → esmagar → drenar.
	var fi: int = clampi(int(t * float(VFX_FRAMES)), 0, VFX_FRAMES - 1)
	(_vfx.texture as AtlasTexture).region = Rect2(fi * VFX_CELL, 0, VFX_CELL, VFX_CELL)

	# Inimigo escurece conforme drena (vivo → casca esvaziada).
	var dark: float = lerpf(0.92, 0.34, t)
	_enemy.modulate = Color(dark, dark * 0.96, dark * 0.96)

	# Clarão pulsa no aperto (pico no meio do esmagamento) e tremor sutil de impacto.
	var pulse: float = sin(t * PI)
	_glow.modulate.a = 0.55 * pulse
	_glow.scale = Vector2(6.0 + 2.0 * pulse, 5.0 + 1.8 * pulse)
	var shake: float = 3.0 * pulse
	_cam.position = CHEST + Vector2(0.0, 10.0) + Vector2(
		sin(t * 47.0) * shake, cos(t * 39.0) * shake)


# ─── Captura + montagem (mesmo formato de capture_clips.gd) ─────
func _grab_frame() -> void:
	var img: Image = root.get_texture().get_image()
	if _cell == Vector2i.ZERO:
		_cell = Vector2i(img.get_width(), img.get_height())
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if _gain != 1.0:
		_apply_gain(img)
	_captured.append(img)


func _apply_gain(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			c.r = minf(c.r * _gain, 1.0)
			c.g = minf(c.g * _gain, 1.0)
			c.b = minf(c.b * _gain, 1.0)
			img.set_pixel(x, y, c)


func _build_strip() -> void:
	var n: int = _captured.size()
	var strip := Image.create(_cell.x * n, _cell.y, false, Image.FORMAT_RGBA8)
	for i in n:
		strip.blit_rect(_captured[i], Rect2i(0, 0, _cell.x, _cell.y), Vector2i(_cell.x * i, 0))
	DirAccess.make_dir_recursive_absolute(_abs(_out.get_base_dir()))
	strip.save_png(_abs(_out))
	_captured[0].save_png(_abs(_out.get_basename() + "_poster.png"))
	_write_manifest(n)


func _write_manifest(n: int) -> void:
	var path: String = _abs(_out.get_base_dir().path_join("clips.json"))
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var prev: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if prev is Dictionary:
			data = prev
	data["finisher"] = {
		"file": _out.get_file(),
		"poster": _out.get_basename().get_file() + "_poster.png",
		"frames": n,
		"cell_w": _cell.x,
		"cell_h": _cell.y,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


func _abs(p: String) -> String:
	if p.begins_with("/") or p.begins_with("user://"):
		return p
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	return ProjectSettings.globalize_path("res://" + p)
