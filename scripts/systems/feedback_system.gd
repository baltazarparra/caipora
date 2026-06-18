class_name FeedbackSystem
extends Node

const BLOOD_PARTICLES := preload("res://scenes/shared/blood_particles.tscn")
const CRITICAL_PARTICLES := preload("res://scenes/shared/critical_particles.tscn")
const DEATH_PARTICLES := preload("res://scenes/shared/death_particles.tscn")

# ─── VFX sprite sheets ─────────────────────────────
const HIT_VFX_PATH      := "res://assets/effects/hit_vfx_sheet.png"
const CRITICAL_VFX_PATH := "res://assets/effects/critical_vfx_sheet.png"
const DODGE_VFX_PATH    := "res://assets/effects/dodge_vfx_sheet.png"
const FINISHER_VFX_PATH := "res://assets/effects/finisher_vfx_sheet.png"
# 5 frames a ~15fps fecham em ~0.33s de tempo-de-cena: cabem na janela de
# slow-mo do golpe final (1.4s reais a time_scale 0.25 = 0.35s de cena).
const FINISHER_VFX_FPS  := 15.0
const LABEL_PATHS := {
	&"critico":  "res://assets/effects/result_critico.png",
	&"perfeito": "res://assets/effects/result_perfeito.png",
	&"errou":    "res://assets/effects/result_errou.png",
	&"esquiva":  "res://assets/effects/result_esquiva.png",
}
const COMBO_DIGIT_PATH  := "res://assets/effects/combo_digit_sheet.png"
const COMBO_DIGIT_W     := 8
const COMBO_DIGIT_H     := 12

# ─── Signals ───────────────────────────────────────
signal hit_stop_started(duration: float)
signal hit_stop_ended
## Sangue derramado em `at_position` (intensity: 1.0 golpe, 1.6 crítico,
## 2.6 morte). Consumido por BloodDecals para manchas persistentes no chão.
signal blood_spilled(at_position: Vector2, intensity: float)

@export var shake_intensity: float = 8.0
@export var shake_duration: float = 0.3

var _hit_stop_active: bool = false

# ─── VFX sprite pool ───────────────────────────────
# AnimatedSprite2D em vez de CPUParticles2D para hit/crit/dodge:
# 1 draw call por sprite vs. 20-60 por nuvem de partículas — ganho de
# performance direto no frame do impacto, onde o timing é mais crítico.
const POOL_PER_VFX := 2

var _vfx_pool: Dictionary = {}      # StringName → Array[AnimatedSprite2D]
var _vfx_pool_idx: Dictionary = {}  # StringName → int (round-robin)

# Texturas carregadas uma vez, reutilizadas pelo pool.
var _tex_hit: Texture2D
var _tex_crit: Texture2D
var _tex_dodge: Texture2D
var _tex_finisher: Texture2D

# ─── Combo tracker ─────────────────────────────────
var _combo_streak: int = 0
var _combo_node: Node2D  # HUD de dígitos (criado sob demanda)
var _combo_tween: Tween

# ─── Screenshake ───────────────────────────────────
func trigger_screenshake(intensity: float = shake_intensity, duration: float = shake_duration) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var original_offset := camera.offset
	var tween := create_tween()
	# Decai com ease-out exponencial: tranco forte que assenta rápido (soco que
	# acomoda), em vez de cair linearmente.
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_EXPO)
	tween.tween_method(_shake_camera.bind(camera), intensity, 0.0, duration)
	tween.tween_callback(func(): camera.offset = original_offset)

func _shake_camera(amount: float, camera: Camera2D) -> void:
	camera.offset = Vector2(
		randf_range(-amount, amount),
		randf_range(-amount, amount)
	)

# ─── Hit-stop ──────────────────────────────────────
## Pausa visual por N frames (60fps de referência): congela sprites dos atores e
## bolhas de timing, mas NÃO toca Engine.time_scale — input continua fluindo.
## Anti-acúmulo: hit-stops simultâneos são ignorados se já houver um ativo.
func trigger_hit_stop(frames: int = 3) -> void:
	if _hit_stop_active:
		return
	# Mix reativo: todo impacto pesado abafa música/ambiência por um instante,
	# deixando o SFX do golpe "estourar" — espelha o hit-stop no áudio.
	AudioDirector.duck()
	_hit_stop_active = true
	var duration: float = frames / 60.0
	hit_stop_started.emit(duration)
	await get_tree().create_timer(duration, true, false, true).timeout
	# Resiliente: se o hit-stop já foi encerrado à força (force_clear_hit_stop, ex.
	# na morte do inimigo), não re-emite ended nem mexe no estado já limpo.
	if _hit_stop_active:
		_hit_stop_active = false
		hit_stop_ended.emit()

## Encerra o hit-stop imediatamente (idempotente). Usado ao encerrar o combate para
## garantir que os sprites voltem a animar (speed_scale=1) antes de qualquer transição,
## sem depender do timer interno do hit-stop em andamento.
func force_clear_hit_stop() -> void:
	if not _hit_stop_active:
		return
	_hit_stop_active = false
	hit_stop_ended.emit()

# ─── VFX Sprite pool (hit/crit/dodge) ─────────────
## Ganho de cor dos feedbacks para compensar o CanvasModulate escuro da fase
## (clareia rótulos/VFX/partículas sem tocar o fundo). Identidade fora das fases escuras.
var _feedback_gain: Color = Color(1, 1, 1)

func _ready() -> void:
	_feedback_gain = Constants.feedback_gain_for_phase(GameState.active_phase)
	_tex_hit   = _safe_load(HIT_VFX_PATH)
	_tex_crit  = _safe_load(CRITICAL_VFX_PATH)
	_tex_dodge = _safe_load(DODGE_VFX_PATH)
	_tex_finisher = _safe_load(FINISHER_VFX_PATH)

## Multiplica só o RGB pelo ganho de cor da fase (preserva alpha).
func _g(c: Color) -> Color:
	return Color(c.r * _feedback_gain.r, c.g * _feedback_gain.g, c.b * _feedback_gain.b, c.a)

func _safe_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _make_vfx(tex: Texture2D, frame_w: int, frame_h: int,
		frame_count: int, fps: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex == null:
		return s
	var frames := SpriteFrames.new()
	frames.add_animation(&"play")
	frames.set_animation_speed(&"play", fps)
	frames.set_animation_loop(&"play", false)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame(&"play", atlas)
	s.sprite_frames = frames
	return s

func _burst_vfx(key: StringName, tex: Texture2D, frame_w: int, frame_h: int,
		frame_count: int, fps: float, at_position: Vector2) -> void:
	if tex == null:
		return
	if not _vfx_pool.has(key):
		_vfx_pool[key] = []
		_vfx_pool_idx[key] = -1
	var nodes: Array = _vfx_pool[key]
	var idx: int = (int(_vfx_pool_idx[key]) + 1) % POOL_PER_VFX
	_vfx_pool_idx[key] = idx
	if nodes.size() <= idx:
		nodes.resize(POOL_PER_VFX)
	var s: AnimatedSprite2D = nodes[idx]
	if not is_instance_valid(s) or not s.is_inside_tree():
		s = _make_vfx(tex, frame_w, frame_h, frame_count, fps)
		if not _attach_to_scene(s):
			nodes[idx] = null
			return
		# Auto-hide after animation ends.
		s.animation_finished.connect(func(): s.visible = false)
		nodes[idx] = s
	s.position = at_position
	# Pool reutiliza sprites: aplica o ganho no play-time, não na criação.
	s.modulate = _feedback_gain
	s.visible = true
	s.play(&"play")

## Impacto de sangue: substitui blood_particles com 1 draw call.
func spawn_hit_vfx(at_position: Vector2) -> void:
	blood_spilled.emit(at_position, 1.0)
	_burst_vfx(&"hit", _tex_hit, 48, 48, 6, 30.0, at_position)

## Explosão crítica laranja: substitui critical_particles + spark burst.
func spawn_critical_vfx(at_position: Vector2) -> void:
	blood_spilled.emit(at_position, 1.6)
	var vp := get_viewport().get_visible_rect().size
	if Constants.particle_amount_scale(vp) >= 1.0:
		_burst_vfx(&"crit", _tex_crit, 64, 64, 6, 20.0, at_position)
	else:
		# Budget device: apenas o hit mais barato.
		_burst_vfx(&"hit", _tex_hit, 48, 48, 6, 30.0, at_position)

## Streaks de esquiva: substitui dodge_particles.
func spawn_dodge_vfx(at_position: Vector2) -> void:
	_burst_vfx(&"dodge", _tex_dodge, 80, 48, 4, 24.0, at_position)

## Golpe final: garra esmagando o coração sobre o peito do inimigo. Toca em
## câmera lenta (a animação herda Engine.time_scale). NÃO dispara death_particles
## aqui — o "respingo extra" é o spawn_death_particles que ArenaMan._on_actor_died
## já chama em toda morte; evita duplicar gore e custo.
func spawn_finisher_vfx(at_position: Vector2) -> void:
	blood_spilled.emit(at_position, 2.6)
	_burst_vfx(&"finisher", _tex_finisher, 64, 64, 5, FINISHER_VFX_FPS, at_position)

# ─── Aliases legados (mantém assinatura pública) ───
func spawn_blood_particles(at_position: Vector2) -> void:
	spawn_hit_vfx(at_position)

func spawn_critical_particles(at_position: Vector2) -> void:
	spawn_critical_vfx(at_position)

func spawn_dodge_particles(at_position: Vector2) -> void:
	spawn_dodge_vfx(at_position)

func spawn_impact_particles(at_position: Vector2) -> void:
	spawn_hit_vfx(at_position)

# ─── Partículas mantidas ───────────────────────────
## Morte: evento raro e dramático — vale o custo dos CPUParticles2D.
func spawn_death_particles(at_position: Vector2) -> void:
	blood_spilled.emit(at_position, 2.6)
	_burst(&"death", _scene_factory(DEATH_PARTICLES, 1.0), at_position)

## Bubble burst e fail continuam como partículas (contexto da bolha de timing,
## não dos atores — custo já estava isolado e aceitável).
func spawn_bubble_burst(at_position: Vector2, tint: Color) -> void:
	_burst(&"bubble", _make_bubble, at_position, _g(tint))

func spawn_fail_particles(at_position: Vector2) -> void:
	_burst(&"fail", _make_fail, at_position)

# ─── Rótulos de resultado ─────────────────────────
## Exibe rótulo pixel-art (critico/perfeito/errou/esquiva) que flutua para cima
## e some. Aparece ACIMA da posição dada (timing bubble). Não precisa de pool
## (1 rótulo por evento de combate — evento raro).
func spawn_result_label(label_key: StringName, at_position: Vector2) -> void:
	var path: String = LABEL_PATHS.get(label_key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	sprite.position = at_position + Vector2(0, -24)
	sprite.z_index = 20
	# Ganho de cor da fase (clareia o rótulo sob CanvasModulate escuro). Alpha
	# começa em 1.0; o fade abaixo anima só modulate:a → compatível.
	sprite.modulate = Color(_feedback_gain.r, _feedback_gain.g, _feedback_gain.b, 1.0)
	if not _attach_to_scene(sprite):
		return
	var tw := create_tween()
	tw.set_parallel(true)
	# Pop de escala rápido.
	tw.tween_property(sprite, "scale", Vector2(2.4, 2.4), 0.06)
	tw.chain().tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.06)
	# Flutua para cima.
	tw.tween_property(sprite, "position:y", sprite.position.y - 28.0, 0.45)
	# Fade-out após hold.
	tw.chain().tween_interval(0.12)
	tw.chain().tween_property(sprite, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(sprite.queue_free)

# ─── Nome do golpe (tag sutil) ─────────────────────
## Nome do golpe (PRD moves nomeados) como tag SUTIL e periférica, ancorada no
## inimigo — longe da bolha de timing (que fica sobre a Caipora). É identidade,
## não interrupção: combate reativo (modelo Expedition 33) não pode perder o foco.
## Por isso cor apagada + alpha baixo + fade rápido; o contorno garante leitura sob
## o CanvasModulate escuro (gotcha #13) sem precisar de preenchimento berrante.
const MOVE_NAME_FONT: String = "res://assets/fonts/PressStart2P.ttf"
const MOVE_NAME_SIZE: int = 10
const MOVE_NAME_COLOR: Color = Color(0.82, 0.78, 0.72)  # cinza-osso apagado
const MOVE_NAME_ALPHA: float = 0.5

func spawn_move_name(text: String, at_position: Vector2) -> void:
	if text.strip_edges().is_empty():
		return
	var font: Font = load(MOVE_NAME_FONT)
	if font == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", MOVE_NAME_SIZE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 5  # abaixo dos rótulos de resultado (z=20) e da bolha
	# Label ancora no canto superior-esquerdo: centraliza pela largura medida.
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MOVE_NAME_SIZE).x
	label.position = at_position - Vector2(w * 0.5, 0)
	var base := _g(MOVE_NAME_COLOR)
	label.modulate = Color(base.r, base.g, base.b, 0.0)
	if not _attach_to_scene(label):
		return
	var tw := create_tween()
	# Fade-in suave, leve deriva pra cima, hold curto, fade-out — calmo, sem pop.
	tw.tween_property(label, "modulate:a", MOVE_NAME_ALPHA, 0.12)
	tw.parallel().tween_property(label, "position:y", label.position.y - 10.0, 0.9)
	tw.tween_interval(0.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(label.queue_free)

# ─── Combo tracker / indicador ────────────────────
## Registra acerto/falha. Streak ≥ 2 exibe o multiplicador na tela.
func track_perfect(is_perfect: bool) -> void:
	if is_perfect:
		_combo_streak += 1
	else:
		_combo_streak = 0
	var vp := get_viewport().get_visible_rect().size
	if Constants.particle_amount_scale(vp) < 1.0:
		return  # Budget device: skip combo indicator
	_update_combo_indicator()

## Passo atual da escada de combo (0..COMBO_MAX_STEP). Fonte única de verdade da
## intensidade escalada (shake/hit-stop/zoom/pitch). Streak 1 = passo 0; cresce daí.
## Streak 0 (erro recente) também devolve 0. Os chamadores leem APÓS track_perfect
## para que o golpe atual já conte na escada.
func combo_step() -> int:
	return clampi(_combo_streak - 1, 0, Constants.COMBO_MAX_STEP)

func _update_combo_indicator() -> void:
	if _combo_streak < 2:
		if is_instance_valid(_combo_node):
			_combo_node.visible = false
		return
	if not is_instance_valid(_combo_node) or not _combo_node.is_inside_tree():
		_combo_node = _make_combo_node()
		if not _attach_to_scene(_combo_node):
			_combo_node = null
			return
	_combo_node.visible = true
	_refresh_combo_digits()
	# Reset auto-hide timer.
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_interval(1.8)
	_combo_tween.tween_callback(func():
		if is_instance_valid(_combo_node):
			_combo_node.visible = false
	)

func _make_combo_node() -> Node2D:
	var node := Node2D.new()
	node.z_index = 25
	# Posição fixa: canto superior esquerdo da área de combate.
	node.position = Vector2(60.0, 60.0)
	return node

func _refresh_combo_digits() -> void:
	if not is_instance_valid(_combo_node):
		return
	for child in _combo_node.get_children():
		child.queue_free()
	var tex := _safe_load(COMBO_DIGIT_PATH)
	if tex == null:
		return
	# Exibe "x{N}" — ex.: "x2", "x3".
	var text: String = "x%d" % _combo_streak
	var x: float = 0.0
	for ch in text:
		var digit_idx: int
		if ch == "x":
			digit_idx = 10  # "x" glyph no final da sheet
		else:
			digit_idx = int(ch)
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.region_enabled = true
		s.region_rect = Rect2(digit_idx * COMBO_DIGIT_W, 0, COMBO_DIGIT_W, COMBO_DIGIT_H)
		s.scale = Vector2(2.0, 2.0)
		s.position = Vector2(x, 0.0)
		_combo_node.add_child(s)
		x += COMBO_DIGIT_W * 2.0

# ─── Partículas legadas (pool, Fase 10) ────────────
# Cada efeito reusa CPUParticles2D via restart() em vez de instantiate() +
# queue_free() por golpe: a alocação acontecia exatamente no frame do impacto —
# o momento crítico do timing — e era o maior suspeito de stutter em Android
# modesto. POOL_PER_KEY=2 em round-robin: um golpe duplo não mata em voo as
# gotas do golpe anterior. Os nós pertencem à cena ativa e morrem com ela; o
# pool detecta o cache inválido e recria. Em telefone, a densidade cai pela
# metade (Constants.particle_amount_scale) — o gore fica nos decals, que são
# baratos e permanentes.
const POOL_PER_KEY := 2

var _pool: Dictionary = {}       # StringName -> Array[CPUParticles2D]
var _pool_idx: Dictionary = {}   # StringName -> int (round-robin)

func _burst(key: StringName, factory: Callable, at_position: Vector2, tint: Color = Color.TRANSPARENT) -> void:
	if not _pool.has(key):
		var fresh: Array = []
		fresh.resize(POOL_PER_KEY)
		_pool[key] = fresh
		_pool_idx[key] = -1
	var nodes: Array = _pool[key]
	var idx: int = (int(_pool_idx[key]) + 1) % POOL_PER_KEY
	_pool_idx[key] = idx
	var p: CPUParticles2D = nodes[idx]
	if not is_instance_valid(p) or not p.is_inside_tree():
		p = factory.call()
		p.one_shot = true
		p.explosiveness = 1.0
		var vp := get_viewport().get_visible_rect().size
		p.amount = maxi(1, int(float(p.amount) * Constants.particle_amount_scale(vp)))
		if not _attach_to_scene(p):
			nodes[idx] = null
			return
		nodes[idx] = p
	p.position = at_position
	if tint.a > 0.0:
		p.color = tint
	p.restart()

## Factory de efeito vindo de cena (.tscn), com escala de densidade própria.
func _scene_factory(scene: PackedScene, amount_scale: float) -> Callable:
	return func() -> CPUParticles2D:
		var p: CPUParticles2D = scene.instantiate()
		if amount_scale != 1.0:
			p.amount = int(p.amount * amount_scale)
		return p

func _make_bubble() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 32
	p.lifetime = 0.45
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 360.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.material = _glow_material()
	return p

func _make_fail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 22
	p.lifetime = 0.4
	p.spread = 180.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = _g(Constants.COLOR_PARTICLE_FAIL)
	return p

func _glow_material() -> CanvasItemMaterial:
	# Recurso compartilhado, nunca CanvasItemMaterial.new(): instâncias idênticas
	# quebram o batching do Compatibility (PLANO-performance-60fps G9).
	return Constants.ADDITIVE_MATERIAL

## Anexa um nó de partículas à cena ativa. Retorna false (e descarta o nó) se a árvore
## ou a cena atual não existir — ex.: durante/depois de uma troca de cena. Evita erro de
## add_child em cena inválida quando a coroutine nasce no meio da transição.
func _attach_to_scene(node: Node) -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		node.queue_free()
		return false
	tree.current_scene.add_child(node)
	return true
