class_name CortejoApparition
extends Node2D

## VFX do Cortejo dos Encantados (etapas 4 e 5 do conceito). Cada elo LANDADO
## convoca o encantado libertado daquela fase: o SEU sprite canônico cruza a arena
## como uma aparição translúcida, tingida na aura do chefe (glow aditivo), golpeia o
## invasor e se desfaz. Um fio de luz ("trilha de cortejo") liga os pontos de
## impacto à medida que a corrente cresce. A Caipora laranja segue sendo a âncora:
## os espíritos entram, batem e somem nas SUAS paletas — verde só no Curupira.
## Ver docs/CONCEITO-corrente-encantados.md §5–6.

# ─── Constants ─────────────────────────────────────
const SPIRIT_FRAMES: Dictionary = {
	1: "res://assets/sprites/mula_sprite_frames.tres",
	2: "res://assets/sprites/boitata_sprite_frames.tres",
	3: "res://assets/sprites/curupira_sprite_frames.tres",
	4: "res://assets/sprites/saci_sprite_frames.tres",
}
## Aura por fase (RGB; o alpha de aparição é fixo abaixo). Verde só no Curupira.
const SPIRIT_AURA: Dictionary = {
	1: Constants.COLOR_AURA_MULA,
	2: Constants.COLOR_AURA_BOITATA,
	3: Constants.COLOR_AURA_CURUPIRA,
	4: Constants.COLOR_AURA_SACI,
}

const SPIRIT_HEIGHT: float = 92.0       # altura-alvo do espírito na tela
const SPIRIT_ALPHA: float = 0.78        # aparição translúcida
const SWEEP_IN: float = 0.16            # entra investindo
const SWEEP_OUT: float = 0.22           # dissolve
const SIDE_OFFSET: float = 150.0        # distância lateral de entrada
const TRAIL_WIDTH: float = 2.5

# ─── State ─────────────────────────────────────────
var _impacts: Array[Vector2] = []
var _trail_alpha: float = 0.0
var _color_gain: Color = Color(1, 1, 1)

# ─── Lifecycle ─────────────────────────────────────
func _ready() -> void:
	z_index = 9   # atrás da bolha/anel (z 10), à frente dos atores
	visible = false

# ─── Public API ────────────────────────────────────
## Abre uma nova corrente: zera a trilha.
func begin() -> void:
	_impacts.clear()
	_trail_alpha = 0.0
	visible = true
	queue_redraw()

## Convoca o espírito da fase `phase` para golpear em `target`, entrando PELA direção
## do chamado `action` (ui_up sobe de baixo, ui_right vem da esquerda, etc.) — coesão
## tátil↔visual: o espírito vem do lado que você tocou.
func strike(phase: int, target: Vector2, action: String) -> void:
	visible = true
	_impacts.append(target)
	_trail_alpha = 1.0
	queue_redraw()
	var ghost := _build_ghost(phase)
	if ghost == null:
		return
	add_child(ghost)
	# Vetor de entrada: começa deslocado na direção OPOSTA ao movimento e investe até
	# o alvo (ui_up → entra de baixo subindo; ui_right → da esquerda; etc.).
	var dir: Vector2 = _entry_dir(action)
	ghost.position = target - dir * SIDE_OFFSET
	if dir.x != 0.0:
		ghost.scale.x = absf(ghost.scale.x) * signf(dir.x)  # encara a direção do avanço
	var overshoot: Vector2 = target + dir * 12.0
	var t := create_tween()
	t.tween_property(ghost, "position", overshoot, SWEEP_IN) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ghost, "modulate:a", 0.0, SWEEP_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(ghost.queue_free)

## Direção do AVANÇO da aparição (coords de tela: Y+ = baixo) a partir do chamado.
func _entry_dir(action: String) -> Vector2:
	match action:
		"ui_up": return Vector2.UP
		"ui_down": return Vector2.DOWN
		"ui_left": return Vector2.LEFT
		"ui_right": return Vector2.RIGHT
		_: return Vector2.UP

## Encerra a corrente: a trilha esmaece.
func finish() -> void:
	var t := create_tween()
	t.tween_property(self, "_trail_alpha", 0.0, 0.35)
	t.tween_callback(func() -> void:
		_impacts.clear()
		visible = false)

func set_color_gain(gain: Color) -> void:
	_color_gain = gain

# ─── Private ───────────────────────────────────────
func _build_ghost(phase: int) -> AnimatedSprite2D:
	var path: String = SPIRIT_FRAMES.get(phase, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var frames: SpriteFrames = load(path)
	if frames == null or not frames.has_animation(&"idle"):
		return null
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = frames
	ghost.animation = &"idle"
	ghost.centered = true
	ghost.material = Constants.ADDITIVE_MATERIAL   # glow aditivo da aparição
	var aura: Color = SPIRIT_AURA.get(phase, Constants.COLOR_AMBER)
	ghost.modulate = Color(aura.r, aura.g, aura.b, SPIRIT_ALPHA)
	var tex := frames.get_frame_texture(&"idle", 0)
	if tex != null and tex.get_height() > 0:
		var s: float = SPIRIT_HEIGHT / float(tex.get_height())
		ghost.scale = Vector2(s, s)
	ghost.play(&"idle")
	return ghost

func _draw() -> void:
	if _trail_alpha <= 0.01 or _impacts.size() < 2:
		return
	# Fio de luz ligando os impactos: a corrente do cortejo se formando.
	var col := Color(Constants.COLOR_CHAMA_HOT.r, Constants.COLOR_CHAMA_HOT.g,
		Constants.COLOR_CHAMA_HOT.b, _trail_alpha * 0.85)
	col = Color(col.r * _color_gain.r, col.g * _color_gain.g, col.b * _color_gain.b, col.a)
	for i: int in range(_impacts.size() - 1):
		draw_line(to_local(_impacts[i]), to_local(_impacts[i + 1]), col, TRAIL_WIDTH)
		draw_circle(to_local(_impacts[i + 1]), TRAIL_WIDTH * 1.4, col)
