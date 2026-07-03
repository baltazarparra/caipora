class_name BossIntroScreen
extends CanvasLayer

## Apresentação de boss no estilo Mega Man: uma pré-tela curta que precede o
## diálogo de toda boss fight. Fundo escuro, o MODELO do boss surge em cena com
## um "pop" e, abaixo, o NOME estilizado se revela letra a letra entre duas
## barras de destaque. Toca uma vez por boss, antes do diálogo.
##
## Fluxo: exploração dispara combate de boss → BossIntroScreen → (diálogo) → arena.
## A cena é montada por código (depende dos dados do boss em start()), seguindo o
## padrão de ending_screen.gd. Avança sozinha após um hold curto, ou ao primeiro
## toque/tecla/clique depois de uma breve janela anti-skip-acidental.

# ─── Constants ─────────────────────────────────────
const LAYER: int = 15                       # acima do HUD/diálogo, abaixo do SceneTransition (100)
const MODEL_TARGET_HEIGHT: float = 280.0    # altura de exibição do modelo (normaliza os 48px)
const MODEL_CENTER_Y_RATIO: float = 0.40
const NAME_CENTER_Y_RATIO: float = 0.74
const POP_DURATION: float = 0.5
const BARS_DURATION: float = 0.28
const NAME_REVEAL_PER_CHAR: float = 0.06
const HOLD_DURATION: float = 1.4
const MIN_SKIP_DELAY: float = 0.4           # carência antes de aceitar skip (evita pular no mesmo input que disparou o combate)
const BACKLIGHT_SIZE: int = 512
const BAR_HEIGHT: float = 4.0
const BAR_WIDTH_RATIO: float = 0.62
const BAR_WIDTH_RATIO_PORTRAIT: float = 0.88   # retrato: tela estreita, barras quase totais
const NAME_MAX_WIDTH_RATIO: float = 0.52   # largura máxima do nome; acima disso, quebra de linha (ex. "MULA SEM CABEÇA")
const NAME_MAX_WIDTH_RATIO_PORTRAIT: float = 0.78  # retrato: mais colunas p/ nomes longos (JESUÍTA...)
const NAME_FONT_MIN: int = 28              # piso de fonte (legibilidade); só recua se a palavra não couber
const BAR_GAP: float = 18.0                # folga entre o bloco do nome e as barras
const SUBTITLE_GAP: float = 24.0           # folga entre a barra de cima e o subtítulo

# ─── State ─────────────────────────────────────────
var _boss_name: String = ""
var _model_full_scale: Vector2 = Vector2.ONE
var _model_home: Vector2 = Vector2.ZERO
var _finished: bool = false
var _can_skip: bool = false

# ─── Nodes (montados em _build) ────────────────────
var _overlay: ColorRect
var _backlight: Sprite2D
var _model: AnimatedSprite2D
var _bar_top: ColorRect
var _bar_bot: ColorRect
var _subtitle: Label
var _name_label: Label

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = LAYER

# ─── Public API ────────────────────────────────────

## Monta e dispara a apresentação. `accent` é a cor de aura do boss (brilho/barras),
## `name_color` é a cor viva da voz do boss (texto do nome).
func start(boss_name: String, frames: SpriteFrames, accent: Color, name_color: Color) -> void:
	_boss_name = boss_name
	_build(frames, accent, name_color)
	SignalBus.boss_intro_started.emit()
	_play_intro()
	get_tree().create_timer(MIN_SKIP_DELAY).timeout.connect(_enable_skip)

## Encerra a apresentação (fim do hold ou skip). Emite boss_intro_finished uma vez.
func finish() -> void:
	if _finished:
		return
	_finished = true
	SignalBus.boss_intro_finished.emit()
	queue_free()

# ─── Input ─────────────────────────────────────────

# Usa _input (não _unhandled_input) pelo mesmo motivo do diálogo: overlays comem o
# toque na fase de GUI. Qualquer tecla/toque/clique pula a apresentação.
func _input(event: InputEvent) -> void:
	if _finished or not _can_skip:
		return
	if _is_skip_event(event):
		get_viewport().set_input_as_handled()
		finish()

func _is_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	return false

# ─── Build ─────────────────────────────────────────
func _build(frames: SpriteFrames, accent: Color, name_color: Color) -> void:
	var vp: Vector2 = _viewport_size()
	var center_x: float = vp.x * 0.5

	_overlay = ColorRect.new()
	_overlay.color = Constants.COLOR_ARENA_BG
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var model_pos := Vector2(center_x, vp.y * MODEL_CENTER_Y_RATIO)

	_backlight = Sprite2D.new()
	_backlight.texture = _make_radial_glow(accent)
	_backlight.position = model_pos
	_backlight.scale = Vector2(1.4, 1.4)
	_backlight.z_index = -1
	_backlight.modulate.a = 0.0
	add_child(_backlight)

	_model = AnimatedSprite2D.new()
	_model.sprite_frames = frames
	_model.animation = &"idle"
	_model.centered = true
	_model.position = model_pos
	_model_home = model_pos
	_model_full_scale = _scale_for(frames)
	_model.scale = Vector2.ZERO
	_model.play(&"idle")
	add_child(_model)

	var portrait: bool = Constants.is_portrait(vp)
	var bar_width: float = vp.x * (BAR_WIDTH_RATIO_PORTRAIT if portrait else BAR_WIDTH_RATIO)
	var name_y: float = vp.y * NAME_CENTER_Y_RATIO
	var max_name_width: float = vp.x \
		* (NAME_MAX_WIDTH_RATIO_PORTRAIT if portrait else NAME_MAX_WIDTH_RATIO)

	# O nome NUNCA encolhe nem corta: fonte grande consistente e quebra em PALAVRA —
	# nomes longos (ex. "MULA SEM CABEÇA") quebram em duas linhas em vez de espremer.
	_name_label = Label.new()
	_name_label.text = ""
	_name_label.add_theme_color_override("font_color", name_color)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP  # TOP mantém a linha 1 fixa durante a revelação
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_name_label)  # na árvore antes de medir → resolução de tema (fonte) confiável

	var font_size: int = _name_font_size(max_name_width)
	_name_label.add_theme_font_size_override("font_size", font_size)

	# Reserva a caixa do nome pela altura REAL do nome COMPLETO quebrado (medida,
	# não capada em N linhas): a revelação letra a letra não empurra as barras e a
	# barra de baixo nunca atravessa a última linha (ex. "JESUÍTA BANDEIRANTE
	# CATEQUIZADOR" ocupa 3 linhas num phone retrato).
	var font: Font = _name_label.get_theme_font(&"font")
	var block_h: float = maxf(font.get_height(font_size),
		font.get_multiline_string_size(_boss_name, HORIZONTAL_ALIGNMENT_CENTER,
			max_name_width, font_size).y)
	var box_top: float = name_y - block_h * 0.5

	_name_label.size = Vector2(max_name_width, block_h)
	_name_label.position = Vector2((vp.x - max_name_width) * 0.5, box_top)

	_bar_top = _make_bar(accent, center_x, box_top - BAR_GAP, bar_width)
	add_child(_bar_top)

	_subtitle = Label.new()
	_subtitle.text = Lang.t(&"boss_intro.subtitle")
	_subtitle.add_theme_font_size_override("font_size", Constants.FONT_SM)
	_subtitle.add_theme_color_override("font_color", accent)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.anchor_left = 0.0
	_subtitle.anchor_right = 1.0
	_subtitle.position.y = box_top - BAR_GAP - SUBTITLE_GAP
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)

	_bar_bot = _make_bar(accent, center_x, box_top + block_h + BAR_GAP, bar_width)
	add_child(_bar_bot)

# ─── Animation ─────────────────────────────────────
func _play_intro() -> void:
	var t := create_tween()
	# 1. Modelo entra com "pop" elástico.
	t.tween_property(_model, "scale", _model_full_scale, POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_backlight, "modulate:a", 1.0, POP_DURATION)
	# 2. Barras de destaque varrem para fora do centro + subtítulo aparece.
	t.tween_property(_bar_top, "scale:x", 1.0, BARS_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_bar_bot, "scale:x", 1.0, BARS_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, BARS_DURATION)
	# 3. Nome se revela letra a letra.
	var reveal := maxf(NAME_REVEAL_PER_CHAR, NAME_REVEAL_PER_CHAR * _boss_name.length())
	t.tween_method(_set_name_chars, 0, _boss_name.length(), reveal)
	# 4. Segura e encerra (skip pode antecipar).
	t.tween_interval(HOLD_DURATION)
	t.tween_callback(finish)

	_start_idle_bob()
	_start_backlight_pulse()

func _set_name_chars(count: int) -> void:
	if _name_label != null:
		_name_label.text = _boss_name.substr(0, count)

func _start_idle_bob() -> void:
	var bob := create_tween().set_loops()
	bob.tween_property(_model, "position:y", _model_home.y - 8.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_model, "position:y", _model_home.y, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_backlight_pulse() -> void:
	var pulse := create_tween().set_loops()
	pulse.tween_property(_backlight, "scale", Vector2(1.55, 1.55), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(_backlight, "scale", Vector2(1.4, 1.4), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ─── Helpers ───────────────────────────────────────
func _enable_skip() -> void:
	_can_skip = true

func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var size := vp.get_visible_rect().size
		if size.x > 0.0 and size.y > 0.0:
			return size
	return Vector2(1280, 720)

## Escala que normaliza o sprite do boss (48px) à altura de exibição.
func _scale_for(frames: SpriteFrames) -> Vector2:
	var h: float = MODEL_TARGET_HEIGHT
	if frames != null and frames.has_animation(&"idle"):
		var tex := frames.get_frame_texture(&"idle", 0)
		if tex != null and tex.get_height() > 0:
			var s: float = MODEL_TARGET_HEIGHT / float(tex.get_height())
			return Vector2(s, s)
	return Vector2(h / 48.0, h / 48.0)

## Tamanho de fonte do nome: grande e fixo (FONT_TITLE). Só recua — até NAME_FONT_MIN —
## se a MAIOR PALAVRA não couber numa linha em max_width (a palavra não pode quebrar).
## O nome nunca encolhe para caber em uma linha: nomes largos quebram em quantas
## linhas precisarem (a caixa reserva a altura real medida).
func _name_font_size(max_width: float) -> int:
	if _boss_name.is_empty() or _name_label == null:
		return Constants.FONT_TITLE
	var font: Font = _name_label.get_theme_font(&"font")
	var longest: String = _longest_word(_boss_name)
	var size: int = Constants.FONT_TITLE
	while size > NAME_FONT_MIN:
		if font.get_string_size(longest, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_width:
			break
		size -= 2
	return size

## Maior palavra do nome (a quebra de linha é por palavra; nenhuma palavra pode estourar a linha).
func _longest_word(text: String) -> String:
	var longest: String = ""
	for word in text.split(" ", false):
		if word.length() > longest.length():
			longest = word
	return longest if not longest.is_empty() else text

func _make_bar(accent: Color, center_x: float, y: float, width: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = accent
	bar.size = Vector2(width, BAR_HEIGHT)
	bar.position = Vector2(center_x - width * 0.5, y)
	bar.pivot_offset = Vector2(width * 0.5, BAR_HEIGHT * 0.5)
	bar.scale.x = 0.0  # varre a partir do centro
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

## Glow radial procedural (sem textura externa): brilho da cor de aura atrás do modelo.
func _make_radial_glow(accent: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(accent.r, accent.g, accent.b, 0.55))
	grad.set_color(1, Color(accent.r, accent.g, accent.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = BACKLIGHT_SIZE
	tex.height = BACKLIGHT_SIZE
	return tex
