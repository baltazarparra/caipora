class_name HealthBar
extends Control

# Barra de vida custom-drawn (substitui o antigo HealthIcons). Mantém a MESMA lógica de
# dano/vida — apenas troca a camada visual. Largura FIXA: a barra preenche por proporção,
# então nunca sai da tela por mais HP que haja (jogador cresce, bosses chegam a 36 HP).
#
# SÓ A BARRA, sem texto (decisão do dono, 2026-07-01): a identidade vem da cor
# (sangue = jogador, âmbar = inimigo) e do espelhamento; a altura é PADRÃO
# (BAR_H) para todo ator — boss não ganha barra mais alta nem mais larga.
#
# Recursos AAA:
#  - fill que drena com tween suave;
#  - rastro de dano (ghost) que desce devagar atrás do fill, marcando o golpe;
#  - ticks de 1 HP (preserva a leitura discreta que os ícones davam, mas com largura fixa);
#  - pulso quando a vida está baixa.

# ─── Constants ─────────────────────────────────────
const BAR_H: float = 20.0              # altura padrão única (todo ator, todo modo)
const MAX_TICKS: int = 48              # acima disso os ticks viram ruído: omitimos
const FILL_TWEEN: float = 0.18         # drena/enche o fill
const TRAIL_TWEEN: float = 0.45        # o rastro persegue o fill, mais lento
const TRAIL_DELAY: float = 0.12
const LOW_RATIO: float = 0.30          # abaixo disto: pulso de alerta
const PULSE_HZ: float = 2.6

# ─── State ─────────────────────────────────────────
var _max: float = 1.0
var _value: float = 1.0
var _display_value: float = 1.0        # fill animado
var _trail_value: float = 1.0          # ghost de dano animado

var _fill_color: Color = Constants.COLOR_BLOOD
var _track_color: Color = Constants.COLOR_ARENA_BG
var _border_color: Color = Constants.COLOR_BLOOD
var _trail_color: Color = Constants.COLOR_BONE

var _mirrored: bool = false
var _fill_tween: Tween
var _trail_tween: Tween

# Camadas de desenho (Frente E do PRD-performance-refactor-web): o pulso de HP
# baixo redesenha POR FRAME — mas só o fill muda. Fill+sheen vivem numa camada
# filha (2 rects/frame); trilho/ghost (pai) e ticks/borda (overlay) só
# redesenham em mudança de valor/tamanho. Ordem de pintura preservada:
# pai (track+ghost) → fill → overlay (ticks+borda).
var _fill_layer: Control
var _overlay_layer: Control

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_layer = _make_layer()
	_fill_layer.draw.connect(_on_fill_layer_draw)
	_overlay_layer = _make_layer()
	_overlay_layer.draw.connect(_on_overlay_layer_draw)

func _make_layer() -> Control:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	return layer

func _redraw_all() -> void:
	queue_redraw()
	# setup()/configure_size() podem rodar antes do _ready (fora da árvore);
	# camadas novas pintam sozinhas ao entrar na árvore, então só encaminha
	# quando já existem.
	if _fill_layer != null:
		_fill_layer.queue_redraw()
		_overlay_layer.queue_redraw()

# ─── Public API ────────────────────────────────────
## Configura cores/identidade. `max` define a escala; o valor começa cheio.
func setup(max_value: float, fill: Color, track: Color, border: Color) -> void:
	_max = maxf(max_value, 1.0)
	_value = _max
	_display_value = _max
	_trail_value = _max
	_fill_color = fill
	_track_color = track
	_border_color = border
	_trail_color = fill.lightened(0.55)
	_redraw_all()

## Atualiza só o teto (jogador cresce; spawn de inimigo redefine a escala).
func set_max(max_value: float) -> void:
	var new_max: float = maxf(max_value, 1.0)
	if is_equal_approx(new_max, _max):
		return
	_max = new_max
	_value = clampf(_value, 0.0, _max)
	_display_value = clampf(_display_value, 0.0, _max)
	_trail_value = clampf(_trail_value, 0.0, _max)
	_redraw_all()

## Define o valor atual e anima fill + rastro de dano.
func set_value(new_value: float) -> void:
	var clamped: float = clampf(new_value, 0.0, _max)
	var took_damage: bool = clamped < _value
	_value = clamped

	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	_fill_tween = create_tween()
	_fill_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_fill_tween.tween_method(_set_display_value, _display_value, _value, FILL_TWEEN)

	if took_damage:
		# o rastro fica para trás e drena devagar, evidenciando o quanto saiu.
		if _trail_tween != null and _trail_tween.is_valid():
			_trail_tween.kill()
		_trail_tween = create_tween()
		_trail_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_trail_tween.tween_interval(TRAIL_DELAY)
		_trail_tween.tween_method(_set_trail_value, _trail_value, _value, TRAIL_TWEEN)
	else:
		# cura: o rastro acompanha o fill subindo, sem ghost.
		if _trail_tween != null and _trail_tween.is_valid():
			_trail_tween.kill()
		_set_trail_value(_value)

	set_process(_value > 0.0 and _ratio() <= LOW_RATIO)
	_redraw_all()

## Aplica a largura responsiva calculada pela HUD; a altura é o padrão BAR_H.
func configure_size(bar_width: float) -> void:
	custom_minimum_size = Vector2(bar_width, BAR_H)
	size = custom_minimum_size
	_redraw_all()

func total_height() -> float:
	return BAR_H

## Espelha a barra: fill/rastro ancoram na direita e drenam em direção ao centro.
## Usado pela barra do inimigo no header de combate (jogador × adversário).
func set_mirrored(value: bool) -> void:
	if _mirrored == value:
		return
	_mirrored = value
	_redraw_all()

# ─── Internals ─────────────────────────────────────
func _set_display_value(v: float) -> void:
	_display_value = v
	queue_redraw()          # fronteira do ghost depende do fill
	if _fill_layer != null:
		_fill_layer.queue_redraw()

func _set_trail_value(v: float) -> void:
	_trail_value = v
	queue_redraw()

func _ratio() -> float:
	return clampf(_value / _max, 0.0, 1.0) if _max > 0.0 else 0.0

func _bar_rect() -> Rect2:
	return Rect2(0.0, 0.0, size.x, BAR_H)

# ─── Drawing ───────────────────────────────────────
# Pai: trilho + ghost (muda só nos tweens de valor).
func _draw() -> void:
	var bar: Rect2 = _bar_rect()

	# trilho de fundo
	draw_rect(bar, _track_color)

	# rastro de dano (ghost) — atrás do fill, da borda do fill até o trail.
	# Espelhado (inimigo no header de combate): fill/rastro ancoram na DIREITA e
	# drenam em direção ao centro. Só a âncora muda; a lógica de valor é a mesma.
	var fill_w: float = bar.size.x * clampf(_display_value / _max, 0.0, 1.0)
	var trail_w: float = bar.size.x * clampf(_trail_value / _max, 0.0, 1.0)
	var ghost_x: float = (bar.position.x + bar.size.x - trail_w) if _mirrored \
		else (bar.position.x + fill_w)
	if trail_w > fill_w + 0.5:
		var ghost: Color = _trail_color
		ghost.a = 0.7
		draw_rect(Rect2(ghost_x, bar.position.y, trail_w - fill_w, bar.size.y), ghost)

# Camada do fill: a ÚNICA que redesenha por frame no pulso de HP baixo.
func _on_fill_layer_draw() -> void:
	var bar: Rect2 = _bar_rect()
	var fill_w: float = bar.size.x * clampf(_display_value / _max, 0.0, 1.0)
	if fill_w <= 0.5:
		return
	var fill_x: float = (bar.position.x + bar.size.x - fill_w) if _mirrored else bar.position.x
	var fill: Color = _fill_color
	# pulso de alerta quando a vida está baixa
	if _value > 0.0 and _ratio() <= LOW_RATIO:
		var t: float = Time.get_ticks_msec() / 1000.0
		var pulse: float = 0.5 + 0.5 * sin(t * TAU * PULSE_HZ)
		fill = _fill_color.lerp(_fill_color.lightened(0.5), pulse * 0.7)
	_fill_layer.draw_rect(Rect2(fill_x, bar.position.y, fill_w, bar.size.y), fill)
	# brilho superior (faceta) para dar volume
	var sheen: Color = fill.lightened(0.25)
	sheen.a = 0.35
	_fill_layer.draw_rect(Rect2(fill_x, bar.position.y, fill_w, bar.size.y * 0.28), sheen)

# Overlay: ticks + moldura por cima do fill (event-driven).
func _on_overlay_layer_draw() -> void:
	var bar: Rect2 = _bar_rect()
	# ticks de 1 HP (leitura discreta) — só quando não viram ruído
	var units: int = int(round(_max))
	if units > 1 and units <= MAX_TICKS:
		var sep: Color = _track_color.darkened(0.4)
		sep.a = 0.9
		for i: int in range(1, units):
			var tx: float = bar.position.x + bar.size.x * (float(i) / float(units))
			_overlay_layer.draw_line(
				Vector2(tx, bar.position.y + 1.0),
				Vector2(tx, bar.position.y + bar.size.y - 1.0), sep, 1.0)
	# moldura (bordas retas — direção de arte)
	_draw_border(bar, _border_color, Constants.UI_BORDER_WIDTH)

func _draw_border(r: Rect2, color: Color, width: int) -> void:
	var w: float = float(width)
	_overlay_layer.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, w), color)
	_overlay_layer.draw_rect(Rect2(r.position.x, r.position.y + r.size.y - w, r.size.x, w), color)
	_overlay_layer.draw_rect(Rect2(r.position.x, r.position.y, w, r.size.y), color)
	_overlay_layer.draw_rect(Rect2(r.position.x + r.size.x - w, r.position.y, w, r.size.y), color)

func _process(_delta: float) -> void:
	# só roda enquanto a vida está baixa, para animar o pulso — e o pulso vive
	# INTEIRO na camada do fill (2 rects/frame; trilho/ticks/borda ficam quietos).
	if _value <= 0.0 or _ratio() > LOW_RATIO:
		set_process(false)
		_fill_layer.queue_redraw()
		return
	_fill_layer.queue_redraw()
