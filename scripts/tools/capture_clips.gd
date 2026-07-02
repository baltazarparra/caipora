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
##   --clip=combat|furia|boss     o que capturar (default combat)
##   --boss=<id>                  boss do clip `boss` (mula|boitata|curupira|saci|jesuita; default mula)
##   --out=<png>                  tira de saída (default p/ combat)
##   --frames=N                   nº de células amostradas (default 30)
##   --sample=S                   captura 1 a cada S frames de render (default 5 ~12fps)
##   --warmup=F                   frames a pular antes de amostrar (pula o loader)
##   --gain=G                     ganho de exposição p/ legibilidade web (default 2.0)
##
## Saídas: <out> (tira), <out sem ext>_poster.png (1ª célula), e atualiza
## <dir>/clips.json com { clip: {frames, cell_w, cell_h} } para o CSS/JS.
##
## NÃO usa GameState.change_screen (passa por SceneTransition/fade que sujaria os
## frames): instancia a cena direto. Seta run state e sandbox de save no FRAME 1
## (autoloads só rodam _ready depois do _initialize — gotcha #14).

var _clip: String = "combat"
## Boss do clip `boss` (--boss=): qualquer chefe redesenhado. Default preserva
## o comportamento histórico (Mula). Fase certa por id para stats/backdrop.
var _boss_id: String = "mula"
const _BOSS_PHASE := {"mula": 1, "boitata": 2, "curupira": 3, "saci": 4, "jesuita": 5}
var _out: String = "site/assets/clips/combat_strip.png"
var _target_frames: int = 30
var _sample: int = 5
var _warmup: int = -1  # -1 = default por clipe
## Multiplicação de exposição aplicada ao frame capturado: o clipe da landing
## roda na web e o jogo é MUITO escuro (Atmosphere/vignette). Multiplicar mantém
## o preto puro preto (0×ganho=0) e levanta só a Caipora/VFX iluminados.
var _gain: float = 2.0

var _frames: int = 0
var _scene: Node = null
var _arena_timing: Node = null
var _pressed_window: bool = false
var _captured: Array[Image] = []
var _cell: Vector2i = Vector2i.ZERO
## Finisher: marca o frame do golpe final (quando _combat_over vira true e o
## slow-mo da garra esmagando o coração começa) para amostrar SÓ a partir dele.
var _death_seen: bool = false
var _death_frame: int = 0


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
		elif arg.begins_with("--gain="):
			_gain = maxf(1.0, arg.substr("--gain=".length()).to_float())
		elif arg.begins_with("--boss="):
			_boss_id = arg.substr("--boss=".length())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_setup()
		return false

	_drive_inputs()

	if _clip == "finisher":
		return _process_finisher()

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
	# Todos os clipes usam a arena, que tem o loader de intro (~2s) antes do 1º turno.
	return 165


## Captura do GOLPE FINAL: dirige o combate até o inimigo morrer e, no instante da
## morte (arena seta `_combat_over` antes do slow-mo), passa a amostrar. O finisher
## roda em câmera lenta (Engine.time_scale 0.25 por 1.4s REAL ~84 frames a 60fps),
## então o sample padrão 3 enche ~26 células com a garra esmagando o coração. Para
## ANTES do fade de vitória (que sujaria as últimas células).
func _process_finisher() -> bool:
	if not _death_seen:
		var combat_over: bool = _scene != null and bool(_scene.get("_combat_over"))
		if _frames > _effective_warmup() and combat_over:
			_death_seen = true
			_death_frame = _frames
		elif _frames > _effective_warmup() + 4000:
			push_error("[capture] finisher: inimigo não morreu a tempo")
			quit(1)
			return true
		return false

	var since: int = _frames - _death_frame
	if since > 0 and since % _sample == 0:
		_grab_frame()
		if _captured.size() >= _target_frames:
			_build_strip()
			print("[capture] finisher: %d frames -> %s" % [_captured.size(), _out])
			return true
	# Trava: encerra antes do fade de vitória mesmo com poucos frames.
	if since > _target_frames * _sample + 30:
		if _captured.size() >= 2:
			_build_strip()
			print("[capture] finisher: parcial %d frames -> %s" % [_captured.size(), _out])
		else:
			push_error("[capture] finisher: sem frames")
		return true
	return false


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
			var phase: int = _BOSS_PHASE.get(_boss_id, 1)
			gs.active_phase = phase
			_override_enemy(_boss_id, phase)
			gs.active_combat_is_boss = true
			gs.next_enemy_scene = (load("res://scenes/arena/%s.tscn" % _boss_id) as PackedScene)
			_scene = _instantiate("res://scenes/arena/arena.tscn")
		"finisher":
			# Inimigo com POUCO HP: morre no golpe perfeito e dispara o FINISHER — a
			# garra preta esmagando o coração em câmera lenta (PRD do golpe final).
			# Dano 1, mas a Caipora está invencível (9999): o foco é o clímax.
			_override_enemy("cacador", 1, 6)
			gs.active_combat_is_boss = false
			_scene = _instantiate("res://scenes/arena/arena.tscn")
		"furia":
			# Fúria MÁXIMA (tier 6 — aura de fogo). Os upgrades têm de estar setados
			# ANTES do add_child: o arena anexa a aura em _apply_furia_visual durante
			# _spawn_caipora (no _ready, disparado pelo add_child abaixo). Padrão de
			# preview_furia_max.gd. SAVE_PATH já foi p/ sandbox: não toca o save real.
			for key in meta.FURIA_KEYS:
				meta.upgrades[key] = 1
			meta.has_chama = true  # chama viva sobre a aura
			_override_enemy("cacador", 1)
			gs.active_combat_is_boss = false
			_scene = _instantiate("res://scenes/arena/arena.tscn")
		_:
			push_error("[capture] clip desconhecido: " + _clip)
			quit(1)
			return
	root.add_child(_scene)
	if _scene.has_node("TimingSystem"):
		_arena_timing = _scene.get_node("TimingSystem")


func _override_enemy(id: String, phase: int, hp: int = 9999) -> void:
	var rc: Node = root.get_node_or_null("RemoteConfig")
	if rc != null and rc.has_method("_set_overrides_for_test"):
		rc._set_overrides_for_test({
			"%s@%d" % [id, phase]: {"hp": hp, "damage": 1},
		})


func _instantiate(path: String) -> Node:
	return (load(path) as PackedScene).instantiate()


# ─── Inputs ────────────────────────────────────────────────────────
func _drive_inputs() -> void:
	if _frames <= _effective_warmup() - 20:
		return
	# combat, furia e boss usam o MESMO driver: tocar a ação esperada na zona perfeita
	# acerta tanto o crítico do turno do jogador quanto a esquiva da defesa.
	_drive_combat()


## Aperta a AÇÃO ESPERADA (ui_up no ataque; ui_down/ui_up na defesa, inclusive a
## sequência do chefe) na zona perfeita real -> crítico/esquiva+contra (VFX + shake).
func _drive_combat() -> void:
	if _arena_timing == null or not _arena_timing.is_open():
		_pressed_window = false
		return
	var p: float = _arena_timing._window_progress
	# Zona perfeita real = Constants.TIMING_PERFECT_START/END (0.65..0.85).
	if not _pressed_window and p >= 0.66 and p <= 0.84:
		_tap(_arena_timing._expected_action)
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
	if _gain != 1.0:
		_apply_gain(img)
	_captured.append(img)


## Multiplica RGB pelo ganho (preto continua preto, ação iluminada aparece). Alpha
## intocado. Loop de pixel no estilo de preview_furia_max.gd — custo trivial p/ dev.
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
