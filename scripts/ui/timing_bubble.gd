class_name TimingBubble
extends Node2D

# ─── Signals ───────────────────────────────────────
signal vulnerable_entered
## Emitido uma vez ao ENTRAR na faixa GOOD (antes do perfeito): cue "prepare → AGORA"
## (modelo Patapon). O perfeito segue sinalizado por vulnerable_entered.
signal approach_entered

# ─── Constants ─────────────────────────────────────
## Anel-alvo fixo: marca a janela de acerto. O jogador aperta quando o anel
## convergente se sobrepõe a ele.
const RADIUS_TARGET: float = 40.0
## Maior extensão visual da bolha (raio inicial do anel convergente). Lido
## externamente por arena_manager.gd (_is_under_dpad) para afastar a bolha do
## D-pad — manter como o maior raio que a bolha desenha.
const RADIUS_MAX: float = RADIUS_TARGET * 1.9
## Raio final do colapso na falha (anel encolhe para dentro do alvo).
const RADIUS_COLLAPSE: float = RADIUS_TARGET * 0.12

const PHASE_ACTIVE: int = 0
const PHASE_IDLE: int = 1

## Flash verde-cristal ao ENTRAR na janela perfeita ("o cristal carregou").
const FLASH_S: float = 0.12
## Halo âmbar (faixa GOOD = bloqueio parcial) desenhado por fora do anel-alvo.
const GOOD_HALO_GAP: float = 8.0

# ─── Glifo direcional — Garra Tribal 16×16 (mesmo de CombatArrowButton) ────
# K = outline preto  O = juba clara  D = juba escura  . = transparente
# Exibido a ARROW_CELL px por célula → ~60×60 px totais.
# Rotação por _key_hint usa o mesmo padrão do CombatArrowButton:
#   up    → (c, r)          right → (GRID-1-r, c)
#   down  → (GRID-1-c, GRID-1-r)  left → (r, GRID-1-c)
const ARROW_GLYPH: PackedStringArray = [
	"................",   # 0
	".......KK.......",   # 1 — ponta 2 px
	"......KOOK......",   # 2
	"....KKOOOOKK....",   # 3
	"...KKOOOOOOKK...",   # 4
	"..KKOOODDOOOKK..",   # 5
	".KKOOODDDDOOOKK.",   # 6
	"KKOOODDKKDDOOOKK",   # 7 — ombros totais
	"KKKK.KOOODK.KKKK",   # 8 — entalhe tribal (arrowhead → shaft)
	".....KOOODK.....",   # 9 — shaft
	".....KOOODK.....",   # 10
	".....KOOODK.....",   # 11
	".....KOOODK.....",   # 12
	".....KDDDDK.....",   # 13 — base com sombra
	".....KKKKKK.....",   # 14 — base fechada
	"................",   # 15
]
const ARROW_GRID: int = 16
const ARROW_CELL: float = 3.75   # px por célula → 60 px total (16 × 3.75)
const ARROW_NUDGE_DIST: float = 4.0   # px de "toque" na direção durante a janela

# ─── State ─────────────────────────────────────────
var _duration: float = 0.8
var _perfect_start: float = 0.65
var _perfect_end: float = 0.85
## Faixa GOOD (bloqueio parcial). Default = faixa perfeita ⇒ sem halo (binário/Cortejo).
var _good_start: float = 0.65
var _good_end: float = 0.85
var _good_alpha: float = 0.0
var _approach_emitted: bool = false
var _elapsed: float = 0.0
var _phase: int = PHASE_IDLE
var _outer_radius: float = RADIUS_MAX
var _color: Color = Color(1, 1, 1, 0.2)
var _target_alpha: float = 0.25
var _arrow_alpha: float = 0.35
var _vuln_emitted: bool = false
var _burst_timer: float = -1.0
var _burst_fail: bool = false
var _burst_good: bool = false
var _burst_radius: float = RADIUS_TARGET
var _burst_color: Color = Color(1, 1, 1, 0.9)
var _defense_mode: bool = false
var _vuln_color: Color = Color.TRANSPARENT
var _key_hint: String = "up"
var _frozen: bool = false
var _flash_timer: float = 0.0
var _arrow_offset: Vector2 = Vector2.ZERO
## Modo GOLPE CARREGADO: a seta vira medidor de fogo (enche com a carga), com bordas
## flamejantes. A zona perfeita = janela de SOLTAR. Tudo em immediate-mode (sem nós).
var _charge_mode: bool = false
## Ganho de cor aplicado no desenho para compensar o CanvasModulate escuro de
## certas fases (ver Constants.feedback_gain_for_phase). Identidade = sem efeito.
var _color_gain: Color = Color(1, 1, 1)


# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if _frozen:
		return
	if _burst_timer >= 0.0:
		_process_burst(delta)
		return

	if _phase == PHASE_IDLE:
		return

	if _charge_mode:
		_process_charge(delta)
		return

	_flash_timer = maxf(0.0, _flash_timer - delta)

	_elapsed += delta
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var pc: float = (_perfect_start + _perfect_end) * 0.5

	# Anel convergente: encolhe de RADIUS_MAX até o alvo no centro da zona perfeita,
	# depois colapsa para dentro.
	if progress <= pc:
		var t: float = progress / maxf(pc, 0.0001)
		_outer_radius = lerpf(RADIUS_MAX, RADIUS_TARGET, t)
	else:
		var t: float = (progress - pc) / maxf(1.0 - pc, 0.0001)
		_outer_radius = lerpf(RADIUS_TARGET, RADIUS_COLLAPSE, t)

	var in_perfect: bool = progress >= _perfect_start and progress <= _perfect_end
	if in_perfect and not _vuln_emitted:
		_vuln_emitted = true
		_flash_timer = FLASH_S
		vulnerable_entered.emit()
	# Faixa GOOD (bloqueio parcial): cue de aproximação ao entrar + halo âmbar aceso.
	var in_good: bool = progress >= _good_start and progress <= _good_end
	if in_good and not _approach_emitted:
		_approach_emitted = true
		approach_entered.emit()
	if in_good and not in_perfect:
		_good_alpha = 0.55
	elif in_perfect:
		_good_alpha = 0.30
	else:
		_good_alpha = maxf(0.0, _good_alpha - delta * 3.0)

	# Cor do anel convergente + brilho do alvo + opacidade da seta.
	var mode_color: Color = _mode_color()
	if in_perfect:
		var t: float = (progress - _perfect_start) / maxf(_perfect_end - _perfect_start, 0.0001)
		var pulse: float = sin(t * TAU * 4.0) * 0.1
		_color = Color(mode_color.r, mode_color.g, mode_color.b, 0.95)
		_target_alpha = 0.7 + pulse
		_arrow_alpha = 0.95
		# Toque gentil na direção da ação: 3 Hz, sempre levemente à frente.
		var nudge: float = (sin(_elapsed * TAU * 3.0) * 0.3 + 0.7) * ARROW_NUDGE_DIST
		_arrow_offset = _key_hint_to_vec() * nudge
	elif progress < _perfect_start:
		var t: float = progress / maxf(_perfect_start, 0.0001)
		_color = Color(mode_color.r, mode_color.g, mode_color.b, lerpf(0.45, 0.9, t))
		_target_alpha = 0.25
		_arrow_alpha = 0.35
		_arrow_offset = Vector2.ZERO
	else:
		# Pós-janela: anel colapsando, esmaece.
		var t: float = (progress - _perfect_end) / maxf(1.0 - _perfect_end, 0.0001)
		_color = Color(mode_color.r * 0.5, mode_color.g * 0.2, mode_color.b * 0.2, lerpf(0.7, 0.0, t))
		_target_alpha = lerpf(0.25, 0.0, t)
		_arrow_alpha = lerpf(0.35, 0.0, t)
		_arrow_offset = Vector2.ZERO

	_color = _flashed(_color)
	queue_redraw()


func _process_burst(delta: float) -> void:
	_burst_timer -= delta
	var t: float = 1.0 - maxf(0.0, _burst_timer / 0.12)
	if _burst_fail:
		_burst_color = Color(0.2, 0.05, 0.05, lerpf(0.8, 0.0, t))
		_burst_radius = lerpf(RADIUS_TARGET * 0.8, RADIUS_TARGET * 0.3, t)
	elif _burst_good:
		# Bloqueio: estouro âmbar de expansão média, entre o sucesso (branco) e a falha.
		var gc: Color = Constants.COLOR_GOOD
		_burst_color = Color(gc.r, gc.g, gc.b, lerpf(0.85, 0.0, t))
		_burst_radius = lerpf(RADIUS_TARGET * 0.8, RADIUS_TARGET * 1.3, t)
	else:
		_burst_color = Color(1, 1, 1, lerpf(0.9, 0.0, t))
		_burst_radius = lerpf(RADIUS_TARGET * 0.8, RADIUS_TARGET * 1.6, t)
	queue_redraw()
	if _burst_timer <= 0.0:
		_phase = PHASE_IDLE
		visible = false


## Modo carga: avança o "enchimento" com o progresso e dispara o cue ao entrar na zona
## de soltar. Sem alocação — só contadores + queue_redraw.
func _process_charge(delta: float) -> void:
	_flash_timer = maxf(0.0, _flash_timer - delta)
	_elapsed += delta
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var in_release: bool = progress >= _perfect_start and progress <= _perfect_end
	if in_release and not _vuln_emitted:
		_vuln_emitted = true
		_flash_timer = FLASH_S
		vulnerable_entered.emit()  # cue "SOLTE!" (timing_alert) + flash verde-cristal
	queue_redraw()


func _draw() -> void:
	if _burst_timer >= 0.0:
		draw_circle(Vector2.ZERO, _burst_radius, _g(_burst_color))
		draw_arc(Vector2.ZERO, _burst_radius, 0.0, TAU, 32, _g(Color(1, 1, 1, _burst_color.a * 0.4)), 1.5)
		return

	if _phase == PHASE_IDLE:
		return

	if _charge_mode:
		_draw_charge()
		return

	# 1. Anel-alvo fixo (a janela de acerto). Acende na zona perfeita.
	var target_col: Color = _flashed(_mode_color())
	draw_circle(Vector2.ZERO, RADIUS_TARGET, _g(Color(target_col.r, target_col.g, target_col.b, _target_alpha * 0.35)))
	draw_arc(Vector2.ZERO, RADIUS_TARGET, 0.0, TAU, 40, _g(Color(target_col.r, target_col.g, target_col.b, _target_alpha)), 2.0)

	# 2. Anel convergente (o timer): encolhe em direção ao alvo.
	draw_arc(Vector2.ZERO, _outer_radius, 0.0, TAU, 40, _g(_color), 2.5)

	# 2b. Halo âmbar = faixa GOOD (bloqueio parcial): aceso quando o input ainda "pega".
	if _good_alpha > 0.01:
		var hc: Color = Constants.COLOR_GOOD
		draw_arc(Vector2.ZERO, RADIUS_TARGET + GOOD_HALO_GAP, 0.0, TAU, 40,
			_g(Color(hc.r, hc.g, hc.b, _good_alpha)), 2.0)

	# 3. Glifo direcional pixel-art: seta 60×60 px com nudge na janela perfeita.
	if _arrow_alpha > 0.01:
		_draw_arrow_glyph(_arrow_alpha, _flashed(_mode_color()))


# ─── Glifo pixel-art ───────────────────────────────
func _draw_arrow_glyph(alpha: float, color: Color) -> void:
	# Origem: canto superior-esquerdo do glifo 12×12 centrado em (0,0) + nudge.
	var half: float = ARROW_GRID * ARROW_CELL * 0.5
	var origin: Vector2 = Vector2(-half, -half) + _arrow_offset
	var cs: Vector2 = Vector2.ONE * (ARROW_CELL + 0.5)  # overlap mínimo anti-seam

	var bright: Color = _g(Color(color.r, color.g, color.b, alpha))
	var dark: Color = _g(Color(
		Constants.COLOR_JUBA_DARK.r, Constants.COLOR_JUBA_DARK.g,
		Constants.COLOR_JUBA_DARK.b, alpha * 0.7))
	var outline: Color = Color(0.0, 0.0, 0.0, alpha)

	for r: int in ARROW_GRID:
		var row: String = ARROW_GLYPH[r]
		for c: int in ARROW_GRID:
			var ch: String = row[c]
			if ch == ".":
				continue
			var col: Color
			match ch:
				"O": col = bright
				"D": col = dark
				_:   col = outline
			var cell_pos: Vector2 = _glyph_rotated_cell(r, c)
			draw_rect(Rect2(origin + cell_pos * ARROW_CELL, cs), col, true)


# ─── Modo carga: medidor de fogo (immediate-mode, sem nós/partículas) ──────
func _draw_charge() -> void:
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var in_release: bool = progress >= _perfect_start and progress <= _perfect_end
	var overcharge: bool = progress > _perfect_end
	var flick: float = sin(_elapsed * TAU * 7.0) * 0.5 + 0.5   # cintilação de chama (barata)

	# 1. Trilho do medidor (apagado) + banda da zona de SOLTAR (chama).
	draw_arc(Vector2.ZERO, RADIUS_TARGET, 0.0, TAU, 40, _g(Color(0.5, 0.3, 0.15, 0.30)), 2.0)
	var a0: float = -PI * 0.5 + _perfect_start * TAU
	var a1: float = -PI * 0.5 + _perfect_end * TAU
	draw_arc(Vector2.ZERO, RADIUS_TARGET, a0, a1, 24,
		_g(Color(Constants.COLOR_CHAMA_HOT.r, Constants.COLOR_CHAMA_HOT.g, Constants.COLOR_CHAMA_HOT.b, 0.55)), 3.0)

	# 2. Arco de carga: enche no sentido horário a partir do topo.
	var fill_end: float = -PI * 0.5 + progress * TAU
	var gauge: Color
	if overcharge:
		gauge = Color(Constants.COLOR_BLOOD.r, 0.1, 0.05, 0.95)
	elif in_release:
		gauge = Constants.COLOR_CRYSTAL_GLOW
	else:
		gauge = Constants.COLOR_AMBER.lerp(Constants.COLOR_CHAMA_HOT, flick)
	draw_arc(Vector2.ZERO, RADIUS_TARGET, -PI * 0.5, fill_end, 36,
		_g(Color(gauge.r, gauge.g, gauge.b, 0.95)), 4.0)

	# 3. Anel de "SOLTE!" pulsando na zona de soltar.
	if in_release:
		var pulse: float = sin(_elapsed * TAU * 4.0) * 0.25 + 0.7
		draw_arc(Vector2.ZERO, RADIUS_TARGET + 6.0 + flick * 3.0, 0.0, TAU, 40,
			_g(Color(Constants.COLOR_CHAMA_CORE.r, Constants.COLOR_CHAMA_CORE.g, Constants.COLOR_CHAMA_CORE.b, pulse)), 2.0)

	# 4. Seta de fogo enchendo de baixo pra cima.
	_draw_charge_glyph(progress, in_release, overcharge, flick)


## A Garra Tribal vira medidor: bordas SEMPRE flamejantes, miolo enche com a carga.
func _draw_charge_glyph(progress: float, in_release: bool, overcharge: bool, flick: float) -> void:
	var half: float = ARROW_GRID * ARROW_CELL * 0.5
	var origin: Vector2 = Vector2(-half, -half)
	var cs: Vector2 = Vector2.ONE * (ARROW_CELL + 0.5)
	var fill_top: float = (1.0 - progress) * float(ARROW_GRID)   # linha r acima = carregado

	var fill_col: Color = Constants.COLOR_CHAMA_CORE.lerp(Constants.COLOR_CHAMA_HOT, flick)
	var edge_col: Color = Constants.COLOR_JUBA.lerp(Constants.COLOR_AMBER, flick)
	if in_release:
		fill_col = Constants.COLOR_CRYSTAL_GLOW
	elif overcharge:
		fill_col = Color(Constants.COLOR_BLOOD.r, 0.12, 0.06)
		edge_col = Color(0.7, 0.1, 0.05)
	var dim: Color = Color(Constants.COLOR_JUBA_DARK.r, Constants.COLOR_JUBA_DARK.g, Constants.COLOR_JUBA_DARK.b, 0.45)

	for r: int in ARROW_GRID:
		var row: String = ARROW_GLYPH[r]
		var charged: bool = float(r) >= fill_top
		for c: int in ARROW_GRID:
			var ch: String = row[c]
			if ch == ".":
				continue
			var col: Color
			if ch == "K":
				col = _g(Color(edge_col.r, edge_col.g, edge_col.b, 0.95))   # borda de fogo
			elif charged:
				col = _g(Color(fill_col.r, fill_col.g, fill_col.b, 0.95))
			else:
				col = _g(dim)
			var cell_pos: Vector2 = _glyph_rotated_cell(r, c)   # cortejo é sempre "up"
			draw_rect(Rect2(origin + cell_pos * ARROW_CELL, cs), col, true)


## Mapeia (row, col) do glifo UP para a posição rotacionada por _key_hint.
func _glyph_rotated_cell(r: int, c: int) -> Vector2:
	var g: int = ARROW_GRID - 1
	match _key_hint:
		"right": return Vector2(float(g - r), float(c))
		"down":  return Vector2(float(g - c), float(g - r))
		"left":  return Vector2(float(r), float(g - c))
		_:       return Vector2(float(c), float(r))  # up


## Vetor unitário na direção de _key_hint (coords de tela: Y+ = baixo).
func _key_hint_to_vec() -> Vector2:
	match _key_hint:
		"down":  return Vector2.DOWN
		"left":  return Vector2.LEFT
		"right": return Vector2.RIGHT
		_:       return Vector2.UP


# ─── Private helpers ───────────────────────────────
## Multiplica só o RGB pelo ganho de cor da fase (preserva alpha). Aplicado no
## momento do desenho para compensar o CanvasModulate escuro de certas fases.
func _g(c: Color) -> Color:
	return Color(c.r * _color_gain.r, c.g * _color_gain.g, c.b * _color_gain.b, c.a)


func _mode_color() -> Color:
	if _vuln_color.a > 0.0:
		return Color(_vuln_color.r, _vuln_color.g, _vuln_color.b, 1.0)
	if _defense_mode:
		return Color(0.1, 0.6, 1.0, 1.0)
	return Color(1.0, 0.15, 0.1, 1.0)


## Lerp para o verde-cristal enquanto o flash da janela perfeita está ativo.
func _flashed(c: Color) -> Color:
	if _flash_timer <= 0.0:
		return c
	var f: float = _flash_timer / FLASH_S
	var g: Color = Constants.COLOR_CRYSTAL_GLOW
	return Color(lerpf(c.r, g.r, f), lerpf(c.g, g.g, f), lerpf(c.b, g.b, f), c.a)


# ─── Public API ────────────────────────────────────
func show_bubble(world_pos: Vector2, duration: float, perfect_start: float, perfect_end: float, defense: bool = false, vuln_color: Color = Color.TRANSPARENT, key_hint: String = "up", charge: bool = false, good_start: float = 0.0, good_end: float = 0.0) -> void:
	_duration = duration
	_perfect_start = perfect_start
	_perfect_end = perfect_end
	# Faixa GOOD: ausente (0.0) ⇒ coincide com a perfeita ⇒ sem halo (binário/Cortejo).
	_good_start = good_start if good_start > 0.0 else perfect_start
	_good_end = good_end if good_end > 0.0 else perfect_end
	_good_alpha = 0.0
	_approach_emitted = false
	_elapsed = 0.0
	_phase = PHASE_ACTIVE
	_burst_timer = -1.0
	_vuln_emitted = false
	_defense_mode = defense
	_vuln_color = vuln_color
	_key_hint = key_hint
	_charge_mode = charge
	_outer_radius = RADIUS_MAX
	_target_alpha = 0.25
	_arrow_alpha = 0.35
	_arrow_offset = Vector2.ZERO
	_flash_timer = 0.0
	_color = Color(1, 1, 1, 0.45)
	position = world_pos
	visible = true
	queue_redraw()


func hide_bubble() -> void:
	_phase = PHASE_IDLE
	_burst_timer = -1.0
	visible = false


func burst_success() -> void:
	_phase = PHASE_IDLE
	_burst_fail = false
	_burst_good = false
	_burst_timer = 0.12
	_burst_color = Color(1, 1, 1, 0.9)
	_burst_radius = RADIUS_TARGET * 0.8
	visible = true
	queue_redraw()


## Estouro de BLOQUEIO (faixa GOOD): expansão âmbar média, entre sucesso e falha.
func burst_good() -> void:
	_phase = PHASE_IDLE
	_burst_fail = false
	_burst_good = true
	_burst_timer = 0.12
	_burst_radius = RADIUS_TARGET * 0.8
	visible = true
	queue_redraw()


func set_frozen(value: bool) -> void:
	_frozen = value


## Ganho de cor para compensar o CanvasModulate da fase (clareia os feedbacks sem
## tocar o fundo). Color(1,1,1) = sem efeito.
func set_color_gain(gain: Color) -> void:
	_color_gain = gain


## Estilhaço de erro: a bolha colapsa (encolhe e escurece) em vez de explodir.
func burst_fail() -> void:
	_phase = PHASE_IDLE
	_burst_fail = true
	_burst_good = false
	_burst_timer = 0.12
	_burst_color = Color(0.2, 0.05, 0.05, 0.8)
	_burst_radius = RADIUS_TARGET * 0.8
	visible = true
	queue_redraw()
