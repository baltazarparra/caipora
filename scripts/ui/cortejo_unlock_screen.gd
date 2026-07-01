class_name CortejoUnlockScreen
extends CanvasLayer

## Tela pós-boss estilo "Mega Man Weapon Get": apresenta a skill Cortejo dos Encantados
## na primeira vitória de boss (P1) e cada golpe novo liberado (P2–P4).
## Disparada pelo ArenaManager após o victory outro, antes da transição de tela.

signal dismissed

# ─── Constants ─────────────────────────────────────
const LAYER: int = 80                     # acima de COMBAT_LOADER (30), abaixo de SceneTransition (100)
const MIN_SKIP_DELAY: float = 0.6
const SWEEP_DURATION: float = 0.55
const SPRITE_TARGET_HEIGHT: float = 96.0
const DOT_SIZE: int = 10
const DOT_GAP: int = 8
const MAX_LINKS: int = 4

# Demo do Golpe Perfeito: a seta abre uma janela única e estoura no centro, em loop.
const DEMO_WINDOW_DURATION: float = 1.15
const DEMO_TAP_AT: float = 0.52
const DEMO_REST: float = 0.7              # pausa antes de repetir o ciclo

const BOSS_SPRITE_PATH: Dictionary = {
	1: "res://assets/sprites/mula_sprite_frames.tres",
	2: "res://assets/sprites/boitata_sprite_frames.tres",
	3: "res://assets/sprites/curupira_sprite_frames.tres",
	4: "res://assets/sprites/saci_sprite_frames.tres",
}

const BOSS_ACCENT: Dictionary = {
	1: Color("#6b1a1a"),
	2: Color("#1a3a6b"),
	3: Color("#1a5c2a"),
	4: Color("#4a1a6b"),
}

const COLOR_CAIPORA_PANEL: Color = Color(0.8, 0.27, 0.0, 0.65)
const COLOR_DARK: Color = Color(0.05, 0.02, 0.02, 1.0)

# ─── State ─────────────────────────────────────────
var _link_count: int = 0
var _phase: int = 0
var _ready_to_dismiss: bool = false
var _last_input_frame: int = -1
var _demo_bubble: TimingBubble = null

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = LAYER

# ─── Public API ────────────────────────────────────
func start(link_count: int) -> void:
	_link_count = link_count
	_phase = GameState.active_phase
	_build()
	_run_animation()
	get_tree().create_timer(MIN_SKIP_DELAY).timeout.connect(func() -> void: _ready_to_dismiss = true)
	if _demo_bubble != null:  # começa o loop da demo após a varredura dos painéis
		get_tree().create_timer(SWEEP_DURATION).timeout.connect(_run_perfect_demo)

# ─── Input ─────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _ready_to_dismiss:
		return
	if not _is_advance_event(event):
		return
	var frame: int = Engine.get_process_frames()
	if frame == _last_input_frame:
		return
	_last_input_frame = frame
	get_viewport().set_input_as_handled()
	dismissed.emit()

func _is_advance_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false

# ─── Build ─────────────────────────────────────────
func _build() -> void:
	var vp: Vector2 = _viewport_size()
	var cx: float = vp.x * 0.5
	var cy: float = vp.y * 0.5

	# Fundo escuro
	var bg := ColorRect.new()
	bg.color = COLOR_DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Flash branco inicial
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	flash.name = &"Flash"
	add_child(flash)

	# Painel esquerdo — cor do boss, varre do centro para a esquerda
	var accent: Color = BOSS_ACCENT.get(_phase, Constants.COLOR_BLOOD)
	var accent_panel: Color = accent
	accent_panel.a = 0.6
	var panel_left := ColorRect.new()
	panel_left.color = accent_panel
	panel_left.size = Vector2(cx, vp.y)
	panel_left.position = Vector2(0.0, 0.0)
	panel_left.pivot_offset = Vector2(cx, 0.0)  # ancora no centro — expande para esquerda
	panel_left.scale.x = 0.0
	panel_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_left.name = &"PanelLeft"
	add_child(panel_left)

	# Painel direito — laranja Caipora, varre do centro para a direita
	var panel_right := ColorRect.new()
	panel_right.color = COLOR_CAIPORA_PANEL
	panel_right.size = Vector2(cx, vp.y)
	panel_right.position = Vector2(cx, 0.0)
	panel_right.pivot_offset = Vector2(0.0, 0.0)  # ancora no centro — expande para direita
	panel_right.scale.x = 0.0
	panel_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_right.name = &"PanelRight"
	add_child(panel_right)

	# Sprite do boss (painel esquerdo, área superior)
	var sprite_path: String = BOSS_SPRITE_PATH.get(_phase, "")
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var frames: SpriteFrames = load(sprite_path)
		if frames != null and frames.has_animation(&"idle"):
			var boss_sprite := AnimatedSprite2D.new()
			boss_sprite.sprite_frames = frames
			boss_sprite.animation = &"idle"
			boss_sprite.centered = true
			var tex := frames.get_frame_texture(&"idle", 0)
			if tex != null and tex.get_height() > 0:
				var s: float = SPRITE_TARGET_HEIGHT / float(tex.get_height())
				boss_sprite.scale = Vector2(s, s)
			boss_sprite.position = Vector2(cx * 0.5, cy * 0.6)
			boss_sprite.modulate.a = 0.0
			boss_sprite.name = &"BossSprite"
			boss_sprite.play(&"idle")
			add_child(boss_sprite)

	# Linha divisória central (estilo Mega Man)
	var divider := ColorRect.new()
	divider.color = Constants.COLOR_AMBER
	divider.size = Vector2(2.0, vp.y)
	divider.position = Vector2(cx - 1.0, 0.0)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.modulate.a = 0.0
	divider.name = &"Divider"
	add_child(divider)

	# Texto — posicionado na metade inferior
	var text_y: float = cy + 20.0

	# Título
	var title_lbl := Label.new()
	title_lbl.text = Lang.t(&"cortejo.unlock.title")
	title_lbl.add_theme_font_size_override("font_size", Constants.FONT_LG)
	title_lbl.add_theme_color_override("font_color", Constants.COLOR_AMBER)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size = Vector2(vp.x, 44.0)
	title_lbl.position = Vector2(0.0, text_y - 50.0)
	title_lbl.modulate.a = 0.0
	title_lbl.name = &"TitleLabel"
	add_child(title_lbl)

	# Sub-título ("OBTIDO!" ou "GOLPE LIBERADO!")
	var is_first: bool = (_link_count == 1)
	var sub_key: StringName = &"cortejo.unlock.subtitle.first" if is_first else &"cortejo.unlock.subtitle.hit"
	var sub_lbl := Label.new()
	sub_lbl.text = Lang.t(sub_key)
	sub_lbl.add_theme_font_size_override("font_size", Constants.FONT_TITLE)
	sub_lbl.add_theme_color_override("font_color", Constants.COLOR_BLOOD)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.size = Vector2(vp.x, 64.0)
	sub_lbl.position = Vector2(0.0, text_y)
	sub_lbl.modulate.a = 0.0
	sub_lbl.name = &"SubLabel"
	add_child(sub_lbl)

	# Dots: 4 quadrados em linha — âmbar = liberado, cinza = bloqueado
	var total_w: float = (DOT_SIZE * MAX_LINKS) + (DOT_GAP * (MAX_LINKS - 1))
	var dots_x: float = cx - total_w * 0.5
	var dots_y: float = text_y + 80.0
	for i: int in range(MAX_LINKS):
		var dot := ColorRect.new()
		dot.size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.position = Vector2(dots_x + i * (DOT_SIZE + DOT_GAP), dots_y)
		dot.color = Constants.COLOR_AMBER if i < _link_count else Color(0.25, 0.25, 0.25, 1.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.modulate.a = 0.0
		dot.name = StringName("Dot%d" % i)
		add_child(dot)

	# Descrição
	var desc_key: StringName = &"cortejo.unlock.desc.first" if is_first else &"cortejo.unlock.desc.hit"
	var desc_text: String = Lang.t(desc_key) if is_first else Lang.tf(desc_key, [_link_count])
	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.add_theme_font_size_override("font_size", Constants.FONT_SM)
	desc_lbl.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size = Vector2(vp.x * 0.8, 96.0)
	desc_lbl.position = Vector2(vp.x * 0.1, dots_y + 24.0)
	desc_lbl.modulate.a = 0.0
	desc_lbl.name = &"DescLabel"
	add_child(desc_lbl)

	# Demo do Golpe Perfeito (só na 1ª liberação): uma janela única de toque, no painel
	# direito (laranja Caipora). Mesmo widget do combate.
	if is_first:
		var demo := TimingBubble.new()
		demo.position = Vector2(cx * 1.5, cy * 0.6)
		demo.name = &"PerfectDemo"
		add_child(demo)
		_demo_bubble = demo

		var demo_cap := Label.new()
		demo_cap.text = Lang.t(&"cortejo.unlock.demo")
		demo_cap.add_theme_font_size_override("font_size", Constants.FONT_SM)
		demo_cap.add_theme_color_override("font_color", Constants.COLOR_CHAMA_HOT)
		demo_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		demo_cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		demo_cap.size = Vector2(cx * 0.9, 44.0)
		demo_cap.position = Vector2(cx * 1.5 - cx * 0.45, cy * 0.6 + 44.0)
		demo_cap.name = &"DemoCaption"
		add_child(demo_cap)

	# Hint (pisca)
	var hint_lbl := Label.new()
	hint_lbl.text = Lang.t(&"cortejo.unlock.hint")
	hint_lbl.add_theme_font_size_override("font_size", Constants.FONT_SM)
	hint_lbl.add_theme_color_override("font_color", Color(Constants.COLOR_TEXT.r, Constants.COLOR_TEXT.g, Constants.COLOR_TEXT.b, 0.5))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.size = Vector2(vp.x, 24.0)
	hint_lbl.position = Vector2(0.0, vp.y - 60.0)
	hint_lbl.modulate.a = 0.0
	hint_lbl.name = &"HintLabel"
	add_child(hint_lbl)

# ─── Animation ─────────────────────────────────────
func _run_animation() -> void:
	var t := create_tween()

	# 1. Flash branco rápido
	var flash: ColorRect = get_node_or_null("Flash")
	if flash:
		t.tween_property(flash, "modulate:a", 1.0, 0.04)
		t.tween_property(flash, "modulate:a", 0.0, 0.09)

	# 2. Painéis varrem do centro para fora
	var panel_left: ColorRect = get_node_or_null("PanelLeft")
	var panel_right: ColorRect = get_node_or_null("PanelRight")
	if panel_left:
		t.tween_property(panel_left, "scale:x", 1.0, SWEEP_DURATION) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if panel_right:
		t.parallel().tween_property(panel_right, "scale:x", 1.0, SWEEP_DURATION) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 3. Divisória e sprite do boss aparecem
	var divider: ColorRect = get_node_or_null("Divider")
	if divider:
		t.tween_property(divider, "modulate:a", 0.6, 0.15)
	var boss_sprite: AnimatedSprite2D = get_node_or_null("BossSprite")
	if boss_sprite:
		t.parallel().tween_property(boss_sprite, "modulate:a", 1.0, 0.3)

	# 4. Título cai de cima
	var title_lbl: Label = get_node_or_null("TitleLabel")
	if title_lbl:
		var orig_y: float = title_lbl.position.y
		title_lbl.position.y = orig_y - 36.0
		t.tween_property(title_lbl, "modulate:a", 1.0, 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(title_lbl, "position:y", orig_y, 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 5. Sub-título (OBTIDO! / GOLPE LIBERADO!)
	var sub_lbl: Label = get_node_or_null("SubLabel")
	if sub_lbl:
		t.tween_property(sub_lbl, "modulate:a", 1.0, 0.18)

	# 6. Dots aparecem um a um
	for i: int in range(MAX_LINKS):
		var dot: ColorRect = get_node_or_null("Dot%d" % i)
		if dot:
			t.tween_property(dot, "modulate:a", 1.0, 0.07)

	# 7. Descrição
	var desc_lbl: Label = get_node_or_null("DescLabel")
	if desc_lbl:
		t.tween_property(desc_lbl, "modulate:a", 1.0, 0.2)

	# 8. Hint — aparece e começa a pulsar
	var hint_lbl: Label = get_node_or_null("HintLabel")
	if hint_lbl:
		t.tween_property(hint_lbl, "modulate:a", 0.7, 0.3)
		t.tween_callback(_start_hint_pulse.bind(hint_lbl))

func _start_hint_pulse(hint: Label) -> void:
	var pulse := create_tween().set_loops()
	pulse.tween_property(hint, "modulate:a", 0.2, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(hint, "modulate:a", 0.8, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ─── Demo do Golpe Perfeito (loop janela→toque) ─────
## Re-arma a si mesmo a cada ciclo; para sozinho quando a tela sai da árvore (free).
func _run_perfect_demo() -> void:
	if not is_inside_tree() or _demo_bubble == null or not is_instance_valid(_demo_bubble):
		return
	_demo_bubble.show_bubble(
		_demo_bubble.position, DEMO_WINDOW_DURATION,
		Constants.CORTEJO_PERFECT_START, Constants.CORTEJO_PERFECT_END,
		false, Constants.COLOR_CHAMA_HOT, "up", false
	)
	get_tree().create_timer(DEMO_WINDOW_DURATION * DEMO_TAP_AT).timeout.connect(_demo_tap)
	get_tree().create_timer(DEMO_WINDOW_DURATION + DEMO_REST).timeout.connect(_run_perfect_demo)

func _demo_tap() -> void:
	if is_instance_valid(_demo_bubble):
		_demo_bubble.burst_success()

# ─── Helpers ───────────────────────────────────────
func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var size: Vector2 = vp.get_visible_rect().size
		if size.x > 0.0 and size.y > 0.0:
			return size
	return Vector2(750.0, 1334.0)
