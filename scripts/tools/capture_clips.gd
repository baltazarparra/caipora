extends SceneTree

## Captura dev-only de CLIPES do jogo real para a landing page (site/). Roda a
## cena de verdade sob DISPLAY (WSLg :0 — não precisa de Xvfb), amostra N frames
## do viewport e monta uma TIRA horizontal de uma linha (frame0|frame1|...|frameN)
## que o site anima com CSS steps(N). Sem ffmpeg, 100% reproduzível.
##
## Uso:
##   ~/.local/bin/godot --path . --resolution 480x270 \
##     -s scripts/tools/capture_clips.gd -- --clip=combat \
##     --out=site/assets/clips/combat_strip.png
##
## Args (-- depois do nome do script):
##   --clip=combat|explore|boss   o que capturar (default combat)
##   --out=<png>                  tira de saída (default p/ combat)
##   --frames=N                   nº de células amostradas (default 30)
##   --sample=S                   captura 1 a cada S frames de render (default 5 ~12fps)
##   --warmup=F                   frames a pular antes de amostrar (pula o loader)
##
## Saídas: <out> (tira), <out sem ext>_poster.png (1ª célula), e atualiza
## <dir>/clips.json com { clip: {frames, cell_w, cell_h} } para o CSS/JS.
##
## NÃO usa GameState.change_screen (passa por SceneTransition/fade que sujaria os
## frames): instancia a cena direto. Seta run state e sandbox de save no FRAME 1
## (autoloads só rodam _ready depois do _initialize — gotcha #14).

var _clip: String = "combat"
var _out: String = "site/assets/clips/combat_strip.png"
var _target_frames: int = 30
var _sample: int = 5
var _warmup: int = -1  # -1 = default por clipe

var _frames: int = 0
var _scene: Node = null
var _arena_timing: Node = null
var _pressed_window: bool = false
var _captured: Array[Image] = []
var _cell: Vector2i = Vector2i.ZERO
const _WALK_DIRS: Array[String] = ["ui_right", "ui_down", "ui_left", "ui_up"]
var _walk_held: String = ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="):
			_clip = arg.substr("--clip=".length())
		elif arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--frames="):
			_target_frames = maxi(2, int(arg.substr("--frames=".length())))
		elif arg.begins_with("--sample="):
			_sample = maxi(1, int(arg.substr("--sample=".length())))
		elif arg.begins_with("--warmup="):
			_warmup = int(arg.substr("--warmup=".length()))


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_setup()
		return false

	_drive_inputs()

	var since: int = _frames - _effective_warmup()
	if since > 0 and since % _sample == 0:
		_grab_frame()
		if _captured.size() >= _target_frames:
			_build_strip()
			print("[capture] %s: %d frames -> %s" % [_clip, _captured.size(), _out])
			return true
	# Trava de segurança: nunca rodar pra sempre.
	if _frames > _effective_warmup() + _target_frames * _sample + 600:
		if _captured.size() >= 2:
			_build_strip()
			print("[capture] %s: parcial %d frames -> %s" % [_clip, _captured.size(), _out])
		else:
			push_error("[capture] sem frames suficientes")
		return true
	return false


func _effective_warmup() -> int:
	if _warmup >= 0:
		return _warmup
	# Combate/chefe têm o loader de intro (~2s). Exploração entra mais rápido.
	return 30 if _clip == "explore" else 165


# ─── Setup (frame 1) ───────────────────────────────────────────────
func _setup() -> void:
	var meta: Node = root.get_node("MetaProgression")
	meta.SAVE_PATH = "user://capture_sandbox.json"  # nunca o save do dev

	var gs: Node = root.get_node("GameState")
	gs.active_phase = 1
	# Caipora "invencível" durante a captura: o clipe é loop, ninguém pode morrer
	# (morte dispara game-over/teardown + fade que arruína o fim da tira).
	gs.caipora_max_hp = 9999.0
	gs.caipora_current_hp = 9999.0

	match _clip:
		"combat":
			# Inimigo invencível e inofensivo: o clipe é loop, ninguém pode morrer
			# (morte dispara teardown + troca de cena e arruína a captura).
			_override_enemy("cacador", 1)
			gs.active_combat_is_boss = false
			_scene = _instantiate("res://scenes/arena/arena.tscn")
		"boss":
			_override_enemy("mula", 1)
			gs.active_combat_is_boss = true
			gs.next_enemy_scene = (load("res://scenes/arena/mula.tscn") as PackedScene)
			_scene = _instantiate("res://scenes/arena/arena.tscn")
		"explore":
			_scene = _instantiate("res://scenes/exploration/exploration.tscn")
		_:
			push_error("[capture] clip desconhecido: " + _clip)
			quit(1)
			return
	root.add_child(_scene)
	if _scene.has_node("TimingSystem"):
		_arena_timing = _scene.get_node("TimingSystem")


func _override_enemy(id: String, phase: int) -> void:
	var rc: Node = root.get_node_or_null("RemoteConfig")
	if rc != null and rc.has_method("_set_overrides_for_test"):
		rc._set_overrides_for_test({
			"%s@%d" % [id, phase]: {"hp": 9999, "damage": 1},
		})


func _instantiate(path: String) -> Node:
	return (load(path) as PackedScene).instantiate()


# ─── Inputs ────────────────────────────────────────────────────────
func _drive_inputs() -> void:
	if _frames <= _effective_warmup() - 20:
		# Durante o warmup do explore, dispensa qualquer diálogo de intro.
		if _clip == "explore" and _frames % 12 == 0:
			_tap("ui_accept")
		return
	match _clip:
		"combat":
			_drive_combat()
		"explore":
			# Exploração lê o movimento por POLLING (Input.is_action_pressed em
			# caipora.gd:62) — precisa MANTER a ação apertada, não um tap de 1 frame.
			# Troca de direção a cada ~16 frames pra não congelar contra parede.
			if _frames % 16 == 0:
				if _walk_held != "":
					Input.action_release(_walk_held)
				_walk_held = _WALK_DIRS[(_frames / 16) % _WALK_DIRS.size()]
				Input.action_press(_walk_held)
		"boss":
			pass  # só observa o loop idle->windup (ameaça)


## Aperta ui_up na zona perfeita da janela -> crítico/contra real (VFX + shake).
func _drive_combat() -> void:
	if _arena_timing == null or not _arena_timing.is_open():
		_pressed_window = false
		return
	var p: float = _arena_timing._window_progress
	if not _pressed_window and p >= 0.45 and p <= 0.6:
		_tap("ui_up")
		_pressed_window = true


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


# ─── Captura + montagem ────────────────────────────────────────────
func _grab_frame() -> void:
	var img: Image = root.get_texture().get_image()
	if _cell == Vector2i.ZERO:
		_cell = Vector2i(img.get_width(), img.get_height())
	if img.get_width() != _cell.x or img.get_height() != _cell.y:
		img.resize(_cell.x, _cell.y, Image.INTERPOLATE_LANCZOS)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	_captured.append(img)


func _build_strip() -> void:
	var n: int = _captured.size()
	var strip := Image.create(_cell.x * n, _cell.y, false, Image.FORMAT_RGBA8)
	for i in n:
		var src: Image = _captured[i]
		strip.blit_rect(src, Rect2i(0, 0, _cell.x, _cell.y), Vector2i(_cell.x * i, 0))
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
	data[_clip] = {
		"file": _out.get_file(),
		"poster": _out.get_basename().get_file() + "_poster.png",
		"frames": n,
		"cell_w": _cell.x,
		"cell_h": _cell.y,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()


## Resolve caminho do projeto (site/...) para absoluto via res://.
func _abs(p: String) -> String:
	if p.begins_with("/") or p.begins_with("res://") or p.begins_with("user://"):
		return ProjectSettings.globalize_path(p) if p.begins_with("res://") else p
	return ProjectSettings.globalize_path("res://" + p)
