class_name FinalChoiceScreen
extends CanvasLayer

## A cena da escolha final. O Jesuíta acaba de tombar no altar da própria igreja:
## a Caipora, DE COSTAS para a câmera (player_back, gen_caipora.py), olha o corpo
## caído sob o facho do vitral. Letterbox cinematográfico, push-in lento, poça de
## sangue crescendo, poeira no feixe de luz — e UMA pergunta: "Poupar ele?".
##
## SIM (poupar)  → ENDING_SACRIFICE (a misericórdia é paga com água benta: a
##                 Caipora morre e a floresta vira cristã).
## NÃO (executar)→ ENDING (o final canônico: a floresta segue respirando).
##
## Tudo é montado por código (padrão ending_screen/arena_backdrop); o desenho
## estático vive em BackdropLayer (uma gravação, redraw só quando a poça cresce
## ou o viewport muda). Funciona em retrato E paisagem (gotcha 10).


# Pacing da cena (segundos).
const FADE_IN_DURATION := 1.8
const QUESTION_DELAY := 2.4
const TYPE_DURATION := 1.1
const BUTTONS_FADE := 0.7
const PUSH_IN_DURATION := 22.0
const PUSH_IN_ZOOM := 1.06
const LETTERBOX_SLIDE := 1.4
const POOL_GROW_DURATION := 14.0
const EXECUTE_CUT_DELAY := 1.1
const SPARE_FADE_DURATION := 2.2

# Letterbox: fração da altura do viewport por barra.
const LETTERBOX_FRACTION := 0.085

# Camadas: mundo < Atmosphere (50) < letterbox < UI < véu de saída < SceneTransition (100).
const WORLD_LAYER := 20
const LETTERBOX_LAYER := 56
const UI_LAYER := 57
const VEIL_LAYER := 99

# Texturas (a protagonista de costas sai SOMENTE de gen_caipora.py — regra 2c).
const CAIPORA_BACK_PATH := "res://assets/sprites/player_back.png"
const CAIPORA_BACK_CHAMA_PATH := "res://assets/sprites/player_back_chama.png"
const JESUITA_PATH := "res://assets/sprites/jesuita_idle.png"
const VITRAL_PATH := "res://assets/sprites/light_vitral.png"
const WALL_PATH := "res://assets/sprites/tile_wall_church.png"
const FLOOR_PATH := "res://assets/sprites/tile_floor_church.png"
const TILE := 32
const WALL_VARIANTS := 4
const FLOOR_VARIANTS := 4

# SFX locais (bus "SFX", mesmo da arena).
const SFX_ATTACK := "res://assets/audio/sfx/attack.wav"
const SFX_HIT := "res://assets/audio/sfx/hit.wav"
const SFX_DEATH := "res://assets/audio/sfx/death.wav"
const STING_AGUA_BENTA := "res://assets/audio/stingers/sting_agua_benta.wav"

# ─── State ─────────────────────────────────────────
var _stage: Node2D
var _backdrop: BackdropLayer
var _blood: BackdropLayer
var _wall_tex: Texture2D
var _floor_tex: Texture2D
var _beam: Sprite2D
var _jesuita: Sprite2D
var _caipora: Sprite2D
var _caipora_shadow: Sprite2D
var _dust: CPUParticles2D
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _question: Label
var _buttons_box: HBoxContainer
var _btn_spare: Button
var _btn_kill: Button
var _veil: ColorRect

var _vp: Vector2 = Vector2(1280, 720)
var _k: float = 2.0
var _horizon: float = 300.0
var _boss_pos: Vector2 = Vector2.ZERO
var _pool_r: float = 0.0
var _zoom: float = 1.0
var _chosen: bool = false
var _breath_tween: Tween

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = WORLD_LAYER
	_wall_tex = load(WALL_PATH)
	_floor_tex = load(FLOOR_PATH)
	_build_world()
	_build_letterbox()
	_build_ui()
	_build_veil()
	_relayout()
	get_viewport().size_changed.connect(_relayout)
	_start_cinematics()

## Tela-alvo de cada resposta (puro — coberto por teste).
static func screen_for_choice(spare: bool) -> SignalBus.Screen:
	return SignalBus.Screen.ENDING_SACRIFICE if spare else SignalBus.Screen.ENDING

# ─── Construção ────────────────────────────────────
func _build_world() -> void:
	_stage = Node2D.new()
	add_child(_stage)

	_backdrop = BackdropLayer.new()
	_backdrop.draw_callback = _draw_backdrop
	_stage.add_child(_backdrop)

	# Poça de sangue sob o Jesuíta — cresce devagar a cena inteira.
	_blood = BackdropLayer.new()
	_blood.draw_callback = _draw_blood
	_stage.add_child(_blood)

	# Facho do vitral caindo sobre o corpo (o céu olhando o próprio emissário).
	_beam = Sprite2D.new()
	_beam.texture = load(VITRAL_PATH)
	_beam.material = Constants.ADDITIVE_MATERIAL
	_beam.modulate = Color(0.95, 0.80, 0.45, 0.55)
	_stage.add_child(_beam)

	# O Jesuíta caído: vivo (respira) — é por isso que a pergunta existe.
	_jesuita = Sprite2D.new()
	_jesuita.texture = load(JESUITA_PATH)
	_jesuita.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_jesuita.rotation = -PI / 2.0
	_jesuita.modulate = Color(0.82, 0.76, 0.74)
	_stage.add_child(_jesuita)

	# Poeira suspensa no feixe — a igreja assentando depois da luta.
	_dust = CPUParticles2D.new()
	_dust.amount = 14
	_dust.lifetime = 6.0
	_dust.preprocess = 6.0
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.direction = Vector2(0, 1)
	_dust.spread = 12.0
	_dust.gravity = Vector2(0, 2.0)
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 7.0
	_dust.scale_amount_min = 0.8
	_dust.scale_amount_max = 1.8
	_dust.color_ramp = _dust_ramp()
	_dust.material = Constants.ADDITIVE_MATERIAL
	_stage.add_child(_dust)

	# Sombra da guardiã no chão da nave.
	_caipora_shadow = Sprite2D.new()
	_caipora_shadow.texture = load(Constants.SHADOW_OVAL_PATH)
	_caipora_shadow.modulate = Constants.COLOR_ACTOR_SHADOW
	_stage.add_child(_caipora_shadow)

	# A Caipora de costas, em primeiro plano: a decisão é DELA — e sua.
	_caipora = Sprite2D.new()
	_caipora.texture = load(_caipora_back_path())
	_caipora.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.add_child(_caipora)

	add_child(Atmosphere.new())

func _caipora_back_path() -> String:
	return CAIPORA_BACK_CHAMA_PATH if MetaProgression.has_chama else CAIPORA_BACK_PATH

func _build_letterbox() -> void:
	var box := CanvasLayer.new()
	box.layer = LETTERBOX_LAYER
	add_child(box)
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar_bottom)

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = UI_LAYER
	add_child(ui)

	_question = Label.new()
	_question.text = Lang.t(&"choice.question")
	_question.visible_characters = 0
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.add_theme_font_size_override("font_size", Constants.FONT_TITLE)
	_question.add_theme_color_override("font_color", Constants.COLOR_TEXT)
	_question.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_question.add_theme_constant_override("shadow_offset_x", 3)
	_question.add_theme_constant_override("shadow_offset_y", 3)
	_question.anchor_left = 0.0
	_question.anchor_right = 1.0
	_question.anchor_top = 0.16
	_question.anchor_bottom = 0.16
	_question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_question)

	_buttons_box = HBoxContainer.new()
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_box.add_theme_constant_override("separation", Constants.SPACE_LG)
	_buttons_box.anchor_left = 0.0
	_buttons_box.anchor_right = 1.0
	_buttons_box.anchor_top = 0.76
	_buttons_box.anchor_bottom = 0.76
	_buttons_box.modulate.a = 0.0
	ui.add_child(_buttons_box)

	_btn_spare = _make_choice_button(Lang.t(&"choice.spare"))
	_btn_spare.pressed.connect(_choose.bind(true))
	_buttons_box.add_child(_btn_spare)

	_btn_kill = _make_choice_button(Lang.t(&"choice.kill"))
	_btn_kill.pressed.connect(_choose.bind(false))
	_buttons_box.add_child(_btn_kill)

func _make_choice_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.disabled = true
	btn.custom_minimum_size = Vector2(132.0, 56.0)
	btn.add_theme_font_size_override("font_size", Constants.FONT_LG)
	btn.focus_entered.connect(AudioDirector.play_ui_hover)
	btn.mouse_entered.connect(AudioDirector.play_ui_hover)
	return btn

func _build_veil() -> void:
	# Véu de entrada/saída acima de tudo (abaixo só do SceneTransition).
	var veil_layer := CanvasLayer.new()
	veil_layer.layer = VEIL_LAYER
	add_child(veil_layer)
	_veil = ColorRect.new()
	_veil.color = Color(0.0, 0.0, 0.0, 1.0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil_layer.add_child(_veil)

# ─── Layout responsivo (retrato E paisagem) ────────
func _relayout() -> void:
	_vp = get_viewport().get_visible_rect().size
	var portrait := Constants.is_portrait(_vp)
	_k = clampf(minf(_vp.x, _vp.y) / 240.0, 1.4, 3.4)
	_horizon = _vp.y * (0.36 if portrait else 0.42)

	# Em retrato a nave é estreita: os atores se aproximam do eixo central.
	var boss_x := _vp.x * (0.63 if portrait else 0.64)
	var boss_y := lerpf(_horizon, _vp.y, 0.36)
	_boss_pos = Vector2(boss_x, boss_y)
	var jes_scale := 2.7 * _k * 0.95
	_jesuita.position = _boss_pos
	_jesuita.scale = Vector2(jes_scale, jes_scale)

	# A guardiã em primeiro plano, "over the shoulder": ela CORTA a moldura
	# inferior (pés abaixo do letterbox) — massa laranja grande, câmera baixa.
	var caipora_x := _vp.x * (0.34 if portrait else 0.36)
	var caipora_scale := 1.55 * _k
	# Pés da sprite (canvas 96, pés em y≈88 → 40px abaixo do centro).
	var caipora_feet_y := lerpf(_horizon, _vp.y, 0.94)
	var caipora_y := caipora_feet_y - 40.0 * caipora_scale
	_caipora.position = Vector2(caipora_x, caipora_y)
	_caipora.scale = Vector2(caipora_scale, caipora_scale)
	_caipora_shadow.position = Vector2(caipora_x, caipora_feet_y)
	_caipora_shadow.scale = Vector2(caipora_scale * 2.6, caipora_scale * 0.9)

	_beam.position = _boss_pos + Vector2(28.0 * _k, -52.0 * _k)
	_beam.rotation = 0.42
	_beam.scale = Vector2(2.4 * _k, 2.4 * _k)

	_dust.position = _boss_pos + Vector2(10.0 * _k, -60.0 * _k)
	_dust.emission_rect_extents = Vector2(40.0 * _k, 30.0 * _k)

	_apply_letterbox(_bar_top.size.y)
	_apply_zoom()
	_backdrop.queue_redraw()
	_blood.queue_redraw()

func _apply_letterbox(h: float) -> void:
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(_vp.x, h)
	_bar_bottom.position = Vector2(0.0, _vp.y - h)
	_bar_bottom.size = Vector2(_vp.x, h)

func _apply_zoom() -> void:
	# Push-in lento em torno do centro do viewport (câmera respirando pra dentro).
	_stage.scale = Vector2(_zoom, _zoom)
	_stage.position = _vp * 0.5 * (1.0 - _zoom)

# ─── Cinemática ────────────────────────────────────
func _start_cinematics() -> void:
	# Entrada: breu → nave. O órgão estertora (AudioDirector já cuidou).
	var t := create_tween()
	t.tween_property(_veil, "color:a", 0.0, FADE_IN_DURATION)

	# Letterbox desliza junto do fade.
	var lb := create_tween()
	lb.tween_method(_apply_letterbox, 0.0, _vp.y * LETTERBOX_FRACTION, LETTERBOX_SLIDE)

	# Push-in contínuo.
	var z := create_tween()
	z.tween_method(_set_zoom, 1.0, PUSH_IN_ZOOM, PUSH_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# A poça abaixo do Jesuíta cresce a cena inteira — o tempo está contra ele.
	var pool := create_tween()
	pool.tween_method(_set_pool_radius, 10.0 * _k, 34.0 * _k, POOL_GROW_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Respiração do caído: o peito (modulate) sobe e desce — ele está VIVO.
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(_jesuita, "modulate", Color(0.92, 0.86, 0.84), 1.5) \
		.set_trans(Tween.TRANS_SINE)
	_breath_tween.tween_property(_jesuita, "modulate", Color(0.82, 0.76, 0.74), 1.9) \
		.set_trans(Tween.TRANS_SINE)

	# A juba da guardiã assenta o peso (bob sutil de pé).
	var bob := create_tween().set_loops()
	bob.tween_property(_caipora, "position:y", 3.0, 2.2) \
		.as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(_caipora, "position:y", -3.0, 2.2) \
		.as_relative().set_trans(Tween.TRANS_SINE)

	# O feixe do vitral pulsa devagar — a luz também espera a resposta.
	var beam := create_tween().set_loops()
	beam.tween_property(_beam, "modulate:a", 0.72, 3.0).set_trans(Tween.TRANS_SINE)
	beam.tween_property(_beam, "modulate:a", 0.50, 3.4).set_trans(Tween.TRANS_SINE)

	# A pergunta, letra a letra; os botões nascem depois dela.
	var q := create_tween()
	q.tween_interval(QUESTION_DELAY)
	q.tween_method(_set_question_chars, 0.0, float(Lang.t(&"choice.question").length()), TYPE_DURATION)
	q.tween_property(_buttons_box, "modulate:a", 1.0, BUTTONS_FADE)
	q.tween_callback(_enable_buttons)

func _set_zoom(v: float) -> void:
	_zoom = v
	_apply_zoom()

func _set_pool_radius(r: float) -> void:
	_pool_r = r
	_blood.queue_redraw()

func _set_question_chars(v: float) -> void:
	_question.visible_characters = int(v)

func _enable_buttons() -> void:
	if _chosen:
		return
	_btn_spare.disabled = false
	_btn_kill.disabled = false
	_btn_kill.grab_focus()

# ─── Escolha ───────────────────────────────────────
func _choose(spare: bool) -> void:
	if _chosen:
		return
	_chosen = true
	_btn_spare.disabled = true
	_btn_kill.disabled = true
	var fade_ui := create_tween()
	fade_ui.tween_property(_buttons_box, "modulate:a", 0.0, 0.25)
	fade_ui.parallel().tween_property(_question, "modulate:a", 0.0, 0.25)
	if spare:
		_spare_beat()
	else:
		_execute_beat()

## NÃO poupar: o golpe final. Seco, rápido, sem glória — corte para o final atual.
func _execute_beat() -> void:
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_callback(func() -> void:
		_play_sfx(SFX_ATTACK)
		_play_sfx(SFX_HIT))
	t.tween_callback(_strike_impact)
	t.tween_interval(0.12)
	t.tween_callback(func() -> void: _play_sfx(SFX_DEATH, -2.0))
	t.tween_interval(EXECUTE_CUT_DELAY)
	t.tween_property(_veil, "color:a", 1.0, 0.5)
	t.tween_callback(func() -> void:
		GameState.change_screen(screen_for_choice(false)))

func _strike_impact() -> void:
	# O corpo apaga: a respiração para no frame do golpe.
	if _breath_tween != null and _breath_tween.is_valid():
		_breath_tween.kill()
	_jesuita.modulate = Color(0.30, 0.24, 0.24)
	_set_pool_radius(maxf(_pool_r * 1.8, 34.0 * _k))
	_spawn_blood_burst()
	_shake_stage()
	# Flash vermelho seco no véu.
	_veil.color = Color(Constants.COLOR_BLOOD.r, Constants.COLOR_BLOOD.g,
		Constants.COLOR_BLOOD.b, 0.45)
	var f := create_tween()
	f.tween_property(_veil, "color", Color(0.0, 0.0, 0.0, 0.0), 0.4)

func _spawn_blood_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.position = _boss_pos
	burst.one_shot = true
	burst.emitting = true
	burst.amount = 26
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 70.0
	burst.gravity = Vector2(0, 600.0)
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 220.0
	burst.scale_amount_min = 1.6
	burst.scale_amount_max = 3.2
	burst.color = Constants.COLOR_BLOOD
	_stage.add_child(burst)

func _shake_stage() -> void:
	var s := create_tween()
	for i: int in 6:
		var off := Vector2(randf_range(-9.0, 9.0), randf_range(-7.0, 7.0))
		s.tween_property(_stage, "position", _vp * 0.5 * (1.0 - _zoom) + off, 0.03)
	s.tween_callback(_apply_zoom)

## POUPAR: a água benta responde primeiro — o branco engole a nave.
func _spare_beat() -> void:
	_play_sfx(STING_AGUA_BENTA, -4.0)
	var beam_up := create_tween()
	beam_up.tween_property(_beam, "modulate", Color(1.4, 1.3, 1.0, 1.0), SPARE_FADE_DURATION)
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(func() -> void: _veil.color = Color(0.92, 0.94, 0.98, 0.0))
	t.tween_property(_veil, "color:a", 1.0, SPARE_FADE_DURATION)
	t.tween_callback(func() -> void:
		GameState.change_screen(screen_for_choice(true)))

func _play_sfx(path: String, volume_db: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = "SFX"
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ─── Desenho (BackdropLayer callbacks) ─────────────
func _draw_backdrop(canvas: Node2D) -> void:
	# Breu total: a abóbada some na treva.
	canvas.draw_rect(Rect2(Vector2.ZERO, _vp), Color(0.03, 0.015, 0.015))
	var ts := float(TILE) * maxf(1.0, roundf(_k))
	var cols := int(ceilf(_vp.x / ts))

	# Parede da nave: fiadas de taipa escurecendo para cima.
	for row: int in 3:
		var y := _horizon - (row + 1) * ts
		var bright := 0.52 - row * 0.16
		for col: int in cols:
			var variant := (col * 13 + row * 7) % WALL_VARIANTS
			canvas.draw_texture_rect_region(
				_wall_tex,
				Rect2(col * ts, y, ts, ts),
				Rect2(variant * TILE, 0, TILE, TILE),
				Color(bright, bright, bright))

	# Chão da nave: longe escuro, perto claro (mesma gramática da arena).
	var frows := int(ceilf((_vp.y - _horizon) / ts))
	for row: int in frows:
		var depth := float(row) / maxf(float(frows - 1), 1.0)
		var bright := lerpf(0.20, 0.52, pow(depth, 1.2))
		for col: int in cols:
			var variant := (col * 31 + row * 17) % FLOOR_VARIANTS
			canvas.draw_texture_rect_region(
				_floor_tex,
				Rect2(col * ts, _horizon + row * ts, ts, ts),
				Rect2(variant * TILE, 0, TILE, TILE),
				Color(bright, bright, bright))

	_draw_cross_and_altar(canvas)
	_draw_pews(canvas)
	_draw_votive_candles(canvas)

func _draw_cross_and_altar(canvas: Node2D) -> void:
	# A cruz torta sobre o altar, eixo da nave (vocabulário do arena_backdrop).
	var s := _k * 1.15
	var cx := _vp.x * 0.5
	var cy := _horizon - 34.0 * s
	var wood := Constants.COLOR_WOOD_DARK
	var gold := Constants.COLOR_GOLD_DARK
	canvas.draw_rect(Rect2(cx - 4.0 * s, cy - 24.0 * s, 8.0 * s, 48.0 * s), wood)
	canvas.draw_rect(Rect2(cx - 14.0 * s, cy - 12.0 * s, 28.0 * s, 8.0 * s), wood)
	canvas.draw_rect(Rect2(cx - 2.0 * s, cy - 24.0 * s, 4.0 * s, 48.0 * s), gold)
	canvas.draw_rect(Rect2(cx - 14.0 * s, cy - 10.0 * s, 28.0 * s, 2.0 * s), gold)
	canvas.draw_rect(Rect2(cx - 30.0 * s, _horizon - 12.0 * s, 60.0 * s, 12.0 * s),
		Constants.COLOR_STONE_DARK)
	canvas.draw_rect(Rect2(cx - 30.0 * s, _horizon - 12.0 * s, 60.0 * s, 3.0 * s),
		Constants.COLOR_STONE)

func _draw_pews(canvas: Node2D) -> void:
	# Bancos quebrados nas laterais — testemunhas vazias da pergunta.
	var s := _k * 0.85
	for side: float in [0.10, 0.90]:
		for i: int in 2:
			var cy := _horizon + (24.0 + i * 34.0) * s
			_draw_pew(canvas, _vp.x * side, cy, s)

func _draw_pew(canvas: Node2D, cx: float, cy: float, s: float) -> void:
	var wood := Constants.COLOR_WOOD
	var wood_dark := Constants.COLOR_WOOD_DARK
	canvas.draw_rect(Rect2(cx - 36.0 * s, cy + 4.0 * s, 72.0 * s, 8.0 * s), wood_dark)
	canvas.draw_rect(Rect2(cx - 36.0 * s, cy + 4.0 * s, 72.0 * s, 3.0 * s), wood)
	canvas.draw_rect(Rect2(cx - 36.0 * s, cy - 12.0 * s, 72.0 * s, 6.0 * s), wood_dark)
	canvas.draw_rect(Rect2(cx - 33.0 * s, cy + 10.0 * s, 6.0 * s, 12.0 * s), wood_dark)
	canvas.draw_rect(Rect2(cx + 27.0 * s, cy + 10.0 * s, 6.0 * s, 12.0 * s), wood_dark)

func _draw_votive_candles(canvas: Node2D) -> void:
	# Círios junto ao altar: pontos âmbar com halo — as únicas chamas mansas.
	var s := _k * 0.9
	var cy := _horizon - 3.0 * s
	for off: float in [-44.0, -38.0, 40.0, 46.0]:
		var p := Vector2(_vp.x * 0.5 + off * s, cy)
		canvas.draw_rect(Rect2(p.x - 1.5 * s, p.y - 6.0 * s, 3.0 * s, 6.0 * s),
			Constants.COLOR_BONE)
		canvas.draw_circle(p + Vector2(0, -7.5 * s), 2.0 * s, Constants.COLOR_FIRE_HOT)
		canvas.draw_circle(p + Vector2(0, -7.5 * s), 4.5 * s, Constants.COLOR_FIRE_GLOW)

func _draw_blood(canvas: Node2D) -> void:
	if _pool_r <= 0.0:
		return
	var p := _boss_pos + Vector2(-4.0 * _k, 10.0 * _k)
	canvas.draw_set_transform(p, 0.0, Vector2(1.0, 0.36))
	var dark := Constants.COLOR_BLOOD_POOL_DARK
	dark.a = 0.92
	var pool := Constants.COLOR_BLOOD_POOL
	pool.a = 0.88
	canvas.draw_circle(Vector2.ZERO, _pool_r, dark)
	canvas.draw_circle(Vector2(2.0 * _k, 1.0), _pool_r * 0.62, pool)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# O sangue procura as frestas das lajes — escorre na direção da câmera.
	var ts := float(TILE) * maxf(1.0, roundf(_k))
	for i: int in 3:
		var gx := p.x + (float(i) - 1.0) * ts * 0.5
		var run_len := _pool_r * (1.4 - 0.3 * absf(float(i) - 1.0))
		canvas.draw_rect(Rect2(gx - 1.0, p.y + _pool_r * 0.18, 2.0, run_len),
			Constants.COLOR_BLOOD_POOL_DARK)

func _dust_ramp() -> Gradient:
	var c := Color(0.85, 0.74, 0.50)
	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(c.r, c.g, c.b, 0.0))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(c.r, c.g, c.b, 0.0))
	grad.add_point(0.5, Color(c.r, c.g, c.b, 0.22))
	return grad
