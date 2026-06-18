class_name CortejoBeatTrack
extends CanvasLayer

## Faixa de leitura do Batuque do Cortejo: uma fileira de "pips" com os glifos
## direcionais da sequência (↑→↓←), estilo Patapon/Guitar Hero. Mostra o que vem
## (preview esmaecido), destaca o chamado atual, acende no acerto / apaga no erro, e
## PULSA no tempo (count-in + cadência) — é a camada que torna o ritmo legível.
## Desenho via o sinal `draw` de um Control interno (mantém uma classe por arquivo).
## Reusa o glifo de TimingBubble (ARROW_GLYPH/ARROW_GRID).

# ─── Constants ─────────────────────────────────────
const LAYER: int = 56            # acima da Atmosphere (50), abaixo de OptionsPanel (60)
const CELL: float = 1.7          # px por célula do glifo → ~27px por pip
const PIP_GAP: float = 18.0
const TOP_FRACTION: float = 0.14 # altura da faixa (fração do viewport)

const STATE_PENDING: int = 0
const STATE_HIT: int = 1
const STATE_MISS: int = 2

# ─── State ─────────────────────────────────────────
var _panel: Control
var _calls: Array[String] = []
var _states: Array[int] = []
var _current: int = -1
var _pulse: float = 0.0
var _color_gain: Color = Color(1, 1, 1)

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	layer = LAYER
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_redraw)
	add_child(_panel)
	visible = false

# ─── Public API ────────────────────────────────────
func set_color_gain(gain: Color) -> void:
	_color_gain = gain

## Inicia a faixa com a sequência de chamados (ações ui_*). Tudo pendente.
func setup(calls: Array[String]) -> void:
	_calls = calls.duplicate()
	_states.clear()
	for _c: String in _calls:
		_states.append(STATE_PENDING)
	_current = -1
	visible = not _calls.is_empty()
	_queue()

## Marca qual chamado está soando agora (destaque + pulso).
func set_current(index: int) -> void:
	_current = index
	pulse()

## Resultado do chamado `index`: aceso (acerto) ou apagado (erro).
func mark(index: int, hit: bool) -> void:
	if index >= 0 and index < _states.size():
		_states[index] = STATE_HIT if hit else STATE_MISS
	_queue()

## Pulso no tempo (count-in e cadência).
func pulse() -> void:
	_pulse = 1.0
	var t := create_tween()
	t.tween_method(_set_pulse, 1.0, 0.0, Constants.CORTEJO_BEAT_SECS * 0.5)
	_queue()

func finish() -> void:
	var t := create_tween()
	t.tween_property(self, "_pulse", 0.0, 0.2)
	t.tween_callback(func() -> void: visible = false)

# ─── Private ───────────────────────────────────────
func _set_pulse(v: float) -> void:
	_pulse = v
	_queue()

func _queue() -> void:
	if _panel != null:
		_panel.queue_redraw()

func _redraw(_ignored: Variant = null) -> void:
	if _calls.is_empty():
		return
	var vp: Vector2 = _panel.size
	var n: int = _calls.size()
	var pip_w: float = TimingBubble.ARROW_GRID * CELL
	var total: float = pip_w * n + PIP_GAP * (n - 1)
	var x0: float = (vp.x - total) * 0.5
	var cy: float = vp.y * TOP_FRACTION
	for i: int in range(n):
		var center := Vector2(x0 + i * (pip_w + PIP_GAP) + pip_w * 0.5, cy)
		var emphasis: float = (1.0 + _pulse * 0.35) if i == _current else 1.0
		_draw_pip(center, _calls[i], _states[i], i == _current, emphasis)

func _draw_pip(center: Vector2, action: String, state: int, is_current: bool, emphasis: float) -> void:
	var alpha: float = 0.30
	var col := Constants.COLOR_AMBER
	match state:
		STATE_HIT:
			col = Constants.COLOR_CHAMA_HOT
			alpha = 0.95
		STATE_MISS:
			col = Constants.COLOR_PARTICLE_FAIL
			alpha = 0.30
		_:
			alpha = 0.85 if is_current else 0.35
	var cell: float = CELL * emphasis
	var grid: int = TimingBubble.ARROW_GRID
	var origin: Vector2 = center - Vector2(grid, grid) * cell * 0.5
	var cs: Vector2 = Vector2.ONE * (cell + 0.4)
	var bright := _g(Color(col.r, col.g, col.b, alpha))
	var dark := _g(Color(Constants.COLOR_JUBA_DARK.r, Constants.COLOR_JUBA_DARK.g, Constants.COLOR_JUBA_DARK.b, alpha * 0.7))
	var outline := Color(0.0, 0.0, 0.0, alpha)
	var glyph: PackedStringArray = TimingBubble.ARROW_GLYPH
	var hint := _action_to_hint(action)
	for r: int in grid:
		var row: String = glyph[r]
		for c: int in grid:
			var ch: String = row[c]
			if ch == ".":
				continue
			var pc: Color
			match ch:
				"O": pc = bright
				"D": pc = dark
				_:   pc = outline
			var rc := _rotate_cell(r, c, grid, hint)
			_panel.draw_rect(Rect2(origin + rc * cell, cs), pc, true)

func _action_to_hint(action: String) -> String:
	match action:
		"ui_right": return "right"
		"ui_left": return "left"
		"ui_down": return "down"
		_: return "up"

## Mesma rotação do glifo UP usada por TimingBubble._glyph_rotated_cell.
func _rotate_cell(r: int, c: int, grid: int, hint: String) -> Vector2:
	var g: int = grid - 1
	match hint:
		"right": return Vector2(float(g - r), float(c))
		"down": return Vector2(float(g - c), float(g - r))
		"left": return Vector2(float(r), float(g - c))
		_: return Vector2(float(c), float(r))

func _g(c: Color) -> Color:
	return Color(c.r * _color_gain.r, c.g * _color_gain.g, c.b * _color_gain.b, c.a)
