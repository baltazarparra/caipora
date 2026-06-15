extends SceneTree

## Preview dev-only: compara a TimingBubble (anel de ataque vermelho) sob o
## CanvasModulate REAL da arena da Fase 3 — esquerda SEM ganho (comportamento
## antigo), direita COM o ganho de Constants.feedback_gain_for_phase(3). Demonstra
## que o feedback volta a ser legível sem clarear o fundo. Usa SubViewport para
## captura determinística (independe do tamanho de janela/WSLg). Precisa de DISPLAY.
## Uso: godot --path . -s scripts/tools/preview_curupira_feedback.gd -- --out=/tmp/curupira.png

const MODULATE_P3 := Color(0.18, 0.45, 0.22)  # = scenes/arena/arena_phase3.tscn
const SIZE := Vector2i(640, 360)

var _out: String = "/tmp/curupira_feedback.png"
var _frames: int = 0
var _vp: SubViewport
var _left: TimingBubble
var _right: TimingBubble

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	# Fundo escuro (como o overlay Dim da fase) para o contraste ser honesto.
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.09, 0.05)
	bg.size = Vector2(SIZE)
	_vp.add_child(bg)

	# CanvasModulate real da Fase 3: multiplica tudo na layer 0 do viewport.
	var cm := CanvasModulate.new()
	cm.color = MODULATE_P3
	_vp.add_child(cm)

	_left = TimingBubble.new()
	_left.position = Vector2(170, 185)
	_vp.add_child(_left)
	# _left fica sem ganho (identidade) = comportamento antigo.

	_right = TimingBubble.new()
	_right.position = Vector2(470, 185)
	_vp.add_child(_right)
	_right.set_color_gain(Constants.feedback_gain_for_phase(3))

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		# Janela de ataque (vermelho), o canal que o modulate verde mais esmaga.
		_left.show_bubble(_left.position, 0.8, 0.65, 0.85, false, Color.TRANSPARENT, "up")
		_right.show_bubble(_right.position, 0.8, 0.65, 0.85, false, Color.TRANSPARENT, "up")
	if _frames >= 46:
		# ~0.73s decorrido → dentro da janela perfeita (anel/seta no brilho máximo).
		var img: Image = _vp.get_texture().get_image()
		img.save_png(_out)
		print("[preview] saved ", _out, "  (esquerda=sem ganho, direita=com ganho)")
		return true
	return false
