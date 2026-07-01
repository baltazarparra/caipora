class_name CortejoUnlockScreen
extends CanvasLayer

## Tela pós-boss do Cortejo "O Chamado". Fonte: docs/PRD-cortejo-o-chamado.md.
##
## 1ª liberação (P1) → TEACH INTERATIVO: reveal do encantado + narrativa; uma
## mão-fantasma demonstra SEGURAR↑→SOLTAR na banda dourada em loop; o jogador faz a
## própria rep (o medido real, mesmo primitivo do combate) e a corrente é ensinada.
## Rede de segurança: conclui sozinho após TEACH_TIMEOUT ou MAX_ATTEMPTS (nunca trava).
##
## Liberações seguintes (P2–P4) → CELEBRAÇÃO incremental: "+1 espírito no cortejo",
## a corrente cresce, e segue.

signal dismissed

# ─── Constants ─────────────────────────────────────
const LAYER: int = 80                     # acima do COMBAT_LOADER (30), abaixo do SceneTransition (100)
const MIN_SKIP_DELAY: float = 0.6
const SPRITE_TARGET_HEIGHT: float = 88.0
const MAX_LINKS: int = 4
const DOT_SIZE: int = 12
const DOT_GAP: int = 10

const REVEAL_HOLD: float = 1.0            # reveal antes de começar a ensinar/celebrar
const TEACH_TIMEOUT: float = 5.0          # rede de segurança: auto-conclui o teach
const MAX_ATTEMPTS: int = 2               # após N tentativas, conclui o teach
const GHOST_PERIOD: float = 1.55          # ciclo da mão-fantasma (demo)
const METER_SCALE: float = 2.4

const BOSS_SPRITE_PATH: Dictionary = {
	1: "res://assets/sprites/mula_sprite_frames.tres",
	2: "res://assets/sprites/boitata_sprite_frames.tres",
	3: "res://assets/sprites/curupira_sprite_frames.tres",
	4: "res://assets/sprites/saci_sprite_frames.tres",
}
const BOSS_ACCENT: Dictionary = {
	1: Color("#6b1a1a"), 2: Color("#1a3a6b"), 3: Color("#1a5c2a"), 4: Color("#4a1a6b"),
}
const COLOR_DARK: Color = Color(0.05, 0.02, 0.02, 1.0)

# ─── State ─────────────────────────────────────────
var _link_count: int = 0
var _phase: int = 0
var _can_dismiss: bool = false
var _last_input_frame: int = -1

var _center: Vector2 = Vector2.ZERO
var _meter: TimingBubble = null
var _timing: TimingSystem = null
var _teaching: bool = false               # fase "sua vez": input do jogador vira carga
var _charging: bool = false               # segurando agora (rep real em curso)
var _attempts: int = 0
var _teach_done: bool = false
var _caption: Label = null
var _hint: Label = null

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	# Dirige o TimingSystem à mão (ele fica com _process/_input desligados) só enquanto
	# o jogador segura: assim o timeout de overcharge conta, sem input real duplicado.
	if _charging and _timing != null:
		_timing._process(delta)

# ─── Public API ────────────────────────────────────
func start(link_count: int) -> void:
	_link_count = clampi(link_count, 1, MAX_LINKS)
	_phase = GameState.active_phase
	_build()
	if link_count <= 1:
		_run_teach_flow()
	else:
		_run_celebration_flow()

# ─── Input ─────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if _teaching:
		_handle_teach_input(event)
		return
	if not _can_dismiss or not _is_advance_event(event):
		return
	var frame: int = Engine.get_process_frames()
	if frame == _last_input_frame:
		return
	_last_input_frame = frame
	get_viewport().set_input_as_handled()
	dismissed.emit()

func _handle_teach_input(event: InputEvent) -> void:
	if _is_press_event(event):
		_begin_charge()
	elif _is_release_event(event):
		_end_charge()

func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false

func _is_press_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false

func _is_release_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return not event.pressed
	if event is InputEventScreenTouch:
		return not event.pressed
	if event is InputEventMouseButton:
		return not event.pressed
	return false

# ─── Fluxo: teach interativo (P1) ──────────────────
func _run_teach_flow() -> void:
	await get_tree().create_timer(REVEAL_HOLD).timeout
	if not is_inside_tree():
		return
	_caption.text = "%s\n%s" % [Lang.t(&"cortejo.unlock.teach.verb"), Lang.t(&"cortejo.unlock.teach.release")]
	_teaching = true
	get_tree().create_timer(TEACH_TIMEOUT).timeout.connect(func() -> void:
		if not _teach_done:
			_end_teach())
	_ghost_tick()   # demo em loop até o jogador segurar pela 1ª vez

## Mão-fantasma: o medidor enche e "solta" no ouro sozinho, em loop, como hint. Para de
## re-armar quando o jogador começa a própria rep (ou o teach termina).
func _ghost_tick() -> void:
	if _teach_done or _charging or not is_inside_tree() or _meter == null:
		return
	_show_meter()
	var hold: float = Constants.CHAMADO_CHARGE_SEC * (Constants.CHAMADO_RELEASE_START + Constants.CHAMADO_RELEASE_END) * 0.5
	get_tree().create_timer(hold).timeout.connect(func() -> void:
		if not _teach_done and not _charging and is_instance_valid(_meter):
			_meter.burst_success())
	get_tree().create_timer(GHOST_PERIOD).timeout.connect(_ghost_tick)

func _begin_charge() -> void:
	if _charging or _teach_done:
		return
	_charging = true
	_caption.text = Lang.t(&"cortejo.unlock.teach.try")
	_show_meter()
	_timing.open_window(Constants.CHAMADO_CHARGE_SEC, Constants.CHAMADO_RELEASE_START,
		Constants.CHAMADO_RELEASE_END, false, 0.0, 0.0, "ui_up", "ui_right", true,
		Constants.CHAMADO_GOOD_START, Constants.CHAMADO_RELEASE_END)
	_timing._input(_action_event("ui_up", true))   # arma a carga

func _end_charge() -> void:
	if not _charging:
		return
	_timing._input(_action_event("ui_up", false))  # solta → _on_teach_result

func _on_teach_result(result: int) -> void:
	_charging = false
	if result == TimingSystem.TimingResult.PERFECT:
		_meter.burst_success()
		_end_teach()
	elif result == TimingSystem.TimingResult.GOOD:
		_meter.burst_good()
		_end_teach()
	else:
		_meter.burst_fail()
		_attempts += 1
		if _attempts >= MAX_ATTEMPTS:
			_end_teach()
		else:
			_caption.text = Lang.t(&"cortejo.unlock.teach.try")

func _end_teach() -> void:
	if _teach_done:
		return
	_teach_done = true
	_teaching = false
	_charging = false
	if _meter != null:
		_meter.hide_bubble()
	_caption.text = Lang.t(&"cortejo.unlock.teach.done")
	_reveal_dismiss()

# ─── Fluxo: celebração incremental (P2–P4) ─────────
func _run_celebration_flow() -> void:
	await get_tree().create_timer(REVEAL_HOLD).timeout
	if not is_inside_tree():
		return
	_caption.text = Lang.tf(&"cortejo.unlock.grow.desc", [_link_count])
	_reveal_dismiss()

# ─── Dismiss ───────────────────────────────────────
func _reveal_dismiss() -> void:
	if _hint != null:
		_hint.visible = true
		var pulse := create_tween().set_loops()
		pulse.tween_property(_hint, "modulate:a", 0.25, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(_hint, "modulate:a", 0.85, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(MIN_SKIP_DELAY).timeout.connect(func() -> void: _can_dismiss = true)

# ─── Build ─────────────────────────────────────────
func _build() -> void:
	var vp: Vector2 = _viewport_size()
	var cx: float = vp.x * 0.5

	var bg := ColorRect.new()
	bg.color = COLOR_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Faixa de destaque na cor do encantado (topo).
	var accent: Color = BOSS_ACCENT.get(_phase, Constants.COLOR_BLOOD)
	accent.a = 0.5
	var band := ColorRect.new()
	band.color = accent
	band.size = Vector2(vp.x, vp.y * 0.42)
	add_child(band)

	# Sprite do encantado libertado (aparição translúcida).
	var sprite_path: String = BOSS_SPRITE_PATH.get(_phase, "")
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var frames: SpriteFrames = load(sprite_path)
		if frames != null and frames.has_animation(&"idle"):
			var boss := AnimatedSprite2D.new()
			boss.sprite_frames = frames
			boss.animation = &"idle"
			boss.centered = true
			var tex := frames.get_frame_texture(&"idle", 0)
			if tex != null and tex.get_height() > 0:
				var s: float = SPRITE_TARGET_HEIGHT / float(tex.get_height())
				boss.scale = Vector2(s, s)
			boss.modulate = Color(1, 1, 1, 0.85)
			boss.position = Vector2(cx, vp.y * 0.20)
			boss.play(&"idle")
			add_child(boss)

	# Título.
	_add_label(Lang.t(&"cortejo.unlock.title"), Constants.FONT_LG, Constants.COLOR_AMBER,
		Vector2(0.0, vp.y * 0.36), vp.x, HORIZONTAL_ALIGNMENT_CENTER)

	# Sub-linha: narrativa (P1) ou "+1 espírito" (P2–P4).
	var sub_key: StringName = &"cortejo.unlock.narrative" if _link_count <= 1 else &"cortejo.unlock.grow.title"
	_add_label(Lang.t(sub_key), Constants.FONT_SM, Constants.COLOR_TEXT,
		Vector2(vp.x * 0.1, vp.y * 0.36 + 40.0), vp.x * 0.8, HORIZONTAL_ALIGNMENT_CENTER)

	# Corrente de elos (dots), sempre visível — a nova cresce a corrente.
	var total_w: float = float(DOT_SIZE * MAX_LINKS + DOT_GAP * (MAX_LINKS - 1))
	var dots_x: float = cx - total_w * 0.5
	var dots_y: float = vp.y * 0.46
	for i: int in range(MAX_LINKS):
		var dot := ColorRect.new()
		dot.size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.position = Vector2(dots_x + i * (DOT_SIZE + DOT_GAP), dots_y)
		dot.color = Constants.COLOR_CHAMA_HOT if i < _link_count else Color(0.25, 0.25, 0.25, 1.0)
		add_child(dot)
		if i == _link_count - 1 and _link_count > 1:   # o novo elo "estala"
			dot.scale = Vector2(1.8, 1.8)
			dot.pivot_offset = dot.size * 0.5
			create_tween().tween_property(dot, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Medidor de carga (o coração do teach). Posicionado na metade inferior.
	_center = Vector2(cx, vp.y * 0.64)
	_meter = TimingBubble.new()
	_meter.scale = Vector2(METER_SCALE, METER_SCALE)
	_meter.position = _center
	add_child(_meter)

	# TimingSystem dirigido à mão (sem _process/_input automáticos): reusa a grade 3-tier.
	_timing = TimingSystem.new()
	_timing.set_process(false)
	_timing.set_process_input(false)
	_timing.timing_result.connect(_on_teach_result)
	add_child(_timing)

	# Legenda (instruções/estado) sob o medidor.
	_caption = _add_label("", Constants.FONT_SM, Constants.COLOR_CHAMA_HOT,
		Vector2(vp.x * 0.1, vp.y * 0.80), vp.x * 0.8, HORIZONTAL_ALIGNMENT_CENTER)

	# Hint de "pressione para continuar" (some até liberar o avanço).
	_hint = _add_label(Lang.t(&"cortejo.unlock.hint"), Constants.FONT_SM,
		Color(Constants.COLOR_TEXT.r, Constants.COLOR_TEXT.g, Constants.COLOR_TEXT.b, 0.6),
		Vector2(0.0, vp.y - 56.0), vp.x, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.visible = false

func _show_meter() -> void:
	if _meter == null:
		return
	_meter.show_bubble(_center, Constants.CHAMADO_CHARGE_SEC, Constants.CHAMADO_RELEASE_START,
		Constants.CHAMADO_RELEASE_END, false, Constants.COLOR_CHAMA_HOT, "up", true,
		Constants.CHAMADO_GOOD_START, Constants.CHAMADO_RELEASE_END, _link_count)

# ─── Helpers ───────────────────────────────────────
func _add_label(text: String, font_size: int, color: Color, pos: Vector2, width: float, align: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size = Vector2(width, 60.0)
	lbl.position = pos
	add_child(lbl)
	return lbl

func _action_event(action: String, pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	return ev

func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var s: Vector2 = vp.get_visible_rect().size
		if s.x > 0.0 and s.y > 0.0:
			return s
	return Vector2(750.0, 1334.0)
