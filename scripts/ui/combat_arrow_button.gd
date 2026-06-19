class_name CombatArrowButton
extends BaseButton

# Botão direcional do D-pad de COMBATE, na identidade da protagonista: garra tribal
# pixel-art na paleta da juba (laranja sobre vazio preto, outline duro, cantos retos),
# que flasheia nos tons de CHAMA ao pressionar, pulsa laranja quando a janela de defesa
# abre e explode verde-cristal no acerto perfeito.
#
# Ergonomia: o retângulo do Control cobre o cluster INTEIRO do D-pad (os 4 irmãos se
# sobrepõem) e `_has_point` aceita apenas o gajo (wedge) de 90° da própria direção —
# como um D-pad físico, toda a área do pad é clicável, dividida em quadrantes, com
# uma zona morta pequena no centro. O visual (plate) é menor que a área de toque.
#
# Este nó é APENAS visual + hit-test. A injeção dual de input, o háptico e o SFX
# permanecem no ControlsHud, dono do contrato com o jogo (mesmo split do FloatingDpad).

# ─── Constants ─────────────────────────────────────
const GRID := 16
# Garra Tribal da Mata — ponta afiada 2px (vs 4px do arrowhead genérico), corpo
# simétrico com D-pixels de profundidade, base V-aberta (dois entalhes divergentes).
# Desenhado apontando para CIMA; as outras direções rotacionam no _draw via _rotated_cell.
# '.'=vazio  'K'=outline preto  'O'=juba clara  'D'=juba escura.
# Tuning visual: xvfb-run -a godot --path . --resolution 393x852
#   -s scripts/tools/preview_combat_dpad.gd -- --out=/tmp/dpad.png [--press=ui_right]
const GLYPH: PackedStringArray = [
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

const GLYPH_PAD_CELLS := 2
const PLATE_BG         := Color(0.04, 0.025, 0.025, 0.92)
const PLATE_BG_PRESSED := Color(0.0, 0.0, 0.0, 0.98)
const PLATE_BG_ACTIVE  := Color(0.06, 0.035, 0.028, 0.95)

# Press: o glifo avança 1.5 células na própria direção (bote, não afundamento).
const PRESS_LUNGE_CELLS := 1.5
const RELEASE_SECONDS   := 0.10
const PERFECT_SECONDS   := 0.14
const MISS_SECONDS      := 0.10
# Anel de impacto: contorno duro expandindo da borda da plate, alpha em degraus.
const RING_SECONDS      := 0.16
const RING_GROW_CELLS   := 2.5
const RING_ALPHA_STEPS  := 4

const _ORIENTATIONS: Dictionary = {
	"ui_up": 0, "ui_right": 1, "ui_down": 2, "ui_left": 3,
}
const _LUNGE_DIRS: Array = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

# ─── State ─────────────────────────────────────────
var action: String = "ui_up":
	set(value):
		action = value
		_orientation = _ORIENTATIONS.get(value, 0)
		queue_redraw()

var _orientation: int = 0
# Geometria local (definida pelo ControlsHud no layout).
var _plate_rect: Rect2 = Rect2()
var _wedge_center: Vector2 = Vector2.ZERO
var _dead_radius: float = 0.0

# Press
var _press_amount: float = 0.0:
	set(value):
		_press_amount = value
		queue_redraw()
var _ring_amount: float = 1.0:
	set(value):
		_ring_amount = value
		queue_redraw()
var _release_tween: Tween = null
var _ring_tween: Tween = null

# Janela de defesa ativa — esta seta é a ação esperada
var _window_open: bool = false
var _window_amount: float = 0.0:
	set(value):
		_window_amount = value
		queue_redraw()
var _window_tween: Tween = null

# Feedback de resultado
var _perfect_amount: float = 0.0:
	set(value):
		_perfect_amount = value
		queue_redraw()
var _miss_amount: float = 0.0:
	set(value):
		_miss_amount = value
		queue_redraw()
var _good_amount: float = 0.0:
	set(value):
		_good_amount = value
		queue_redraw()
var _perfect_tween: Tween = null
var _miss_tween: Tween = null
var _good_tween: Tween = null

# Golpe Carregado: a garra "enche de fogo" enquanto a janela está aberta (espelho
# visual da bolha de timing — só feedback, sem tocar no contrato de input).
var _cortejo_charge: float = 0.0:
	set(value):
		_cortejo_charge = value
		queue_redraw()
var _charge_tween: Tween = null


# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	button_down.connect(_on_visual_press)
	button_up.connect(_on_visual_release)


func _process(_delta: float) -> void:
	# Pulso animado do anel de janela ativa / cintilação da carga: redraw contínuo.
	if _window_amount > 0.001 or _cortejo_charge > 0.001:
		queue_redraw()


# ─── Public API ────────────────────────────────────
## Geometria do botão em coordenadas LOCAIS: plate desenhada, centro do cluster
## (vértice dos gajos) e raio da zona morta central.
func configure(plate_rect: Rect2, wedge_center: Vector2, dead_radius: float) -> void:
	_plate_rect = plate_rect
	_wedge_center = wedge_center
	_dead_radius = dead_radius
	queue_redraw()


## Zera o estado visual de press, janela e resultados.
func clear_feedback() -> void:
	for tw: Tween in [_release_tween, _ring_tween, _window_tween, _perfect_tween, _miss_tween, _good_tween, _charge_tween]:
		if tw != null:
			tw.kill()
	_press_amount = 0.0
	_ring_amount = 1.0
	_window_open = false
	_window_amount = 0.0
	_perfect_amount = 0.0
	_miss_amount = 0.0
	_good_amount = 0.0
	_cortejo_charge = 0.0


## Inicia o "enchimento de fogo" da carga ao longo de `duration` (espelho da bolha).
func start_cortejo_charge(duration: float) -> void:
	if _charge_tween != null:
		_charge_tween.kill()
	_cortejo_charge = 0.0
	_charge_tween = create_tween()
	_charge_tween.tween_property(self, "_cortejo_charge", 1.0, maxf(0.05, duration))


## Apaga o fogo da carga (soltou/estourou/expirou).
func clear_cortejo_charge() -> void:
	if _charge_tween != null:
		_charge_tween.kill()
	_cortejo_charge = 0.0


## Ativa/desativa o estado de janela de defesa (esta seta = ação esperada agora).
func set_window_open(on: bool) -> void:
	_window_open = on
	if _window_tween != null:
		_window_tween.kill()
	_window_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_window_tween.tween_property(self, "_window_amount", 1.0 if on else 0.0, 0.18)


## Flash verde-cristal: acerto perfeito (0.14s expo-out).
func flash_perfect() -> void:
	if _perfect_tween != null:
		_perfect_tween.kill()
	_perfect_amount = 1.0
	_perfect_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_perfect_tween.tween_property(self, "_perfect_amount", 0.0, PERFECT_SECONDS)


## Flash âmbar: bloqueio parcial (faixa GOOD), entre o verde do perfeito e o sangue do erro.
func flash_good() -> void:
	if _good_tween != null:
		_good_tween.kill()
	_good_amount = 1.0
	_good_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_good_tween.tween_property(self, "_good_amount", 0.0, PERFECT_SECONDS)


## Pulso sangue escuro: erro ou janela expirada (0.10s sine-out).
func flash_miss() -> void:
	if _miss_tween != null:
		_miss_tween.kill()
	_miss_amount = 1.0
	_miss_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_miss_tween.tween_property(self, "_miss_amount", 0.0, MISS_SECONDS)


# ─── Hit-test em gajo (wedge) ──────────────────────
func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	var v := point - _wedge_center
	if v.length() < _dead_radius:
		return false
	match _orientation:
		0: return -v.y >= absf(v.x)
		1: return v.x >= absf(v.y)
		2: return v.y >= absf(v.x)
		_: return -v.x >= absf(v.y)


# ─── Feedback visual ───────────────────────────────
func _on_visual_press() -> void:
	if _release_tween != null:
		_release_tween.kill()
	if _ring_tween != null:
		_ring_tween.kill()
	# Resposta instantânea no press (zero latência percebida); o anel expande.
	_press_amount = 1.0
	_ring_amount = 0.0
	_ring_tween = create_tween()
	_ring_tween.tween_property(self, "_ring_amount", 1.0, RING_SECONDS)


func _on_visual_release() -> void:
	if _release_tween != null:
		_release_tween.kill()
	_release_tween = create_tween()
	_release_tween.set_trans(Tween.TRANS_SINE)
	_release_tween.set_ease(Tween.EASE_OUT)
	_release_tween.tween_property(self, "_press_amount", 0.0, RELEASE_SECONDS)


# ─── Draw ──────────────────────────────────────────
func _draw() -> void:
	if _plate_rect.size.x <= 0.0:
		return
	var border_w := float(Constants.UI_BORDER_WIDTH)
	var cell := (_plate_rect.size.x - border_w * 2.0) / float(GRID + GLYPH_PAD_CELLS * 2)

	# ── Plate: base. Janela ativa clareia o background e aquece a borda. ──
	var border_color := Constants.COLOR_JUBA_DARK.lerp(Constants.COLOR_JUBA, _press_amount)
	if _window_amount > 0.0:
		border_color = border_color.lerp(Constants.COLOR_CHAMA_HOT, _window_amount * 0.6)
	draw_rect(_plate_rect, border_color, true)
	var bg := PLATE_BG.lerp(PLATE_BG_PRESSED, _press_amount)
	if _window_amount > 0.0:
		bg = bg.lerp(PLATE_BG_ACTIVE, _window_amount)
	draw_rect(_plate_rect.grow(-border_w), bg, true)

	# ── Golpe Carregado: fogo subindo de baixo pra cima + borda flamejante. ──
	if _cortejo_charge > 0.001:
		var inner := _plate_rect.grow(-border_w)
		var flick := sin(Time.get_ticks_msec() * 0.001 * TAU * 7.0) * 0.5 + 0.5
		var fill_h := inner.size.y * _cortejo_charge
		var fill := Constants.COLOR_AMBER.lerp(Constants.COLOR_CHAMA_HOT, flick)
		fill.a = 0.55
		draw_rect(Rect2(inner.position.x, inner.position.y + inner.size.y - fill_h, inner.size.x, fill_h), fill, true)
		var fire_border := Constants.COLOR_CHAMA_HOT
		fire_border.a = 0.5 + 0.45 * _cortejo_charge
		draw_rect(_plate_rect, fire_border, false, maxf(border_w * 0.7, 1.0))

	# ── Anel pulsante de janela ativa (3 Hz) ──
	if _window_amount > 0.001:
		var t := Time.get_ticks_msec() * 0.001
		var pulse_alpha := (sin(t * TAU * 3.0) * 0.4 + 0.6) * _window_amount * 0.7
		var pulse_color := Constants.COLOR_JUBA
		pulse_color.a = pulse_alpha
		draw_rect(_plate_rect.grow(-border_w * 1.5), pulse_color, false, 1.0)

	# ── Anel de impacto de press: alpha quantizado, cor depende do resultado ──
	if _ring_amount < 1.0:
		var alpha := floorf((1.0 - _ring_amount) * RING_ALPHA_STEPS) / float(RING_ALPHA_STEPS)
		if alpha > 0.0:
			var ring := _plate_rect.grow(_ring_amount * RING_GROW_CELLS * cell)
			var ring_color := Constants.COLOR_CRYSTAL_GLOW if _perfect_amount > 0.001 else Constants.COLOR_JUBA
			ring_color.a = alpha
			draw_rect(ring, ring_color, false, maxf(border_w * 0.5, 1.0))

	# ── Overlay de resultado ──
	if _perfect_amount > 0.001:
		var gc := Constants.COLOR_CRYSTAL_GLOW
		gc.a = _perfect_amount * 0.55
		draw_rect(_plate_rect.grow(-border_w), gc, true)
	if _good_amount > 0.001:
		var ac := Constants.COLOR_GOOD
		ac.a = _good_amount * 0.45
		draw_rect(_plate_rect.grow(-border_w), ac, true)
	if _miss_amount > 0.001:
		var bc := Constants.COLOR_BLOOD
		bc.a = _miss_amount * 0.45
		draw_rect(_plate_rect.grow(-border_w), bc, true)

	# ── Glifo: célula a célula, rotacionado para a direção; no press, troca a paleta
	# para CHAMA e avança ("bote") na direção do comando. Janela ativa aquece levemente. ──
	var bright := Constants.COLOR_JUBA.lerp(Constants.COLOR_CHAMA_CORE, _press_amount)
	var dark := Constants.COLOR_JUBA_DARK.lerp(Constants.COLOR_CHAMA_HOT, _press_amount)
	if _window_amount > 0.0:
		bright = bright.lerp(Constants.COLOR_CHAMA_CORE, _window_amount * 0.3)
		dark = dark.lerp(Constants.COLOR_CHAMA_HOT, _window_amount * 0.3)
	var lunge: Vector2 = _LUNGE_DIRS[_orientation] * (PRESS_LUNGE_CELLS * cell * _press_amount)
	var origin := _plate_rect.position + Vector2.ONE * (border_w + GLYPH_PAD_CELLS * cell) + lunge
	# Overlap mínimo entre células vizinhas: mata as emendas de float sem borrar.
	var cell_size := Vector2.ONE * (cell + 0.5)

	for r in GRID:
		var row := GLYPH[r]
		for c in GRID:
			var ch := row[c]
			if ch == ".":
				continue
			var color: Color
			match ch:
				"O": color = bright
				"D": color = dark
				_: color = Color.BLACK
			var cell_pos := _rotated_cell(r, c)
			draw_rect(Rect2(origin + cell_pos * cell, cell_size), color, true)


## Mapeia a célula (r, c) do glifo "para cima" na posição (x, y) da orientação atual.
func _rotated_cell(r: int, c: int) -> Vector2:
	match _orientation:
		1: return Vector2(float(GRID - 1 - r), float(c))
		2: return Vector2(float(GRID - 1 - c), float(GRID - 1 - r))
		3: return Vector2(float(r), float(GRID - 1 - c))
		_: return Vector2(float(c), float(r))
