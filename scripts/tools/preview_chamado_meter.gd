extends SceneTree

## Preview do medidor de carga do Cortejo "O Chamado" (TimingBubble em modo carga).
## Captura o medidor num ponto de carga (--at=fração) para inspeção visual sem device.
##
##   xvfb-run -a ~/.local/bin/godot --path . --resolution 520x520 \
##       -s scripts/tools/preview_chamado_meter.gd -- --out=/tmp/chamado.png --at=0.87
##
## Frações de referência: 0.30 (FRACO) · 0.72 (ombro GOOD) · 0.87 (banda SOLTE) ·
## 0.98 (QUEIMA/overcharge). --links=N controla os notches de espírito (default 4).

var _out: String = "/tmp/chamado_meter.png"
var _at: float = 0.87
var _links: int = 4
var _frames: int = 0
var _bubble: TimingBubble = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr("--out=".length())
		elif arg.begins_with("--at="):
			_at = float(arg.substr("--at=".length()))
		elif arg.begins_with("--links="):
			_links = int(arg.substr("--links=".length()))


func _process(_delta: float) -> bool:
	_frames += 1
	# Frame 1: monta a cena (autoloads já rodaram _ready). Ver gotcha #14.
	if _frames == 1:
		var vp: Vector2 = root.get_visible_rect().size
		var bg := ColorRect.new()
		bg.color = Color(0.06, 0.04, 0.05, 1.0)
		bg.size = vp
		root.add_child(bg)
		_bubble = TimingBubble.new()
		_bubble.set_process(false)   # dirigimos o estado à mão (sem avançar a carga)
		_bubble.scale = Vector2(4.0, 4.0)
		root.add_child(_bubble)
		_bubble.show_bubble(vp * 0.5, Constants.CHAMADO_CHARGE_SEC,
			Constants.CHAMADO_RELEASE_START, Constants.CHAMADO_RELEASE_END,
			false, Constants.COLOR_CHAMA_HOT, "up", true,
			Constants.CHAMADO_GOOD_START, Constants.CHAMADO_RELEASE_END, _links)
		_bubble._elapsed = _at * Constants.CHAMADO_CHARGE_SEC   # congela na fração pedida
		_bubble.queue_redraw()
	if _frames >= 3:
		var tex: ViewportTexture = root.get_texture()
		if tex == null:
			push_error("preview_chamado_meter precisa de display (Xvfb/WSLg), não --headless")
			return true
		tex.get_image().save_png(_out)
		print("saved ", _out, " (at=", _at, ", links=", _links, ")")
		return true
	return false
